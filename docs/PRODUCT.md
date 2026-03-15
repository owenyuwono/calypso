# NPC System — Gap Analysis

Comparison of `docs/npc-system-design.md` (design vision) against the current codebase.

**Full technical spec**: [`docs/npc-system-spec.md`](npc-system-spec.md) — unified design covering all systems below with data models, APIs, and implementation tasks.

---

## What We Already Have

### One-Speaker-Per-Call Architecture
Each LLM call generates one NPC's response. `NPCBrain` sends a single chat request per decision cycle.

### Goal-Driven Behavior State Machine
`NPCBehavior` implements a deterministic goal state machine: hunt_field → sell_loot → buy_potions → return_to_town, with survival checks (low HP, low stamina) as highest priority. Matches the design's "goal-driven" schedule type.

### LLM Decision Loop + Deterministic Fallback
`NPCBrain` queries LLM every 5s when idle. If LLM unavailable, `NPCBehavior` runs deterministic fallback. Hybrid approach already matches the design's "code/rules + 4B model" two-layer split.

### Action Executor
`NPCActionExecutor` handles: move_to, attack, use_item, buy_item, sell_item, talk_to, wait. Matches the design's expectation that actions are code-driven, not LLM-driven.

### Per-NPC Memory
`NPCMemory` stores per-NPC: observations (20 rolling), key_memories (10 rolling), conversation_history (10 per partner), area_chat_log (15 rolling), relationships, goals_history. Information is local to each NPC — no global fact pool.

### Per-NPC Relationship Tracking
`NPCMemory.relationships` tracks affinity [-1,1], shared_combat count, conversations count, last_interaction per partner. NPCs track relationships with each other, not just with the player.

### Social Chat System
`NPCBehavior` initiates social chat based on sociability trait, picks targets by affinity, selects intent from 8 options (ask_question, share_story, brag, complain, warn, gossip, joke, ask_advice), respects cooldowns and turn limits (3 turns per partner per 120s window).

### Entity Component System
StatsComponent, InventoryComponent, EquipmentComponent, CombatComponent, ProgressionComponent, AutoAttackComponent, StaminaComponent — all composition nodes on entity.

### Signal-Based Event Bus
`GameEvents` emits: npc_action_completed, npc_spoke, entity_damaged, entity_healed, entity_died, entity_respawned, proficiency_xp_gained, proficiency_level_up, item_purchased, item_sold, time_phase_changed, item_looted, skill_used, skill_learned, stamina_changed.

### Perception System
`WorldState.get_npc_perception()` returns nearby monsters, NPCs, shops, locations, items, and objects within radius. Used by both LLM prompts and deterministic behavior.

### NPC Loadouts & Personality
`NpcLoadouts` defines 7 adventurer NPCs with trait profiles (boldness, sociability, generosity, curiosity), voice styles, backstories, starting items/gold/goals. `NpcTraits` maps traits to behavior parameters.

### Day/Night Awareness
Cautious NPCs (boldness < 0.4) return to town at night. Time phase (dawn/day/dusk/night) included in LLM prompts.

---

## What Needs to Change

### Memory System → Scored, Tagged, Source-Tracked, Fuzzy

**Current**: Two rolling arrays — `observations` (20, FIFO) and `key_memories` (10, FIFO). Each entry is `{type, text, time}`. No source tracking, no importance scoring, no forgetting mechanics.

**Design target**: Each memory is `{fact, source (witnessed/heard_from:X/overheard), importance (high/med/low), emotional (bool), times_reinforced, timestamp, fuzzy (bool), game_day (int), confidence (float 0-1: observed=1.0, heard=0.7, heard_from_liar=0.4), fuzzy_text (String, degraded version), topic (String, category tag), shared_with (Array[String])}`. Capped at ~20 with scoring-based eviction. Fuzzy degradation: sharp → fuzzy → almost gone → dropped. Nightly garbage collection.

