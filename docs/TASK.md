# NPC System Overhaul — Implementation Tasks

## Dependency Graph

```
Wave 0: 0-A, 0-B, 0-C, 0-D                    (fully parallel, no deps)
         │
Wave 1: 1-A (← 0-A, 0-B)                       (parallel within wave)
         1-B (← 0-A)
         1-C (← 0-A)
         │
Wave 2: 2-A (← 1-A, 1-B)                       (parallel within wave)
         2-B (← 1-C)
         2-C (no dep, parallel)
         │
Wave 3: 3-A (← 2-A, 2-C)                       (parallel within wave)
         3-B (← 1-A, 1-B)
         3-C (← 2-A)
         │
Wave 4: 4-A (← 0-C, 0-D, Wave 3)               (sequential within wave)
         4-B (← 4-A)
         4-C (← 4-A, 4-B, 3-A)
         │
Wave 5: 5-A (← 4-A, 1-C)                       (parallel within wave)
         5-B (← 1-A, 5-A)
         │
Wave 6: 6-A (← 4-A)                             (parallel within wave)
         6-B (← Waves 1-4)
         6-C (← 3-A)
         6-D (← 6-B, 1-A)
         6-E (← 3-A, 2-A)
```

---

## Wave 0 — Foundation (parallel, no deps)

### 0-A: New Signals
**Ref**: New Signals (PRODUCT.md)
**Files**: MOD `autoloads/game_events.gd`
**Depends on**: None
**Steps**:
1. Open `game_events.gd`
2. Add 10 new signals after existing ones:
   - `mood_changed(entity_id: String, emotion: String, energy: String)`
   - `memory_added(entity_id: String, fact: String, importance: String)`
   - `relationship_tier_changed(entity_id: String, partner_id: String, old_tier: String, new_tier: String)`
   - `conversation_started(conversation_id: String, participant_ids: Array)`
   - `conversation_ended(conversation_id: String)`
   - `conversation_participant_joined(conversation_id: String, entity_id: String)`
   - `conversation_participant_left(conversation_id: String, entity_id: String)`
   - `conversation_turn_added(conversation_id: String, speaker_id: String, dialogue: String, action: String)`
   - `fact_learned(entity_id: String, fact_content: String, source: String)`
   - `opinion_formed(entity_id: String, topic: String, stance: String)`
**Verify**: All signals declared, no parse errors in Godot

---

### 0-B: NpcIdentityDatabase
**Ref**: NPC Data / Loadouts (PRODUCT.md "What Needs to Change")
**Files**: NEW `scripts/data/npc_identity_database.gd`
**Depends on**: None
**Steps**:
1. Create static RefCounted class `NpcIdentityDatabase`
2. Define `const IDENTITIES: Dictionary` with entries for all 7 adventurer NPCs (kael, lyra, bjorn, sera, thane, mira, dusk) + 2 shop NPCs (weapon_shop_npc, item_shop_npc)
3. Each entry schema: `{ name, age, occupation, traits (4 floats), speech_style, backstory, likes, dislikes, desires [{want, intensity}], opinions [{topic, take, strength, will_share_with, stance, reasoning, source, formed_at}], secrets [{fact, known_by, reveal_condition}], tendencies {exaggerates, withholds_from_strangers, lies_when, avoids_topics}, baseline_emotion, baseline_energy, schedule_type, routine (Array, for routine type), periodic_pattern (Array, for periodic type), shop_type (String, optional), shop_items (Array, optional) }`
4. Migrate content from `NpcTraits.BACKSTORIES` and `NpcTraits.VOICE_STYLES` into the corresponding identity fields
5. Migrate loadout data from `NpcLoadouts.LOADOUTS` (items, gold, goal, equip) — keep these as `starting_items`, `starting_gold`, `starting_goal`, `starting_equip`
6. Add static method `get_identity(npc_id: String) -> Dictionary`
7. Add static method `get_all_ids() -> Array`
**Verify**: `get_identity("kael")` returns complete dict with all fields; all 9 NPCs have entries (including weapon_shop_npc and item_shop_npc)

---

