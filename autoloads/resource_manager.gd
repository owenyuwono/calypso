extends Node
## Global resource simulation autoload. Tracks containers, devices, grid connection,
## and farm growth. Runs in real-time via _process(delta).

const DeviceDatabase = preload("res://scripts/data/device_database.gd")
const ItemDatabase = preload("res://scripts/data/item_database.gd")

# 1 game hour = 112.5 real seconds (2700s / 24h)
const SECONDS_PER_GAME_HOUR: float = 112.5

# Cascade check interval (real seconds)
const CASCADE_INTERVAL: float = 2.0

# Signal emission throttle (real seconds)
const SIGNAL_INTERVAL: float = 1.0

# WorldState sync interval (real seconds)
const SYNC_INTERVAL: float = 5.0

# Grid gold billing interval — once per game-hour via signal
const GRID_BASE_COST: Dictionary = {
	"electricity": 2,
	"water": 1,
}

# --- Inner Classes ---

class ResContainer extends RefCounted:
	var id: String
	var type: String
	var resource_type: String
	var current: float
	var capacity: float

	func add(amount: float) -> float:
		var actual := minf(amount, capacity - current)
		current += actual
		return amount - actual

	func consume(amount: float) -> bool:
		if current >= amount:
			current -= amount
			return true
		return false

	func is_empty() -> bool:
		return current <= 0.01

	func get_fill_percent() -> float:
		if capacity <= 0.0:
			return 0.0
		return current / capacity

	func to_dict() -> Dictionary:
		return {"type": type, "resource_type": resource_type, "current": current, "capacity": capacity}

	static func from_dict(cont_id: String, d: Dictionary) -> ResContainer:
		var c := ResContainer.new()
		c.id = cont_id
		c.type = d["type"]
		c.resource_type = d["resource_type"]
		c.current = d.get("current", 0.0)
		c.capacity = d.get("capacity", 0.0)
		return c


class Device extends RefCounted:
	var id: String
	var type: String
	var produces: Dictionary
	var consumes: Dictionary
	var active: bool = true
	var shutdown: bool = false
	# Farm-specific
	var growth_timer: float = 0.0

	func is_running() -> bool:
		return active and not shutdown

	func get_effective_production(hour: int) -> Dictionary:
		var def: Dictionary = DeviceDatabase.get_device(type)
		if def.get("time_modifier", false):
			var multiplier := _get_time_multiplier(hour)
			var result: Dictionary = {}
			for res_id in produces:
				result[res_id] = produces[res_id] * multiplier
			return result
		return produces

	func _get_time_multiplier(hour: int) -> float:
		if hour >= 7 and hour < 18:
			return 1.0
		elif (hour >= 5 and hour < 7) or (hour >= 18 and hour < 20):
			return 0.5
		else:
			return 0.0

	func to_dict() -> Dictionary:
		var d: Dictionary = {"type": type, "active": active}
		if growth_timer > 0.0:
			d["growth_timer"] = growth_timer
		return d

	static func from_dict(dev_id: String, d: Dictionary) -> Device:
		var dev := Device.new()
		dev.id = dev_id
		dev.type = d["type"]
		dev.active = d.get("active", true)
		dev.growth_timer = d.get("growth_timer", 0.0)
		var def: Dictionary = DeviceDatabase.get_device(dev.type)
		dev.produces = def.get("produces", {})
		dev.consumes = def.get("consumes", {})
		return dev


# --- State ---

var _containers: Dictionary = {}  # id -> ResContainer
var _devices: Dictionary = {}     # id -> Device
var _next_container_id: int = 0
var _next_device_id: int = 0

# Grid
var grid_connected: bool = true
var grid_failed: bool = false
var grid_cost_multiplier: float = 1.0
var _grid_gold_accumulator: Dictionary = {}  # resource_type -> gold owed this hour

# Grid outage (virus outbreak stage)
var _grid_outage_hours_remaining: int = 0

# Timers
var _cascade_timer: float = 0.0
var _signal_timer: float = 0.0
var _sync_timer: float = 0.0


