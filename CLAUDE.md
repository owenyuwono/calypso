# Arcadia — Godot 4.6 GDScript Project

## Conventions
- **Engine**: Godot 4.6, GDScript only
- **Autoload singletons**: WorldState (registry + spatial only), LLMClient, GameEvents (signals, LLM)
- **Static utility classes**: ModelHelper (3D models, effects), UIHelper (panel styles, UI helpers)
- **Composition nodes**: EntityVisuals (visual state: model, overlay, animations, HP bar) + entity components (stats, inventory, equipment, combat, progression, skills) for all entities
- **Duck typing**: Component vars declared as `Node`, called with duck-typed method calls. Use `var x: int = node.method()` (not `:=`) when return type can't be inferred
- **State machines**: String-based states (idle/thinking/moving/combat/dead)
- **Inventory**: Count-based Dictionary {item_type_id: count}, not arrays
- **No automated tests**: Verify manually in editor (panels, combat, minimap, world map, chat)
- **Input**: Left-click move/attack/interact, E interact, Tab inventory, C status, S skills, P proficiencies, M minimap, W world map, 1-5 hotbar, D debug, Esc close panel

## Entity Component System
Each entity (player, NPC, monster) owns its state via child Node components:
- `StatsComponent` — hp, max_hp, atk, def, level, attack_speed, attack_range. **Must set `.name = "StatsComponent"` before `add_child()`**
- `InventoryComponent` — items dict + gold. API: `add_item()`, `remove_item()`, `has_item()`, `get_items()`, `add_gold_amount()`, `remove_gold_amount()`, `get_gold_amount()`, `set_gold_amount()`
- `EquipmentComponent` — weapon/armor slots. Requires InventoryComponent ref. API: `equip()`, `unequip()`, `get_atk_bonus()`, `get_def_bonus()`
- `CombatComponent` — damage/heal logic. Requires StatsComponent + optional EquipmentComponent. API: `deal_damage_to()`, `deal_damage_amount_to()`, `heal()`, `get_effective_atk()`, `get_effective_def()`, `is_alive()`
- `ProgressionComponent` — owns proficiency state `{skill_id: {level, xp}}`. Derives stats from proficiency levels. Requires StatsComponent. API: `grant_proficiency_xp()`, `get_proficiency_level()`, `get_proficiency_xp()`, `get_total_level()`, `get_proficiencies()`
- `SkillsComponent` — active skills (no skill points). Skills unlock via proficiency milestones. API: `unlock_skill()`, `grant_skill_xp()`, `has_skill()`, `get_skill_level()`, `set_hotbar_slot()`, `get_hotbar()`

Components sync state back to `WorldState.entity_data` via `_sync()` (bridge layer — keeps perception/memory reads working).

## WorldState (slim — registry + spatial only)
- **Registry** (6): `register_entity`, `unregister_entity`, `get_entity`, `get_entity_data`, `set_entity_data`, `get_entity_id_for_node`
- **Locations** (4): `register_location`, `get_location`, `has_location`, `get_all_locations`
- **Spatial** (2): `get_nearby_entities`, `get_npc_perception`
- **Convenience** (1): `is_alive(id)` — looks up entity's StatsComponent

Do NOT add inventory/gold/equipment/combat/progression/skills methods back to WorldState. Access components directly via the entity node.

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

## Proficiency System (RuneScape-style)
- **ProficiencyDatabase**: 13 skills, 4 categories (weapon/attribute/gathering/production), max level 10, XP formula: `level * 50`
- **Weapon** (5): sword, axe, mace, dagger, staff. **Attribute** (2): constitution, agility. **Gathering** (3): mining, woodcutting, fishing. **Production** (3): smithing, cooking, crafting
- **Stat derivation**: ATK = 5 + weapon_level * 2, DEF = 3 + constitution_level, Max HP = 40 + constitution_level * 10, player level = sum of all proficiency levels
- **XP sources**: weapon proficiency XP on combat hits, constitution XP on taking damage. Gathering/production are placeholders (not yet implemented)
- **Monsters**: `proficiency_xp` field in MonsterDatabase (3–20 per monster type)
- **Items**: `weapon_type`, `required_skill`, `required_level` fields for equipment proficiency requirements
- **Signals**: `proficiency_xp_gained(entity_id, skill_id, amount, new_xp)`, `proficiency_level_up(entity_id, skill_id, new_level)`
