# Arcadia — Godot 4.6 GDScript Project

## Conventions
- **Engine**: Godot 4.6, GDScript only
- **Autoload singletons**: WorldState (registry only), LLMClient (Ollama `/api/chat`, think:false), GameEvents (signals, LLM)
- **Static utility classes**: ModelHelper (3D models, effects), UIHelper (panel styles, UI helpers), NpcLoadouts (NPC starting data), NpcGenerator (procedural NPC creation), GossipSystem (fact propagation), SkillDatabase (skill definitions), SkillEffectResolver (skill damage resolution), world builders (see below)
- **Composition nodes**: EntityVisuals (visual state: model, overlay, animations, HP bar) + AutoAttackComponent (signal-based auto-attack shared by all entities) + PerceptionComponent (Area3D-based spatial awareness per entity) + entity components (stats, inventory, equipment, combat, progression, skills) for all entities
- **Duck typing**: Component vars declared as `Node`, called with duck-typed method calls. Use `var x: int = node.method()` (not `:=`) when return type can't be inferred
- **State machines**: String-based states (idle/thinking/moving/combat/dead)
- **Inventory**: Count-based Dictionary {item_type_id: count}, not arrays
- **No automated tests**: Verify manually in editor (panels, combat, minimap, world map, chat)
- **Input**: Left-click move/attack/interact, E interact, Tab inventory, C status, S skills, P proficiencies, M minimap, W world map, V vend setup, 1-5 hotbar, D debug, Esc close panel

## Entity Component System
Each entity (player, NPC, monster) owns its state via child Node components:
- `StatsComponent` — hp, max_hp, atk, def, level, attack_speed, attack_range. **Must set `.name = "StatsComponent"` before `add_child()`**. API: `take_damage()`, `heal()`, `restore_full_hp()`, `is_alive()`, `get_stats_dict()`
- `InventoryComponent` — items dict + gold. API: `add_item()`, `remove_item()`, `has_item()`, `get_items()`, `add_gold_amount()`, `remove_gold_amount()`, `get_gold_amount()`, `set_gold_amount()`
- `EquipmentComponent` — weapon/armor slots. Requires InventoryComponent ref. API: `equip()`, `unequip()`, `get_atk_bonus()`, `get_def_bonus()`
- `CombatComponent` — damage/heal logic. Requires StatsComponent + optional EquipmentComponent. API: `deal_damage_to()`, `deal_damage_amount_to()`, `deal_damage_amount_to_with_pierce(target_id, amount, def_ignore)`, `heal()`, `get_effective_atk()`, `get_effective_def()`, `is_alive()`
- `ProgressionComponent` — owns proficiency state `{skill_id: {level, xp}}`. Derives stats from proficiency levels. Requires StatsComponent. API: `grant_proficiency_xp()`, `get_proficiency_level()`, `get_proficiency_xp()`, `get_total_level()`, `get_proficiencies()`
- `SkillsComponent` — active skills (no skill points). Skills unlock via proficiency milestones. API: `unlock_skill()`, `grant_skill_xp()`, `has_skill()`, `get_skill_level()`, `set_hotbar_slot()`, `get_hotbar()`
- `VendingComponent` — vending state, listings, buy/sell. **Must set `.name = "VendingComponent"` before `add_child()`**. API: `start_vending()`, `stop_vending()`, `is_vending()`, `get_listings()`, `get_shop_title()`, `buy_from()`
- `PerceptionComponent` — Area3D-based spatial awareness (radius 25). Tracks nearby entities via `body_entered`/`body_exited` signals on collision layer 9 (bit 8). **Area3D must be parented to entity Node3D, not the component Node.** API: `get_perception(radius)`, `get_nearby(radius)`, `get_nearby_locations(radius)`, `is_tracking(id)`, `get_distance_to(id)`

Components sync state back to `WorldState.entity_data` via `_sync()` (bridge layer — keeps perception/memory reads working).

