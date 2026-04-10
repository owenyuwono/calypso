# Resource Simulation System — Design Spec

## Context

Calypso is a base-building zombie survival game about living off the grid in an apocalyptic world. The player starts with a suburban house connected to municipal electricity and water grids. As the world deteriorates through crisis stages (inflation, virus, zombie apocalypse), grids fail and the player must build self-sufficient infrastructure.

The resource simulation is the backbone system — house upgrades, survival needs, defenses, and farming all depend on resources flowing correctly. This spec covers: container-based resource tracking, device production/consumption, cascading shutdowns, grid connection, and personal survival needs.

## Architecture: Autoload with Typed Data Objects

`ResourceManager` autoload holds all resource state as `RefCounted` inner classes (`Container`, `Device`). Devices are pure data — no coupling to zone lifecycle. Scene nodes in the house zone are visual-only representations that read state from the autoload.

Player personal needs are handled by `NeedsComponent` (extends BaseComponent), following the same pattern as `StatsComponent` and `StaminaComponent`.

### Why This Approach

- **Zone safety**: ZoneManager frees all zone children on unload. Keeping device data in an autoload avoids the snapshot/restore fragility of component-based devices.
- **Type safety**: Cascade resolution iterates devices checking resource dependencies. Typed classes prevent silent dictionary key typos.
- **Separation**: Base infrastructure (global autoload) vs player needs (component on player node). Each concern in its natural home.

## Resource Model: Container-Based

No abstract resource pools. Everything is physical.

### Resource Types

| Type | Unit | Stored In | Examples |
|------|------|-----------|----------|
| Electricity | kWh | Batteries (base devices) | Battery bank (50 kWh) |
| Water | liters | Water tanks (base devices) | Small tank (30L), large tank (100L) |
| Fuel | liters | Fuel containers (base devices) | Jerry can (20L), drum (200L) |

**Food** is not a resource type — it's individual inventory items with a `nutrition` value. Farm plots produce specific food items into inventory over time.

### Container (RefCounted inner class)

```gdscript
class ResContainer extends RefCounted:
    var id: String            # "battery_1", "water_tank_1", "jerry_can_3"
    var type: String          # device type key from DeviceDatabase
    var resource_type: String # "electricity", "water", "fuel"
    var current: float        # current fill level
    var capacity: float       # max capacity

    func add(amount: float) -> float:
        var actual := minf(amount, capacity - current)
        current += actual
        return amount - actual  # returns overflow

    func consume(amount: float) -> bool:
        if current >= amount:
            current -= amount
            return true
        return false

    func is_empty() -> bool:
        return current <= 0.01

    func to_dict() -> Dictionary:
        return {"type": type, "resource_type": resource_type, "current": current, "capacity": capacity}

    static func from_dict(id: String, d: Dictionary) -> Container:
        var c := Container.new()
        c.id = id
        c.type = d["type"]
        c.resource_type = d["resource_type"]
        c.current = d["current"]
        c.capacity = d["capacity"]
        return c
```

### Device (RefCounted inner class)

```gdscript
class Device extends RefCounted:
    var id: String
    var type: String           # key in DeviceDatabase
    var produces: Dictionary   # {resource_type: rate_per_game_hour}
    var consumes: Dictionary   # {resource_type: rate_per_game_hour}
    var active: bool = true    # player-controlled on/off
    var shutdown: bool = false # system-set when input resource depleted

    func is_running() -> bool:
        return active and not shutdown

    func get_effective_production(hour: int) -> Dictionary:
        # Override for time-dependent devices (solar panels)
        var def := DeviceDatabase.get_device(type)
        if def.get("time_modifier", false):
            var multiplier := _get_time_multiplier(hour)
            var result := {}
            for res_id in produces:
                result[res_id] = produces[res_id] * multiplier
            return result
        return produces

    func _get_time_multiplier(hour: int) -> float:
        if hour >= 7 and hour < 18:
            return 1.0  # full day
        elif (hour >= 5 and hour < 7) or (hour >= 18 and hour < 20):
            return 0.5  # dawn/dusk
        else:
            return 0.0  # night

    func to_dict() -> Dictionary:
        return {"type": type, "active": active}

    static func from_dict(id: String, d: Dictionary) -> Device:
        var dev := Device.new()
        dev.id = id
        dev.type = d["type"]
        dev.active = d.get("active", true)
        var def := DeviceDatabase.get_device(dev.type)
        dev.produces = def.get("produces", {})
        dev.consumes = def.get("consumes", {})
        return dev
```

