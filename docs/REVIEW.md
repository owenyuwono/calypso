# Arcadia — Code Review & Refactoring Plan

**Date:** 2026-03-15
**Scope:** 63 .gd files across autoloads, scenes, components, data, LLM, utils, world builders
**Principles:** SOLID, Godot Philosophy (signals + scene composition), KISS, Modular & Loosely Coupled

---

## Summary of Findings

| Category | Count |
|---|---|
| Dead / unreachable code | 14 items |
| Bug (logic error) | 1 confirmed |
| Duplicated code blocks | 9 clusters |
| Hard-coded magic values | 8 groups |
| God-object files (>500 lines, multiple concerns) | 4 |
| Polling anti-patterns (_process instead of signal/Timer) | 3 |
| Procedural scene construction (should be .tscn) | 3 |
| SRP violations in utilities | 4 |
| Tight coupling to WorldState in components/utils | 6 |

---

## Phase 0 — Quick Wins

Low risk. No structural changes. Can be done in any order.

### 0-A: Remove Dead Code

| Item | File | Action |
|---|---|---|
| `StatsComponent.apply_level_up()` | `scripts/components/stats_component.gd` | Delete method — never called |
| `player.gd::_talk_to_npc()` | `scenes/player/player.gd` | Delete method — dead path |
| `EntityVisuals.highlight_vend_sign()` / `unhighlight_vend_sign()` / `get_overlay()` / `get_model()` | `scripts/components/entity_visuals.gd` | Delete all four — never called |
| `AutoAttackComponent.is_pending_hit()` | `scripts/components/auto_attack_component.gd` | Delete — never called |
| `StaminaComponent.is_exhausted()` / `is_resting()` | `scripts/components/stamina_component.gd` | Delete both — never called externally |
| `WorldState.get_all_locations()` | `autoloads/world_state.gd` | Delete — never called |
| `CombatComponent.get_stat()` | `scripts/components/combat_component.gd` | Delete — never called |
| `SkillDatabase.get_skill_name()` | `scripts/data/skill_database.gd` | Delete — never called |
| `StaminaComponent.DRAIN_SKILL` constant | `scripts/components/stamina_component.gd` | Delete — literal `5.0` used in `player.gd` instead (replaced by constant in 0-C) |
| `TerrainGenerator` `clear_circle` rule handler | `scripts/utils/terrain_generator.gd` | Delete the `match` branch — rule type never used |
| `NpcLoadouts` `"position"` and `"model"` fields on merchants | `scripts/data/npc_loadouts.gd` | Remove from dict — never read by spawn code |
| Per-skill `max_level` in `ProficiencyDatabase` | `scripts/data/proficiency_database.gd` | Remove per-entry key; only global `MAX_LEVEL` is used |
| `DUNGEON_DIR` constant in `city_builder.gd` | `scripts/world/city_builder.gd` | Delete — `AssetSpawner.DUNGEON_DIR` is the canonical copy |
| Debug `print("[CHAT] ...")` statements | `scenes/npcs/npc_behavior.gd` | Remove 4 debug prints in `_try_social_chat()` |

### 0-B: Fix `NpcInfoPanel.toggle()` Bug

**File:** `scenes/ui/npc_info_panel.gd:80-84`

Both branches call `close()`. The `else` branch should be a no-op (panel only opens via `show_npc()`):

```gdscript
# Before (broken):
func toggle() -> void:
    if _is_open:
        close()
    else:
        close()   # BUG

# After:
func toggle() -> void:
    if _is_open:
        close()
```

### 0-C: Extract Magic Numbers to Named Constants

