extends StaticBody3D
## A world item that can be picked up by NPCs.

const ModelHelper = preload("res://scripts/utils/model_helper.gd")

@export var object_id: String = ""
@export var object_name: String = ""

@onready var visual_mesh: MeshInstance3D = $Visual
var _overlay: StandardMaterial3D

func _ready() -> void:
	WorldState.register_entity(object_id, self, {
		"type": "item",
		"name": object_name,
	})
	# Set base material color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.7, 0.2, 1)
	visual_mesh.set_surface_override_material(0, mat)
	# Create overlay for highlight effects (project convention)
	_overlay = ModelHelper.create_overlay_material()
	visual_mesh.material_overlay = _overlay

func highlight() -> void:
	ModelHelper.set_highlight(_overlay, true)

func unhighlight() -> void:
	ModelHelper.set_highlight(_overlay, false)
