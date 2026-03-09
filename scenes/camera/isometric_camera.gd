extends Camera3D

@export var target_path: NodePath
var _offset: Vector3

func _ready() -> void:
	var target := get_node(target_path)
	_offset = global_position - target.global_position

func _process(_delta: float) -> void:
	var target := get_node(target_path)
	global_position = target.global_position + _offset
