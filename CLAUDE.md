# Arcadia — Godot 4.6 GDScript Project

## Conventions
- **Engine**: Godot 4.6, GDScript only
- **Fonts**: Marcellus-Regular for body text (`GAME_FONT`, `GAME_FONT_BOLD`, project default). Philosopher-Bold for display/titles (`GAME_FONT_DISPLAY`). Set in `project.godot` + `UIHelper` constants
- **Autoload singletons**: WorldState (registry only), GameEvents (signals), TimeManager (24h day cycle: dawn/day/dusk/night phases, `time_phase_changed` signal), ZoneManager (zone transitions: async load, fade, nav reset), AudioManager (UI SFX pool + master mute on startup)
- **Static utility classes**: ModelHelper (3D models, effects, animation merging, `create_toon_material()`, `apply_toon_to_model()`, `create_fallback_mesh()`, `spawn_damage_number()`), UIHelper (panel styles, UI helpers), NpcLoadouts (NPC starting data), NpcGenerator (procedural NPC creation), NpcTraits (personality axes + trait profiles), NpcIdentityDatabase (named NPC identity data), DialogueDatabase (scripted dialogue + canned greetings), GossipSystem (fact propagation), SkillDatabase (skill definitions), SkillEffectResolver (skill damage resolution), OreDatabase (mining tier data), FishDatabase (fishing tier data), RecipeDatabase (unified crafting recipes), TreeDatabase (tree tier data), ProficiencyDatabase (19 skills, 4 categories, XP formulas), SfxDatabase (audio SFX key→path/volume/pitch mapping), MonsterDatabase (monster type definitions: stats, model, resistances), ItemDatabase (item definitions: weapons, armor, consumables), LevelData (base player stats), ZoneDatabase (zone metadata + portal connections), InteriorDatabase (building_type → interior scene mapping), world builders (see below)
- **Composition nodes**: EntityVisuals (visual state: model, overlay, animations, HP bar) + AudioComponent (per-entity positional audio: footsteps, presence, combat loops, one-shot SFX) + AutoAttackComponent (signal-based auto-attack shared by all entities) + PerceptionComponent (Area3D-based spatial awareness per entity) + entity components (stats, inventory, equipment, combat, progression, skills) for all entities
- **Duck typing**: Component vars declared as `Node`, called with duck-typed method calls. Use `var x: int = node.method()` (not `:=`) when return type can't be inferred
- **State machines**: String-based states (idle/thinking/moving/combat/dead)
- **Inventory**: Count-based Dictionary {item_type_id: count}, not arrays
- **No automated tests**: Verify manually in editor (panels, combat, minimap, world map, chat)
- **Input**: Left-click move/attack/interact/open dialogue (click NPC), E interact, I inventory, C status, S skills, P proficiencies, 1-5 hotbar, Esc close/settings

## Coding Principles
- **SOLID**: Single responsibility per script/node. Open for extension (signals, composition). Depend on interfaces (duck typing), not concrete types
- **Keep It Simple (KISS)**: Simplest solution that works. No premature abstraction. Three similar lines > one clever helper
- **Godot's philosophy**: Composition over inheritance (child nodes, not deep class hierarchies). Nodes as building blocks. Signals for decoupling. GDScript idiomatic patterns (match, @onready, @export). Scene tree is the architecture

