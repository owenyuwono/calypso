extends RefCounted
## Static interior scene definitions mapped by building type.

class_name InteriorDatabase

const INTERIORS: Dictionary = {
	"inn": {
		"scene_path": "res://scenes/interiors/interior_inn.tscn",
		"name": "Inn",
		"spawn_offset": Vector3(0, 0, 3),
		"interior_size": Vector3(8, 3, 6),
		"loading_art": "res://assets/textures/ui/loading/interior_inn.png",
	},
}

static func get_interior(building_type: String) -> Dictionary:
	return INTERIORS.get(building_type, {})

static func has_interior(building_type: String) -> bool:
	return INTERIORS.has(building_type)

static func get_all_types() -> Array:
	return INTERIORS.keys()