**What changes**: Unify observations + key_memories into a single scored memory array. Add source, importance, emotional, reinforcement fields. Replace FIFO with score-based eviction. Scoring formula: `(importance_weight + recency_bonus + times_reinforced*3 + emotional_bonus) * confidence`. Staggered GC: triggered per NPC via `hash(npc_id) % 24` on `game_hour_changed`, bottom 25% marked fuzzy, already-fuzzy below threshold dropped, cap enforced at MAX_MEMORIES. Add fuzzy text degradation (LLM call or template-based).

### Relationships → Tier System with Impressions, Tension, History

**Current**: `{affinity: float, shared_combat: int, conversations: int, last_interaction: float}`. Affinity increments: +0.05/conversation, +0.1/shared combat. Labels derived from affinity thresholds.

**Design target**: New **`RelationshipComponent`** node extracted from NpcMemory. `{tier (stranger → recognized → acquaintance → friendly → close → bonded), impression (LLM-generated sentence), tension (float 0.0-1.0, independent of tier), history [{event, timestamp, game_day}]}`. Tiers are event-triggered, not point-based. Each tier unlocks behavior (strangers = generic dialogue, close = confide/defend/worry).

**What changes**: Replace affinity float with tier enum. Add impression string (updated by LLM after meaningful interactions). Add tension float (0.0-1.0). Replace counters with event history array. Demotion rules: tension > 0.7 for 3+ interactions → drop one tier; attacked → drop to recognized. Promotion triggers are event-driven (spec Section 6.2 has full table). Implement tier-gated behavior in prompts and social chat logic.

### Mood → Two-Axis with Baseline Decay

**Current**: Single string from 8 options (neutral, pumped, thoughtful, irritated, relaxed, curious, cocky, tired). Set per decision but doesn't change from game events. No decay.

**Design target**: Two axes — emotion (content/worried/angry/sad/excited/afraid) + energy (tired/normal/energetic). Each NPC has baseline_emotion and baseline_energy. Event triggers:
- `entity_damaged (>20% HP)` → worried
- `entity_damaged (<20% HP)` → afraid
- `entity_died (nearby enemy)` → content + energetic
- `proficiency_level_up` → excited + energetic
- `entity_died (self)` → sad + tired
- `entity_respawned` → content + tired
- `conversation_started (player in)` → excited

**What changes**: Replace mood string with `{emotion, energy, baseline_emotion, baseline_energy}`. Add event-driven mood shifts (connect to GameEvents signals). Decays toward baseline per game hour via `GameEvents.game_hour_changed`. Update prompts to use both axes.

### NPC Data / Loadouts → Richer Character Data

**Current**: Loadouts have trait profile (4 floats), backstory, voice_style, starting items/gold/goal. No age, occupation, likes, dislikes, desires, opinions, secrets, or tendencies.

**Design target**: New **`NpcIdentity`** composition node on each NPC, backed by **`NpcIdentityDatabase`** static RefCounted (replaces NpcLoadouts/NpcTraits). Each NPC has age (String: young/adult/old, narrative only), occupation, personality.likes/dislikes, desires [{want, intensity}], opinions [{topic, take, strength, will_share_with}], secrets [{fact, known_by}], tendencies {exaggerates, withholds_from_strangers, lies_when, avoids_topic}.

**What changes**: Replace NpcLoadouts/NpcTraits with NpcIdentityDatabase. Introduce NpcIdentity as a composition node. Opinions and memories are dynamic (formed during gameplay), but NPCs can have starting opinions/secrets. Tendencies and desires are static character data.

### Prompt Structure → Three-Block Format

**Current**: System prompt combines personality + goals + action list. User prompt combines stats + perception + memory. Chat prompt is separate. No opinions, tensions, secrets, or desires in prompts.

**Design target**: Block 1 (World — constant setting/constraints), Block 2 (Character — personality, speech, desires, tendencies, mood, secrets), Block 3 (Context — relationships + tensions, active memories, opinions, conversation history). Instruction: 1-2 sentences, stay in character, memory-grounded, can exaggerate/withhold/lie per tendencies.

**What changes**: Restructure `PromptBuilder` into 3 blocks. Add desires, tendencies, secrets, opinions to character block. Opinions in context block are tier-gated via `will_share_with` field. Two opinion formation paths: personality-derived (at creation) and experience-derived (post-conversation). Add relationship tensions and scored memories to context block. Update instruction to reference tendency-driven behavior.