## Entity Component System
Each entity (player, NPC, monster) owns its state via child Node components:
- `StatsComponent` — hp, max_hp, atk, def, matk, mdef, accuracy, evasion, crit_rate, crit_damage, attack_speed, attack_speed_mult, attack_range, move_speed, cast_speed, max_stamina, stamina_regen, hp_regen, cooldown_reduction, level. **Must set `.name = "StatsComponent"` before `add_child()`**. API: `take_damage()`, `heal()`, `restore_full_hp()`, `is_alive()`, `get_stats_dict()`
- `InventoryComponent` — items dict + gold. API: `add_item()`, `remove_item()`, `has_item()`, `get_items()`, `add_gold_amount()`, `remove_gold_amount()`, `get_gold_amount()`, `set_gold_amount()`
- `EquipmentComponent` — 8 slots (head, torso, legs, gloves, feet, back, main_hand, off_hand). Items route to slot via `slot_type` field (fallback: weapon→main_hand, armor→off_hand). Requires InventoryComponent ref. API: `equip()`, `unequip()`, `get_slot(name)`, `get_weapon()`, `get_armor()`, `get_atk_bonus()`, `get_def_bonus()`, `get_matk_bonus()`, `get_mdef_bonus()`, `get_armor_type()`. Bonuses summed across all slots
- `CombatComponent` — damage/heal logic. Requires StatsComponent + optional EquipmentComponent. API: `deal_damage_to()`, `deal_damage_amount_to()`, `deal_damage_amount_to_with_pierce()`, `apply_flat_damage_to()`, `heal()`, `get_effective_atk()`, `get_effective_matk()`, `get_effective_def()`, `get_effective_mdef()`, `get_armor_type()`, `get_equipped_phys_type()`, `roll_hit()`, `roll_crit()`, `is_alive()`, `get_attack_speed_multiplier()`, `get_equipped_weapon_type()`
- `ProgressionComponent` — owns proficiency state `{skill_id: {level, xp}}`. Derives stats from proficiency levels. Requires StatsComponent. API: `grant_proficiency_xp()`, `get_proficiency_level()`, `get_proficiency_xp()`, `get_total_level()`, `get_proficiencies()`
- `SkillsComponent` — active skills (no skill points). Skills unlock via proficiency milestones. API: `unlock_skill()`, `grant_skill_xp()`, `has_skill()`, `get_skill_level()`, `set_hotbar_slot()`, `get_hotbar()`
- `VendingComponent` — vending state, listings, buy/sell. **Must set `.name = "VendingComponent"` before `add_child()`**. API: `start_vending()`, `stop_vending()`, `is_vending()`, `get_listings()`, `get_shop_title()`, `buy_from()`, `refresh_listings(inventory, equipment)`, `add_listing(item_id, count, price)`
- `PerceptionComponent` — Area3D-based spatial awareness (radius 15). Tracks nearby entities via `body_entered`/`body_exited` signals on collision layer 9 (bit 8). **Area3D must be parented to entity Node3D, not the component Node.** API: `get_perception(radius)`, `get_nearby(radius)`, `is_tracking(id)`, `get_distance_to(id)`
- `AutoAttackComponent` — signal-based auto-attack shared by all entities. Requires visuals + combat + nav_agent. Emits `attack_landed(target_id, damage, target_pos)` and `target_lost()`. `process_attack()` handles chase + stuck detection
- `StaminaComponent` — skill resource pool with fatigue system. No passive drains — only depletes from skill use. Regen rates: 1.0/sec out-of-combat, 3.0/sec rest spots, 0.3/sec in-combat (all × stamina_regen from StatsComponent). Fatigue: low stamina softly debuffs ATK/MATK (0.9× at 0%), Move Speed (0.8×), Attack/Cast Speed (0.85×). API: `get_stamina()`, `get_stamina_percent()`, `get_max_stamina()`, `drain_flat()`, `get_fatigue_multiplier(stat_type)`. Signal: `stamina_changed`
- `NpcIdentity` — personality, mood (emotion + energy with decay), opinions, schedule, backstory. Loaded from NpcIdentityDatabase. API: `setup()`, `shift_mood()`
- `RelationshipComponent` — tier ladder (stranger → recognized → acquaintance → friendly → close → bonded). Event history with timestamps. Auto-promotes/demotes on milestones. API: `get_or_create()`, `record_event()`

Components sync state back to `WorldState.entity_data` via `_sync()` (bridge layer — keeps perception/memory reads working).

## WorldState (slim — registry only)
- **Registry** (6): `register_entity`, `unregister_entity`, `get_entity`, `get_entity_data`, `set_entity_data`, `get_entity_id_for_node`
- **Locations** (3): `register_location`, `get_location`, `has_location`
- **Convenience** (1): `is_alive(id)` — looks up entity's StatsComponent
- `tree_entities` dict for cached tree registry (O(1) lookup)

Do NOT add inventory/gold/equipment/combat/progression/skills/spatial methods back to WorldState. Use `PerceptionComponent` for spatial queries. Access components directly via the entity node.