## Real-Time Simulation

The simulation runs in `_process(delta)`, not per-tick. Rates are defined in per-game-hour units for readability but applied continuously.

**Conversion**: 1 game hour = 112.5 real seconds (2700s / 24h). So `rate_per_second = rate_per_game_hour / 112.5`.

### ResourceManager._process(delta)

```
1. For each running device:
   a. Calculate per-frame production: rate_per_hour / 112.5 * delta
   b. Calculate per-frame consumption: rate_per_hour / 112.5 * delta
   c. Attempt to consume from containers of input resource type
   d. If consumption succeeds, add production to containers of output resource type
   e. If consumption fails (not enough in containers), mark for cascade check

2. Grid supplement (if connected):
   - For electricity and water, if devices couldn't consume enough, grid covers the deficit
   - Track gold cost (billed hourly, not per-frame)

3. Cascade check (every ~2 seconds via timer accumulator):
   - Clear all shutdown flags
   - For each resource type, sum total across all containers
   - If total <= 0, mark all devices consuming that resource as shutdown
   - Repeat until stable (max 3 iterations)

4. Signal emission (throttled ~1 second):
   - GameEvents.resources_updated.emit(snapshot)
```

### Grid Connection

```gdscript
var grid_connected: bool = true
var grid_failed: bool = false
var grid_cost_multiplier: float = 1.0
var _grid_gold_accumulator: float = 0.0  # accumulates cost, deducts hourly

# Base costs per game-hour (gold)
const GRID_COST: Dictionary = {
    "electricity": 2,  # gold per game-hour of grid electricity use
    "water": 1,        # gold per game-hour of grid water use
}
```

**Grid behavior by apocalypse stage:**

| Stage | Grid Effect |
|-------|-------------|
| 1. World crisis | Normal |
| 2. War news | Normal |
| 3. Local inflation | `grid_cost_multiplier = 2.5` |
| 4. Virus outbreak | Random outages (10% chance per game-hour of 2-4 hour blackout) |
| 5. Zombie apocalypse | `grid_failed = true` (permanent) |

**Gold billing**: Every game-hour, calculate total grid usage since last bill. Deduct `usage * GRID_COST[type] * grid_cost_multiplier` gold from player inventory. If insufficient gold, grid stops supplementing until player has gold again.

**Illegal rainwater collection**: Pre-apocalypse (stages 1-2), if a rainwater collector is active, there's a small chance per game-day of a fine (gold penalty). After stage 3, no enforcement.

## Cascade Resolution

When a resource type is depleted across all containers, devices consuming it shut down. This cascades.

**Example**: Fuel runs out → generator shuts down → no electricity production → batteries drain to 0 → water pump shuts down → water stops filling → farm plots stop → no food production.

**Algorithm** (runs every ~2 seconds):

```
func _resolve_cascades() -> void:
    for device in _devices.values():
        device.shutdown = false  # reset each cycle

    for _iteration in range(3):  # max 3 passes (one per resource type)
        var changed := false
        var totals := _sum_resource_totals()

        for device in _devices.values():
            if not device.active:
                continue
            for res_type in device.consumes:
                if totals.get(res_type, 0.0) <= 0.01:
                    if not device.shutdown:
                        device.shutdown = true
                        changed = true
                        GameEvents.device_shutdown.emit(device.id, device.type)

        if not changed:
            break
```

**Key distinction**:
- `active`: Player-controlled on/off toggle
- `shutdown`: System-imposed due to resource depletion. Cleared at start of each cascade check.
- Device runs only when `active AND NOT shutdown`

## Device Catalog (DeviceDatabase)

Static data class at `scripts/data/device_database.gd`.

### Producers

| Device | Produces | Consumes | Notes |
|--------|----------|----------|-------|
| Fuel Generator | electricity: 5.0 kWh/hr | fuel: 1.0 L/hr | Noisy (future: attracts zombies) |
| Solar Panel | electricity: 2.0 kWh/hr | — | Day-only via time_modifier |
| Electric Water Pump | water: 5.0 L/hr | electricity: 0.5 kWh/hr | Most efficient water source |
| Rainwater Collector | water: 1.0 L/hr | — | Illegal pre-apocalypse. Weather-dependent (future) |
| Well | water: 3.0 L/hr | — | Expensive to build, reliable |
| Soil Farm Plot | food items/cycle | water: 1.0 L/hr | Produces 1 food item every ~6 game-hours when watered |
| Vertical Farm | food items/cycle | water: 2.0 L/hr, electricity: 0.5 kWh/hr | 1 food item every ~3 game-hours |
| Aquaponics | food items/cycle | water: 0.5 L/hr, electricity: 1.0 kWh/hr | 1 food item every ~2 game-hours + water recycling |