### 0-C: ConversationState Data Class
**Ref**: ConversationManager & ConversationState (PRODUCT.md "What We Need to Add")
**Files**: NEW `scripts/conversation/conversation_state.gd`
**Depends on**: None
**Steps**:
1. Create RefCounted class `ConversationState`
2. Fields: `conversation_id: String`, `participant_ids: Array[String]`, `location: String`, `topic: String`, `turns: Array` (of ConversationTurn dicts), `nearby_listeners: Array[String]`, `mood: String` (friendly/tense/casual/heated/quiet), `started_at: float`, `max_turns: int`
3. Create static factory: `static func create(id: String, participants: Array, location: String, topic: String) -> ConversationState`
4. Define ConversationTurn as Dictionary schema: `{ speaker_id: String, text: String, action: String, timestamp: float, topic: String }` — action is "speak" | "silence" | "topic_change" | "walk_away" | "join"
5. Add helper: `func add_turn(turn: Dictionary) -> void`
6. Add helper: `func get_participant_count() -> int`
7. Add helper: `func get_last_speaker() -> String`
8. Add helper: `func get_turn_count() -> int`
**Verify**: Create a ConversationState, add turns, read them back — no errors

---

### 0-D: LLM Priority Queue
**Ref**: LLM Priority Queue (PRODUCT.md "What We Need to Add")
**Files**: MOD `autoloads/llm_client.gd`
**Depends on**: None
**Steps**:
1. Add optional `priority: int = 3` parameter to `send_chat()` signature
2. Store pending requests in an internal queue array instead of processing immediately
3. Sort queue by priority (1 = highest, 5 = lowest) before picking next request
4. Process one request at a time from queue head
5. Prefix routing convention (document in comments): `conv_player_` = priority 1, `conv_` = priority 2, default = priority 3, `extract_` = priority 4, `fuzzy_`/`opinion_`/`impression_` = priority 5
6. Existing callers unchanged (default priority 3)
**Verify**: Send requests with priorities 5, 1, 3 — observe execution order is 1, 3, 5. Existing NPC decisions still work.

---

## Wave 1 — New Components (depends on Wave 0)

### 1-A: NpcIdentity Component
**Ref**: NPC Data / Loadouts + Mood System + Behavioral Tendencies + Desires + Secrets + Opinions (PRODUCT.md)
**Files**: NEW `scripts/components/npc_identity.gd`
**Depends on**: 0-A, 0-B
**Steps**:
1. Create Node class `NpcIdentity` extending Node
2. Declare all data fields matching NpcIdentityDatabase schema (name, age, occupation, traits, speech_style, backstory, likes, dislikes, desires, opinions, secrets, tendencies, mood_emotion, mood_energy, baseline_emotion, baseline_energy, schedule_type, routine, periodic_pattern)
3. Implement `setup(data: Dictionary)` — populate all fields from database entry
4. **Mood system**: Implement `shift_mood(emotion: String, energy: String)` — updates mood_emotion/mood_energy, emits `GameEvents.mood_changed`
5. **Mood decay**: Connect to `GameEvents.game_hour_changed` — step mood_emotion toward baseline_emotion, step mood_energy toward baseline_energy (one step per hour)
6. **Mood event triggers**: Connect to `GameEvents.entity_damaged`, `entity_died`, `entity_respawned`, `proficiency_level_up`, `conversation_started` — apply mood shifts per trigger table:
   - entity_damaged (self, >20% HP) → worried
   - entity_damaged (self, <20% HP) → afraid
   - entity_died (nearby enemy) → content + energetic
   - proficiency_level_up (self) → excited + energetic
   - entity_died (self) → sad + tired
   - entity_respawned (self) → content + tired
   - conversation_started (player in participants) → excited
7. **Prompt accessors**: `get_personality_prompt() -> String`, `get_mood_prompt() -> String`, `get_tendency_prompt() -> String`, `get_desires_prompt() -> String`
8. **Secret API**: `get_secrets_for_tier(tier: String) -> Array` — returns secrets where tier >= required tier (close/bonded only)
9. **Opinion API**: `add_opinion(opinion: Dictionary)`, `get_opinions() -> Array`, `get_opinions_for(topic: String, tier: String) -> Array` — filter by will_share_with vs tier
10. **Schedule API**: `resolve_schedule_goal(hour: int) -> Dictionary` — for routine type, find matching time slot; for periodic, check cycle position; for goal, return null (NPCBehavior handles)
11. Implement `_sync()` — write mood, opinions to `WorldState.entity_data[entity_id]`
**Verify**: Create NpcIdentity, call setup() with kael's data, check mood decay works over game hours, check secrets are tier-gated