func _ready() -> void:
	GameEvents.game_hour_changed.connect(_on_game_hour_changed)


func _process(delta: float) -> void:
	_tick_devices(delta)
	_tick_farms(delta)

	_cascade_timer += delta
	if _cascade_timer >= CASCADE_INTERVAL:
		_cascade_timer = 0.0
		_resolve_cascades()

	_signal_timer += delta
	if _signal_timer >= SIGNAL_INTERVAL:
		_signal_timer = 0.0
		GameEvents.resources_updated.emit(_get_resource_snapshot())

	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		_sync()


# --- Device Tick ---

func _tick_devices(delta: float) -> void:
	var hour: int = int(TimeManager.get_game_hour())

	for device in _devices.values():
		if not device.is_running():
			continue

		var def: Dictionary = DeviceDatabase.get_device(device.type)
		var category: String = def.get("category", "")
		if category == "farm" or category == "storage":
			continue

		# Consume inputs
		var can_run := true
		var consume_amounts: Dictionary = {}
		for res_type in device.consumes:
			var rate: float = device.consumes[res_type]
			var amount: float = rate / SECONDS_PER_GAME_HOUR * delta
			consume_amounts[res_type] = amount
			if _get_resource_total(res_type) < amount:
				# Try grid supplement
				if _is_grid_supplying(res_type):
					_track_grid_usage(res_type, amount)
				else:
					can_run = false

		if not can_run:
			continue

		# Actually consume
		for res_type in consume_amounts:
			var amount: float = consume_amounts[res_type]
			if not _consume_from_containers(res_type, amount):
				# Grid covers the deficit
				if _is_grid_supplying(res_type):
					_track_grid_usage(res_type, amount)

		# Produce outputs
		var effective_prod: Dictionary = device.get_effective_production(hour)
		for res_type in effective_prod:
			var rate: float = effective_prod[res_type]
			var amount: float = rate / SECONDS_PER_GAME_HOUR * delta
			_add_to_containers(res_type, amount)


# --- Farm Tick ---

func _tick_farms(delta: float) -> void:
	for device in _devices.values():
		if not device.is_running():
			continue

		var def: Dictionary = DeviceDatabase.get_device(device.type)
		if def.get("category", "") != "farm":
			continue

		# Check if water (and electricity if needed) are available
		var can_grow := true
		for res_type in device.consumes:
			var rate: float = device.consumes[res_type]
			var amount: float = rate / SECONDS_PER_GAME_HOUR * delta
			if _get_resource_total(res_type) < amount:
				if not _is_grid_supplying(res_type):
					can_grow = false
					break

		if not can_grow:
			continue

		# Consume resources
		for res_type in device.consumes:
			var rate: float = device.consumes[res_type]
			var amount: float = rate / SECONDS_PER_GAME_HOUR * delta
			if not _consume_from_containers(res_type, amount):
				if _is_grid_supplying(res_type):
					_track_grid_usage(res_type, amount)

		# Advance growth timer
		device.growth_timer += delta
		var growth_threshold: float = def.get("growth_time_hours", 6.0) * SECONDS_PER_GAME_HOUR
		if device.growth_timer >= growth_threshold:
			device.growth_timer = 0.0
			_harvest_farm(device, def)


func _harvest_farm(device: Device, def: Dictionary) -> void:
	var food_items: Array = def.get("food_items", [])
	if food_items.is_empty():
		return
	# Pick a random food item from the list
	var item_id: String = food_items[randi() % food_items.size()]
	var player: Node3D = WorldState.get_entity("player")
	if player:
		var inv: Node = player.get_node_or_null("InventoryComponent")
		if inv:
			inv.add_item(item_id, 1)
			GameEvents.item_looted.emit("player", item_id, 1)


# --- Cascade Resolution ---

