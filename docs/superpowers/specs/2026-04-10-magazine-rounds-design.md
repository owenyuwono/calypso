# Magazine & Rounds System

## Context

The player can toggle into gun mode (T key) and fire bullets with unlimited ammo. This removes tension from the zombie survival experience. Adding a magazine/reload/reserve system creates resource pressure and tactical decision-making — when to reload, when to conserve, when to switch to melee.

## Requirements

- Magazine-based shooting: each shot consumes one round from the current magazine
- Manual reload (R key) + auto-reload when magazine hits 0
- Finite ammo reserves: reload draws from reserves, can't reload when reserves are empty
- HUD: text counter (bottom-right), visible only in gun mode, flashes red when low/empty
- Weapon-specific magazine config via ItemDatabase
- Firing blocked during reload and when magazine is empty with no reserves

## Architecture

### New: AmmoComponent (`scripts/components/ammo_component.gd`)

Node component following existing pattern (StatsComponent, StaminaComponent).

**State:**
- `_magazine_current: int` — rounds currently in magazine
- `_magazine_max: int` — max magazine capacity (from weapon config)
- `_reserve: int` — total spare rounds
- `_reload_time: float` — seconds to reload (from weapon config)
- `_reload_timer: float` — countdown during active reload
- `_is_reloading: bool`

**API:**
- `setup(magazine_max: int, reload_time: float, starting_reserve: int)` — initialize for a weapon
- `try_consume() -> bool` — attempt to fire one round; returns false if empty
- `start_reload()` — begin reload if not full and has reserves
- `cancel_reload()` — cancel active reload (e.g., on weapon swap)
- `is_reloading() -> bool`
- `can_fire() -> bool` — has ammo and not reloading
- `get_magazine_current() -> int`
- `get_magazine_max() -> int`
- `get_reserve() -> int`
- `add_reserve(amount: int)` — for looting ammo
- `configure_weapon(magazine_max: int, reload_time: float)` — on weapon swap

**Reload logic (in `_process`):**
- Decrement `_reload_timer` by delta
- When timer reaches 0: transfer min(`_magazine_max - _magazine_current`, `_reserve`) rounds from reserve to magazine
- Emit `GameEvents.ammo_changed`

### Modified: GameEvents (`autoloads/game_events.gd`)

New signal:
```
signal ammo_changed(entity_id: String, magazine_current: int, magazine_max: int, reserve: int)
```

### Modified: ItemDatabase (`scripts/data/item_database.gd`)

Add fields to weapon items:
```gdscript
"pistol": {
    name = "Pistol",
    type = "weapon",
    slot_type = "main_hand",
    weapon_type = "pistol",
    phys_type = "pierce",
    atk_bonus = 3,
    attack_speed = 0.12,
    magazine_size = 12,
    reload_time = 1.5,
    ammo_type = "bullet",
    is_ranged = true,
    value = 0,
}
```

Existing melee weapons unchanged (no magazine fields = melee).

### Modified: player.gd

**`_fire_gun()`:**
- Before spawning bullet: call `_ammo_comp.try_consume()`
- If returns false and has reserves: trigger auto-reload
- If returns false and no reserves: play empty click, skip shot

**`_unhandled_input()`:**
- R key: call `_ammo_comp.start_reload()`
- Block left-click fire while `_ammo_comp.is_reloading()`

**`_ready()`:**
- Create AmmoComponent as child node
- Configure with default pistol values (magazine_size=12, reload_time=1.5, starting_reserve=48)

### Modified: PlayerHUD (`scenes/ui/player_hud.gd`)

**New UI element: ammo counter panel (bottom-right)**

Structure:
```
PanelContainer (styled with UIHelper.create_panel_style())
├── VBoxContainer
│   ├── HBoxContainer
│   │   ├── Label "🔫" (weapon icon placeholder)
│   │   └── Label "8 / 12" (magazine_current / magazine_max)
│   └── Label "Reserve: 47" (smaller, dimmer text)
```

Behavior:
- Visible only when player is in gun mode
- Red tint flash when magazine ≤ 3 rounds
- Red text when reserve = 0
- Shows "RELOADING..." replacing the count during reload
- Anchored bottom-right, above any future hotbar

Signal connection: `GameEvents.ammo_changed` → `_on_ammo_changed()`

Player notifies HUD of mode changes via a new signal or direct call.

### Modified: EquipmentComponent (`scripts/components/equipment_component.gd`)

On `equipment_changed` signal: if new weapon has `is_ranged` and `magazine_size`, call `_ammo_comp.configure_weapon()`.

## Starting Values

| Parameter | Value |
|-----------|-------|
| Magazine size | 12 |
| Reload time | 1.5s |
| Fire rate | 0.12s (existing) |
| Starting reserve | 48 (4 full mags) |
| Low ammo threshold | ≤ 3 rounds |

## Verification

1. Enter gun mode (T), fire — magazine count decreases in HUD
2. Empty the magazine — auto-reload triggers, "RELOADING..." shows for 1.5s
3. Press R mid-magazine — manual reload works, partial mag rounds not lost
4. Deplete all reserves — can't reload, empty click on fire attempt
5. Switch to melee mode — ammo HUD hides
6. Switch back to gun mode — ammo HUD reappears with correct state