---

### 1-B: RelationshipComponent
**Ref**: Relationships (PRODUCT.md "What Needs to Change")
**Files**: NEW `scripts/components/relationship_component.gd`
**Depends on**: 0-A
**Steps**:
1. Create Node class `RelationshipComponent` extending Node
2. Data: `var relationships: Dictionary = {}` — keyed by entity_id, value is `{ tier: String, impression: String, tension: float, history: Array }`
3. Constants: Tier ladder `["stranger", "recognized", "acquaintance", "friendly", "close", "bonded"]`
4. Implement `get_or_create(entity_id: String) -> Dictionary` — returns existing relationship or creates new one at "stranger" tier
5. Implement `record_event(entity_id: String, event: String, game_day: int)` — appends to history, calls `_evaluate_tier()`
6. Implement `_evaluate_tier(entity_id: String)` — count events by type, check promotion triggers:
   - stranger → recognized: first conversation OR fought near each other
   - recognized → acquaintance: 3+ conversations OR 2+ shared_combat
   - acquaintance → friendly: 5+ conversations AND 1+ shared_combat; OR received help
   - friendly → close: 10+ conversations AND 3+ shared_combat AND tension < 0.7
   - close → bonded: special event only (saved_from_death, shared_secret)
7. Implement demotion: tension > 0.7 for 3+ consecutive interactions → drop one tier; attacked → drop to recognized
8. Emit `GameEvents.relationship_tier_changed(entity_id, partner_id, old_tier, new_tier)` on tier change
9. Implement `set_impression(entity_id: String, text: String)`, `get_impression(entity_id: String) -> String`
10. Implement `get_tier(entity_id: String) -> String`
11. Implement `get_tension(entity_id: String) -> float`
12. Implement `set_tension(entity_id: String, value: float)`
13. Implement `get_relationships_summary() -> Dictionary` — returns all relationships as {entity_id: {tier, impression, tension}}
14. Implement `_sync()` — write to `WorldState.entity_data[entity_id]`
15. Cap history at 10 events per partner (FIFO)
**Verify**: Record events, check tier promotions fire at correct thresholds, check demotion works with high tension, check signal emission

---

### 1-C: NpcMemory Rewrite
**Ref**: Memory System (PRODUCT.md "What Needs to Change")
**Files**: MOD `scenes/npcs/npc_memory.gd`
**Depends on**: 0-A
**Steps**:
1. Replace `observations` array and `key_memories` array with single `var memories: Array = []`
2. Each memory entry: `{ id: String, fact: String, source: String, importance: String, emotional: bool, times_reinforced: int, timestamp: float, game_day: int, fuzzy: bool, fuzzy_text: String, confidence: float, topic: String, shared_with: Array }`
3. Implement `add_memory(fact: String, source: String = "witnessed", importance: String = "low", emotional: bool = false, topic: String = "") -> Dictionary`:
   - Generate unique ID (timestamp-based)
   - Deduplicate: if similar fact exists, increment times_reinforced instead
   - Set confidence: witnessed=1.0, heard_from=0.7
   - If count > MAX_MEMORIES (20), evict lowest-scored
   - Emit `GameEvents.memory_added(entity_id, fact, importance)`
   - Return the memory dict
4. Implement `score_memory(memory: Dictionary) -> float`:
   - Formula: `(importance_weight + recency_bonus + times_reinforced * 3.0 + (5.0 if emotional else 0.0)) * confidence`
   - importance_weight: high=10, medium=5, low=2
   - recency_bonus by game_day delta: same_day=10, 1_day=6, 2-3_days=3, 4-7_days=1, older=0
5. Implement `run_garbage_collection(current_game_day: int)`:
   - Recalculate all scores
   - Bottom 25% of memories: if not fuzzy, mark fuzzy=true; if already fuzzy, drop entirely
   - Enforce cap at MAX_MEMORIES
