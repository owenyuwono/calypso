# Calypso — Godot 4.6 GDScript Project

## Overview
Base-building zombie survival game set in a suburban area. Isometric camera, keyboard-first controls. Solo player vs zombies, single zone MVP. Base-building and zombie systems are planned but not yet implemented.

## Conventions
- **Engine**: Godot 4.6, GDScript only
- **Fonts**: Marcellus-Regular for body text (`GAME_FONT`, `GAME_FONT_BOLD`, project default). Philosopher-Bold for display/titles (`GAME_FONT_DISPLAY`). Set in `project.godot` + `UIHelper` constants
- **Autoload singletons**: WorldState (entity registry), GameEvents (signals), TimeManager (24h day cycle), ZoneManager (zone transitions), AudioManager (UI SFX pool + master mute on startup)
- **Static utility classes**: ModelHelper (3D models, effects, animation merging, `create_toon_material()`, `apply_toon_to_model()`, `create_fallback_mesh()`, `spawn_damage_number()`), UIHelper (panel styles, UI helpers), EntityHelpers (entity lifecycle utilities), TerrainGenerator (terrain mesh generation), HitVfx (combat hit effects), BuildingHelper (building + prop creation), AssetSpawner (model spawning, material caching), BiomeScatter (exclusion zones, scatter algorithm), TerrainHelpers (noise init, shader params shared across zones)
- **Composition nodes**: EntityVisuals (visual state: model, overlay, animations, HP bar) + AudioComponent (per-entity positional audio) + AutoAttackComponent (signal-based auto-attack) + PerceptionComponent (Area3D-based spatial awareness) + entity components (stats, inventory, equipment, combat, stamina) for all entities
- **Duck typing**: Component vars declared as `Node`, called with duck-typed method calls. Use `var x: int = node.method()` (not `:=`) when return type can't be inferred
- **Inventory**: Count-based Dictionary {item_type_id: count}, not arrays
- **No automated tests**: Verify manually in editor
- **Input**: WASD move (camera-relative), Shift sprint, E interact, Tab GameMenu (Status/Inventory/System), Q/E cycle GameMenu tabs, Left-click melee attack, Hold Right-click block / tap Right-click parry, Esc close/settings

## Coding Principles
- **SOLID**: Single responsibility per script/node. Open for extension (signals, composition). Depend on interfaces (duck typing), not concrete types
- **Keep It Simple (KISS)**: Simplest solution that works. No premature abstraction. Three similar lines > one clever helper
- **Godot's philosophy**: Composition over inheritance (child nodes, not deep class hierarchies). Nodes as building blocks. Signals for decoupling. GDScript idiomatic patterns (match, @onready, @export). Scene tree is the architecture

## Autoload Singletons

- **WorldState** (`autoloads/world_state.gd`): Entity registry only. Registry (6): `register_entity`, `unregister_entity`, `get_entity`, `get_entity_data`, `set_entity_data`, `get_entity_id_for_node`. Locations (3): `register_location`, `get_location`, `has_location`. Convenience (1): `is_alive(id)`. Components sync state back to `entity_data` via `_sync()`. Sets project-wide default font in `_ready()`.
- **GameEvents** (`autoloads/game_events.gd`): Global signal bus. Signals: `entity_damaged`, `entity_healed`, `entity_died`, `entity_respawned`, `damage_defended`, `item_looted`, `time_phase_changed`, `game_hour_changed`, `stamina_changed`.
- **TimeManager** (`autoloads/time_manager.gd`): 24h game clock. 1 in-game day = 2700 real seconds. 4 phases: dawn (5-7h), day (7-18h), dusk (18-20h), night (20-5h). API: `get_game_hour()`, `get_phase()`, `get_time_display()`, `get_day()`, `is_night()`, `set_time()`, `set_paused()`. Emits `time_phase_changed` and `game_hour_changed` via GameEvents.
- **ZoneManager** (`autoloads/zone_manager.gd`): Zone lifecycle — loading, unloading, transitions. Derives scene path from zone_id: `res://scenes/zones/{zone_id}.tscn`. Disables player input during transitions. Unregisters zone-owned entities on unload. Emits `zone_changed`, `zone_load_started`, `zone_load_completed`. API: `setup(zone_anchor, player, root_node)`, `load_zone(zone_id, spawn_position)`, `get_loaded_zone()`, `is_transitioning()`.
- **AudioManager** (`autoloads/audio_manager.gd`): UI SFX pool (4 non-positional AudioStreamPlayer nodes, bus "UI"). **Starts muted** (-80 dB on Master bus). API: `play_ui_sfx(sfx_key)`.

