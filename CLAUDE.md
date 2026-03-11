# Arcadia — Godot 4.6 GDScript Project

## Conventions
- **Engine**: Godot 4.6, GDScript only
- **Autoload singletons**: WorldState, LLMClient, GameEvents (global state, signals, LLM)
- **Static utility classes**: ModelHelper (3D models, effects), UIHelper (panel styles, UI helpers)
- **Duck typing**: NPC component scripts use duck typing for Godot 4 compatibility
- **State machines**: String-based states (idle/thinking/moving/combat/dead)
- **Inventory**: Count-based Dictionary {item_type_id: count}, not arrays
- **No automated tests**: Verify manually in editor (panels, combat, minimap, chat)

## Key Patterns
- `UIHelper.create_panel_style()` for all panel backgrounds
- `UIHelper.center_panel()` to center a PanelContainer on screen
- `UIHelper.set_corner_radius()` / `set_border_width()` for StyleBoxFlat shortcuts
- `ModelHelper.get_hit_delay()` for animation-timed hit delays
- `ModelHelper.update_entity_hp_bar()` for HP bar updates
- `DragHandle` for draggable panel title bars with close buttons
- Direction checks: always `dir.length_squared() > 0.01` before normalizing