6. Stagger GC: connect to `GameEvents.game_hour_changed`, trigger when `hour == hash(npc_id) % 24`
7. Implement `get_memories_for_prompt(limit: int = 10) -> String` — return top-scored memories formatted for LLM
8. Implement `get_facts_about(topic: String) -> Array` — filter by topic
9. Implement `get_unshared_facts(target_id: String) -> Array` — facts where target_id not in shared_with
10. Implement `mark_fact_shared(memory_id: String, target_id: String)` — add to shared_with
11. **Keep** conversation_history, area_chat_log, goals_history unchanged
12. **Relationship stubs**: Keep deprecated relationship methods that delegate to RelationshipComponent if present, fallback to old dict otherwise. These stay until Wave 6-E.
13. Implement `_sync()` — write memories to `WorldState.entity_data[entity_id]`
**Verify**: Add 25 memories, check capped at 20. Score formula produces expected values. GC marks bottom 25% fuzzy. get_unshared_facts works correctly.

---

## Wave 2 — Wiring (depends on Wave 1)

### 2-A: Wire Components into npc_base.gd
**Ref**: NPC Data / Loadouts (PRODUCT.md)
**Files**: MOD `scenes/npcs/npc_base.gd`
**Depends on**: 1-A, 1-B
**Steps**:
1. In `_ready()`, after existing component setup:
   - Create NpcIdentity node: `var identity := NpcIdentity.new(); identity.name = "NpcIdentity"; add_child(identity)`
   - Create RelationshipComponent node: `var rel := RelationshipComponent.new(); rel.name = "RelationshipComponent"; add_child(rel)`
2. Load identity data: `var data := NpcIdentityDatabase.get_identity(npc_id); identity.setup(data)`
3. Migrate all `_memory.add_observation(text)` calls in npc_base.gd → `_memory.add_memory(text, "witnessed", "low")`
4. Migrate all `_memory.add_key_memory(type, text)` calls → `_memory.add_memory(text, "witnessed", "high", false, type)`
5. Keep existing `@export` vars and other component wiring unchanged
**Verify**: NPCs boot with NpcIdentity and RelationshipComponent as child nodes. Identity loaded from database. No add_observation/add_key_memory calls remain in npc_base.gd.

---

### 2-B: Update npc_action_executor.gd
**Ref**: Memory System (PRODUCT.md)
**Files**: MOD `scenes/npcs/npc_action_executor.gd`
**Depends on**: 1-C
**Steps**:
1. Find all `add_observation()` and `add_key_memory()` calls in action handlers
2. Replace with `add_memory()` using appropriate importance:
   - Combat events (attack, deal_damage, take_damage, defeat) → importance "high"
   - Interaction events (buy_item, sell_item, talk_to, use_item) → importance "medium"
   - Movement/ambient events (move_to, wait) → importance "low"
3. Ensure source is "witnessed" for all (these are direct NPC actions)
**Verify**: Execute actions, check NpcMemory has new scored memories with correct importance levels. No old API calls remain.

---

### 2-C: Response Parser Extension
**Ref**: Conversation Outputs (PRODUCT.md "What Needs to Change")
**Files**: MOD `scripts/llm/response_parser.gd`
**Depends on**: None
**Steps**:
1. Add new method `parse_conversation_response(response: Dictionary) -> Dictionary`
2. Extract text from response (reuse existing `_clean_chat_response()`)
3. Parse token rules:
   - Text starts with `[SILENCE]` → `{ valid: true, dialogue: "", action: "silence" }`
   - Text starts with `[LEAVE]` → `{ valid: true, dialogue: text_after_tag, action: "walk_away" }`
   - Text starts with `[TOPIC:xyz]` → `{ valid: true, dialogue: text_after_tag, action: "topic_change", new_topic: "xyz" }`
   - Anything else → `{ valid: true, dialogue: cleaned_text, action: "speak" }`
4. Handle edge cases: empty response → treat as silence; malformed tags → treat as speak
**Verify**: Test all 4 token types return correct action. Empty response → silence. Normal text → speak.

---

## Wave 3 — Brain & Prompt Integration (depends on Wave 2)

