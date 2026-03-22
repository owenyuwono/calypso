extends Node
## Global entity registry and alive checks.

# Entity registry: id -> Node3D reference
var entities: Dictionary = {}

func _ready() -> void:
	# Set project-wide default font (done in code so it loads after import system)
	var theme := Theme.new()
	theme.default_font = UIHelper.GAME_FONT
	ThemeDB.get_project_theme().default_font = UIHelper.GAME_FONT
# Reverse lookup: Node3D -> entity id
var _node_to_id: Dictionary = {}
# Location markers: id -> Vector3 position
var location_markers: Dictionary = {}
# Entity metadata: id -> Dictionary with type, stats, inventory, etc.
var entity_data: Dictionary = {}
# Cached tree entity ids for fast perception lookups (avoids O(N) scan of all entities)
var tree_entities: Dictionary = {}

# --- Entity Registry ---

func register_entity(id: String, node: Node3D, data: Dictionary = {}) -> void:
	entities[id] = node
	_node_to_id[node] = id
	entity_data[id] = data
	if data.get("type", "") == "tree":
		tree_entities[id] = node

func unregister_entity(id: String) -> void:
	var node = entities.get(id)
	if node:
		_node_to_id.erase(node)
	entities.erase(id)
	entity_data.erase(id)
	tree_entities.erase(id)

func get_entity(id: String) -> Node3D:
	return entities.get(id)

func get_entity_data(id: String) -> Dictionary:
	return entity_data.get(id, {})

func get_entity_id_for_node(node: Node3D) -> String:
	return _node_to_id.get(node, "")

func set_entity_data(id: String, key: String, value: Variant) -> void:
	if entity_data.has(id):
		entity_data[id][key] = value

# --- Location Markers ---

func register_location(id: String, pos: Vector3) -> void:
	location_markers[id] = pos

func get_location(id: String) -> Vector3:
	return location_markers.get(id, Vector3.ZERO)

func has_location(id: String) -> bool:
	return location_markers.has(id)

# --- Alive Check (convenience) ---

func is_alive(entity_id: String) -> bool:
	var entity := get_entity(entity_id)
	if entity and is_instance_valid(entity):
		var stats = entity.get_node_or_null("StatsComponent")
		if stats:
			return stats.is_alive()
	return false
