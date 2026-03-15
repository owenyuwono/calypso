# NPC System Overhaul — Unified Spec

## 1. Overview

This spec covers the complete overhaul of the NPC layer: data model, memory, relationships, conversations, behavioral tendencies, opinion formation, information propagation, schedules, mood, and LLM integration. It synthesizes the Data Layer spec and the Conversation/Social Layer spec into a single authoritative document.

**Key architectural decisions:**

- **Unified NPC entity.** `shop_npc.gd` is deprecated. All NPCs use the same composition tree. A shopkeeper is an NPC whose `NpcIdentity` has `schedule_type: "routine"` and a "make profit" desire. No special-casing.
- **Player = peer agent.** `RelationshipComponent` tracks relationships with all entities including the player. NPCs have no special player-facing logic — the player is just another entity in the world.
- **No world fact pool.** Information lives in NPC memories, not a global state. Facts spread through conversations, with distortion. If nobody told you, you don't know.
- **Multi-party conversations are first-class.** All NPC social interactions go through `ConversationManager`. 1:1 conversations are the minimum case of multi-party.
- **LLM for generation and extraction only.** Turn order, tier progression, memory scoring, and mood decay are all deterministic code. LLM handles dialogue, memory extraction, opinion formation, impression generation, and fuzzy degradation.
- **Three new composition nodes:** `NpcIdentity` (personality, mood, schedule), `RelationshipComponent` (extracted from NpcMemory), and `ConversationManager` (added to game_world).
- **Full spec, no scope trimming.** Prioritization happens at the implementation phase. This document is the complete blueprint.

---

## 2. Unified NPC Entity Architecture

Every NPC (adventurer, shopkeeper, future guard) is the same scene with the same composition tree. Role differentiation comes entirely from data.

**Composition tree:**

```
NPC (CharacterBody3D)
├── StatsComponent
├── InventoryComponent
├── EquipmentComponent
├── CombatComponent
├── ProgressionComponent
├── StaminaComponent
├── AutoAttackComponent
├── EntityVisuals
├── NpcIdentity          ← NEW: personality, mood, schedule, desires, secrets, opinions
├── RelationshipComponent ← NEW: tier-based relationships with impressions and history
├── NpcMemory            ← REWRITTEN: scored memories with GC and fuzzy degradation
├── NpcBrain             ← MODIFIED: conversation-aware, new LLM request handlers
└── NpcBehavior          ← MODIFIED: routes social through ConversationManager
```

**How role is encoded in NpcIdentity:**

| Role | `occupation` | `schedule_type` | Primary desire |
|------|-------------|-----------------|----------------|
| Adventurer | "adventurer" | "goal" | hunt/explore/grow |
| Shopkeeper | "shopkeeper" | "routine" | "make profit, serve customers" |
| Guard (future) | "guard" | "routine" | "keep the town safe" |
| Traveling merchant (future) | "merchant" | "periodic" | "buy low, sell high" |

**`shop_npc.gd` deprecation path:** Replace usages with `npc_base.gd` + appropriate `NpcIdentityDatabase` entry. The shop interaction logic (buy/sell item actions) stays in `NpcActionExecutor` — it is not tied to the NPC type.

### 2.1 Shop NPC Migration

`shop_npc.gd` is a `StaticBody3D` with no navigation, brain, or combat. Migrating it requires more than a file swap.

**Identity data.** `weapon_shop_npc` and `item_shop_npc` get full `NpcIdentityDatabase` entries with `schedule_type: "routine"`. Shop inventory (`shop_items`, `shop_type`) moves to the identity entry as additional fields. `NpcActionExecutor` buy/sell logic reads `shop_type` and `shop_items` from the NPC's identity data instead of the old shop_npc script.

**NpcIdentityDatabase entries (example):**
```
"weapon_shop_npc": {
  occupation: "shopkeeper",
  schedule_type: "routine",
  routine: [
    {start_hour: 7, end_hour: 20, goal: "tend_shop", location: "weapon_shop"},
    {start_hour: 20, end_hour: 7,  goal: "rest",      location: "inn"},
  ],
  shop_type: "weapons",
  shop_items: ["iron_sword", "iron_axe", "iron_mace", "iron_dagger", "iron_staff"],
  desires: [{want: "make profit and arm adventurers well", intensity: "high"}],
  ...
}
```

**`tend_shop` goal.** A new goal handled by `NpcBehavior`: NPC navigates to its shop location and stays there, enabling trade interaction. When a player interacts with a `tend_shop` NPC, the existing buy/sell UI opens — the trigger is the same `E` interact key. `NpcActionExecutor` detects `tend_shop` as a goal and looks up shop inventory from the NPC's identity data.

**WorldState registration.** During NPC registration in `npc_base._ready()`, if identity has a `shop_type` field, it is written to `entity_data["shop_type"]`. This lets `WorldState.get_npc_perception()` and other observers identify shop NPCs without importing identity data directly.

**Navigation.** Former shop NPCs gain full `NavigationAgent3D` navigation (already present in `npc_base.gd`). Their routine keeps them near the shop counter during trading hours; the nav system handles minor idle movement within the shop.

**Implementation task:** Task 6-D (see Wave 6).

---

## 3. NpcIdentity Component

**File:** `scripts/components/npc_identity.gd`

NpcIdentity holds all mutable narrative state for an NPC. It is a Node (not a RefCounted data class) because it connects to GameEvents signals at `_ready()` for mood decay and mood shift triggers.

### Data Model

| Field | Type | Description |
|-------|------|-------------|
| `traits` | Array[String] | e.g. `["competitive", "impatient", "protective"]` |
| `speech_style` | String | Prose description of how this NPC talks |
| `likes` | Array[String] | Things the NPC values or enjoys |
| `dislikes` | Array[String] | Things the NPC dislikes or resents |
| `exaggerates` | bool | Inflates stories for attention |
| `withholds_from_strangers` | bool | Stays vague with low-tier relationships |
| `lies_when` | String | `""` = never; `"cornered"` / `"about_past"` / etc. |
| `avoids_topics` | Array[String] | Topics the NPC deflects or refuses |
| `desires` | Array[Dict] | `{want: String, intensity: "high"/"medium"/"low"}` |
| `secrets` | Array[Dict] | `{fact: String, known_by: Array[String], reveal_condition: String}` |
| `opinions` | Array[Dict] | See opinion data model in Section 10 |
| `mood_emotion` | String | `content / worried / angry / sad / excited / afraid` |
| `mood_energy` | String | `tired / normal / energetic` |
| `baseline_emotion` | String | Resting state for emotion axis |
| `baseline_energy` | String | Resting state for energy axis |
| `schedule_type` | String | `"goal"` / `"routine"` / `"periodic"` |
| `routine` | Array[Dict] | `{start_hour, end_hour, goal, location}` — for schedule_type "routine" |
| `periodic_pattern` | Array[Dict] | `{duration_hours, goal}` — for schedule_type "periodic"; uses game-time hours |
| `age` | String | `"young"` / `"adult"` / `"old"` — narrative only |
| `occupation` | String | "adventurer" / "shopkeeper" / "guard" |

### API