### 3-A: Update npc_brain.gd
**Ref**: Memory Extraction + Opinions + Impressions + Prompt Structure (PRODUCT.md)
**Files**: MOD `scenes/npcs/npc_brain.gd`
**Depends on**: 2-A, 2-C
**Steps**:
1. Add reference to NpcIdentity and RelationshipComponent (get from parent node)
2. Replace all `NpcTraits.pick_mood()` calls → `_identity.get_mood_prompt()`
3. Replace all `_memory.get_relationship_label(id)` calls → `_relationship.get_tier(id)`
4. **New LLM response routing**: In `_on_llm_response(req_id, response)`, route by prefix:
   - `extract_` → `_handle_extract_response(response)`
   - `fuzzy_` → `_handle_fuzzy_response(response)`
   - `opinion_` → `_handle_opinion_response(response)`
   - `impression_` → `_handle_impression_response(response)`
   - Existing prefixes continue to work
5. **Scaffold handlers** (bodies filled in Waves 4-5):
   - `_handle_extract_response(response)` — parse facts from extraction, store via memory.add_memory()
   - `_handle_fuzzy_response(response)` — update memory's fuzzy_text field
   - `_handle_opinion_response(response)` — parse opinion, store via identity.add_opinion()
   - `_handle_impression_response(response)` — parse impression, store via relationship.set_impression()
6. **New trigger methods** (called by signals, bodies filled in Waves 4-5):
   - `_request_memory_extraction(conversation_id: String)` — builds extraction prompt, sends with priority 4
   - `_request_impression_update(entity_id: String)` — sends impression prompt with priority 5
   - `_maybe_form_opinion(entity_id: String, fact: String, importance: String)` — if importance == "high", sends opinion prompt with priority 5
7. Connect to signals: `GameEvents.memory_added.connect(_on_memory_added)`, `GameEvents.relationship_tier_changed.connect(_on_tier_changed)`
**Verify**: Old NpcTraits/memory calls fully replaced. Response routing by prefix works. Signal connections established.

---

### 3-B: Conversation Prompt Builder
**Ref**: Prompt Structure (PRODUCT.md "What Needs to Change")
**Files**: MOD `scripts/llm/prompt_builder.gd`
**Depends on**: 1-A, 1-B
**Steps**:
1. Add constant `WORLD_BLOCK: String` — fixed game world description (setting, constraints, no modern language)
2. Add method `build_conversation_system_message(npc_node: Node, partner_ids: Array) -> String`:
   - Block 1 (World): Use WORLD_BLOCK constant
   - Block 2 (Character): personality from `identity.get_personality_prompt()`, mood from `identity.get_mood_prompt()`, tendencies from `identity.get_tendency_prompt()`, desires from `identity.get_desires_prompt()`, secrets from `identity.get_secrets_for_tier(tier)` (tier-gated per partner)
   - Block 3 (Context): for each partner, include tier + impression + tension from RelationshipComponent; include opinions tier-gated by `will_share_with`
   - Instruction: "Respond with 1-2 sentences as {name}. You may also: stay silent [SILENCE], change topic [TOPIC:new topic], or leave [LEAVE]. Stay in character. No narration. No modern language. Only reference known memories."
3. Add method `build_conversation_user_message(npc_node: Node, conversation: ConversationState) -> String`:
   - Conversation history (all turns formatted as "Speaker: text")
   - Recent memories from `memory.get_memories_for_prompt()`
   - Current opinions on conversation topic
4. Keep existing `build_system_message()` and `build_user_message()` for non-conversation LLM calls
**Verify**: System message contains all 3 blocks. Secrets only appear for close/bonded tiers. World block is identical across calls.

---

### 3-C: Update npc_behavior.gd
**Ref**: Schedule System + Relationships (PRODUCT.md)
**Files**: MOD `scenes/npcs/npc_behavior.gd`
**Depends on**: 2-A
**Steps**:
1. In `evaluate()`, add schedule override as step 2.5 (after survival checks, before goal evaluation):
   - `var identity = npc.get_node("NpcIdentity")`
   - If identity.schedule_type == "routine": `var sched_goal = identity.resolve_schedule_goal(TimeManager.get_hour())`
   - If sched_goal is not null and differs from current goal: set goal to sched_goal, execute it
2. In `_try_social_chat()`, replace affinity-based candidate sorting with tier-based:
   - Get RelationshipComponent from NPC node
   - Sort candidates by tier (bonded > close > friendly > acquaintance > recognized > stranger)
3. In `_try_social_chat()`, prepare ConversationManager call:
   - Instead of directly handling chat, call `ConversationManager.start_conversation(npc_id, [target_id], topic)` (ConversationManager built in Wave 4, but wire the call now — guard with `if conversation_manager:`)