## Entity Component System
Each entity (player) owns its state via child Node components:

- `StatsComponent` — hp, max_hp, atk, def, matk, mdef, crit_rate, crit_damage, attack_speed, attack_speed_mult, attack_range, move_speed, cast_speed, max_stamina, stamina_regen, hp_regen, cooldown_reduction, level. **Must set `.name = "StatsComponent"` before `add_child()`**. API: `take_damage()`, `heal()`, `restore_full_hp()`, `is_alive()`. Syncs to `WorldState.entity_data` via `_sync()`.
- `InventoryComponent` — items dict + gold. API: `add_item()`, `remove_item()`, `has_item()`, `get_item_count()`, `get_items()`, `add_gold_amount()`, `remove_gold_amount()`, `get_gold_amount()`, `set_gold_amount()`.
- `EquipmentComponent` — 8 slots (head, torso, legs, gloves, feet, back, main_hand, off_hand). Items route to slot via `slot_type` field (fallback: weapon→main_hand, armor→off_hand). Requires InventoryComponent ref. API: `equip()`, `unequip()`, `get_slot(name)`, `get_weapon()`, `get_atk_bonus()`, `get_def_bonus()`. Emits `equipment_changed(slot, item_id)`.
- `CombatComponent` — damage logic + block/parry system. Requires StatsComponent + optional EquipmentComponent. Block: hold to reduce incoming damage (30% base, 50-70% with shield), drains stamina passively + per hit. Parry: 200ms window after block start — full negate + stamina restore + stagger attacker. Guard break: blocking depleted stamina forces vulnerability window. API: `start_blocking()`, `stop_blocking()`, `is_blocking()`, `is_in_parry_window()`, `tick_block(delta)`, `receive_damage(incoming, attacker_id)`, `apply_flat_damage_to(target_id, amount)`, `get_effective_atk()`, `get_effective_def()`, `roll_crit()`, `get_attack_speed_multiplier()`, `get_equipped_weapon_type()`, `get_equipped_phys_type()`.
- `AutoAttackComponent` — signal-based auto-attack loop shared by all entities. Handles target validation, range check, chase navigation, animation-synced hit timing, and armor/phys-type resistance. Emits `attack_started(target_id)`, `attack_landed(target_id, damage, target_pos)`, `target_lost()`. API: `process_attack(delta, target_id, owner_pos, move_speed, attack_range, attack_speed)`, `cancel()`. Inlines armor/phys-type resistance table (heavy/medium/light vs slash/pierce/blunt).
- `PerceptionComponent` — Area3D-based spatial awareness (radius 15). Tracks nearby entities via `body_entered`/`body_exited` on collision layer 9 (bit 8). **Area3D must be parented to entity Node3D, not the component Node.** API: `get_perception(radius)`, `get_nearby(radius)`, `is_tracking(id)`, `get_distance_to(id)`. `get_perception()` returns categorized dict: npcs, monsters, items, objects, locations, vendors.
- `StaminaComponent` — stamina pool with fatigue system. No passive drains — only depletes from explicit `drain_flat()` calls and blocking. Regen rates: 1.0/sec out-of-combat, 3.0/sec rest spots, 0.3/sec in-combat (all × stamina_regen from StatsComponent). Fatigue: low stamina softly debuffs ATK/MATK (0.9× at 0%), Move Speed (0.8×), Attack/Cast Speed (0.85×). API: `get_stamina()`, `get_stamina_percent()`, `get_max_stamina()`, `drain_flat()`, `get_fatigue_multiplier(stat_type)`. Signal: `stamina_changed` (emitted via GameEvents on 10% threshold crossings).
- `PlayerInputComponent` (`scripts/components/player_input_component.gd`): Stub — movement and attack handled directly in `player.gd`. API: `setup(player)`.
- `EntityVisuals` — visual state composition node. `setup_model(path, scale, color)` for single-file models. `setup_model_with_anims(mesh_path, anim_paths, scale, color)` for Meshy characters with separate animation files (auto-shifts center-origin models). `setup_custom_model(model, mesh_instances)` for procedural meshes. API: `play_anim()`, `crossfade_anim()`, `face_direction()`, `flash_hit()`, `highlight()`, `unhighlight()`, `set_state_tint()`, `fade_out()`, `spawn_damage_number()`, `spawn_styled_damage_number()`, `setup_hp_bar()`, `update_hp_bar()`, `update_hp_bar_combat()`, `update_weapon_visual()`, `get_anim_player()`.
- `AudioComponent` — per-entity positional audio (4 AudioStreamPlayer3D children parented to entity). API: `setup(entity)`, `start_footsteps(surface)`, `stop_footsteps()`, `start_presence(sound_key)`, `stop_presence()`, `start_combat_loop()`, `stop_combat_loop()`, `play_oneshot(sfx_key)`, `stop_all_loops()`.

