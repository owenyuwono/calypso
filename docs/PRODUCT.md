# Arcadia — Product Roadmap

## Vision

A living world where the player is just another person — not the chosen one, not the hero. Every character is LLM-powered and feels like an actual person with their own life, goals, relationships, and memories. The world exists independently of the player: NPCs trade, fight, gossip, form opinions, hold grudges, and build friendships whether or not you're watching. Your actions matter not because the game gives you a quest marker, but because the people around you remember what you did.

## Current State (Milestone 0 — Playable Prototype)

### Done
- **World**: 3 zones (Prontera City with 8 districts + East/West Fields), ~97 buildings, terrain painting, portals
- **NPCs**: 12 named + 50 procedural, full LLM-driven AI (event-triggered, not timer), personality traits, goal-driven behavior
- **Combat**: 15 active skills across 5 weapon types, synergy system (proficiency-scaled effectiveness, multi-proficiency bonuses, self-harm on overreach)
- **Progression**: 13 proficiencies (RuneScape-style use-based XP), stat derivation, skill synergy
- **Economy**: 60+ items, count-based inventory, 8-slot equipment, NPC vending from inventory
- **Gathering**: Mining (3 ore tiers), woodcutting, respawn mechanics
- **Social**: Gossip propagation (15% distortion per retelling), relationship tiers (stranger→bonded), scored memory (max 20, source-tracked), multi-party conversations
- **UI**: Sidebar proficiency/skill panel, inventory, status, hotbar, minimap, world map, chat log, dialogue bubbles, hover skill tooltips
- **LLM**: Ollama async pool (10 concurrent), priority queue, compact prompts, event-driven triggers, canned fallbacks

### Missing
- Crafting mechanics (proficiency icons exist, no gameplay)
- Audio (no BGM, no SFX)
- Quest/objective system
- Housing / persistent player space
- Day/night visual cycle (time system exists, no lighting changes)
- More zones (dungeons, wilderness, other towns)
- Deeper NPC autonomy (schedules, routines, long-term goals)

---

## Milestone 1 — Living Routines (COMPLETE)

**Theme**: NPCs feel alive because they have daily lives, not just reactive behaviors.

- [x] **NPC Schedules**: Routine-based daily patterns. Shop NPCs follow time-slot routines via `npc_behavior.gd`
- [x] **NPC Opinions**: NPCs form opinions via LLM, stored in NpcIdentity, included in conversation prompts with tier-gating
- [x] **NPC Desires**: Motivational wants defined per NPC in NpcIdentityDatabase, included in LLM prompts
- [x] **Behavioral Tendencies**: Exaggeration, withholding, lying tendencies active in prompt generation
- [x] **Conversation Silence/Exit**: NPCs auto-leave after 3 silent turns, walk_away mechanic, silence tracking
- [x] **Day/Night Lighting**: DayNightCycle script smoothly transitions sun, ambient, and fog across dawn/day/dusk/night phases

---

## Milestone 2 — Memory & Reputation (COMPLETE)

**Theme**: The world remembers. Your actions have social consequences that ripple through NPC networks.

- [x] **Memory Extraction**: Post-conversation LLM call via `npc_brain.request_memory_extraction()`, personality-filtered
- [x] **Memory Degradation**: Scored memory with fuzzy degradation, nightly GC via `npc_memory.run_garbage_collection()`
- [x] **LLM-Generated Impressions**: Triggered on relationship tier changes, stored via `relationship_component.set_impression()`
- [x] **Tier-Gated Behavior**: Relationship tiers gate opinion/secret sharing in prompts
- [x] **Reputation Propagation**: Gossip system with 15% distortion, rumor decay, spread tracking
- [x] **NPC Secrets**: Defined in NpcIdentityDatabase, included in prompts only at close/bonded tier

---

## Milestone 3 — Crafting & Economy

**Theme**: The economy is player-driven and NPC-driven. Everyone participates.

