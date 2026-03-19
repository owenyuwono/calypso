extends RefCounted
## Static zone definitions for all world zones and portal connections.

class_name ZoneDatabase

# Zone definitions: id -> metadata
const ZONES: Dictionary = {
	"city": {
		"name": "Prontera City",
		"scene_path": "res://scenes/zones/zone_city.tscn",
		"bounds": Rect2(-70, -50, 140, 100),  # world XZ (x, z, width, height)
		"spawn_point": Vector3(0, 1, 0),
		"color": Color(0.2, 0.35, 0.2, 0.2),
		"loading_art": "res://assets/textures/ui/loading/city.png",
	},
	"east_field": {
		"name": "East Field",
		"scene_path": "res://scenes/zones/zone_east_field.tscn",
		"bounds": Rect2(70, -40, 80, 80),
		"spawn_point": Vector3(75, 1, 0),
		"color": Color(0.35, 0.35, 0.15, 0.2),
		"loading_art": "res://assets/textures/ui/loading/east_field.png",
	},
	"west_field": {
		"name": "West Field",
		"scene_path": "res://scenes/zones/zone_west_field.tscn",
		"bounds": Rect2(-150, -40, 80, 80),
		"spawn_point": Vector3(-75, 1, 0),
		"color": Color(0.35, 0.35, 0.15, 0.2),
		"loading_art": "res://assets/textures/ui/loading/west_field.png",
	},
}

# Portal connections: source_zone_id -> array of portal defs
# Each portal def: {target_zone, source_rect (Rect2 for Area3D trigger), target_spawn (Vector3)}
# Portal positions are at city wall gates: east gate x≈70, west gate x≈-70
const PORTALS: Dictionary = {
	"city": [
		{"target": "east_field", "source_rect": Rect2(68, -5, 4, 10), "target_spawn": Vector3(72, 1, 0)},
		{"target": "west_field", "source_rect": Rect2(-72, -5, 4, 10), "target_spawn": Vector3(-72, 1, 0)},
	],
	"east_field": [
		{"target": "city", "source_rect": Rect2(68, -5, 4, 10), "target_spawn": Vector3(65, 1, 0)},
	],
	"west_field": [
		{"target": "city", "source_rect": Rect2(-72, -5, 4, 10), "target_spawn": Vector3(-65, 1, 0)},
	],
}

static func get_zone(zone_id: String) -> Dictionary:
	return ZONES.get(zone_id, {})

static func get_zone_name(zone_id: String) -> String:
	var zone: Dictionary = ZONES.get(zone_id, {})
	return zone.get("name", "Unknown")

static func get_portals(zone_id: String) -> Array:
	return PORTALS.get(zone_id, [])

static func get_zone_at_position(pos: Vector3) -> String:
	for zone_id in ZONES:
		var bounds: Rect2 = ZONES[zone_id]["bounds"]
		if bounds.has_point(Vector2(pos.x, pos.z)):
			return zone_id
	return ""