## Key Patterns
- `UIHelper.create_panel_style()` for all panel backgrounds — returns `StyleBoxTexture` with 9-patch dark textured background + gold border (`assets/textures/ui/panel/frame.png`)
- `UIHelper.center_panel()` to center a PanelContainer on screen
- `UIHelper.set_corner_radius()` / `set_border_width()` for StyleBoxFlat shortcuts
- `UIHelper.create_titled_panel(title, size, close_cb)` — returns `{panel, vbox, drag_handle}` for standard draggable panels
- `EntityVisuals` composition node for all entity visual state
- `_visuals.play_anim()`, `_visuals.flash_hit()`, `_visuals.highlight()` etc. for visual delegation
- `ModelHelper.get_hit_delay()` for animation-timed hit delays
- `DragHandle` for draggable panel title bars with close buttons
- Direction checks: always `dir.length_squared() > 0.01` before normalizing
- UI panels receive player node via `set_player(player)` from `main._ready()`, then read components directly
- **GameMenu** (`scenes/ui/game_menu.gd`): Full-screen tabbed menu (Tab toggle, Q/E cycle). 3 tabs: Status, Inventory, System. Each tab instantiates its panel builder. Panel builders have `refresh()`, `set_player()`, `build_content()` API.
- **Proximity interaction**: `player_hover.gd` (child of player) shows [E] label + ground ring on nearest interactable within 3m
- Components sync state back to `WorldState.entity_data` via `_sync()` (bridge layer)