```
func setup(identity_data: Dictionary) -> void
  # Loads all fields from NpcIdentityDatabase entry

func get_personality_prompt() -> String
  # "Traits: competitive, impatient. Likes: fighting, competition. Dislikes: cowardice."

func get_behavioral_prompt() -> String
  # "Tends to exaggerate. Withholds info from strangers. Avoids: his brother."

func get_desires_prompt() -> String
  # "Wants: find his brother (high), become the strongest fighter (medium)"

func get_mood_prompt() -> String
  # "Current mood: worried, energetic"

func get_opinions_for(topic: String, relationship_tier: String) -> Array
  # Returns opinions this NPC would share at this tier
  # Filters by will_share_with vs tier

func get_shareable_secrets(relationship_tier: String) -> Array
  # close/bonded → secrets with reveal_condition satisfied
  # friendly and below → none

func get_secrets_for(partner_id: String) -> Array
  # Returns secrets partner_id already knows about (in known_by)

func shift_mood(emotion: String, energy: String) -> void
  # Updates mood, resets decay timer, emits GameEvents.mood_changed

func add_opinion(topic, take, strength, will_share_with) -> void
  # Upserts by topic

func reveal_secret(secret_index: int, to_partner_id: String) -> void
  # Adds to known_by

func get_current_schedule_goal() -> String
  # routine: checks TimeManager.get_game_hour() against routine entries
  # periodic: tracks elapsed time against pattern
  # goal: returns "" (NPCBehavior owns this)

func _on_game_hour_changed(hour: int) -> void
  # Connected at _ready() to GameEvents.game_hour_changed
  # Each game hour, step mood toward baseline (replaces _process()-based timer)

func _sync() -> void
  # Writes mood_emotion, mood_energy, occupation to WorldState.entity_data
```

### Mood Shift Triggers

NpcIdentity connects to GameEvents at `_ready()`:

| Signal | Mood shift |
|--------|-----------|
| `entity_damaged` (self) | → `worried` or `angry` |
| `entity_died` (self) | → `sad`, `tired` |
| `entity_respawned` (self) | → `content`, `tired` |
| `proficiency_level_up` (self) | → `excited`, `energetic` |

### Mood Decay

Every game hour (`GameEvents.game_hour_changed`), mood steps one value toward baseline. `NpcIdentity` connects to this signal at `_ready()` instead of using a `_process()`-based timer — consistent with GC staggering and schedule resolution. Step order: `angry → content`, `excited → content`, `worried → content`, `tired → normal`, `energetic → normal`. Baseline is never changed by events — only by the NpcIdentityDatabase defaults.

---

## 4. NpcIdentityDatabase

**File:** `scripts/data/npc_identity_database.gd`

Static `RefCounted` with a `const IDENTITIES` dictionary. Loaded once by `NpcIdentity.setup()`.

**Schema per entry:**

```
{
  traits: Array[String],
  speech_style: String,
  likes: Array[String],
  dislikes: Array[String],
  exaggerates: bool,
  withholds_from_strangers: bool,
  lies_when: String,
  avoids_topics: Array[String],
  desires: Array[{want, intensity}],
  secrets: Array[{fact, known_by, reveal_condition}],
  opinions: Array,          # usually [] at start — formed at runtime
  baseline_emotion: String,
  baseline_energy: String,
  age: String,
  occupation: String,
  schedule_type: String,
  routine: Array,           # populated for routine-type NPCs
  periodic_pattern: Array,  # populated for periodic-type NPCs
}
```

**Starting entries (adventurers):**

| NPC | Traits | Tendencies | Avoids | Secret |
|-----|--------|-----------|--------|--------|
| Kael | competitive, impatient, protective | — | "his brother" | Brother disappeared in the dungeon |
| Lyra | curious, careful, scholarly | withholds | — | Was expelled, not graduated |
| Bjorn | boisterous, brave, careless | exaggerates, blurts_secrets | — | — |
| Sera | shrewd, guarded, charming | withholds, lies_when_cornered | "past", "real name" | Not her real name, fleeing royal spy |
| Thane | stoic, dutiful, haunted | withholds, avoids_topic | "the Order", "failure" | Order disbanded because he failed to protect a village |
| Mira | warm, observant, anxious | — | — | — |
| Dusk | quiet, calculating, guilty | withholds, lies_when_cornered, avoids_topic | "old party", "tally marks" | Last party died because he triggered a trap alone |

**Shop NPC entries:**

```
"weapon_shop_npc": {
  occupation: "shopkeeper",
  schedule_type: "routine",
  routine: [{start_hour: 7, end_hour: 20, goal: "tend_shop", location: "weapon_shop"}],
  desires: [{want: "make profit and arm adventurers well", intensity: "high"}],
  ...
}
```

`NpcTraits.BACKSTORIES` and `NpcTraits.VOICE_STYLES` content migrates here. The text is moved, not duplicated.

---

## 5. Memory System

### 5.1 Unified Memory Model

**File:** `scenes/npcs/npc_memory.gd` (rewrite in place)

Single `memories` array replaces the previous `observations` + `key_memories` split. High-importance memories serve the role key_memories previously had.

**Each memory entry:**

| Field | Type | Description |
|-------|------|-------------|
| `fact` | String | "Killed a wolf in the field" |
| `source` | String | `"witnessed"` / `"heard_from:kael"` / `"overheard"` |
| `importance` | String | `"high"` / `"medium"` / `"low"` |
| `emotional` | bool | Permanent score bonus, never goes fuzzy |
| `times_reinforced` | int | Incremented when same fact seen again |
| `timestamp` | float | Game time (TimeManager ticks) |
| `game_day` | int | `TimeManager.get_day()` when created |
| `fuzzy` | bool | True if memory has degraded |
| `fuzzy_text` | String | Degraded version: "I think I fought something in the field" |
| `confidence` | float | `0.0–1.0` (observed=1.0, heard=0.7, heard from liar=0.4) |
| `topic` | String | Category tag: "wolves", "equipment", "town" |
| `shared_with` | Array[String] | entity_ids this fact has been shared with (drives propagation) |

### 5.2 Scoring Formula

```
total_score = (importance_weight
             + recency_bonus
             + (times_reinforced * 3.0)
             + (5.0 if emotional else 0.0)) * confidence

importance_weight: high=10, medium=5, low=2

recency_bonus (game_day delta):
  same day  → +10
  1 day ago → +6
  2-3 days  → +3
  4-7 days  → +1
  older     → +0

confidence multiplier: observed=1.0, heard=0.7, heard_from_liar=0.4
  Uncertain facts (heard from others) naturally score lower than
  directly witnessed facts without needing separate sorting logic.
```

### 5.3 API