## Key Patterns
- `UIHelper.create_panel_style()` for all panel backgrounds — returns `StyleBoxTexture` with 9-patch dark textured background + gold border (`assets/textures/ui/panel/frame.png`)
- `UIHelper.center_panel()` to center a PanelContainer on screen
- `UIHelper.set_corner_radius()` / `set_border_width()` for StyleBoxFlat shortcuts
- `EntityVisuals` composition node for all entity visual state (model, overlay, animations, HP bar)
- `_visuals.play_anim()`, `_visuals.flash_hit()`, `_visuals.highlight()` etc. for visual delegation
- `ModelHelper.get_hit_delay()` for animation-timed hit delays
- `ModelHelper.update_entity_hp_bar()` for HP bar updates
- `DragHandle` for draggable panel title bars with close buttons
- Direction checks: always `dir.length_squared() > 0.01` before normalizing
- UI panels receive player node via `set_player(player)` from `main._ready()`, then read components directly
- **NPC behavior**: Goal-driven scripted behavior. No LLM. `npc_behavior.gd` evaluates every 1s: survival → goal completion → goal execution. Traits: boldness (risk tolerance), generosity (cooperation), sociability (chat cooldown), curiosity (unused). Smart target selection: generous NPCs avoid contested monsters, help retreating allies; selfish NPCs steal kills. Combat tracker in `npc_base.gd` tracks damage dealt/taken for mid-fight threat assessment. Goals: `hunt_field`, `patrol`, `rest`, `idle`, `follow_player`, `return_to_town`, `vend`, `chop_wood`, `craft_items`. Night pressure: cautious NPCs (boldness < 0.4) return to town at night. Social chat uses canned greetings (proximity-based, 12m range, 15-45s cooldown).
- **NPC navigation**: NavigationAgent3D with avoidance enabled (radius 0.5, neighbor_distance 5.0, max_neighbors 5). Uses `velocity_computed` signal for avoidance-adjusted movement. Personal space 1.5m with separation force 1.5 (applied to other NPCs and player). Area-based arrival: patrol/rest destinations use 15m arrival radius (NPCs don't pile up at exact center points). Location navigation adds ±4m random offset. Patrol/retreat/rest destinations spread across districts (MarketDistrict, NobleQuarter, ParkGardens, CityGate) — TownSquare removed to prevent fountain convergence
- **NPC scaling**: `NpcGenerator` creates 25 procedural NPCs (5 archetypes: warrior/mage/rogue/ranger/merchant, ~200 name pool, tiered loadouts, random trait_profile selection from archetype's allowed profiles, crafting_proficiencies per archetype). `game_world.gd` spawns them at world init. Combat archetypes default to `hunt_field`, merchants default to `vend`
- **Entity LOD**: Distance-based in `npc_base.gd` and `monster_base.gd`. Levels: 0 (<30m, full + separation), 1 (30-60m, skip separation), 2 (>60m, skip animations). 0.5s staggered checks. Dead/thinking always process
- **Dynamic HP bars**: Show on combat entry or damage, hide on combat exit + full HP. Driven by entity combat state via `update_hp_bar_combat()`
- **Vicinity chat log**: Combat/speech messages filtered to 30m from player. System/level-up messages always show
- **Gossip system**: `GossipSystem` propagates facts between NPCs during social chat. Memories have gossip metadata (source: witnessed/told_by/rumor, spread_count, original_source). 15% distortion per retelling, `spread_count >= 4` becomes rumor. Gossip affects relationships
- **Collision layers**: Layer 1 = physics, Layer 6 = vend signs, Layer 9 (bit 8) = entity perception (PerceptionComponent detection)
- `NpcLoadouts.LOADOUTS` — static Dictionary of hardcoded NPC starting data (7 named adventurers + 2 shop NPCs). Merchant NPCs use `default_goal: "vend"` to auto-start vending on spawn
- `NpcGenerator.generate_npcs(count)` — procedural NPC creation for scaling. Returns array of loadout dicts matching NpcLoadouts format. `npc_base.gd:initialize_from_loadout()` applies generated data
- Merchant vending: any entity can vend from inventory via VendingComponent — no fixed shop NPCs
- Vend sign: `_visuals.show_vend_sign()` / `hide_vend_sign()` — StaticBody3D (layer 6) + opaque panel quad + Label3D + white border quad (hover). Click sign to shop, click NPC body for info/chat
- Vend sign interaction: player raycast detects sign via `"vend_sign"` group, `_hovered_vend_sign` / `_pending_vend_sign_click` flags route to shop panel

## NPC Systems
- **NpcTraits** (`scripts/data/npc_traits.gd`): Personality axes (0.0-1.0): boldness (retreat threshold), sociability (chat cooldown), generosity (trade willingness), curiosity (goal switching). 13 trait profiles: 6-attribute starting proficiencies (str/con/agi/int/dex/wis) + weapon type. Profiles: bold_warrior, cautious_mage, sly_rogue, stern_guardian, gentle_healer, charming_bard, wild_berserker, stoic_knight, keen_archer, earnest_apprentice, devout_cleric, shadow_stalker, merchant
- **NpcMemory** (`scenes/npcs/npc_memory.gd`): Scored memory array (max 20, lowest evicted). Sources: witnessed (1.0 confidence), heard_from (0.7), rumor (0.4). Stores event history + area chat log + goals history. No LLM context feeding.
- **NpcSocial** (`scenes/npcs/npc_social.gd`): Proximity-based canned greeting exchange (12m range, 15-45s cooldown). No LLM chat. Candidates sorted by relationship tier.
- **Archetype proficiency seeds**: warrior (smithing 2), mage (crafting 2), merchant (cooking 2 + crafting 2). Applied via `initialize_from_loadout()` in npc_base.gd

## Dialogue System
- **DialogueDatabase** (`scripts/data/dialogue_database.gd`): Static class with DIALOGUES dict for 9 named NPCs + GENERIC_GREETINGS by archetype/mood. Condition system: relationship tier gates, time of day, mood, player inventory. Methods: `get_dialogue_entry()`, `get_node()`, `has_dialogue()`, `get_generic_greeting()`, `evaluate_condition()`
- **DialoguePanel** (`scenes/ui/dialogue_panel.gd`): Bottom-screen JRPG-style dialogue box. Full width, anchored to bottom. NPC name + text + horizontal choice buttons. Signal: `trade_requested(npc_node)`. Special actions: `"trade"` opens ShopPanel, `"info"` opens NpcInfoPanel. Click NPC body → opens DialoguePanel. Escape closes.

## Indoor Rooms System
- **InteriorDatabase** (`scripts/data/interior_database.gd`): Maps building_type to interior scene path, name, spawn_offset, loading_art
- **InteriorManager** (`scripts/world/interior_manager.gd`): In-zone instantiation at Y=-50. Loading screen transitions. Camera yaw 45° for interiors. Hides exterior (zone NavigationRegion3D + NPCs). Switches nav map. Enter via DoorTrigger click, exit via walk-through Area3D or Escape
- **InteriorBase** (`scenes/interiors/interior_base.gd`): Base script with navmesh baking, `exit_requested` signal, `get_spawn_point()`, `get_nav_region()`
- **InteriorNpc** (`scenes/interiors/interior_npc.gd`): Lightweight StaticBody3D NPC for interiors. No AI brain. VendingComponent for shops. Canned greetings.
- **DoorTrigger** (`scripts/world/door_trigger.gd`): Clickable StaticBody3D on buildings with interiors. Group `"door"`, registered with WorldState as type `"door"`

## UI Systems
- **DialogueBubble** (`scenes/ui/dialogue_bubble.gd`): 3D speech bubble via SubViewport + Sprite3D. Queue-based, 4s default duration, word-wrap at 600px
- **DialoguePanel** (`scenes/ui/dialogue_panel.gd`): Bottom-screen JRPG-style dialogue box. Full width, anchored to bottom. NPC name + text + horizontal choice buttons. Signal: `trade_requested(npc_node)`. Special actions: `"trade"` opens ShopPanel, `"info"` opens NpcInfoPanel.
- **InventoryPanel** (`scenes/ui/inventory_panel.gd`): Grid-based inventory with 8-slot equipment section on top (armor 2×3 left, weapons right) + 5-column item grid below. Equipment slots use generated icons (`assets/textures/ui/equip_slots/`). Stat icons (HP/ATK/DEF/Gold) from `assets/textures/ui/stats/`. Hover shows tooltip (name + stat). Left-click opens item description panel (name, type, stats, requirements). Right-click shows context menu: Use/Equip + Discard (drops loot at player feet). Medieval RPG aesthetic (warm amber on dark parchment)
- **SkillPanel** (`scenes/ui/skill_panel.gd`): Two-level UI — proficiency grid overview (19 buttons with icons + XP fill, left-aligned, content-sized) → drill-down detail with icon + skills + hotbar assignment. Both S and P keys toggle. Category dividers: `——— Weapon ———` style with full-width separators
- **StatusPanel** (`scenes/ui/status_panel.gd`): Character stats panel (C key) — 2-column layout: Offensive (ATK/MATK/Accuracy/CritRate/CritDmg) + Defensive (HP/DEF/MDEF/Evasion) left, Speed (AtkSpd/MoveSpd/CastSpd) + Resource (Stamina/HPRegen/CDR) right. Proficiency icons in 2-column grid below.
- **PlayerHUD** (`scenes/ui/player_hud.gd`): Top-left compact panel showing HP + stamina bars only. Time panel (single line) positioned left of minimap
- **Panel toggles**: Top-right button bar aligned with minimap (`offset_left = -194`): Status [C] | Inv [I] | Skills [S] | Map [W]
- **ProficiencyPanel** (`scenes/ui/proficiency_panel.gd`): RuneScape-style skill list, P key toggle
- **ShopPanel** (`scenes/ui/shop_panel.gd`): Shopping interface for vendors
- **NpcInfoPanel** (`scenes/ui/npc_info_panel.gd`): NPC stats, traits, memories, relationships
- **SkillHotbar** (`scenes/ui/skill_hotbar.gd`): Active skill hotbar display
- **WorldMapPanel** (`scenes/ui/world_map_panel.gd`): World map UI
- **Minimap** (`scenes/ui/minimap.gd`): Minimap display
- **LoadingScreen** (`scenes/ui/loading_screen.gd`): Zone transition loading screen
- **SettingsPanel** (`scenes/ui/settings_panel.gd`): Audio volume sliders (Master/SFX/Ambient) + Quit button. Esc key toggle
- **SkillDetailPanel** (`scenes/ui/skill_detail_panel.gd`): Tooltip popup showing detailed skill info (damage, cooldown, type, synergies, danger warning). Appears on hover over skill rows in the proficiency panel
- **Icon pipeline**: `scripts/tools/generate_icon.py` — generates icons via Gemini API (gemini-3.1-flash-image-preview), auto-removes backgrounds. Green-screen keying for transparent icons. Full icon spec in `docs/UI.md`
- **Proficiency icon pipeline**: Generate on green screen → crop 35px border → key out green + despill → composite on category base (`subjects/v1/red|green|yellow|grey.png`) → final icons at `assets/textures/ui/proficiencies/`. Bases generated programmatically (PIL: gradient + vignette + themed texture overlay + bevel, 512x512, rounded corners)
- **Proficiency icon gen**: `scripts/tools/generate_proficiency_icons.py` — batch generates proficiency icons via Gemini API (green screen → bg removal → composite onto category base). Uses pre-existing bases at `subjects/v1/{grey,red,green,yellow}.png`

## Proficiency System (RuneScape-style)
- **ProficiencyDatabase**: 19 skills, 4 categories (weapon/attribute/gathering/production), max level 10, XP formula: `level * 50`
- **Weapon** (7): sword, axe, mace, dagger, staff, bow, spear. **Attribute** (6): str, con, agi, int, dex, wis. **Gathering** (3): mining, woodcutting, fishing. **Production** (3): smithing, cooking, crafting
- **Stat derivation** (ProgressionComponent._recalculate_stats): ATK = 5 + STR×3 + weapon_prof×2 (bow uses DEX instead of STR), MATK = 5 + INT×3 + staff_prof×2, DEF = 3 + CON×2, MDEF = 3 + INT, Max HP = 50 + CON×15, Accuracy = 80 + DEX×5, Evasion = AGI×3, Crit Rate = 5 + DEX×2, Crit Damage = 150 + STR×5, ASPD Mult = 1.0 + AGI×0.05, Move Speed = 1.0 + AGI×0.03, Cast Speed = 1.0 + WIS×0.05, Max Stamina = 100 + CON×10, Stamina Regen = 1.0 + WIS×0.1, HP Regen = CON×0.5/sec (out of combat), CDR = WIS×3 (cap 30%)
- **XP sources**: STR 3/physical hit, CON 3/hit taken, AGI 5/dodge + 1/10m combat travel, INT 3/magical hit, DEX 2/hit landed, WIS 2/skill use. Weapon XP on combat hits. Woodcutting/mining/fishing XP on harvests
- **Damage types**: Physical (ATK vs DEF) with subtypes slash/pierce/blunt (from weapon phys_type vs armor_type). Magical (MATK vs MDEF) with elements fire/ice/lightning/earth/light/dark/arcane
- **Resistance scale**: fatal (2.0×), weak (1.5×), neutral (1.0×), resist (0.5×), immune (0.0×). MonsterDatabase has element + per-type resistances. Armor types: heavy (resist slash, weak blunt), medium (weak pierce), light (weak slash)
- **Hit/miss**: `hit_chance = clamp(accuracy - evasion, 5, 100)`. Miss shows "MISS" floating text, emits `GameEvents.attack_missed`
- **Crit**: `crit_rate` (from DEX) determines chance, `crit_damage` (from STR) determines multiplier. Crits show yellow damage numbers
- **Items**: `weapon_type`, `phys_type` (slash/pierce/blunt), `slot_type`, `required_skill`, `required_level`, `armor_type` (heavy/medium/light), `matk_bonus`, `mdef_bonus`
- **Signals**: `proficiency_xp_gained`, `proficiency_level_up`, `skill_learned`, `skill_used`, `attack_missed`

## Active Skill System
- **SkillDatabase** (`scripts/data/skill_database.gd`): Static class defining 21 skills across 7 weapon types. Each skill has `required_proficiency` (weapon + level), `damage_multiplier`, `cooldown`, `max_level` (5), `animation`, `color`, `synergy` field with `primary` (weapon requirement) and `secondary` bonuses, `damage_category` (physical/magical), `element` (fire/ice/lightning/earth/light/dark/arcane/null), `stamina_cost`. Methods: `get_synergy_bonuses()`, `get_total_effectiveness_percent()`
- **Weapon skills**: Sword (Bash, Cleave, Rend), Axe (Chop, Whirlwind, Execute), Mace (Crush, Shatter, Quake), Dagger (Stab, Lacerate, Backstab), Staff (Arcane Bolt, Flame Burst, Drain), Bow (Aimed Shot, Volley, Piercing Arrow), Spear (Thrust, Sweep, Impale)
- **Skill types**: `melee_attack` (single-target), `aoe_melee` (AoE via PerceptionComponent), `armor_pierce` (ignores % DEF), `bleed` (initial hit + damage-over-time ticks)
- **SkillEffectResolver** (`scripts/skills/skill_effect_resolver.gd`): Stateless static class. `resolve_skill_hit()` dispatches by type, returns `Array[{target_id, damage, is_crit, is_miss}]`. Owns full damage pipeline: physical/magical branching, element modifiers, phys_type vs armor_type modifiers, hit/miss checks, crit system. `process_bleeds()` ticks active bleeds each frame
- **SkillsComponent** (`scripts/components/skills_component.gd`): Shared skill execution for all entities. Data: skill levels, XP, hotbar. Execution: `begin_skill_use()` → validate → animate → cooldown → pending state. `tick_pending_hit(delta)` → animation/timer check → `_execute_skill_hit()` → SkillEffectResolver dispatch with synergy/effectiveness. Manages cooldowns, bleeds, stamina drain (from skill_data.stamina_cost), combat proficiency XP. Grants attribute XP on hits (STR/INT/DEX/WIS). CDR combines StatsComponent + synergy, capped at 40%. `setup_execution(combat, stats, progression, visuals, perception, auto_attack)` wires execution deps
- **PlayerInputComponent** (`scripts/components/player_input_component.gd`): Thin input adapter. `try_use_hotbar_slot(slot)` → resolves hotbar slot to skill_id → delegates to SkillsComponent. `process_skill_hit(delta, attack_range)` handles player-specific chase-to-range movement, delegates hit timing to SkillsComponent
- **NPCInputComponent** (`scripts/components/npc_input_component.gd`): Thin AI adapter. `try_use_skill(target_id)` → `_pick_best_skill()` (AoE if ≥2 nearby enemies, else highest multiplier) → delegates to SkillsComponent. 4.0s global cooldown
- **Skill unlocking**: Proficiency-driven. Skills auto-unlock when entity's proficiency level meets `required_proficiency`. `npc_base.late_init_skills()` re-applies after trait_profile set
- **Skill leveling**: Use-based, 5 XP per hit, independent from proficiency XP. `get_effective_multiplier()` and `get_effective_cooldown()` scale with skill level
- **Bleed tracking**: `_active_bleeds` Dictionary lives in SkillsComponent. Ticked in `_process()`. Tracks `damage_per_tick`, `ticks_remaining`, `tick_timer`, `tick_interval` per target

## Toon Shading & Shadows
- **Shaders**: `terrain_blend.gdshader` (terrain), `toon.gdshader` (characters/objects), `toon_cutout.gdshader` (foliage) — all use `render_mode diffuse_toon, specular_toon` with custom `light()` functions
- **Shadow rule**: In custom `light()` functions, `ATTENUATION` (cast shadow data) must be applied **independently** of `light_band` (NdotL toon banding). Multiplying `light_band * ATTENUATION` causes cast shadows to disappear when `light_band = 0` (flat surfaces in self-shadow). Correct pattern: compute toon result from NdotL first, then `result *= ATTENUATION` separately
- **Ambient vs shadow contrast**: Environment `ambient_light_energy` must be low enough (≤0.25) for cast shadows to be visible — high ambient washes out the DIFFUSE_LIGHT contribution where shadow data lives

## Terrain & Texturing
- **Shader**: `terrain_blend.gdshader` — vertex-color-based blending, no anti-tiling/rotation (straight tiling only)
- **Texture channels**: R=dirt, G=stone, B=cobble (roads), A(inverted)=packed_earth (pavements). Default (no channel)=pavement base texture
- **Paint rule types**: `line` (roads), `rect` (district grounds — axis-aligned rectangles), `flatten` / `flatten_rect` (height smoothing), `fill`, `clear_rect`
- **No circles for texturing** — use `rect` rules with `center` + `size` for all rectangular texture areas. Circles only for height flattening around buildings
- **No noise_perturb or falloff on texture rules** — keep edges sharp and tidy
- **Road textures**: Bricks_17 (`texture_cobble`, channel 2), UV scale 0.5
- **Pavement textures**: Bricks_23 (`texture_packed_earth`, channel 3 + base `texture_grass`), UV scale 0.5
- **All UV scales**: 0.5 for pavement/cobble/earth, other channels as set in shader defaults

## World Builder Utilities (`scripts/world/`)
Static utility classes for procedural world construction (one-shot builders, no per-frame lifecycle):
- `WorldBuilderContext` — shared mutable context (terrain_noise, caches, exclusion zones, nav_region)
- `AssetSpawner` — model spawning, material caching, tree/foliage model helpers, `spawn_mineable_rock()` for ore nodes
- `BiomeScatter` — exclusion zones, scatter algorithm, rock clusters
- `TownBuilder` — city walls (4 gates: north/south/east/west), city biome definitions + props
- `BuildingHelper` — `create_building()` with optional `building_type: String` metadata for future mesh replacement. Also `create_bench()`, `create_fountain()`
- `CityBuilder` — district building placement, delegates to 8 district scripts
- `FieldBuilder` — field biome definitions (trees, rocks, mineable ore nodes) — used by both east and west field zones
- **Zone scenes** (`scenes/zones/`): 3 zones total — `zone_city` (x:-70..70, z:-50..50, walled city), `zone_east_field` (x:70..150, z:-40..40, slimes + wolves), `zone_west_field` (x:-150..-70, z:-40..40, wolves + skeletons + dark mages, rocky clearing biome). Portals at city east gate (x≈70) and west gate (x≈-70). `ZoneDatabase` (`scripts/data/zone_database.gd`) holds zone metadata + portal definitions
- **District scripts** (`scripts/world/districts/`): `district_plaza`, `district_market`, `district_residential`, `district_noble`, `district_park`, `district_craft`, `district_garrison`, `district_gate` (east + north + south gates)
- **City walls**: 4 gates at x=±70 (east/west, gap z:-5..5) and z=±50 (north/south, gap x:-5..5). Gate towers height 6.0, width 3.0. Archways above each gate. ~97 buildings total across 8 districts

## Meshy AI Asset Pipeline
- **Character models**: `assets/models/characters/` — Meshy exports separate .glb files: one mesh (T-pose) + separate per-animation files (withSkin). Loaded via `ModelHelper.instantiate_model_with_anims(mesh_path, anim_paths, scale)` which merges animations into a single AnimationPlayer. Auto-creates zero-track Idle fallback if no Idle animation provided
- **EntityVisuals**: `setup_model_with_anims(mesh_path, anim_paths, scale, color)` for Meshy characters with separate animation files + center-origin Y offset. `setup_model()` still works for single-file KayKit models
- **Art style**: Anime fantasy, realistic proportions, flat color textures. Prompt suffix: `flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model`
- **Prompt catalog**: `docs/assets/PROMPT.md` — all Meshy prompts for characters (16), weapons (7), buildings (6), mining rocks (5)
- **Naming**: Characters `{archetype}_{m|f}.glb`, animations `{archetype}_{m|f}_{anim}.glb`

## Gathering System
- **HarvestableComponent** (`scripts/components/harvestable_component.gd`): Generic gathering component for woodcutting, mining, and fishing. `setup(tier, skill_id, database_lookup)` — skill_id determines which proficiency grants XP, database_lookup is a Callable to the tier's database. Manages chop count, depletion, and respawn. `respawn_mode`: `"in_place"` (default, trees/fishing) or `"destroy"` (rocks — zone manages respawn at random position)
- **MineableRock** (`scenes/objects/mineable_rock.gd`): StaticBody3D ore node. Tiers: copper/iron/gold. On depletion: shrinks then `queue_free()`, emits `rock_depleted(tier, respawn_time)`. Zone field scripts listen and spawn replacement at random biome position after delay
- **OreDatabase** (`scripts/data/ore_database.gd`): Static tier data — copper (3-5 chops, 5 XP, level 1), iron (5-8, 12 XP, level 3), gold (8-12, 25 XP, level 6). Drops: ore + stone
- **ChoppableTree** (`scenes/objects/choppable_tree.gd`): Uses HarvestableComponent with `skill_id: "woodcutting"` and `TreeDatabase.get_tree` lookup. Respawns in-place
- **FishingSpot** (`scenes/objects/fishing_spot.gd`): StaticBody3D with blue water disc visual. Tiers: shallow/medium/deep. Uses HarvestableComponent with `skill_id: "fishing"` and `FishDatabase.get_fish`. Fades on depletion, respawns in-place
- **FishDatabase** (`scripts/data/fish_database.gd`): 3 tiers — shallow (sardine, lv1), medium (trout, lv3), deep (salmon, lv6)
- **Player interaction**: Left-click rock/tree/fishing spot → walk to + harvest. `player.gd` generalizes harvesting for all types via `HarvestableComponent.get_skill_id()`

## Production/Crafting System
- **RecipeDatabase** (`scripts/data/recipe_database.gd`): Unified recipe store for cooking, smithing, crafting. Each recipe: `{name, skill_id, required_level, inputs: {item_id: count}, outputs: {item_id: count}, xp, craft_time}`. API: `get_recipe(id)`, `get_recipes_for_skill(skill_id)`
- **CraftingStation** (`scenes/objects/crafting_station.gd`): StaticBody3D with colored marker + Label3D. Properties: `station_type` ("cooking"/"smithing"/"crafting"), `station_name`. 3 stations near center fountain in plaza district. Player left-clicks → walks to → opens CraftingPanel
- **CraftingPanel** (`scenes/ui/crafting_panel.gd`): Two-column UI (recipe list + detail). Filters recipes by station's skill_id. Shows input availability (green/red), craft button (disabled if requirements unmet). On craft: removes inputs, adds outputs, grants proficiency XP. `open(skill_id, station_name)`, `set_player(player)`
- **Recipes**: 5 cooking (cooked fish, stew, soup), 5 smithing (ingots, weapons), 4 crafting (bandage, potion, armor, dagger)
- **Items**: Fish (sardine/trout/salmon), ingots (copper/iron/gold), cooked food (5 consumables with heal), crafted goods (bandage, leather armor, bone dagger)

## Audio System
- **No BGM** — SFX, entity loops, and ambient emitters only
- **Audio buses**: Master → SFX (0 dB), Ambient (-6 dB), UI (-3 dB). Layout in `default_bus_layout.tres`
- **AudioComponent** (`scripts/audio/audio_component.gd`): Per-entity composition Node with 4 AudioStreamPlayer3D children parented to the entity (not self — plain Node children sit at world origin). No `_process()` — purely state-driven. API: `setup(entity)`, `start_footsteps(surface)`, `stop_footsteps()`, `start_presence(sound_key)`, `stop_presence()`, `start_combat_loop()`, `stop_combat_loop()`, `play_oneshot(sfx_key)`, `stop_all_loops()`. Players: FootstepPlayer (loop), PresencePlayer (loop), CombatLoopPlayer (loop), OneShotPlayer (max_polyphony: 3). All AudioStreamPlayer3D config: max_distance 40.0, INVERSE_SQUARE_DISTANCE, unit_size 10.0, bus "SFX". Loop streams duplicated before setting `loop = true` to avoid mutating shared resources
- **AudioManager** (`autoloads/audio_manager.gd`): Autoload for UI SFX only. Pool of 4 non-positional AudioStreamPlayer nodes (bus: "UI"). API: `play_ui_sfx(sfx_key)`. Also listens to `GameEvents.proficiency_level_up` to play level-up fanfare for player. **Starts muted** (-80 dB on Master bus) — player raises volume in settings
- **AmbientEmitter** (`scripts/audio/ambient_emitter.gd`): Node3D with AudioStreamPlayer3D child (bus: "Ambient"). Phase-aware: `setup(stream_path, active_phases, volume_db, max_distance)`. Connects to `GameEvents.time_phase_changed`, tweens volume up/down over 3s. Checks current phase from `TimeManager.get_phase()` on setup. Placed by zone builders, freed on zone unload
- **SfxDatabase** (`scripts/audio/sfx_database.gd`): Static class mapping 34 string keys to `{path, volume_db, pitch_variance}`. Categories: combat (10), gathering (6), movement (3), presence (2), UI (7), ambient (6). `static func get_sfx(key) -> Dictionary`
- **Entity audio hooks**: AudioComponent initialized in `_ready()` after EntityVisuals for player/NPC/monster. Footsteps start on navigate, stop on arrival/stuck. Combat loop on enter_combat, stop on target_lost/death. Weapon-type hit sounds on `attack_landed`. Death SFX + `stop_all_loops()` on `_die()`. Presence loops start on spawn, restart on respawn and LOD recovery
- **LOD audio**: At LOD 2 (>60m), `stop_all_loops()`. On return to LOD <2, `start_presence()` restarts. Footsteps/combat resume on next state transition
- **Harvestable depletion SFX**: ChoppableTree, MineableRock, FishingSpot each have own AudioStreamPlayer3D for depletion sounds (tree_fall, rock_break, fish_catch)
- **Ambient emitter placement**: Plaza fountain (all phases) + forge (day/dusk), market chatter (day), park birds (dawn/day/dusk) + crickets (night/dusk), craft district forge (day), field zones wind (all) + birds (dawn/day) + crickets (night)
- **UI SFX**: All 9 toggle panels call `AudioManager.play_ui_sfx("ui_panel_open"/"ui_panel_close")`. Crafting: `ui_craft_complete`. Shop: `ui_buy_sell`. Equip: `ui_item_equip`
- **Audio assets**: `assets/audio/sfx/` (combat, gathering, movement, presence, ui) + `assets/audio/ambient/`. CC0 Kenney.nl packs (RPG Audio, UI Audio, Impact Sounds) + generated ambient. Ogg Vorbis format, stereo 44100 Hz
