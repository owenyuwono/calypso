extends StaticBody3D
## A world item that can be picked up by NPCs.

@export var object_id: String = ""
@export var object_name: String = ""

@onready var visual_mesh: CSGBox3D = $Visual

func _ready() -> void:
	WorldState.register_entity(object_id, self, {
		"type": "item",
		"name": object_name,
	})

func highlight() -> void:
	if visual_mesh and visual_mesh.material:
		visual_mesh.material.emission_enabled = true
		visual_mesh.material.emission = Color(1.0, 1.0, 0.8)
		visual_mesh.material.emission_energy_multiplier = 0.3

func unhighlight() -> void:
	if visual_mesh and visual_mesh.material:
		visual_mesh.material.emission_enabled = false