## UI Systems
- **PlayerHUD** (`scenes/ui/player_hud.gd`): Bottom-center HP + stamina bars. Time label. Event-driven updates via GameEvents signals. No background panel.
- **GameMenu** (`scenes/ui/game_menu.gd`): Full-screen BotW-style tabbed menu. Tab key toggles. Q/E cycles tabs. 3 tabs: Status, Inventory, System.
- **InventoryPanel** (`scenes/ui/inventory_panel.gd`): GameMenu Inventory tab. Layout: item grid (left) + equipment slots (right, two columns of 4 slots). WASD zone-based keyboard navigation. Enter opens context menu (Use/Equip/Discard). Equipment slots use generated icons. `cursor_hand.png` TextureRect for keyboard navigation focus.
- **StatusPanel** (`scenes/ui/status_panel.gd`): GameMenu Status tab — stat display (ATK, MATK, DEF, MDEF, HP, Crit Rate, Crit Dmg, Atk Speed, Move Speed, Cast Speed, Stamina, HP Regen, CDR).
- **SettingsPanel** (`scenes/ui/settings_panel.gd`): GameMenu System tab. Sidebar + content layout. Audio volume sliders (Master/SFX/Ambient) + Quit button. WASD keyboard navigation. Esc key toggle.
- **Minimap** (`scenes/ui/minimap.gd`): Top-right overlay. Entity dots on a 2D projection (30m world radius, 180px map). Toggled with M key.
- **DamageNumber** (`scenes/ui/damage_number.gd`): Floating combat number popup. Spawned via `ModelHelper.spawn_damage_number()` / `spawn_styled_damage_number()`.
- **DialogueBubble** (`scenes/ui/dialogue_bubble.gd`): 3D speech bubble via SubViewport + Sprite3D. Queue-based, 4s default duration, word-wrap at 600px. 12 words max per bubble.
- **LoadingScreen** (`scenes/ui/loading_screen.gd`): Zone transition loading screen. Fade in/out with minimum display time.
- **HpBar3D** (`scenes/ui/hp_bar_3d.gd`): World-space HP bar above entities. Show on combat/damage, hide on full HP + out of combat.

## World & Zone Systems
- **ZoneSuburb** (`scenes/zones/zone_suburb.gd`): Placeholder suburb zone — flat grassy plane, navmesh, location markers. Emits `zone_ready` after async navmesh bake. `zone_id = "suburb"`.
- **ZonePortal** (`scripts/world/zone_portal.gd`): Area3D trigger for zone transitions. Configured at runtime via `setup(portal_def)`. Shows pulsing torus ring + billboard label. Fires `ZoneManager.load_zone()` on player body entry.
- **DayNightCycle** (`scripts/world/day_night_cycle.gd`): Node3D child of Main, persists across zone transitions. Animates DirectionalLight3D + WorldEnvironment on `time_phase_changed`. 30s tween between phases. Phase settings: dawn (warm orange, low sun), day (white, overhead), dusk (orange-red, low), night (blue, dim). Re-acquires lighting nodes from zones via `zone_changed` signal.
- **TerrainHelpers** (`scripts/world/terrain_helpers.gd`): Shared terrain utilities — `create_terrain_noise()` (seed 42, simplex smooth), `apply_standard_shader_params()`. Used across zone scripts to eliminate duplication.
- **BuildingHelper** (`scripts/world/building_helper.gd`): `create_building()` with optional GLB model override (falls back to procedural box+roof). Also `create_bench()`, `create_fountain()`. Snaps props to terrain height.
- **AssetSpawner** (`scripts/world/asset_spawner.gd`): Model spawning with terrain height snapping, material caching, texture loading.
- **BiomeScatter** (`scripts/world/biome_scatter.gd`): Exclusion zones (roads, building footprints) + density-modulated scatter placement for props/foliage.
- **WorldBuilderContext** (`scripts/world/world_builder_context.gd`): Shared mutable context for world builders (terrain_noise, caches, exclusion zones, nav_region).

## Combat System
- **Damage pipeline**: ATK vs DEF (physical). Physical damage modified by weapon `phys_type` (slash/pierce/blunt) vs target `armor_type` (heavy/medium/light). Resistance scale: fatal (2.0×), weak (1.5×), neutral (1.0×), resist (0.5×), immune (0.0×). Armor table: heavy (resist slash, weak blunt), medium (weak pierce), light (weak slash).
- **Crit**: `crit_rate` (%) chance, `crit_damage` (%) multiplier. Crits show yellow damage numbers.
- **Block/parry**: Hold Right-click to block (30% damage reduction, stamina drain). Tap Right-click within 200ms parry window for full negation + stamina restore + attacker stagger + knockback. Guard break on stamina depletion while blocking (0.5s vulnerability, 0.5× incoming damage).
- **Combo system**: Player has multi-step combo chain with `COMBO_WINDOW` (0.4s) to buffer next attack. Sword and unarmed variants.
- **HitVfx** (`scripts/vfx/hit_vfx.gd`): Procedural hit impact effects — slash arc (ImmediateMesh fan triangles) + spark burst (GPUParticles3D). `spawn_hit_effect(caller, hit_pos, direction)`.
- **EntityHelpers** (`scripts/utils/entity_helpers.gd`): `apply_death_gold_penalty(inventory, ratio)` — deducts gold on death.