```
func add_memory(fact, source, importance, emotional=false, topic="", confidence=1.0) -> void
  # Deduplicates by fact content (exact match → increment times_reinforced)
  # At capacity (MAX_MEMORIES=20): evict lowest-scored memory
  # Emits GameEvents.memory_added(entity_id, fact, importance)

func score_memory(mem: Dictionary) -> float

func get_memories_for_prompt(max_count: int = 5) -> String
  # Top N by score, uses fuzzy_text if fuzzy==true
  # Format: "- [witnessed] Killed a wolf (important)"

func get_memories_about(topic: String) -> Array
  # Substring search across fact + fuzzy_text

func get_facts_about(topic: String, max_count: int = 5) -> Array
  # Returns memories matching topic, sorted by confidence * score

func get_unshared_facts(target_id: String, max_count: int = 3) -> Array
  # Facts not yet in shared_with for target_id
  # Used by conversation system to surface new information

func mark_fact_shared(fact_id: String, target_id: String) -> void

func has_memory_about(keyword: String) -> bool

func run_garbage_collection() -> void
  # Called when GameEvents.game_hour_changed fires with hour == hash(npc_id) % 24
  # Staggered per NPC to avoid queuing all 7 NPCs at the same tick
  # 1. Recalculate all scores
  # 2. Sort ascending
  # 3. Bottom 25%: mark fuzzy=true if not already
  # 4. Already-fuzzy below DROP_THRESHOLD: remove
  # 5. Ensure count <= MAX_MEMORIES

func apply_fuzzy_degradation(memory_index: int, fuzzy_version: String) -> void
  # Called by LLM response handler after fuzzy generation

# Conversation state API (preserved from current implementation)
func add_conversation(partner_id, speaker_id, text) -> void
func get_conversation_with(partner_id) -> Array
func add_area_chat(speaker_name, text) -> void
func get_area_chat_context(max_count) -> String
func can_continue_conversation(partner_id) -> bool
func increment_turn(partner_id) -> void
func reset_conversation_turns(partner_id) -> void
func add_recent_topic(topic) -> void
func is_recent_topic(topic) -> bool
func add_goal(goal) -> void
func gather_chat_facts(target_id: String) -> Array
  # Blends scored memories with real-time state queries:
  #   - Top-scored memories (replaces old observations + key_memories arrays)
  #   - Live StatsComponent queries (current HP, level)
  #   - Live EquipmentComponent queries (equipped weapon/armor)
  #   - Live InventoryComponent queries (notable items, gold range)
  #   - Current perception from WorldState.get_npc_perception()
  # Scored memories replace the old arrays, but live state lookups remain.
```

### 5.4 Nightly Garbage Collection

Triggered by `GameEvents.game_hour_changed` when hour matches `hash(npc_id) % 24` (staggered to avoid queuing all 7 NPCs at the same midnight tick).

GC pass:
1. Recalculate all scores
2. Sort ascending by score
3. Bottom 25%: `fuzzy = true` if not already; request LLM fuzzy text (deferred, priority 5)
4. Already-fuzzy entries below `DROP_THRESHOLD`: remove
5. Enforce `MAX_MEMORIES` cap by dropping lowest-scored

### 5.5 Fuzzy Degradation

Three states:
- Sharp: "wolves attacked east gate, three of them"
- Fuzzy: "wolves attacked east gate recently"
- Almost gone: "some trouble at the east gate a while back"

Fuzzy text is LLM-generated (priority 5, deferred). System prompt: "Rewrite this memory as if the person is starting to forget it. Make it vaguer, less certain, with 'I think' or 'something about'. Keep it under 15 words." Request ID: `fuzzy_{npc_id}_{memory_index}`.

### 5.6 Post-Conversation Memory Extraction

After each conversation ends, `ConversationManager` triggers a deferred extraction LLM call for each NPC participant. Request ID: `extract_{npc_id}_{conversation_id}`.

Extraction prompt (system):
```
"Read the following conversation and list any NEW FACTS that {npc_name} learned.
Output a JSON array: [{"fact": "...", "importance": "high/medium/low", "emotional": bool, "topic": "..."}]
Only include facts {npc_name} did NOT already know. Max 3 facts. If nothing new, return []."
```

Extracted facts are added via `add_memory()` with source `"heard_from:{speaker_id}"`. Priority: 4 (deferred).

---

## 6. Relationship System

**File:** `scripts/components/relationship_component.gd`

Extracted from `NpcMemory`. Owns the full relationship model for one NPC with all other entities.

### 6.1 Data Model

```
relationships: Dictionary  # partner_id -> entry
Each entry:
{
  tier: String,        # see tier ladder below
  impression: String,  # "A loud brawler who fights well but talks too much"
  tension: float,      # 0.0–1.0, independent of tier
  history: Array,      # [{event: String, timestamp: float, game_day: int}]
}
```

**Tier ladder:** `stranger → recognized → acquaintance → friendly → close → bonded`

### 6.2 Tier Progression

Event-driven, not point-based. `record_event()` appends to history then calls `_evaluate_tier()`.

**Promotion triggers:**

| Transition | Requirement |
|-----------|------------|
| stranger → recognized | First conversation OR fought near each other once |
| recognized → acquaintance | 3+ conversations OR 2+ shared combat encounters |
| acquaintance → friendly | 5+ conversations AND 1+ shared combat; OR received help (healed/given item) |
| friendly → close | 10+ conversations AND 3+ shared combat AND no high-tension episodes |
| close → bonded | Special event only: saved from death, shared a secret, completed quest together |

**Demotion triggers:**

| Condition | Effect |
|-----------|--------|
| Tension > 0.7 for 3+ interactions | Drop one tier |
| Attacked by partner | Drop to "recognized" minimum (immediate) |

**Turn selection bonus mapping** (for conversation scoring):
- stranger/recognized → +0.0
- acquaintance → +0.5
- friendly → +1.0
- close/bonded → +2.0

### 6.3 API

```
func get_relationship(partner_id: String) -> Dictionary
  # Returns entry; creates default (stranger, no impression, tension=0, []) if missing

func get_tier(partner_id: String) -> String
func get_impression(partner_id: String) -> String

func record_event(partner_id: String, event: String) -> void
  # Events: "conversation", "shared_combat", "helped", "attacked_by",
  #         "shared_secret", "saved_from_death"
  # After appending, calls _evaluate_tier()
  # History capped at MAX_HISTORY_PER_RELATIONSHIP (10) per partner

func set_impression(partner_id: String, impression: String) -> void

func add_tension(partner_id: String, amount: float) -> void
func reduce_tension(partner_id: String, amount: float) -> void

func get_relationships_summary(max_count: int = 3) -> String
  # Top N by tier for prompt context

func get_partners_at_tier(min_tier: String) -> Array
  # "who can I share secrets with?" → get_partners_at_tier("close")

func _evaluate_tier(partner_id: String) -> void
  # Counts events by type, checks thresholds, promotes/demotes
  # Emits GameEvents.relationship_tier_changed on change

func _sync() -> void
  # WorldState: {partner_id: tier} dict (minimal, debug only)
```

### 6.4 LLM-Generated Impressions

Triggered by `GameEvents.relationship_tier_changed` or after any 3+ turn conversation. NPCBrain fires the request.

Request ID: `impression_{npc_id}_{partner_id}`. System prompt: "You are {npc_name}. In one sentence (under 20 words), describe your impression of {partner_name} based on your interactions. Be specific and personal."

Response handler calls `relationship.set_impression(partner_id, text)`.

---

## 7. Conversation System

### 7.1 ConversationState

**File:** `scripts/conversation/conversation_state.gd` (new RefCounted data class)

```
ConversationState:
  conversation_id: String         # "conv_001"
  participants: Array[String]     # entity_ids currently in conversation
  location: Vector3               # spatial anchor (center at creation)
  topic: String                   # current topic label
  turns: Array[ConversationTurn]
  nearby_listeners: Array[String] # entity_ids within EARSHOT_RANGE but not participating
  mood: String                    # "friendly" | "tense" | "casual" | "heated" | "quiet"
  started_at: float
  last_activity: float
  ended: bool

ConversationTurn:
  speaker_id: String
  text: String
  action: String                  # "speak" | "silence" | "topic_change" | "walk_away" | "join"
  timestamp: float
  topic: String                   # topic at time of this turn (captures topic shifts)
```