| Value | Current location | Constant name | Files affected |
|---|---|---|---|
| `0.1` (death gold penalty) | `player.gd`, `npc_base.gd` | `DEATH_GOLD_PENALTY_RATIO` | both |
| `0.8` (vend listing price) | `npc_behavior.gd` | `VEND_PRICE_RATIO` | `npc_behavior.gd` |
| `0.5` (sell price) | `npc_action_executor.gd` | `SELL_PRICE_RATIO` | `npc_action_executor.gd` |
| `3` (constitution XP per hit) | `player.gd`, `npc_base.gd` | `CONSTITUTION_XP_PER_HIT` | both |
| `3`, `2`, `0`, `40` (potion thresholds) | `npc_behavior.gd` | `POTION_STOCK_TARGET`, `POTION_RESTOCK_THRESHOLD`, `POTION_BUY_GOLD_MIN` | `npc_behavior.gd` |
| `200.0` (vendor search radius) | `npc_behavior.gd` | `VENDOR_SEARCH_RADIUS` | `npc_behavior.gd` |
| `3.0` / `5.0` (respawn timers) | `player.gd`, `npc_base.gd` | `RESPAWN_TIME` | both |
| `5.0` (skill stamina drain) | `player.gd` | `STAMINA_DRAIN_SKILL` | `player.gd` |
| `2.0` / `1.0` (attack range/speed fallbacks) | `player.gd`, `npc_base.gd` | Move to `StatsComponent` defaults | `stats_component.gd`, `player.gd`, `npc_base.gd` |

Constants declared at file scope, close to usage. No separate constants file.

---

## Phase 1 — Extract Shared Patterns

**Requires:** Phase 0 complete

### 1-A: Create `BaseComponent` to Eliminate `_get_entity_id()` Duplication

**Problem:** Identical `_get_entity_id()` pattern exists in 7+ component files.

**Fix:** Create `scripts/components/base_component.gd`:

```gdscript
class_name BaseComponent
extends Node

func _get_entity_id() -> String:
    var parent := get_parent()
    if parent and "entity_id" in parent:
        return parent.entity_id
    return ""
```

All components change from `extends Node` to `extends BaseComponent` and delete their local copies.

**Files:**
- Create: `scripts/components/base_component.gd`
- Modify: `stats_component.gd`, `inventory_component.gd`, `equipment_component.gd`, `combat_component.gd`, `progression_component.gd`, `skills_component.gd`, `vending_component.gd`, `auto_attack_component.gd`, `stamina_component.gd`

### 1-B: Extract Death/Respawn Shared Logic

**Problem:** Death sequence duplicated between `player.gd` and `npc_base.gd` — gold penalty formula, animation, timer setup.

**Fix:** Create `scripts/utils/entity_helpers.gd` with a static helper:

```gdscript
static func apply_death_gold_penalty(inventory: Node, ratio: float) -> int:
    var gold: int = inventory.get_gold_amount()
    var lost := int(gold * ratio)
    inventory.remove_gold_amount(lost)
    return lost
```

Both `_die()` methods call this helper instead of inlining the formula.

**Files:**
- Create: `scripts/utils/entity_helpers.gd`
- Modify: `scenes/player/player.gd`, `scenes/npcs/npc_base.gd`

### 1-C: Extract XP-Grant-on-Hit into `ProgressionComponent`

**Problem:** Auto-attack XP grant logic cloned in both `player.gd` and `npc_base.gd`:
```gdscript
var monster_type = target_data.get("monster_type", "")
var monster_stats = MonsterDatabase.get_monster(monster_type)
var prof_xp = monster_stats.get("proficiency_xp", 3)
var weapon_type = _combat.get_equipped_weapon_type()
_progression.grant_proficiency_xp(weapon_type, prof_xp)
```

**Fix:** Add `ProgressionComponent.grant_combat_xp(monster_type: String, weapon_type: String)` — callers become one line.

**Files:**
- Modify: `scripts/components/progression_component.gd`
- Modify: `scenes/player/player.gd`, `scenes/npcs/npc_base.gd`

---

## Phase 2 — Decouple Components

**Requires:** Phase 1 complete (BaseComponent exists)

### 2-A: Remove WorldState Coupling from `StaminaComponent`

**Problem:** `StaminaComponent` queries `WorldState.get_location()` for hardcoded `"TownWell"` / `"TownInn"` strings.

**Fix:** Replace `const REST_SPOTS` with `var _rest_spots: Array`. Add `setup_rest_spots(spots: Array)`. The entity that owns the component sets this at init time.

**Files:**
- `scripts/components/stamina_component.gd`
- `scenes/player/player.gd` — call `stamina.setup_rest_spots(["TownWell", "TownInn"])`
- `scenes/npcs/npc_base.gd` — same