## WorldState (slim — registry only)
- **Registry** (6): `register_entity`, `unregister_entity`, `get_entity`, `get_entity_data`, `set_entity_data`, `get_entity_id_for_node`
- **Locations** (3): `register_location`, `get_location`, `has_location`
- **Convenience** (1): `is_alive(id)` — looks up entity's StatsComponent

Do NOT add inventory/gold/equipment/combat/progression/skills/spatial methods back to WorldState. Use `PerceptionComponent` for spatial queries. Access components directly via the entity node.

## Key Patterns
- `UIHelper.create_panel_style()` for all panel backgrounds
- `UIHelper.center_panel()` to center a PanelContainer on screen
- `UIHelper.set_corner_radius()` / `set_border_width()` for StyleBoxFlat shortcuts
- `EntityVisuals` composition node for all entity visual state (model, overlay, animations, HP bar)
- `_visuals.play_anim()`, `_visuals.flash_hit()`, `_visuals.highlight()` etc. for visual delegation
- `ModelHelper.get_hit_delay()` for animation-timed hit delays
- `ModelHelper.update_entity_hp_bar()` for HP bar updates
- `DragHandle` for draggable panel title bars with close buttons
- Direction checks: always `dir.length_squared() > 0.01` before normalizing
- UI panels receive player node via `set_player(player)` from `main._ready()`, then read components directly
- `AutoAttackComponent` — emits `attack_landed(target_id, damage, target_pos)` and `target_lost()` signals; entities connect handlers for visual feedback (damage numbers, flash, shouts). `_chase()` is pure movement (untouched); stuck detection lives in `process_attack()` only
- **NPC behavior**: Goal-driven with trait-influenced decisions. `npc_behavior.gd` evaluates every 1s: survival → goal completion → goal execution. Traits: boldness (risk tolerance), generosity (cooperation), sociability (chat), curiosity (unused). Smart target selection: generous NPCs avoid contested monsters, help retreating allies; selfish NPCs steal kills. Combat tracker in `npc_base.gd` tracks damage dealt/taken for mid-fight threat assessment
- **Event-driven LLM**: NPCs only consult LLM on significant events (goal_completed, combat_outcome, low_resources, idle_timeout, player/NPC chat), not on timers. Event cooldowns prevent spam. Scripted behavior handles ~95% of decisions
- **NPC scaling**: `NpcGenerator` creates 50+ procedural NPCs (5 archetypes: warrior/mage/rogue/ranger/merchant, ~200 name pool, tiered loadouts). `game_world.gd` spawns them at world init. Animation LOD skips updates > 50m from camera
- **Gossip system**: `GossipSystem` propagates facts between NPCs during social chat. Memories have gossip metadata (source: witnessed/told_by/rumor, spread_count, original_source). 15% distortion per retelling, `spread_count >= 4` becomes rumor. Gossip affects relationships
- **Compact prompts**: `prompt_builder.gd` uses token-efficient formats: `Kael(knight,hp:full,fighting:slime,8m)` for perception, `lv5 hp:80/100 atk:15+4 def:8+3 gold:150` for stats
- **Collision layers**: Layer 1 = physics, Layer 6 = vend signs, Layer 9 (bit 8) = entity perception (PerceptionComponent detection)
- `NpcLoadouts.LOADOUTS` — static Dictionary of hardcoded NPC starting data (7 named adventurers + 2 shop NPCs). Merchant NPCs use `default_goal: "vend"` to auto-start vending on spawn
- `NpcGenerator.generate_npcs(count)` — procedural NPC creation for scaling. Returns array of loadout dicts matching NpcLoadouts format. `npc_base.gd:initialize_from_loadout()` applies generated data
- Merchant vending: any entity can vend from inventory via VendingComponent — no fixed shop NPCs
- Vend sign: `_visuals.show_vend_sign()` / `hide_vend_sign()` — StaticBody3D (layer 6) + opaque panel quad + Label3D + white border quad (hover). Click sign to shop, click NPC body for info/chat
- Vend sign interaction: player raycast detects sign via `"vend_sign"` group, `_hovered_vend_sign` / `_pending_vend_sign_click` flags route to shop panel