**Verify**: Routine NPCs follow schedule goals. Candidates sorted by tier. Social chat attempts ConversationManager call.

---

## Wave 4 — ConversationManager (depends on Wave 3)

### 4-A: ConversationManager Core
**Ref**: ConversationManager & ConversationState (PRODUCT.md "What We Need to Add")
**Files**: NEW `scripts/conversation/conversation_manager.gd`
**Depends on**: 0-C, 0-D, Wave 3
**Steps**:
1. Create Node class extending Node
2. Data: `var active_conversations: Dictionary = {}` (conversation_id → ConversationState), `var entity_to_conversation: Dictionary = {}` (entity_id → conversation_id)
3. Constants: `SILENCE_TIMEOUT: float = 30.0`, `MAX_TURNS: int = 20`, `EARSHOT_RANGE: float = 15.0`, `TURN_COOLDOWN: float = 3.0`
4. Implement `start_conversation(initiator_id: String, target_ids: Array, topic: String) -> String`:
   - Generate conversation_id
   - Create ConversationState via factory
   - Register all participants in entity_to_conversation
   - Emit `GameEvents.conversation_started`
   - Return conversation_id
5. Implement `end_conversation(conversation_id: String)`:
   - Remove from active_conversations
   - Clean up entity_to_conversation entries
   - Emit `GameEvents.conversation_ended`
   - Trigger memory extraction for each NPC participant (call brain._request_memory_extraction)
6. Implement `join_conversation(conversation_id: String, entity_id: String)`:
   - Add to participants
   - Inject join turn
   - Emit `GameEvents.conversation_participant_joined`
7. Implement `leave_conversation(conversation_id: String, entity_id: String, reason: String = "walked away")`:
   - Remove from participants
   - Inject walk_away turn
   - Emit `GameEvents.conversation_participant_left`
   - If < 2 participants remain: end_conversation()
8. Implement `add_turn(conversation_id: String, turn: Dictionary)`:
   - Append to ConversationState.turns
   - Emit `GameEvents.conversation_turn_added`
   - Check MAX_TURNS → end if exceeded
9. Implement `get_conversation(entity_id: String) -> ConversationState` — lookup by entity
10. Implement `is_in_conversation(entity_id: String) -> bool`
11. Implement `update_nearby_listeners(conversation_id: String)` — scan for entities within EARSHOT_RANGE of conversation location
**Verify**: Start conversation between 2 NPCs, add turns, join a 3rd, leave one, end when < 2 remain. All signals fire correctly.

---

### 4-B: Turn Selection Algorithm
**Ref**: Turn Selection Algorithm (PRODUCT.md "What We Need to Add")
**Files**: MOD `scripts/conversation/conversation_manager.gd`
**Depends on**: 4-A
**Steps**:
1. Implement `select_next_speaker(conversation_id: String) -> String`:
   - For each participant (excluding player), calculate score:
     - `base = 1.0`
     - `+ topic_relevance (0-3)` — how relevant the topic is to this NPC (check identity likes/dislikes/opinions)
     - `+ relationship_bonus` — higher tier with recent speaker = more likely to respond
     - `+ personality_drive` — sociability trait * weight
     - `- recency_penalty` — spoke recently = less likely (last speaker gets -2.0)
     - `+ silence_streak_bonus` — +0.5 per consecutive silence from this NPC
     - `+ random_jitter` — randf_range(-0.3, 0.3)
   - If max score < SPEAK_THRESHOLD (2.0): return "" (no one wants to speak)
   - Player is never auto-selected (must voluntarily speak)
   - Return entity_id of highest scorer
2. Track consecutive silence counts per participant in ConversationState
3. If a participant has 3+ consecutive silences (MAX_CONSECUTIVE_SILENCE): auto-leave
4. If all participants silent for one round: end conversation
**Verify**: High-sociability NPCs score higher. Recent speakers penalized. 3 silences triggers auto-leave.

---