### 2-B: Replace WorldState Bridge Reads for Attack Stats

**Problem:** `player.gd` and `npc_base.gd` read `attack_range` / `attack_speed` from `WorldState.get_entity_data()` instead of directly from `_stats.attack_range`.

**Fix:** Replace `WorldState.get_entity_data(id).get("attack_range", 2.0)` with `_stats.attack_range`. The fallback stays as `StatsComponent`'s default.

**Files:**
- `scenes/player/player.gd`
- `scenes/npcs/npc_base.gd`

### 2-C: Fix `SkillsComponent` XP Storage

**Problem:** `grant_skill_xp()` stores XP in `WorldState.entity_data` as string keys (`"skill_xp_{skill_id}"`) instead of in component state. Violates component ownership.

**Fix:** Add `var _skill_xp: Dictionary` to `SkillsComponent`. Store/read XP from there. `_sync()` writes to WorldState for NPC perception reads.

**Files:**
- `scripts/components/skills_component.gd`

### 2-D: Remove WorldState from `ModelHelper`

**Problem:**
- `spawn_damage_number()` calls `WorldState.get_entity()` to resolve position
- `update_entity_hp_bar()` calls `WorldState.get_entity_data()` for hp/max_hp

Callers already have these values.

**Fix:** Make `target_pos` required on `spawn_damage_number()`. Change `update_entity_hp_bar()` signature to `(hp_bar, hp, max_hp)`. Callers pass values directly.

**Files:**
- `scripts/utils/model_helper.gd`
- `scripts/components/entity_visuals.gd`
- `scenes/player/player.gd`

### 2-E: Remove Hardcoded City Bounds from `AssetSpawner`

**Problem:** `AssetSpawner.spawn_model()` has inline `x >= -70 and x <= 70 and z >= -50 and z <= 50`.

**Fix:** Add `city_bounds: Rect2` to `WorldBuilderContext`. `AssetSpawner` uses `ctx.city_bounds.has_point(Vector2(pos.x, pos.z))`.

**Files:**
- `scripts/world/world_builder_context.gd`
- `scripts/world/asset_spawner.gd`

### 2-F: Inject Component References Instead of Scene Tree Traversal

**Problem:**
- `CombatComponent._get_item_penalty()` does `get_parent().get_node_or_null("ProgressionComponent")`
- `ProgressionComponent._get_active_weapon_proficiency_level()` does `get_parent().get_node_or_null("EquipmentComponent")`

**Fix:** Extend `setup()` on both components to accept the sibling reference. Callers already have both references at init time.

**Files:**
- `scripts/components/combat_component.gd` — `setup(stats, equipment, progression)`
- `scripts/components/progression_component.gd` — `setup(stats, equipment)`
- `scenes/player/player.gd`, `scenes/npcs/npc_base.gd` — update setup calls

---

## Phase 3 — Break Up God Objects

**Requires:** Phase 2 complete

### 3-A: Split `player.gd` (~906 lines -> ~450 lines)

Extract into composition child nodes (Godot-idiomatic):

| Extract | New file | Responsibility |
|---|---|---|
| Raycast + hover + tooltip + hover ring | `scenes/player/player_hover.gd` | `_process_hover()` (113 lines), tooltip, ring management |
| Skill execution | `scenes/player/player_skills.gd` | `_use_skill()`, `_process_skill_hit()`, `_execute_skill_hit()`, `_try_use_hotbar_slot()` |
| Click marker | `scenes/objects/click_marker.tscn` | Scene instead of procedural mesh. Instantiate once, reposition on click |

Also fix: `_spawn_click_marker()` currently adds child to `get_tree().current_scene` (crosses scene boundaries). Instantiate once in `_ready()` on a dedicated parent node.

### 3-B: Split `NpcBehavior` (741 lines -> ~350 lines)

| Extract | New file | Responsibility |
|---|---|---|
| Social chat subsystem | `scenes/npcs/npc_social.gd` | `_try_social_chat()`, `_pick_weighted_fact()`, `_pick_chat_intent()` |
| Vendor/trade pure functions | `scenes/npcs/npc_trade_helper.gd` | `_find_vendor()`, `_build_vend_listings()`, `_get_best_upgrade()` |