## Proficiency System (RuneScape-style)
- **ProficiencyDatabase**: 13 skills, 4 categories (weapon/attribute/gathering/production), max level 10, XP formula: `level * 50`
- **Weapon** (5): sword, axe, mace, dagger, staff. **Attribute** (2): constitution, agility. **Gathering** (3): mining, woodcutting, fishing. **Production** (3): smithing, cooking, crafting
- **Stat derivation**: ATK = 5 + weapon_level * 2, DEF = 3 + constitution_level, Max HP = 40 + constitution_level * 10, player level = sum of all proficiency levels
- **XP sources**: weapon proficiency XP on combat hits, constitution XP on taking damage. Gathering/production are placeholders (not yet implemented)
- **Monsters**: `proficiency_xp` field in MonsterDatabase (3–20 per monster type)
- **Items**: `weapon_type`, `required_skill`, `required_level` fields for equipment proficiency requirements
- **Signals**: `proficiency_xp_gained(entity_id, skill_id, amount, new_xp)`, `proficiency_level_up(entity_id, skill_id, new_level)`, `skill_learned(entity_id, skill_id)`, `skill_used(entity_id, skill_id, target_id)`

## Active Skill System
- **SkillDatabase** (`scripts/data/skill_database.gd`): Static class defining 16 skills across 5 weapon types. Each skill has `required_proficiency` (weapon + level), `damage_multiplier`, `cooldown`, `max_level` (5), `animation`, `color`
- **Weapon skills**: Sword (Bash, Cleave, Rend), Axe (Chop, Whirlwind, Execute), Mace (Crush, Shatter, Quake), Dagger (Stab, Lacerate, Backstab), Staff (Arcane Bolt, Flame Burst, Drain)
- **Skill types**: `melee_attack` (single-target), `aoe_melee` (AoE via PerceptionComponent), `armor_pierce` (ignores % DEF), `bleed` (initial hit + damage-over-time ticks)
- **SkillEffectResolver** (`scripts/skills/skill_effect_resolver.gd`): Stateless static class. `resolve_skill_hit()` dispatches by type, returns `Array[{target_id, damage}]`. `process_bleeds()` ticks active bleeds each frame
- **Player skills** (`player_skills.gd`): Requires `setup(player, combat, stats, skills_comp, progression, visuals, perception)`. `use_skill(skill_id)` → validate → animate → resolve via SkillEffectResolver. Tracks `_active_bleeds` dict, ticked in `_process()`
- **NPC skills** (`scenes/npcs/npc_skills.gd`): AI-driven skill selection. `try_use_skill(target_id)` picks best skill (AoE if ≥2 nearby enemies, else highest multiplier). 4.0s global cooldown. 5 XP per skill hit
- **Skill unlocking**: Proficiency-driven. Skills auto-unlock when entity's proficiency level meets `required_proficiency`. `npc_base.late_init_skills()` re-applies after trait_profile set
- **Skill leveling**: Use-based, 5 XP per hit, independent from proficiency XP. `get_effective_multiplier()` and `get_effective_cooldown()` scale with skill level
- **Bleed tracking**: `_active_bleeds` Dictionary lives in player_skills/npc_skills (not CombatComponent). Tracks `damage_per_tick`, `ticks_remaining`, `tick_timer`, `tick_interval` per target

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
- `AssetSpawner` — model spawning, material caching, tree/foliage model helpers
- `BiomeScatter` — exclusion zones, scatter algorithm, rock clusters
- `TownBuilder` — city walls, city biome definitions + props
- `CityBuilder` — district building placement
- `FieldBuilder` — field biome definitions