### 4-C: Turn Loop
**Ref**: ConversationManager (PRODUCT.md)
**Files**: MOD `scripts/conversation/conversation_manager.gd`
**Depends on**: 4-A, 4-B, 3-A
**Steps**:
1. Add `var _turn_timer: float = 0.0` per conversation (or global with per-conversation tracking)
2. In `_process(delta)`:
   - For each active conversation, decrement turn timer
   - When timer expires (TURN_COOLDOWN reached):
     - Call `select_next_speaker(conversation_id)`
     - If no speaker selected: increment global silence counter, check end condition
     - If speaker selected: get NPC brain node, call `brain.generate_conversation_turn(conversation_id)`
     - Brain calls LLM, response parsed by ResponseParser.parse_conversation_response()
     - Result passed back to `add_turn(conversation_id, turn)`
     - Reset turn timer
3. Round-robin across multiple active conversations (don't let one monopolize LLM)
4. Handle SILENCE_TIMEOUT: if no turns added for SILENCE_TIMEOUT seconds, end conversation
5. Guard against NPCs being in combat or dead (skip their turn, mark silence)
**Verify**: 2-NPC conversation runs start to finish. Multiple simultaneous conversations get fair time. Dead/combat NPCs don't stall conversations.

---

## Wave 5 — Memory Extraction & Opinions (depends on Wave 4)

### 5-A: Post-Conversation Memory Extraction
**Ref**: Memory Extraction (PRODUCT.md "What We Need to Add")
**Files**: MOD `scripts/conversation/conversation_manager.gd`, MOD `scenes/npcs/npc_brain.gd`
**Depends on**: 4-A, 1-C
**Steps**:
1. In `ConversationManager.end_conversation()`, for each NPC participant:
   - Call `npc_brain._request_memory_extraction(conversation_id)`
2. In `npc_brain._request_memory_extraction()`:
   - Build extraction prompt: "You are {name}. You just had this conversation: {transcript}. What 1-3 facts would you remember? List each fact on its own line."
   - Send via LLMClient with request_id `extract_{npc_id}_{conversation_id}`, priority 4
3. In `_handle_extract_response()`:
   - Parse response as line-separated facts
   - For each fact: call `_memory.add_memory(fact, "heard_from:{speaker_id}", "medium", false, "")`
   - Emit `GameEvents.fact_learned` for each fact
4. Graceful failure: if LLM call fails, conversation still ends, just no new memories
**Verify**: After a conversation ends, participants have new memories with correct sources. Facts show up in memory.get_memories_for_prompt().

---

### 5-B: Opinion Formation
**Ref**: Opinion System (PRODUCT.md "What We Need to Add")
**Files**: MOD `scenes/npcs/npc_brain.gd`, MOD `scripts/components/npc_identity.gd`
**Depends on**: 1-A, 5-A
**Steps**:
1. In `npc_brain._on_memory_added(entity_id, fact, importance)`:
   - If this NPC's entity_id AND importance == "high": call `_maybe_form_opinion(entity_id, fact, importance)`
2. In `_maybe_form_opinion()`:
   - Build prompt: "You are {name}, a {personality}. You just learned: '{fact}'. In one sentence, what is your opinion about this? Respond with: TOPIC: <topic>\nSTANCE: <positive/negative/neutral/curious/fearful>\nOPINION: <your take>"
   - Send via LLMClient with request_id `opinion_{npc_id}_{timestamp}`, priority 5
3. In `_handle_opinion_response()`:
   - Parse topic, stance, opinion text from response
   - Create opinion dict: `{ topic, take: opinion_text, strength: "moderate", will_share_with: "anyone", stance, reasoning: opinion_text, source: "experience", formed_at: timestamp }`
   - Store via `_identity.add_opinion(opinion_dict)`
   - Emit `GameEvents.opinion_formed(entity_id, topic, stance)`
**Verify**: High-importance memory triggers opinion formation. Opinion stored in NpcIdentity. Appears in subsequent conversation prompts.

---

## Wave 6 — Player UX & Cleanup (depends on Wave 5)

### 6-A: Player Conversation UX
**Ref**: Multi-Party Conversations (PRODUCT.md "What We Need to Add")
**Files**: MOD `scenes/player/player.gd`, MOD `scenes/ui/chat_log.gd`, MOD `scenes/ui/chat_input.gd`
**Depends on**: 4-A
**Steps**:
1. In player.gd, add `var _nearby_conversation_id: String = ""`
2. In `_process()`: scan for nearby conversations via ConversationManager — if any active conversation has participant within EARSHOT_RANGE of player position, set _nearby_conversation_id
3. Show UI indicator when nearby conversation detected (e.g., "Press E to join conversation")
4. Input handling: E key when near conversation → `ConversationManager.join_conversation(conversation_id, "player")`
5. When player is in conversation: open chat input, allow typing responses
6. Player response → `ConversationManager.add_turn(conversation_id, { speaker_id: "player", text: input, action: "speak" })`
7. Auto-leave: when player walks beyond EARSHOT_RANGE, call `ConversationManager.leave_conversation()`
8. Chat log: connect to `GameEvents.conversation_turn_added` — display turns with speaker names, color-coded per NPC
**Verify**: Player can detect, join, speak in, and leave NPC conversations. Chat log shows full history.

---

### 6-B: Game World Wiring
**Ref**: All systems
**Files**: MOD `scenes/game_world/game_world.gd`
**Depends on**: Waves 1-4
**Steps**:
1. In `_ready()`: instantiate ConversationManager as child node
2. Store reference: `var conversation_manager: Node`
3. Expose to NPCs: either via method `get_conversation_manager()` or set on each NPC brain/behavior
4. In NPC setup loop: ensure `identity.setup()` is called after NpcIdentity node is added (may already happen in npc_base._ready() from Task 2-A)
5. Wire ConversationManager reference to NPCBehavior (for social chat routing) and NPCBrain (for conversation turn generation)
**Verify**: All NPCs boot with identity loaded. ConversationManager accessible. No startup crashes.

---

### 6-C: NpcTraits Cleanup
**Ref**: NPC Data / Loadouts (PRODUCT.md)
**Files**: MOD `scripts/data/npc_traits.gd`
**Depends on**: 3-A
**Steps**:
1. Remove: `BACKSTORIES` dict, `VOICE_STYLES` dict, `MOODS` array, `pick_mood()` method
2. Grep entire codebase for references to removed items — should be zero (migrated in 3-A)
3. Add: `const NPC_TENDENCIES: Dictionary` — maps npc_id to tendency description string for all 9 NPCs
4. Add: `const NPC_AVOIDS_TOPICS: Dictionary` — maps npc_id to Array of topic strings
5. Keep: `PROFILES`, `get_trait()`, `get_trait_summary()`
**Verify**: No references to removed methods/constants in codebase. NPC_TENDENCIES has entries for all NPCs. Existing get_trait() still works.

---

### 6-D: Shop NPC Migration
**Ref**: Shop NPC Migration (PRODUCT.md "What We Need to Add")
**Files**: MOD `scripts/data/npc_identity_database.gd`, MOD `scenes/npcs/npc_behavior.gd`, MOD `scenes/npcs/npc_action_executor.gd`, MOD `scenes/game_world/game_world.gd` (shared with 6-B — coordinate edits), DEPRECATED `scenes/npcs/shop_npc.gd`
**Depends on**: 6-B, 1-A
**Steps**:
1. Update weapon_shop_npc and item_shop_npc NpcIdentityDatabase entries with full shop_type, shop_items, and routine schedule data
2. In NPCBehavior: add `tend_shop` goal handler — navigate to shop location, stay in place, face outward
3. In NPCActionExecutor: update buy_item/sell_item to read shop_items from NpcIdentity instead of shop_npc
4. In game_world.gd: spawn shop NPCs as npc_base scenes instead of shop_npc StaticBody3D
5. Remove all references to shop_npc.gd
**Verify**: weapon_shop_npc and item_shop_npc spawn as npc_base entities. Trade interaction works (E key, buy/sell). Shop NPCs follow routine schedule.

---

### 6-E: Relationship Stub Removal
**Ref**: Relationships (PRODUCT.md)
**Files**: MOD `scenes/npcs/npc_memory.gd`
**Depends on**: 3-A, 2-A
**Steps**:
1. Remove all deprecated relationship methods from NpcMemory (get_relationship_label, get_affinity, set_affinity, modify_affinity, record_shared_combat, record_conversation, etc.)
2. Remove old `var relationships: Dictionary = {}` fallback dict
3. Grep codebase for any remaining calls to these methods — should be zero
4. Remove any backward-compat delegation code added in Task 1-C
**Verify**: NpcMemory has zero relationship methods. All relationship access goes through RelationshipComponent. No regressions in NPC behavior.