func _resolve_cascades() -> void:
	# Track previous state for transition-only signals
	var was_shutdown: Dictionary = {}
	for device in _devices.values():
		was_shutdown[device.id] = device.shutdown
		device.shutdown = false

	for _iteration in range(3):
		var changed := false
		var totals := _get_all_resource_totals()

		for device in _devices.values():
			if not device.active:
				continue
			if device.shutdown:
				continue
			for res_type in device.consumes:
				if totals.get(res_type, 0.0) <= 0.01 and not _is_grid_supplying(res_type):
					device.shutdown = true
					changed = true
					# Only emit on false -> true transition
					if not was_shutdown.get(device.id, false):
						GameEvents.device_shutdown.emit(device.id, device.type)
					break

		if not changed:
			break

	# Check for resource depletion signals
	var totals := _get_all_resource_totals()
	for res_type in totals:
		if totals[res_type] <= 0.01 and not _is_grid_supplying(res_type):
			GameEvents.resource_depleted.emit(res_type)


# --- Grid ---

func _is_grid_supplying(resource_type: String) -> bool:
	if not grid_connected or grid_failed:
		return false
	if _grid_outage_hours_remaining > 0:
		return false
	return resource_type in ["electricity", "water"]


func _track_grid_usage(resource_type: String, amount: float) -> void:
	_grid_gold_accumulator[resource_type] = _grid_gold_accumulator.get(resource_type, 0.0) + amount


func _on_game_hour_changed(hour: int) -> void:
	# Bill grid usage
	_bill_grid_usage()

	# Handle grid outage countdown
	if _grid_outage_hours_remaining > 0:
		_grid_outage_hours_remaining -= 1
		if _grid_outage_hours_remaining <= 0:
			GameEvents.grid_status_changed.emit(true)


func _bill_grid_usage() -> void:
	if not grid_connected or grid_failed:
		_grid_gold_accumulator.clear()
		return

	var total_gold: int = 0
	for res_type in _grid_gold_accumulator:
		var usage: float = _grid_gold_accumulator[res_type]
		if usage <= 0.0:
			continue
		var base_cost: int = GRID_BASE_COST.get(res_type, 0)
		# Gold = usage_amount * cost_per_unit * multiplier
		total_gold += int(ceilf(usage * base_cost * grid_cost_multiplier))

	if total_gold > 0:
		var player: Node3D = WorldState.get_entity("player")
		if player:
			var inv: Node = player.get_node_or_null("InventoryComponent")
			if inv:
				if inv.get_gold_amount() >= total_gold:
					inv.remove_gold_amount(total_gold)
				else:
					# Can't afford grid — stop supplementing next hour
					pass

	_grid_gold_accumulator.clear()


func trigger_grid_outage(hours: int) -> void:
	_grid_outage_hours_remaining = hours
	GameEvents.grid_status_changed.emit(false)


func fail_grid_permanently() -> void:
	grid_failed = true
	GameEvents.grid_status_changed.emit(false)


# --- Container Helpers ---

func _get_resource_total(resource_type: String) -> float:
	var total: float = 0.0
	for container in _containers.values():
		if container.resource_type == resource_type:
			total += container.current
	return total


func _get_resource_capacity(resource_type: String) -> float:
	var total: float = 0.0
	for container in _containers.values():
		if container.resource_type == resource_type:
			total += container.capacity
	return total


func _get_all_resource_totals() -> Dictionary:
	var totals: Dictionary = {}
	for container in _containers.values():
		var rt: String = container.resource_type
		totals[rt] = totals.get(rt, 0.0) + container.current
	return totals


func _consume_from_containers(resource_type: String, amount: float) -> bool:
	var remaining: float = amount
	for container in _containers.values():
		if container.resource_type != resource_type:
			continue
		if remaining <= 0.0:
			break
		var take: float = minf(remaining, container.current)
		container.current -= take
		remaining -= take
	return remaining <= 0.01


func _add_to_containers(resource_type: String, amount: float) -> void:
	var remaining: float = amount
	for container in _containers.values():
		if container.resource_type != resource_type:
			continue
		if remaining <= 0.0:
			break
		var space: float = container.capacity - container.current
		var add_amount: float = minf(remaining, space)
		container.current += add_amount
		remaining -= add_amount


# --- Public API: Containers ---