### 7.2 ConversationManager

**File:** `scripts/conversation/conversation_manager.gd` (new Node, added as child of game_world)

**Constants:**
```
EARSHOT_RANGE: float = 10.0
MAX_PARTICIPANTS: int = 6
MAX_TURNS: int = 30
SILENCE_TIMEOUT: float = 15.0
TURN_COOLDOWN: float = 2.0
MAX_CONSECUTIVE_SILENCE: int = 3
JOIN_THRESHOLD: float = 2.5
SPEAK_THRESHOLD: float = 2.0
```

**State:**
```
var active_conversations: Dictionary = {}    # conversation_id -> ConversationState
var entity_to_conversation: Dictionary = {}  # entity_id -> conversation_id
var _llm_queue: Array[String] = []           # conversation_ids waiting for LLM
```

**Lifecycle API:**
```
func start_conversation(initiator_id, target_id, topic) -> String
  # Creates ConversationState, maps both entity_ids, emits conversation_started

func end_conversation(conversation_id) -> void
  # Cleans mappings, triggers deferred memory extraction for each participant
  # Emits conversation_ended

func join_conversation(entity_id, conversation_id) -> bool
  # Adds to participants, injects "join" turn, emits conversation_participant_joined

func leave_conversation(entity_id, reason="walked away") -> void
  # Removes from participants, injects "walk_away" turn
  # If < 2 participants remain: end_conversation()
  # Emits conversation_participant_left

func add_turn(conversation_id, turn: Dictionary) -> void
  # Appends turn, updates last_activity, updates topic if action=="topic_change"
  # Emits conversation_turn_added

func select_next_speaker(conversation_id) -> String
  # Returns entity_id of next speaker, or "" if conversation should pause/end
  # See scoring algorithm below
  # After returning a speaker_id, the turn loop does:
  #   var node = WorldState.get_entity(speaker_id)
  #   node.get_node("NPCBrain").generate_conversation_turn(conversation_id)
  # For player turns, skip LLM — player input is added directly via submit_player_turn().

func submit_player_turn(conversation_id: String, text: String) -> void
  # Creates a turn with speaker_id="player", action="speak"
  # Adds it via add_turn(), then calls select_next_speaker() to drive the next NPC response

func get_conversation_history(conversation_id, max_turns=20) -> Array
func update_nearby_listeners(conversation_id) -> void
func is_in_conversation(entity_id) -> bool
func get_entity_conversation(entity_id) -> String  # returns "" if not in one
```

### 7.3 Turn Selection Algorithm

`select_next_speaker()` scores each participant (excluding the last speaker). Returns the highest scorer if above `SPEAK_THRESHOLD`, otherwise returns "" (silence beat).

```
score = 1.0 (base)
      + topic_relevance(npc, topic)         # 0.0–3.0
      + relationship_bonus(npc, last_speaker)  # from tier (see Section 6.2)
      + personality_drive(npc)              # sociability * 2.0, capped 0.5 for loners
      + recency_penalty(npc, conversation)  # -1.0 per recent turn, -2.0 if spoke last
      + silence_streak_bonus(npc)           # +0.5 per silent turn (cap +1.0)
      + random_jitter()                     # -0.5 to +0.5

topic_relevance:
  - Keyword overlap with NPC's key memories and recent observations
  - NPC's current_goal relevance (e.g., "hunt_field" NPC cares about "wolves" topic)
  - Match in NPC's opinions dict
  → 0.0 (none) to 3.0 (highly relevant)

personality_drive:
  - sociability * 2.0
  - BUT if schedule is "routine" or loner tendency: cap at 0.5

recency_penalty:
  - NPC who spoke last turn: -2.0
  - -1.0 per turn spoken in last 3 turns
```

The player is **never** auto-selected. The player interjects by typing. When the player speaks, their turn is inserted and the next NPC speaker is selected normally.

Consecutive silence counter: increments when top score < `SPEAK_THRESHOLD`. When counter reaches `MAX_CONSECUTIVE_SILENCE`, end_conversation().

### 7.4 Join/Leave Mechanics

**Joining:**
- `update_nearby_listeners()` is called each turn cycle
- NPCs in `nearby_listeners` evaluated: `join_score = topic_relevance * sociability * (1.0 if not busy else 0.0)`
- If `join_score > JOIN_THRESHOLD`: NPC moves to conversation location, then `join_conversation()`
- Injected turn: `{speaker_id: npc_id, text: "", action: "join"}`

**Leaving (NPC):**
- 3 consecutive "silence" actions from this NPC
- Topic shifted to relevance < 0.5 for this NPC
- Goal priority override (low HP, need to retreat)
- Conversation exceeds MAX_TURNS and interest wanes

**Player joining:**
- Player walks within `EARSHOT_RANGE` of active conversation
- UI shows `[Nearby: Kael, Bjorn talking about wolves]`
- Press E → `join_conversation("player", conv_id)`, chat input opens

**Player leaving:**
- Walk away beyond `EARSHOT_RANGE * 1.5` → auto-leave
- Press Esc or click away → leave
- Silence timeout: player treated as silent participant but not removed

### 7.5 Conversation Lifecycle

```
1. NpcBehavior._try_social_chat() → ConversationManager.start_conversation()
2. ConversationManager stores state, emits conversation_started
3. Initiator's NpcBrain generates opening line (LLM, priority 2)
4. add_turn() records it
5. select_next_speaker() picks responder
6. Responder's NpcBrain.generate_conversation_turn() (LLM, priority 2)
7. add_turn(), select_next_speaker(), repeat
8. End conditions: MAX_TURNS, SILENCE_TIMEOUT, MAX_CONSECUTIVE_SILENCE, < 2 participants
9. end_conversation() fires deferred extraction for each participant
```

### 7.6 NPCBrain Integration

**New method:** `generate_conversation_turn(conversation_id: String) -> void`
- Builds 3-block prompt from conversation state
- Sends LLM request with ID `conv_{npc_id}_{conversation_id}`
- On response: calls `ConversationManager.add_turn()` with parsed result
- On timeout/error: adds silence turn