Replace 5 scattered potion count/gold checks with `_should_buy_potions() -> bool` and `_can_afford_potions() -> bool` predicates.

### 3-C: Fix `NpcBehavior` Accessing Private Brain Vars

**Problem:** `npc_behavior.gd:643` reads `brain._waiting_for_llm`, `brain._responding_to`, `brain._conversation_hold`, `brain._reading_queue`.

**Fix:** Use `brain.is_busy()` (already exists) instead of reading private vars directly.

**Files:**
- `scenes/npcs/npc_behavior.gd`
- `scenes/npcs/npc_brain.gd` — verify `is_busy()` covers all states

### 3-D: Split `CityBuilder` (~960 lines -> dispatcher + district modules)

Extract `_build_<district>()` methods into per-district files:

| New file | District |
|---|---|
| `scripts/world/districts/district_plaza.gd` | Central Plaza |
| `scripts/world/districts/district_market.gd` | Market District |
| `scripts/world/districts/district_residential.gd` | Residential Quarter |
| `scripts/world/districts/district_noble.gd` | Noble/Temple Quarter |
| `scripts/world/districts/district_park.gd` | Park/Gardens |
| `scripts/world/districts/district_craft.gd` | Craft/Workshop |
| `scripts/world/districts/district_garrison.gd` | Garrison/Training |
| `scripts/world/districts/district_gate.gd` | City Gate Area |

Shared helpers (`_create_building()`, `_snap_y()`, `_create_fountain()`, `_create_bench()`) move to `scripts/world/building_helper.gd`.

Also: add `class_name CityBuilder` — currently missing (inconsistent with all other world builder scripts).

---

## Phase 4 — Godot-ify

**Requires:** Phase 3 complete

### 4-A: Replace `panel_toggles.gd::_process()` StyleBox Rebuild

**Problem:** Creates new `StyleBoxFlat` objects every frame.

**Fix:** Pre-create `_normal_style` and `_active_style` in `_ready()`. Toggle between cached instances. Better: use a Timer (0.25s) instead of `_process()` entirely.

**Files:** `scenes/ui/panel_toggles.gd`

### 4-B: Replace `NpcInfoPanel._process()` Polling with Timer

**Problem:** Manual `_update_timer` accumulator in `_process()` to refresh every 0.5s.

**Fix:** Create a `Timer` node, `wait_time = 0.5`, connect `timeout` to `_refresh()`. Start in `show_npc()`, stop in `close()`. Delete `_process()`.

**Files:** `scenes/ui/npc_info_panel.gd`

### 4-C: Convert Tooltip and Hover Ring to Scene Composition

**Problem:** `player.gd` procedurally constructs CanvasLayer + PanelContainer + Label for tooltip, and MeshInstance3D + TorusMesh for hover ring.

**Fix:**
- Create `scenes/player/player_tooltip.tscn` — CanvasLayer > PanelContainer > Label
- Create `scenes/player/hover_ring.tscn` — MeshInstance3D with torus mesh pre-configured
- `player.gd._ready()` instantiates scenes instead of building procedurally

### 4-D: Fix `npc_action_completed` Signal Fan-Out (O(n^2))

**Problem:** Every `NpcBehavior` connects to `GameEvents.npc_action_completed` globally. When any NPC acts, all 7 NPCs fire the handler; only one matches.

**Fix:** Filter at connection time:
```gdscript
GameEvents.npc_action_completed.connect(
    func(n_id, action, success):
        if n_id == npc.npc_id:
            _on_action_completed(n_id, action, success)
)
```

Or have `NpcActionExecutor` emit a local signal instead of going through the global bus.

**Files:** `scenes/npcs/npc_behavior.gd`, optionally `scenes/npcs/npc_action_executor.gd`

### 4-E: Connect `time_phase_changed` to NPC Behavior

**Problem:** `GameEvents.time_phase_changed` only connected in `monster_base.gd`. NPCs poll `TimeManager.is_night()` every tick instead.

**Fix:** Connect in `npc_behavior.gd`. On `"night"` phase, trigger immediate evaluation rather than waiting for next 1s tick.

**Files:** `scenes/npcs/npc_behavior.gd`