### Conversation Outputs → Support Silence and Walking Away

**Current**: LLM always generates dialogue. No structured support for silence, deflection, or leaving.

**Design target**: Valid outputs include silence, one-word answers, changing subject, or walking away. Specific token types: `[SILENCE]` → silence action, `[LEAVE]` → walk_away action, `[TOPIC:xyz]` → topic_change action.

**What changes**: Add parsing support in `ResponseParser` for silence/walk-away tokens. Add action handling in `ConversationManager` for conversation exit. Update prompts to explicitly allow these outputs.

---

## What We Need to Add

### Opinion System
NPCs form opinions after learning new facts. Full opinion model: `{topic, take, strength (strong/moderate/mild), will_share_with (anyone/close only/keeps to self), stance (positive/negative/neutral/curious/fearful), reasoning (one-sentence rationale), source (personality/experience/heard_from:{id}), formed_at (timestamp)}`. Same fact → different opinions per NPC based on personality. Opinions drive conversation more than raw facts. Could be LLM-generated post-conversation or template-based.

### Secrets System
Facts known only to specific NPCs: `{fact, known_by [], reveal_condition}`. `reveal_condition` (String) controls when/how the secret can be shared. Creates tension and depth. NPCs protect secrets based on relationship tier and tendencies. Secrets can be revealed under pressure, to close friends, or accidentally. Starting secrets defined in loadouts; new secrets formed during gameplay.

### Behavioral Tendencies
Structured data per NPC: `{exaggerates: bool, withholds_from_strangers: bool, lies_when: string, avoids_topic: []}`. Fed into LLM prompts to guide dialogue generation. Not just personality flavor — these actively filter what NPCs share and how they distort it.

### Desires System
Motivational wants with intensity: `[{want: string, intensity: high/med/low}]`. Drive proactive behavior — NPCs seek situations that fulfill desires. Create internal conflict when desires clash with circumstances. Influence goal selection and social interactions. Different from goals: goals are functional tasks, desires are emotional motivations.

### Memory Extraction (Post-Conversation LLM Call)
After each conversation ends, LLM call extracts what the NPC would remember. Personality filters what they care about (guard remembers threats, baker remembers danger). Each extracted memory gets tagged with source (heard_from:X), importance, emotional flag. This is how information enters NPC memory from conversations — the core of the "no world facts" principle.

### Memory Forgetting (Nightly Garbage Collection)
Each in-game night, recalculate memory scores and clean up. Score = importance_weight (high=10, med=5, low=2) + recency_bonus (same day=10, yesterday=6, etc.) + repetition_bonus (+3 per reinforcement) + emotional_bonus (+5 permanent). Drop lowest scores when over cap. Memories below threshold go fuzzy, below lower threshold get dropped entirely.

### Fuzzy Memory Degradation
Three states: sharp ("wolves attacked east gate, three of them") → fuzzy ("wolves attacked east gate recently") → almost gone ("some trouble at the east gate"). Could be LLM-generated or template-based (replace specifics with vague terms). Fuzzy memories included in prompts with reduced weight.

### Information Propagation
When NPCs converse, facts transfer. NPC A tells NPC B about wolves → B gets a memory with source "heard_from:A". Distortion happens based on tendencies: exaggerating NPCs inflate, self-interested NPCs downplay, scared NPCs dramatize. Player telling an NPC something creates a memory with source "heard_from:player". This is how news spreads through the world organically.

### Routine Schedules
Time-slot-based daily patterns for NPCs with `schedule_type: "routine"`. Example: baker bakes at dawn, sells at morning market, eats at tavern in evening. Requires mapping game hours to named time slots (dawn/morning/afternoon/evening/night) and location-based activity resolution.

### Periodic Schedules
Visit patterns for NPCs like traveling merchants: `{visits: "every 3 days", duration: "1 day", location_when_present, location_when_absent}`. Requires day counter and presence/absence state management.

### Multi-Party Conversations
Conversation state object tracking: participants (list), location, topic, turns (history), nearby NPCs who could join, overall mood. Interest scoring determines who speaks next (topic relevance + personality). NPCs can join mid-conversation ("walks over, having overheard"). NPCs can leave naturally. Currently all conversations are 1:1.