**Modified `_on_npc_spoke`:** If NPC is in a managed conversation, ignore signal (conversation owns this NPC's speech). Combat shouts and non-conversation speech continue to use `npc_spoke` normally.

**NPCBehavior changes:**
- `_try_social_chat()` routes through `ConversationManager.start_conversation()` instead of `brain.initiate_social_chat()`
- `evaluate()` checks `ConversationManager.is_in_conversation(npc_id)`: if yes, skip goal execution, stay in "talking" state

---

## 8. Prompt Structure

Three-block format for all conversation generation. Replaces current system/user message pair.

### Block 1 — World (Constant)

```
WORLD:
You are in a medieval village with a walled city and surrounding fields.
The city has shops, districts, and rest areas. The field has monsters (slimes, wolves, goblins).
There are NO journals, scrolls, dragons, traps, camps, or magic spells.
Do NOT invent things not in this world.
It is currently {time_display} ({phase}).
```

Cached as a constant string with time substitution. Identical for all NPCs in all conversations.

### Block 2 — Character (Per NPC, Refreshed Each Decision Cycle)

```
CHARACTER:
You are {npc_name}.
Personality: {get_personality_prompt()}
Speech style: {speech_style}
Background: {backstory}
Current mood: {mood_emotion}, {mood_energy}

Desires: {get_desires_prompt()}

Tendencies:
{get_behavioral_prompt()}
{tendency_instructions}   (see Section 9)

Topics you avoid: {avoids_topics}
If asked about these, change the subject or give a vague non-answer.

Secrets you know (DO NOT share unless conditions are met):
{secret_instructions}
```

**Desires** are derived deterministically from goal + personality via a mapping function. Not LLM-generated:
```
hunt_field + bold_warrior → "Eager to prove yourself against stronger monsters"
idle + cheerful_scholar   → "Looking for interesting people to talk to"
```

### Block 3 — Context (Dynamic, Per Turn)

```
CONTEXT:
[Conversation with: {participant_names}]
[Location: {location_description}]

Relationships with present participants:
- {name}: {tier} (impression: "{impression}")
  {tension_note if tension > 0.3}

Relevant memories (highest relevance first):
- {memory_1}
- {memory_2}
- {memory_3}

Your opinion on "{topic}": {opinion_text or "You have no strong opinion on this."}

Conversation so far:
{last_20_turns formatted}

---
INSTRUCTION:
Respond with 1-2 sentences as {npc_name}. You may also:
- Stay silent (respond with exactly [SILENCE])
- Change the topic (respond with [TOPIC:new topic] your dialogue)
- Leave the conversation (respond with [LEAVE] optional parting words)

Stay in character. No narration. No modern language. No *emotes*.
Only reference things you know from your memories.
{tendency_instructions}
```

### Response Parsing

`ResponseParser.parse_conversation_response(response: Dictionary) -> Dictionary`

```
Returns:
{
  valid: bool,
  dialogue: String,    # spoken text (empty if silence)
  action: String,      # "speak" | "silence" | "topic_change" | "walk_away"
  new_topic: String,   # only if action == "topic_change"
  error: String,
}

Rules:
  "[SILENCE]"        → action: "silence", dialogue: ""
  "[LEAVE] ..."      → action: "walk_away", dialogue: text after [LEAVE]
  "[TOPIC:xyz] ..."  → action: "topic_change", new_topic: "xyz", dialogue: text after tag
  anything else      → action: "speak", dialogue: cleaned text
```

Reuses `_clean_chat_response()` for shared cleanup (strip emotes, JSON wrapping, name prefixes). Truncates to 2 sentences max.

### PromptBuilder New Methods

```
static func build_conversation_system_message(
  npc_name, personality, trait_profile, mood_data,
  desires, tendencies, secrets
) -> Dictionary

static func build_conversation_user_message(
  npc_id, npc_node, conversation, memory_node, identity_node
) -> Dictionary
```

Existing `build_chat_system_message` and `build_chat_initiate_system_message` kept during transition, deprecated after.

---

## 9. Behavioral Tendencies

Tendencies are behavioral directives in the CHARACTER block. They instruct the LLM how to behave. They do not filter or transform data programmatically — the LLM handles distortion, and memory extraction captures the distorted output.

### Tendency Definitions

| ID | Description | Prompt instruction | Trait gate |
|----|-------------|-------------------|-----------|
| `exaggerates` | Inflates danger and achievement | "When sharing facts about battles or danger, inflate the numbers and drama slightly." | boldness ≥ 0.6 AND sociability ≥ 0.5 |
| `withholds` | Vague with strangers | "Do NOT share specific details (numbers, locations, names) with strangers or people you distrust. Be vague." | sociability < 0.4 |
| `lies_when_cornered` | Deflects on sensitive topics | "If asked directly about {avoids_topics}, deflect or give a misleading answer." | boldness < 0.5 |
| `blurts_secrets` | Accidentally overshares | "If you are in a good mood and talking to a friend, you might accidentally reveal something you shouldn't." | sociability ≥ 0.8 |
| `avoids_topic` | Deflects specific subjects | "Change the subject or give a vague non-answer if {topics} come up." | per-NPC config |

### Per-NPC Assignment

| NPC (trait profile) | Tendencies |
|--------------------|-----------|
| bold_warrior (Kael) | exaggerates |
| cautious_mage (Lyra) | withholds |
| boisterous_brawler (Bjorn) | exaggerates, blurts_secrets |
| sly_rogue (Sera) | withholds, lies_when_cornered, avoids_topic |
| stoic_knight (Thane) | withholds, avoids_topic |
| cheerful_scholar (Mira) | blurts_secrets |
| mysterious_loner (Dusk) | withholds, lies_when_cornered, avoids_topic |

**Storage:** `NpcTraits` gains `NPC_TENDENCIES` and `NPC_AVOIDS_TOPICS` const dictionaries. `NpcIdentity.setup()` reads from them.

---

## 10. Opinion Formation

### Data Model

Stored in `NpcIdentity.opinions` array. Each entry:

```
{
  topic: String,          # "wolves", "the field", "equipment"
  take: String,           # "Wolves are getting smarter — I can feel it"
  stance: String,         # "positive" | "negative" | "neutral" | "curious" | "fearful"
  strength: String,       # "strong" | "moderate" | "mild"
  will_share_with: String,# "anyone" | "close" | "keeps_to_self"
  reasoning: String,      # one-sentence rationale (shown in prompt)
  source: String,         # "personality" | "experience" | "heard_from:{id}"
  formed_at: float,       # timestamp
}
```

### Formation Triggers

**A. Personality-derived (at NPC creation, no LLM):**

`derive_initial_opinions(trait_profile)` maps personality to baseline opinions deterministically:

```
bold_warrior  → {"monsters": stance="positive", take="Good for training strength"}
cautious_mage → {"monsters": stance="cautious", take="Dangerous but valuable for research"}
boisterous_brawler → {"combat": stance="positive", take="Best way to spend a day"}
```

**B. Experience-derived (after memory extraction, deferred LLM call):**

When `GameEvents.memory_added` fires with importance == "high" AND no existing opinion on that topic:

```
System: "You are {npc_name}. {personality}. You just learned: {fact}.
         Do you have a reaction or opinion?
         If yes: {"topic":"...", "stance":"...", "strength":"...", "reasoning":"one sentence"}
         If no reaction: {}"

Request ID: opinion_{npc_id}_{topic_hash}
Priority: 5 (lowest, deferred)
Cooldown: 5 minutes between opinion formation calls per NPC
```

**Global cap:** Max 5 queued priority-5 opinion requests at any time. If exceeded, drop the oldest queued request. Before queuing, check two guards:
1. NPC does not already have an opinion on this topic (skip if exists).
2. The fact is relevant to the NPC's personality category — warriors (`bold_warrior`, `boisterous_brawler`, `stoic_knight`) care about combat/monsters/strength topics; scholars/mages (`cautious_mage`, `cheerful_scholar`) care about knowledge/exploration topics. Facts outside an NPC's category are skipped.

### Influence on Conversation

Opinions appear in Block 3 of the prompt:
```
Your opinion on "wolves": Wolves are getting smarter — I can feel it. (strength: strong)
```

NPCs inject opinions naturally via dialogue. The prompt instruction "You may share opinions, exaggerate, withhold, or lie per your tendencies" drives organic expression.

---

## 11. Information Propagation

**Core principle: No world facts.** There is no global fact pool. An NPC can only know something through:

1. **Direct observation** (`source: "witnessed"`) — from game events: `entity_died`, `entity_damaged`, proficiency events, etc.
2. **Being told** (`source: "heard_from:{id}"`) — extracted from conversation transcripts
3. **Overhearing** (`source: "overheard"`) — from area_chat_log when nearby but not a participant

### Propagation Flow

```
NPC A observes event → add_memory(fact, "witnessed", importance)
   ↓
NPC A tells NPC B in conversation (LLM generates dialogue)
   ↓
Conversation ends → memory extraction for NPC B
   ↓
NPC B gets: add_memory(fact, "heard_from:A", "medium", confidence=0.7)
   ↓
NPC B tells NPC C → add_memory(fact, "heard_from:B", "low", confidence=0.5)
```

### Distortion

Distortion is LLM behavior guided by tendency instructions, not a code transformation. `exaggerates` tendency causes the NPC's dialogue to inflate facts. Memory extraction captures the distorted version. The receiving NPC's memory has `confidence` reduced (heard=0.7, heard_from_liar=0.4) and `distorted=true` when source is not "witnessed".

`shared_with` in each memory entry tracks who this NPC has already told this fact to. `get_unshared_facts(target_id)` drives interesting dialogue by surfacing things the NPC hasn't told this person yet.

### Information Isolation Guarantee

There is no broadcast mechanism for facts. `npc_spoke` signal allows nearby NPCs to hear dialogue (area_chat_log), but fact extraction into memory only happens for active conversation participants. Being within earshot means overhearing, not learning — overheard entries have source "overheard" and lower confidence (0.5).

---

## 12. Schedule System

Three schedule types, all encoded in `NpcIdentity`. `NPCBehavior.evaluate()` checks the schedule override after survival and goal-completion checks, before social chat.

### Schedule Override in NPCBehavior

```
NPCBehavior.evaluate():
  1. Survival check (unchanged)
  2. Goal completion check (unchanged)
  3. [NEW] Schedule override:
     if identity.schedule_type == "routine":
       var goal = identity.get_current_schedule_goal()
       if goal != "" and goal != npc.current_goal:
         npc.set_goal(goal)
         return
     if identity.schedule_type == "periodic":
       var goal = identity.get_current_schedule_goal()
       if goal != "":
         npc.set_goal(goal)
  4. Social chat (unchanged)
  5. Execute goal (unchanged)
```

### Routine Schedule

Time-slot-based daily pattern. Uses `TimeManager.get_game_hour()`.

```
routine: [
  {start_hour: 7.0, end_hour: 12.0, goal: "tend_shop", location: "weapon_shop"},
  {start_hour: 12.0, end_hour: 13.0, goal: "eat_lunch", location: "tavern"},
  {start_hour: 13.0, end_hour: 20.0, goal: "tend_shop", location: "weapon_shop"},
  {start_hour: 20.0, end_hour: 23.0, goal: "rest", location: "inn"},
]
```

`get_current_schedule_goal()` iterates routine entries and returns the goal for the current hour. Returns "" if no entry matches (NPC is free).

### Goal Schedule

The default for adventurer NPCs. `get_current_schedule_goal()` returns "". `NPCBehavior` drives all goal logic as it does today. No change.

### Periodic Schedule

Visit/absence pattern for traveling merchants or returning wanderers.

```
periodic_pattern: [
  {duration_hours: 8.0,  goal: "tend_market", location: "market"},  # 8 game-hours present
  {duration_hours: 72.0, goal: "travel",       location: ""},        # 3 game-days absent
]
```

`get_current_schedule_goal()` tracks elapsed game-time hours using `TimeManager.get_game_hour()` and `TimeManager.get_day()` (consistent with routine schedule resolution). Cycles through pattern entries and sets presence/absence state accordingly. `duration_hours` uses game-time hours throughout — not real-time minutes.

---

## 13. Mood System

Two independent axes:
- **Emotion:** `content | worried | angry | sad | excited | afraid`
- **Energy:** `tired | normal | energetic`

Each NPC has `baseline_emotion` and `baseline_energy` defined in NpcIdentityDatabase.

### Event-Driven Shifts

Mood shifts happen in `NpcIdentity._on_event()` handlers connected to GameEvents. Shifts are immediate and override current mood.

| Event | Emotion shift | Energy shift |
|-------|--------------|-------------|
| entity_damaged (self, >20% HP) | worried | — |
| entity_damaged (self, <20% HP) | afraid | — |
| entity_died (nearby enemy) | content | energetic |
| proficiency_level_up (self) | excited | energetic |
| entity_died (self) | sad | tired |
| entity_respawned (self) | content | tired |
| conversation_started (player in) | excited | — |

### Baseline Decay

Every game hour (`GameEvents.game_hour_changed`), mood steps one value toward baseline. Non-baseline moods decay in one step to baseline. Energy decays similarly. `NpcIdentity` connects to `GameEvents.game_hour_changed` at `_ready()` instead of using `_process()` — this is more efficient and consistent with GC and schedule resolution patterns across the project.

### Prompt Integration

`get_mood_prompt()` replaces the old `NpcTraits.pick_mood()` randomized approach. Mood is now actual state, not a random pick.

Block 2 includes: `Current mood: {mood_emotion}, {mood_energy}` — the LLM handles tonal adjustment.

---

## 14. LLM Integration

### Priority Queue

`LLMClient.send_chat()` gains an optional `priority: int` parameter (default 3). The queue is sorted by priority before processing.

| Priority | Request type | ID prefix |
|----------|-------------|-----------|
| 1 | Player-involved conversation turn | `conv_player_` |
| 2 | NPC conversation turn | `conv_` |
| 3 | NPC decision-making | (no prefix, existing) |
| 4 | Memory extraction (post-conversation) | `extract_` |
| 5 | Fuzzy degradation, opinion formation, impression generation | `fuzzy_`, `opinion_`, `impression_` |

Backward compatible — existing callers without priority get default 3.

### Concurrency Limit

Max 2 concurrent LLM requests (unchanged). Priority queue ensures player-facing calls get served first. Deferred calls (4-5) only run when both slots would otherwise be idle.

### Request Routing

All deferred LLM responses are routed in `NPCBrain._on_llm_response()` by request ID prefix:

| Prefix | Handler |
|--------|---------|
| `conv_{npc_id}` | `_handle_conversation_response()` |
| `extract_{npc_id}` | `_handle_extraction_response()` |
| `fuzzy_{npc_id}` | `_handle_fuzzy_response()` |
| `opinion_{npc_id}` | `_handle_opinion_response()` |
| `impression_{npc_id}` | `_handle_impression_response()` |

### Error Handling

| Failure | Behavior |
|---------|---------|
| LLM timeout on conversation turn | Add silence turn, select next speaker |
| Parse error on conversation response | Same as timeout |
| Empty response | Same as timeout |
| All participants time out consecutively | end_conversation() |
| NPC dies during conversation | entity_died signal → ConversationManager removes from participants |
| Extraction LLM failure | No facts extracted; no retry |
| Opinion/impression failure | No opinion/impression formed; no retry |

---

## 15. New Signals

All signals added to `autoloads/game_events.gd`:

```
# Identity / Mood
signal mood_changed(entity_id: String, emotion: String, energy: String)

# Memory
signal memory_added(entity_id: String, fact: String, importance: String)

# Relationships
signal relationship_tier_changed(entity_id: String, partner_id: String,
  old_tier: String, new_tier: String)

# Conversation lifecycle
signal conversation_started(conversation_id: String, participant_ids: Array)
signal conversation_ended(conversation_id: String)
signal conversation_participant_joined(conversation_id: String, entity_id: String)
signal conversation_participant_left(conversation_id: String, entity_id: String)
signal conversation_turn_added(conversation_id: String, speaker_id: String,
  dialogue: String, action: String)

# Information / Opinion
signal fact_learned(entity_id: String, fact_content: String, source: String)
signal opinion_formed(entity_id: String, topic: String, stance: String)
```

---

## 16. Files Summary

### New Files

| File | Type | Purpose |
|------|------|---------|
| `scripts/components/npc_identity.gd` | Node (composition) | Personality, mood, schedule, desires, secrets, opinions |
| `scripts/data/npc_identity_database.gd` | RefCounted (static) | Initial identity data for all NPCs |
| `scripts/components/relationship_component.gd` | Node (composition) | Tier-based relationships with impressions and history |
| `scripts/conversation/conversation_manager.gd` | Node (game_world child) | Conversation lifecycle, turn selection, spatial tracking |
| `scripts/conversation/conversation_state.gd` | RefCounted (data) | ConversationState and ConversationTurn data classes |

### Modified Files

| File | Changes |
|------|---------|
| `autoloads/game_events.gd` | 9 new signals |
| `autoloads/llm_client.gd` | Priority queue for send_chat() |
| `scenes/npcs/npc_memory.gd` | Full rewrite: scored memories, GC, fuzzy, fact propagation API |
| `scenes/npcs/npc_brain.gd` | Conversation turn generation, new LLM response handlers |
| `scenes/npcs/npc_behavior.gd` | ConversationManager routing, schedule override in evaluate() |
| `scenes/npcs/npc_base.gd` | Add NpcIdentity + RelationshipComponent; migrate add_observation calls |
| `scripts/llm/prompt_builder.gd` | 3-block conversation prompt methods |
| `scripts/llm/response_parser.gd` | parse_conversation_response() |
| `scripts/data/npc_traits.gd` | Remove BACKSTORIES/VOICE_STYLES/MOODS/pick_mood; add NPC_TENDENCIES |
| `scenes/game_world/game_world.gd` | Add ConversationManager, wire NpcIdentity setup |
| `scenes/ui/chat_log.gd` | conversation_turn signal handler |
| `scenes/player/player.gd` | Nearby conversation detection, E-to-join, auto-leave on distance |

### Deprecated

| File | Status |
|------|--------|
| `scenes/npcs/shop_npc.gd` | Deprecated — replace with npc_base + identity data |

---

## 17. Implementation Tasks

Tasks organized into parallelizable waves. Tasks within a wave have no shared file edits.

### Wave 0 — Foundation (no dependencies, fully parallel)

**Task 0-A: New signals (game_events.gd)**
- Add all 9 new signals
- Acceptance: All signals declared and callable

**Task 0-B: NpcIdentityDatabase (new file)**
- Static RefCounted with IDENTITIES dict for all 7 adventurer NPCs + shop NPCs
- Migrates content from NpcTraits.BACKSTORIES and NpcTraits.VOICE_STYLES
- `get_identity(npc_id)` static method
- Acceptance: All 7+ NPC entries have complete fields

**Task 0-C: ConversationState data class (new file)**
- ConversationState and ConversationTurn data structures
- Constructor/factory methods
- Acceptance: Data classes exist with all fields, no logic

**Task 0-D: LLM priority queue (llm_client.gd)**
- `send_chat()` gains optional `priority` parameter (default 3)
- Queue sorted by priority before processing
- Acceptance: Existing callers unaffected; priority honored

---

### Wave 1 — New components (depends on Wave 0)

**Task 1-A: NpcIdentity component (new file)**
- Depends on: 0-A (mood_changed signal), 0-B (database)
- Full data model, setup(), all prompt accessors, shift_mood(), mood decay, opinion API, secret API, schedule goal resolution, _sync(), GameEvents connections
- Acceptance: setup() loads all fields; mood decays toward baseline; get_mood_prompt() returns actual state (not random)

**Task 1-B: RelationshipComponent (new file)**
- Depends on: 0-A (relationship_tier_changed signal)
- Full data model, tier progression rules, record_event(), _evaluate_tier(), tension API, impression storage, get_relationships_summary(), _sync()
- Acceptance: Tier promotions and demotions trigger correctly; impression stores LLM text; summary matches old memory format

**Task 1-C: NpcMemory rewrite (npc_memory.gd)**
- Depends on: 0-A (memory_added signal)
- Replace observations + key_memories with scored memories array; add_memory() with dedup and eviction; score_memory(); get_memories_for_prompt(); run_garbage_collection(); fuzzy degradation API; fact propagation API (add_fact, get_facts_about, get_unshared_facts, mark_fact_shared); preserve all conversation state API
- **Relationship methods:** Keep existing relationship methods as deprecated stubs. Each stub checks `owner.has_node("RelationshipComponent")`: if present, delegate to it; otherwise fall back to old in-memory dict behavior. This allows Wave 1 to deploy without breaking callers in NpcBrain/NpcBehavior that haven't been migrated yet (those migrate in Tasks 2-A and 3-A).
- Do NOT remove relationship methods in this task — stubs remain until Wave 6 cleanup.
- Acceptance: Conversation state API unchanged; scored memories cap at 20; GC triggered at staggered midnight; fact propagation fields present; relationship stubs pass through to RelationshipComponent when available

---

### Wave 2 — Wiring and brain updates (depends on Wave 1)

**Task 2-A: Wire components into npc_base.gd**
- Depends on: 1-A, 1-B
- Add NpcIdentity and RelationshipComponent as child nodes in _ready()
- Load identity via NpcIdentityDatabase.get_identity(npc_id)
- Migrate all add_observation() calls → add_memory()
- Migrate all add_key_memory() calls → add_memory(text, "witnessed", "high", true)
- Keep @export var personality for backward compat
- Acceptance: NPCs boot with all 3 new nodes; no add_observation() calls remain in npc_base.gd

**Task 2-B: Update npc_action_executor.gd**
- Depends on: 1-C
- All add_observation() / add_key_memory() calls → add_memory() with appropriate importance levels
- Acceptance: No old memory API calls remain; importance levels are sensible

**Task 2-C: Response parser extension (response_parser.gd)**
- Depends on: none (pure addition)
- parse_conversation_response() with [SILENCE], [LEAVE], [TOPIC:x] handling
- Reuses _clean_chat_response()
- Acceptance: All 4 action types parse correctly; untagged text defaults to "speak"

---

### Wave 3 — Brain and prompt integration (depends on Wave 2)

**Task 3-A: Update npc_brain.gd**
- Depends on: 2-A (components wired), 2-C (parser)
- New LLM response handlers for extract_, fuzzy_, opinion_, impression_ prefixes
- _request_memory_extraction() after conversation ends
- _request_impression_update() on relationship_tier_changed
- _maybe_form_opinion() on memory_added for high-importance memories
- Replace NpcTraits.pick_mood() → identity.get_mood_prompt()
- Replace memory.get_relationship_label() → relationship.get_tier()
- Acceptance: All old NpcTraits references replaced; new handlers route correctly

**Task 3-B: Conversation prompt builder (prompt_builder.gd)**
- Depends on: 1-A (NpcIdentity for tendency/opinion data), 1-B (RelationshipComponent for tier/impression data in Block 3)
- build_conversation_system_message() with 3-block format
- build_conversation_user_message() with conversation history, relationships, memories, opinions
- World block cached as constant
- Tendency and secret instructions in CHARACTER block
- Tier-gated secret injection (tier >= "close")
- Acceptance: Output is well-formed; world block is identical string across all callers

**Task 3-C: Update npc_behavior.gd**
- Depends on: 2-A (components wired)
- evaluate(): schedule override added (step 2.5)
- _try_social_chat(): routes through ConversationManager.start_conversation() (ConversationManager not yet built — wire up in Wave 4)
- Sort candidates by tier instead of affinity
- Acceptance: Schedule override fires for routine-type NPCs; tier-based sorting works

---

### Wave 4 — ConversationManager (depends on Wave 3)

**Task 4-A: ConversationManager core (new file)**
- Depends on: 0-C (data class), 0-D (priority queue), all Wave 3 complete
- start_conversation, end_conversation, join_conversation, leave_conversation
- entity_to_conversation mapping consistency
- SILENCE_TIMEOUT auto-end
- MAX_TURNS enforcement
- Signals emitted correctly
- Acceptance: Conversations start, run, and end; mapping is always consistent; signals fire

**Task 4-B: Turn selection algorithm (conversation_manager.gd)**
- Depends on: 4-A
- select_next_speaker() with full scoring formula
- SPEAK_THRESHOLD, consecutive silence detection
- Player never auto-selected
- Acceptance: High-sociability NPCs speak more; recent speakers penalized; silence counter ends conversation

**Task 4-C: ConversationManager turn loop (_process)**
- Depends on: 4-A, 4-B, 3-A (brain.generate_conversation_turn)
- _process drives: select speaker → request LLM → add turn → repeat
- TURN_COOLDOWN pacing
- Multiple active conversations round-robin fairly
- Join evaluation for nearby listeners
- Clean shutdown mid-turn
- Acceptance: A 2-NPC conversation runs to completion without stalling; join/leave works

---

### Wave 5 — Memory extraction and opinion formation (depends on Wave 4)

**Task 5-A: Post-conversation memory extraction**
- Depends on: 4-A (end_conversation triggers it), 1-C (fact memory API)
- end_conversation() triggers deferred extraction for each participant
- Extraction prompt built from transcript
- Parsed facts stored in NpcMemory with source "heard_from:{speaker_id}"
- Priority 4, graceful failure
- Acceptance: After a 3-turn conversation, participants have new memories with correct sources

**Task 5-B: Opinion formation**
- Depends on: 1-A (NpcIdentity.add_opinion), 5-A (fact_learned signal)
- maybe_form_opinion() triggered on memory_added (high importance)
- Deferred LLM call, priority 5
- Opinion stored in NpcIdentity.opinions
- Opinions appear in conversation prompts
- Acceptance: High-importance memory → deferred opinion call → opinion in subsequent prompts

---

### Wave 6 — Player UX and cleanup (depends on Wave 5)

**Task 6-A: Player conversation UX (player.gd + chat_log.gd)**
- Depends on: 4-A (ConversationManager exists), Wire-up in game_world
- Nearby conversation indicator when within EARSHOT_RANGE
- E key joins conversation; chat input opens
- Player chat input → turn via ConversationManager
- Walk-away auto-leave
- chat_log.gd: connect to conversation_turn signal; color-coded speakers
- Acceptance: Player can join and leave NPC conversations; chat log shows full conversation history

**Task 6-B: Game world wiring (game_world.gd)**
- Depends on: All Wave 1–4 complete
- Instantiate ConversationManager as child node
- Wire NpcIdentity setup in _setup_adventurer_npcs() (call identity.setup() after component creation)
- Expose ConversationManager to NPCBrain and NPCBehavior
- Acceptance: All NPCs boot with NpcIdentity loaded; ConversationManager accessible globally

**Task 6-C: NpcTraits cleanup (npc_traits.gd)**
- Depends on: 3-A (all callers migrated)
- Remove BACKSTORIES, VOICE_STYLES, MOODS, pick_mood(), get_backstory(), get_voice_style()
- Add NPC_TENDENCIES, NPC_AVOIDS_TOPICS const dicts
- Keep PROFILES, get_profile(), get_trait(), get_trait_summary()
- Acceptance: No references to removed methods exist anywhere; NPC_TENDENCIES is complete for all 7 NPCs

**Task 6-D: Shop NPC migration (shop_npc.gd → npc_base)**
- Depends on: 6-B (game_world wiring), 1-A (NpcIdentity with routine schedule + shop_items fields)
- Replace weapon_shop and item_shop StaticBody3D nodes with npc_base scenes
- Add `weapon_shop_npc` and `item_shop_npc` entries to NpcIdentityDatabase with full fields including shop_type, shop_items, routine schedule, and NPC personality data
- Add `tend_shop` goal handler in NpcBehavior: navigate to shop location, stay in place, enable trade interaction
- Update NpcActionExecutor buy/sell to read shop_items from identity data instead of shop_npc script
- Write shop_type to entity_data during registration in npc_base._ready()
- Acceptance: Shop NPCs boot as npc_base entities; trade interaction (E key) still works; shop NPCs follow day/night routine; old shop_npc.gd has no remaining references

**Task 6-E: NpcMemory relationship stub removal**
- Depends on: 3-A (NpcBrain migrated), 2-A (NpcBehavior migrated) — all callers off the stubs
- Remove deprecated relationship stubs from NpcMemory (the delegation wrappers added in Task 1-C)
- Remove the old in-memory relationships dict fallback
- Acceptance: NpcMemory has no relationship methods; all callers use RelationshipComponent directly; no regression in tier tracking

---

## Dependency Graph Summary

```
Wave 0: 0-A, 0-B, 0-C, 0-D  (fully parallel)
         ↓
Wave 1: 1-A(←0-A,0-B), 1-B(←0-A), 1-C(←0-A)  (parallel within wave)
         ↓
Wave 2: 2-A(←1-A,1-B), 2-B(←1-C), 2-C(no dep)  (parallel within wave)
         ↓
Wave 3: 3-A(←2-A,2-C), 3-B(←1-A,1-B), 3-C(←2-A)  (parallel within wave)
         ↓
Wave 4: 4-A(←0-C,0-D,Wave3), 4-B(←4-A), 4-C(←4-A,4-B,3-A)  (sequential within wave)
         ↓
Wave 5: 5-A(←4-A,1-C), 5-B(←1-A,5-A)  (parallel after 4-A)
         ↓
Wave 6: 6-A(←4-A), 6-B(←Waves1-4), 6-C(←3-A), 6-D(←6-B,1-A), 6-E(←3-A,2-A)  (parallel within wave)
```

**Total tasks: 22.** Maximum parallelism: 4 agents in Waves 0 and 1. Critical path: 0-A → 1-C → 2-B (memory rewrite chain) and 0-C → 4-A → 4-C (conversation manager chain).