---

## Phase 5 — World Builder Cleanup

**Requires:** Phase 3-D complete (CityBuilder already split)

### 5-A: Separate Data from Algorithms in `NpcTraits`

**Problem:** `NpcTraits` is a data file but contains `pick_mood()` (weighted random algorithm) and `get_trait_summary()` (string formatting).

**Fix:** Move algorithmic methods to `scripts/utils/npc_trait_helpers.gd` or inline into `npc_brain.gd` / `npc_behavior.gd` where mood is consumed.

**Files:**
- `scripts/data/npc_traits.gd`
- Create: `scripts/utils/npc_trait_helpers.gd` (or inline into consumers)

### 5-B: Decompose `BiomeScatter.scatter_biome()` (76 lines)

Extract helpers: `_generate_candidate()`, `_passes_noise()`, `_passes_spacing()`, `_spawn_recipe()`. Main function becomes a clean loop.

**Files:** `scripts/world/biome_scatter.gd`

### 5-C: Decompose `TerrainGenerator.generate_terrain()` (265 lines)

Extract: `_apply_texture_rules()`, `_apply_flatten_rules()`, `_build_mesh_arrays()`. Reduces main function to ~40 lines of orchestration.

**Files:** `scripts/utils/terrain_generator.gd`

### 5-D: Decompose `game_world._build_terrain()` (150 lines)

Extract: `_city_terrain_rules() -> Array`, `_field_terrain_rules() -> Array`. Separates config data from orchestration.

**Files:** `scenes/game_world/game_world.gd`

### 5-E: Fix `TownBuilder` NavigationRegion Parent Walk

**Problem:** `build_walls()` accesses `ctx.nav_region.get_parent()` to attach nodes — escapes the context abstraction.

**Fix:** Add `world_root: Node3D` to `WorldBuilderContext`. Builders use `ctx.world_root` instead of walking the scene tree.

**Files:**
- `scripts/world/world_builder_context.gd`
- `scripts/world/town_builder.gd`
- `scenes/game_world/game_world.gd`

---

## Execution Order

```
Phase 0  ->  Phase 1  ->  Phase 2  ->  Phase 3  ->  Phase 4  ->  Phase 5
(no deps)    (needs 0)    (needs 1)    (needs 2)    (needs 3)    (needs 3-D)
```

- Phases 0-2: tasks within each phase can be parallelized (different files)
- Phase 1-A (BaseComponent) must complete before 1-B and 1-C touch components
- Phase 2-D (ModelHelper decoupling) must complete before any ModelHelper split
- Phase 3-D (CityBuilder split) must complete before Phase 5 world builder work

## Risk Assessment

| Phase | Risk | Verification |
|---|---|---|
| 0 | Very Low | All panels open/close, NPC dies and respawns, combat works |
| 1 | Low | Combat, death, XP gain all function |
| 2 | Low-Medium | Equip items, buy potions, vendor NPC, damage numbers display |
| 3 | Medium | Full player flow, NPC AI loop, city loads without errors |
| 4 | Low-Medium | Signal/Timer replacements isolated; click marker visual check |
| 5 | Low | Navmesh bakes, no terrain gaps, scatter spawns correctly |

## Files NOT Requiring Changes

These are well-scoped and should not be modified:

- `autoloads/llm_client.gd` — single-purpose HTTP client
- `autoloads/time_manager.gd` — clean time progression
- `autoloads/game_events.gd` — pure signal bus, no logic
- `scripts/data/item_database.gd`, `monster_database.gd`, `level_data.gd`, `skill_database.gd` — static data
- `scripts/llm/action_schema.gd`, `prompt_builder.gd`, `response_parser.gd` — well-bounded LLM layer
- `scripts/utils/ui_helper.gd`, `drag_handle.gd`, `cursor_manager.gd` — small, focused utilities
- `scenes/ui/` panels (except `panel_toggles.gd` and `npc_info_panel.gd`)
- `scenes/npcs/npc_action_executor.gd`, `npc_brain.gd`, `npc_memory.gd` — well-bounded
- `scenes/monsters/monster_base.gd`, `monster_spawner.gd` — clean
- `scripts/world/field_builder.gd` — small and focused
