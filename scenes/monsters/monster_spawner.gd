extends Node3D
## Spawns and respawns monsters in an area.

@export var monster_type: String = "slime"
@export var spawn_count: int = 3
@export var spawn_radius: float = 8.0

var _monster_scene := preload("res://scenes/monsters/monster_base.tscn")
var _spawn_counter: int = 0

func _ready() -> void:
	# Defer spawning to allow navmesh to bake
	await get_tree().create_timer(1.0).timeout
	_spawn_all()

func _spawn_all() -> void:
	for i in spawn_count:
		_spawn_one()

func _spawn_one() -> void:
	var monster := _monster_scene.instantiate()
	_spawn_counter += 1
	monster.monster_type = monster_type
	monster.monster_id = "%s_%s_%d" % [monster_type, name, _spawn_counter]

	var offset := Vector3(
		randf_range(-spawn_radius, spawn_radius),
		0,
		randf_range(-spawn_radius, spawn_radius)
	)
	monster.position = offset + Vector3(0, 1, 0)
	add_child(monster)