- **Crafting System**: Smithing (ore → weapons/armor), cooking (ingredients → food buffs), crafting (materials → tools/accessories). Recipe discovery through experimentation or NPC tips
- **Crafting UI**: Workbench interaction, recipe list, material requirements, success chance based on proficiency
- **NPC Crafters**: NPCs with production proficiencies craft and sell their output. A skilled NPC smith produces better gear than a novice
- **Dynamic Pricing**: Item prices influenced by supply/demand. If wolves are hunted heavily, fur becomes cheap. If nobody mines, ore prices rise
- **Trade Routes**: NPCs travel between zones to buy low and sell high. Merchant NPCs have preferred trade routes
- **Player Shops**: Set up a persistent shop stall in the market district. Price your inventory, NPCs browse and buy

**Success criteria**: Craft a sword from mined ore. Sell it to an NPC merchant who resells it at markup. Another NPC buys it and equips it in combat.

---

## Milestone 4 — World Expansion

**Theme**: The world grows. New places to explore, new dangers, new communities.

- **Dungeon Zone**: Underground area with tougher monsters, rare ore, environmental hazards. Multi-floor with increasing difficulty
- **Second Town**: A smaller settlement with its own NPC population, culture, and economy. NPCs can travel between towns
- **Wilderness**: Untamed zone between towns. Random encounters, rare resources, bandit NPCs
- **World Events**: Periodic emergent events (monster invasion, merchant caravan, festival, drought) that affect NPC behavior and create shared experiences
- **Fast Travel**: Unlockable waypoints between visited locations

**Success criteria**: Travel from Prontera to the new town. Notice NPCs discussing the journey, referencing landmarks. A merchant NPC you know from Prontera shows up at the new town's market.

---

## Milestone 5 — Audio & Polish

**Theme**: The world sounds alive.

- **Zone BGM**: Distinct music per zone with crossfade on transition (town = peaceful, fields = adventurous, dungeon = tense)
- **Combat SFX**: Hit sounds, skill effects, monster death, critical hits
- **Ambient SFX**: Town bustle, forest birds, mine echoes, market chatter
- **UI SFX**: Button clicks, panel open/close, item equip, level up fanfare
- **NPC Voice Tones**: Short audio cues for NPC speech types (greeting, angry, sad, excited) — not full voice acting, just tonal indicators
- **Visual Polish**: Particle effects for skills, smoother animations, camera shake on big hits

**Success criteria**: Close your eyes in town. You can tell where you are from sound alone. Open a shop and the UI feels satisfying. Use a skill and the feedback is punchy.

---

## Milestone 6 — Emergent Stories

**Theme**: The world generates its own narratives. You participate in stories, not follow quest markers.

- **NPC Long-Term Goals**: NPCs pursue multi-day objectives (save enough gold to buy a house, become the best swordsman, find a missing friend). These create story arcs that intersect with player and other NPC activities
- **NPC Alliances & Rivalries**: NPCs form factions based on shared goals, personality compatibility, and history. Rivalries emerge from competition, betrayal, or clashing opinions
- **Emergent Quests**: Instead of scripted quests, NPCs ask for help based on genuine needs ("I need iron ore for my order, I'll pay well" from a smith who's actually low on stock). Completion affects their actual inventory and reputation
- **Player Reputation System**: Aggregated from NPC impressions. Multiple reputation axes (helpful, dangerous, trustworthy, skilled, wealthy). NPCs react to your reputation, not a quest flag
- **NPC Death Consequences**: When an NPC dies permanently, their friends grieve, their shop closes, their enemies celebrate. The world feels the loss
- **Player Journal**: Auto-generated journal entries from significant events, conversations, and discoveries. Not quest objectives — a diary of your life in this world

**Success criteria**: Play for an hour without any scripted direction. Find yourself naturally drawn into an NPC's problem. Help or ignore them — either way, the world reacts. A week of in-game time later, the consequences of your choice are still visible in NPC conversations and behaviors.

---

## Principles

1. **No chosen one** — The player is a newcomer in a world that existed before them and will exist after them
2. **No quest markers** — NPCs ask for help because they need it, not because a designer wrote a quest
3. **Every NPC is a person** — They have memories, opinions, relationships, and daily lives. They're not vending machines with dialogue
4. **Actions have social consequences** — Kill, help, lie, trade — the world remembers through its people
5. **Emergent over scripted** — Systems that generate stories are better than handcrafted narratives
6. **Simplicity in mechanics, depth in interactions** — Combat and progression stay simple. The complexity is in how people treat you
7. **LLM as personality, not as game designer** — The LLM gives NPCs voice and judgment. Game rules handle mechanics