func add_container(device_type: String, initial_fill: float = 0.0) -> String:
	var def: Dictionary = DeviceDatabase.get_device(device_type)
	if def.is_empty():
		return ""
	var c := ResContainer.new()
	c.id = "%s_%d" % [device_type, _next_container_id]
	_next_container_id += 1
	c.type = device_type
	c.resource_type = def.get("resource_type", "")
	c.capacity = def.get("capacity", 0.0)
	c.current = clampf(initial_fill, 0.0, c.capacity)
	_containers[c.id] = c
	return c.id


func remove_container(container_id: String) -> void:
	_containers.erase(container_id)


func get_container(container_id: String) -> ResContainer:
	return _containers.get(container_id)


func get_all_containers() -> Dictionary:
	return _containers


# --- Public API: Devices ---

func add_device(device_type: String) -> String:
	var def: Dictionary = DeviceDatabase.get_device(device_type)
	if def.is_empty():
		return ""
	var d := Device.new()
	d.id = "%s_%d" % [device_type, _next_device_id]
	_next_device_id += 1
	d.type = device_type
	d.produces = def.get("produces", {})
	d.consumes = def.get("consumes", {})
	d.active = true
	_devices[d.id] = d
	return d.id


func remove_device(device_id: String) -> void:
	_devices.erase(device_id)


func set_device_active(device_id: String, is_active: bool) -> void:
	var device: Device = _devices.get(device_id)
	if device:
		device.active = is_active


func get_device(device_id: String) -> Device:
	return _devices.get(device_id)


func get_all_devices() -> Dictionary:
	return _devices


func is_device_running(device_id: String) -> bool:
	var device: Device = _devices.get(device_id)
	if device:
		return device.is_running()
	return false


# --- Public API: Resource queries ---

func get_resource_total(resource_type: String) -> float:
	return _get_resource_total(resource_type)


func get_resource_capacity(resource_type: String) -> float:
	return _get_resource_capacity(resource_type)


func try_consume(resource_type: String, amount: float) -> bool:
	if _get_resource_total(resource_type) >= amount:
		return _consume_from_containers(resource_type, amount)
	if _is_grid_supplying(resource_type):
		_track_grid_usage(resource_type, amount)
		return true
	return false


func is_grid_active() -> bool:
	return grid_connected and not grid_failed and _grid_outage_hours_remaining <= 0


# --- Snapshot & Persistence ---

func _get_resource_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for container in _containers.values():
		var rt: String = container.resource_type
		if not snapshot.has(rt):
			snapshot[rt] = {"current": 0.0, "capacity": 0.0}
		snapshot[rt]["current"] += container.current
		snapshot[rt]["capacity"] += container.capacity
	return snapshot


func _sync() -> void:
	if not WorldState.get_entity("player"):
		return
	var containers_data: Dictionary = {}
	for cid in _containers:
		containers_data[cid] = _containers[cid].to_dict()

	var devices_data: Dictionary = {}
	for did in _devices:
		devices_data[did] = _devices[did].to_dict()

	var base_data: Dictionary = {
		"containers": containers_data,
		"devices": devices_data,
		"grid": {
			"connected": grid_connected,
			"failed": grid_failed,
			"cost_multiplier": grid_cost_multiplier,
		},
		"next_container_id": _next_container_id,
		"next_device_id": _next_device_id,
	}
	WorldState.set_entity_data("player", "base", base_data)


func load_state() -> void:
	var data: Dictionary = WorldState.get_entity_data("player").get("base", {})
	if data.is_empty():
		return

	_containers.clear()
	var containers_data: Dictionary = data.get("containers", {})
	for cid in containers_data:
		_containers[cid] = ResContainer.from_dict(cid, containers_data[cid])

	_devices.clear()
	var devices_data: Dictionary = data.get("devices", {})
	for did in devices_data:
		_devices[did] = Device.from_dict(did, devices_data[did])

	var grid_data: Dictionary = data.get("grid", {})
	grid_connected = grid_data.get("connected", true)
	grid_failed = grid_data.get("failed", false)
	grid_cost_multiplier = grid_data.get("cost_multiplier", 1.0)

	_next_container_id = data.get("next_container_id", 0)
	_next_device_id = data.get("next_device_id", 0)