### LLM-Generated Impressions
After meaningful interactions, LLM generates a one-sentence impression update for the relationship. Example: "New face. Seems capable." → "Helped me fight wolves. Brave, maybe reckless." Stored per-relationship, included in prompts for context.

### Tier-Gated Behavior
Relationship tier determines what NPCs share and do. Strangers get generic dialogue. Acquaintances get opinions shared with "anyone". Friends get closer opinions and help in combat. Close/bonded NPCs confide secrets, defend each other, worry when the other is hurt. Tier checks gate prompt content and behavioral triggers.

### ConversationManager & ConversationState
Multi-party conversation orchestrator added to game_world. `ConversationState` tracks: participants, location, topic, turns (Array of ConversationTurn), nearby_listeners, mood (friendly/tense/casual/heated/quiet). `ConversationManager` handles: start/end/join/leave, turn pacing via TURN_COOLDOWN, multiple active conversations round-robin, SILENCE_TIMEOUT auto-end, MAX_TURNS enforcement. All NPC social interactions route through ConversationManager — 1:1 conversations are the minimum case of multi-party.

### Turn Selection Algorithm
Code-driven turn selection (not LLM). Scoring formula: `base(1.0) + topic_relevance(0-3) + relationship_bonus + personality_drive + recency_penalty + silence_streak_bonus + random_jitter`. SPEAK_THRESHOLD = 2.0, JOIN_THRESHOLD = 2.5. Player is never auto-selected (always voluntary). 3 consecutive silences from one NPC = auto-leave. MAX_CONSECUTIVE_SILENCE = 3 ends conversation if all participants silent.

### LLM Priority Queue
`LLMClient.send_chat()` gains optional `priority` parameter (1-5, default 3). Queue sorted by priority. Request routing by prefix: `conv_player_` (priority 1, player conversations), `conv_` (priority 2, NPC conversations), existing decision-making (priority 3, default), `extract_` (priority 4, memory extraction), `fuzzy_` / `opinion_` / `impression_` (priority 5, deferred background tasks).

### Schedule System
Three schedule types managed by NpcIdentity: **Routine** (fixed daily pattern with start_hour/end_hour/goal/location per slot, e.g. baker bakes at dawn), **Periodic** (visit patterns with duration_hours and cycling, e.g. traveling merchant every 3 days), **Goal** (existing NPCBehavior goal-driven behavior, unchanged). NPCBehavior.evaluate() gains schedule override as step 2.5 in priority chain.

### New Signals
10 new signals added to GameEvents: `mood_changed(entity_id, emotion, energy)`, `memory_added(entity_id, fact, importance)`, `relationship_tier_changed(entity_id, partner_id, old_tier, new_tier)`, `conversation_started(conversation_id, participant_ids)`, `conversation_ended(conversation_id)`, `conversation_participant_joined(conversation_id, entity_id)`, `conversation_participant_left(conversation_id, entity_id)`, `conversation_turn_added(conversation_id, speaker_id, dialogue, action)`, `fact_learned(entity_id, fact_content, source)`, `opinion_formed(entity_id, topic, stance)`.

### Shop NPC Migration
`shop_npc.gd` deprecated. All NPCs (including shopkeepers) use `npc_base` with NpcIdentity. A shopkeeper is an NPC whose NpcIdentityDatabase entry has `schedule_type: "routine"` and a "make profit" desire. No special-casing — shops are behavior, not a separate class. Requires NpcIdentityDatabase entries for weapon_shop and item_shop with shop_type/shop_items fields, and a `tend_shop` goal handler in NPCBehavior.

### Implementation Roadmap
23 implementation tasks across 7 waves (Wave 0-6) with dependency graph. See `npc-system-spec.md` Section 17 for full task breakdown. Wave 0 = foundation (signals, database, data classes, LLM queue). Wave 1 = new components. Wave 2 = wiring. Wave 3 = brain/prompt integration. Wave 4 = ConversationManager. Wave 5 = memory extraction + opinions. Wave 6 = player UX + cleanup.
