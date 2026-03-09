extends StaticBody3D
## Base class for interactable world objects.

@export var object_id: String = ""
@export var object_name: String = ""
@export var object_type: String = "object"

var _highlight_mesh: Node = null

func _ready() -> void:
	_register()
	_find_highlight_mesh()

func _register() -> void:
	WorldState.register_entity(object_id, self, {
		"type": object_type,
		"name": object_name,
	})

func _find_highlight_mesh() -> void:
	for child in get_children():
		if child is CSGShape3D and child.material:
			_highlight_mesh = child
			break

func highlight() -> void:
	if _highlight_mesh and _highlight_mesh.material:
		_highlight_mesh.material.emission_enabled = true
		_highlight_mesh.material.emission = Color(1.0, 1.0, 0.8)
		_highlight_mesh.material.emission_energy_multiplier = 0.3

func unhighlight() -> void:
	if _highlight_mesh and _highlight_mesh.material:
		_highlight_mesh.material.emission_enabled = false
