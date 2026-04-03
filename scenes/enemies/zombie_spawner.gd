extends Node
## Manages spawning and respawning of zombies within a zone area.

const ZombieBase = preload("res://scenes/enemies/zombie_base.tscn")

var _spawn_center: Vector3
var _spawn_radius: float
var _max_count: int
var _parent: Node3D
var _active_zombies: Dictionary = {}  # entity_id → node
var _next_id: int = 0
var _respawn_delay: float = 10.0
var _exclusion_zones: Array = []  # Array of {center: Vector3, radius: float}


func setup(parent: Node3D, spawn_center: Vector3, count: int, spawn_radius: float) -> void:
	_parent = parent
	_spawn_center = spawn_center
	_max_count = count
	_spawn_radius = spawn_radius
	GameEvents.entity_died.connect(_on_entity_died)
	for i in count:
		_spawn_zombie()


func add_exclusion_zone(center: Vector3, radius: float) -> void:
	_exclusion_zones.append({"center": center, "radius": radius})


func _is_in_exclusion_zone(pos: Vector3) -> bool:
	for zone in _exclusion_zones:
		var dist: float = Vector2(pos.x - zone.center.x, pos.z - zone.center.z).length()
		if dist < zone.radius:
			return true
	return false


func _spawn_zombie() -> void:
	var zombie = ZombieBase.instantiate()
	var id: String = "zombie_%d" % _next_id
	_next_id += 1
	zombie.entity_id = id
	var pos: Vector3
	for _attempt in 20:
		var angle: float = randf() * TAU
		var dist: float = randf_range(5.0, _spawn_radius)
		pos = _spawn_center + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		if not _is_in_exclusion_zone(pos):
			break
	zombie.position = pos
	zombie.position.y = 1.0
	_parent.add_child(zombie)
	_active_zombies[id] = zombie


func _on_entity_died(entity_id: String, _killer_id: String) -> void:
	if not _active_zombies.has(entity_id):
		return
	_active_zombies.erase(entity_id)
	get_tree().create_timer(_respawn_delay).timeout.connect(_spawn_zombie)