## Item System
- **ItemDatabase** (`scripts/data/item_database.gd`): 3 placeholder items. Weapons: `fists` (blunt, atk 0, speed 1.5), `wooden_plank` (blunt, atk +4, speed 0.9). Consumable: `bandage` (heal 20). Item fields: `name`, `type`, `slot_type`, `weapon_type`, `phys_type`, `atk_bonus`, `attack_speed`, `heal`, `value`. API: `get_item(id)`, `get_item_name(id)`.

## Audio System
- **No BGM** — SFX, entity loops, and ambient emitters only
- **Audio buses**: Master → SFX (0 dB), Ambient (-6 dB), UI (-3 dB). Layout in `default_bus_layout.tres`
- **AudioComponent** (`scripts/audio/audio_component.gd`): Per-entity Node with 4 AudioStreamPlayer3D children parented to the entity. Players: FootstepPlayer (loop), PresencePlayer (loop), CombatLoopPlayer (loop), OneShotPlayer (max_polyphony: 3). All configured: max_distance 40.0, INVERSE_SQUARE_DISTANCE, unit_size 10.0, bus "SFX". Loop streams duplicated before setting `loop = true` to avoid mutating shared resources.
- **AudioManager** (`autoloads/audio_manager.gd`): UI SFX pool. **Starts muted** — player raises volume in settings.
- **AmbientEmitter** (`scripts/audio/ambient_emitter.gd`): Node3D with AudioStreamPlayer3D child (bus "Ambient"). Phase-aware: `setup(stream_path, active_phases, volume_db, max_distance)`. Tweens volume over 3s on phase change.
- **SfxDatabase** (`scripts/audio/sfx_database.gd`): Static class mapping string keys to `{path, volume_db, pitch_variance}`. Categories: combat (block, parry, guard_break, hit variants, death, hurt, loop), gathering (tree_chop, rock_mine, fishing, tree_fall, rock_break, fish_catch), movement (footstep_stone/grass/dirt), presence (monster_idle, npc_ambient), UI (panel_open, panel_close, etc.). API: `get_sfx(key) -> Dictionary`.

## Toon Shading & Terrain
- **Shaders**: `terrain_blend.gdshader` (terrain), `toon.gdshader` (characters/objects) — both use `render_mode diffuse_toon, specular_toon`
- **Toon shader defaults**: `light_attenuation = 0.3`, `shadow_strength = 0.4`, `shadow_threshold = 0.3`
- **Shadow rule**: In custom `light()` functions, `ATTENUATION` must be applied independently of `light_band`. Compute toon result from NdotL first, then `result *= ATTENUATION` separately. Multiplying `light_band * ATTENUATION` causes cast shadows to vanish on flat surfaces.
- **Ambient vs shadow contrast**: `ambient_light_energy` must be ≤ 0.25 for cast shadows to be visible
- **Terrain shader channels**: R=dirt, G=stone, B=cobble, A(inverted)=packed_earth. Default=pavement base.

## Meshy AI Asset Pipeline
- **Character models**: `assets/models/characters/` — separate .glb files per mesh and per animation (withSkin). Loaded via `ModelHelper.instantiate_model_with_anims(mesh_path, anim_paths, scale)` which merges animations into a single AnimationPlayer. Auto-creates zero-track Idle fallback if no Idle provided.
- **Art style**: Anime fantasy, realistic proportions, flat color textures. Prompt suffix: `flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model`

## Planned Systems (Not Yet Implemented)
- Zombie enemies (types, AI, spawning)
- Base building (grid-based placement)
- Scavenging/looting system
- Survival mechanics (hunger, thirst)
- Suburban zone generation (houses, streets, props)
- Multiple zones