### Storage Only (containers)

| Device | Resource | Capacity | Notes |
|--------|----------|----------|-------|
| Battery Bank | electricity | 50 kWh | |
| Water Tank (small) | water | 30 L | |
| Water Tank (large) | water | 100 L | |
| Jerry Can | fuel | 20 L | Portable, refillable at gas stations |
| Fuel Drum | fuel | 200 L | Stationary |

### Utility Devices

| Device | Consumes | Effect |
|--------|----------|--------|
| Fridge | electricity: 0.3 kWh/hr | Prevents food spoilage for items in fridge inventory |

### Farm Plot Special Behavior

Farm plots don't produce a continuous "food" resource. Instead:
- Each farm Device in ResourceManager tracks a `growth_timer: float` (accumulated real-time seconds)
- When timer reaches threshold AND water was available throughout: add a specific food item to player inventory via InventoryComponent
- Different farm types produce different items (soil: tomatoes, carrots; vertical: lettuce; aquaponics: fish, herbs)
- If water is unavailable, growth timer pauses (crops don't die instantly, just stop growing)

## Personal Needs (NeedsComponent)

Extends `BaseComponent`, attached as child of player node.

### Four Needs (0-100 scale)

| Need | Decay Rate | Replenishment | Consequences at 0 |
|------|-----------|---------------|-------------------|
| Hunger | -3.0/hr | Eat food items (each has `nutrition` value) | HP drain -5/hr, ATK 0.5x |
| Thirst | -5.0/hr | Drink from water containers or water bottles | HP drain -8/hr, move speed 0.7x |
| Hygiene | -1.5/hr | Shower (10L water), brush teeth (1L water + toothpaste item) | Disease risk: 5% per hour when <25 |
| Health | No decay | Medicine items, rest (hunger>50 AND thirst>50 = +2/hr) | At 0: death |

### Threshold Effects

| Range | Visual | Gameplay |
|-------|--------|----------|
| 75-100 | Green indicator | No effects |
| 50-75 | Yellow indicator | Warning only |
| 25-50 | Orange indicator | Moderate debuffs (partial penalties) |
| 0-25 | Red, pulsing | Full penalties active |

### Health as Consequence Meter

Health doesn't decay naturally. It's damaged by:
- Hunger at 0: -5 hp/hr
- Thirst at 0: -8 hp/hr
- Hygiene below 25: 5% chance per game-hour of disease event (-20 health)
- Zombie combat (existing damage system)

Health heals when:
- Hunger > 50 AND thirst > 50: +2 health/hr (natural recovery)
- Medicine items: instant health restoration (amount per item)

### Replenishment Actions

| Action | Resource Cost | Need Effect | Interaction |
|--------|--------------|-------------|-------------|
| Eat food item | 1 food item from inventory | Hunger + item's nutrition value | Use from inventory |
| Drink water | ~2L from water containers | Thirst +30 | Interact with tap/tank |
| Drink water bottle | 1 water bottle from inventory | Thirst +20 | Use from inventory |
| Shower | 10L water | Hygiene = 100 | Interact with shower (5 game-min) |
| Brush teeth | 1L water + 1 toothpaste | Hygiene +20 | Interact with sink |
| Use medicine | 1 medicine item | Health + item's heal value | Use from inventory |

### Real-Time Decay

NeedsComponent runs in `_process(delta)`. Decay rates are per-game-hour, converted the same way as resource rates: `decay_per_second = decay_per_hour / 112.5`. Emits `GameEvents.needs_changed` throttled to ~1 second intervals.

## UI Integration

### PlayerHUD Additions

**Resource indicators** (top-left area):
- Battery icon + fill bar (sum of electricity across all batteries)
- Water droplet icon + fill bar (sum of water across all tanks)
- Fuel icon + fill bar (sum of fuel across all containers)

**Needs indicators** (below existing HP/stamina bars):
- 4 small icons: fork (hunger), droplet (thirst), soap (hygiene), heart (health)
- Each with a thin fill bar
- Color transitions: green → yellow → orange → red based on thresholds
- Pulse animation when critical (<25)

### GameMenu — "Base" Tab

New 4th tab: **Status | Inventory | Base | System**

Base panel contents:
- **Resource Overview**: All containers listed with individual fill levels ("Battery 1: 32/50 kWh")
- **Device List**: All devices with status (running/off/shutdown), rates displayed
- **Grid Status**: Connected/disconnected, hourly cost, total expenditure
- **Needs Detail**: All 4 needs with current values, decay rates, and tips

### Signal Flow

```
ResourceManager._process()
  → (throttled ~1s) GameEvents.resources_updated(containers_snapshot)
  → PlayerHUD updates resource bars
  → BasePanel refreshes if open

NeedsComponent._process()
  → (throttled ~1s) GameEvents.needs_changed(needs_snapshot)
  → PlayerHUD updates need indicators
  → BasePanel refreshes needs detail
```

## Persistence

### ResourceManager → WorldState

Syncs every ~5 seconds to `WorldState.entity_data["player"]["base"]`:

```gdscript
{
    "containers": {
        "battery_1": {"type": "battery_bank", "resource_type": "electricity", "current": 32.0, "capacity": 50.0},
        "water_tank_1": {"type": "water_tank", "resource_type": "water", "current": 18.0, "capacity": 50.0},
        "jerry_can_1": {"type": "jerry_can", "resource_type": "fuel", "current": 12.0, "capacity": 20.0},
    },
    "devices": {
        "solar_panel_1": {"type": "solar_panel", "active": true},
        "water_pump_1": {"type": "water_pump", "active": true},
        "farm_plot_1": {"type": "soil_farm", "active": true},
    },
    "grid": {
        "connected": true,
        "failed": false,
        "cost_multiplier": 1.0,
    }
}
```

### NeedsComponent → WorldState

Syncs on threshold crossings to `WorldState.entity_data["player"]["needs"]`:

```gdscript
{"hunger": 85.0, "thirst": 72.0, "hygiene": 90.0, "health": 100.0}
```

## New GameEvents Signals

```gdscript
signal resources_updated(snapshot: Dictionary)        # container totals per resource type
signal resource_depleted(resource_type: String)        # a resource hit 0
signal device_shutdown(device_id: String, device_type: String)  # cascade shutdown
signal grid_status_changed(connected: bool)            # grid connect/disconnect
signal needs_changed(needs: Dictionary)                # player needs update
signal need_critical(need_type: String)                # a need dropped below 25
```

## New Files

| File | Purpose |
|------|---------|
| `autoloads/resource_manager.gd` | Global resource simulation. Container, Device inner classes. Real-time tick, cascade, grid. |
| `scripts/components/needs_component.gd` | Player personal needs. Extends BaseComponent. |
| `scripts/data/device_database.gd` | Static device definitions (rates, names, categories). |
| `scenes/ui/base_panel.gd` | GameMenu "Base" tab builder. |

## Modified Files

| File | Change |
|------|--------|
| `autoloads/game_events.gd` | Add 6 new signals (resources_updated, resource_depleted, device_shutdown, grid_status_changed, needs_changed, need_critical) |
| `scripts/data/item_database.gd` | Add food items with `nutrition` field, hygiene items (soap, toothpaste, water bottle) |
| `scenes/ui/player_hud.gd` | Add resource bars (top-left) + needs indicators (below HP/stamina) |
| `scenes/ui/game_menu.gd` | Add Base tab as 4th tab, wire up BasePanel builder |
| `scenes/player/player.gd` | Add NeedsComponent as child node in _ready() |
| `project.godot` | Register ResourceManager autoload |

## Verification Plan

1. **ResourceManager unit test (manual)**:
   - Add a battery + solar panel via ResourceManager API
   - Observe battery filling in real-time
   - Add a water pump → observe it consuming electricity and producing water
   - Remove all fuel → verify generator shuts down → cascade to dependent devices

2. **Grid test**:
   - With grid connected, verify devices work without storage
   - Verify gold deduction per game-hour
   - Set `grid_failed = true` → verify cascade when batteries empty

3. **Needs test**:
   - Observe hunger/thirst/hygiene decaying in real-time
   - Eat a food item → verify hunger restored by nutrition value
   - Let hunger hit 0 → verify HP drain begins
   - Let hygiene drop below 25 → observe disease events

4. **UI test**:
   - HUD resource bars update smoothly
   - HUD needs indicators change color at thresholds
   - Base tab shows accurate container/device/grid state
   - Opening/closing GameMenu doesn't break signal connections

5. **Zone transition test**:
   - Leave house zone → verify resource simulation continues
   - Return to house zone → verify device visuals match ResourceManager state
