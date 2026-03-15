extends Node
## Global entity registry, spatial queries, and alive checks.

# Entity registry: id -> Node3D reference
var entities: Dictionary = {}
# Reverse lookup: Node3D -> entity id
var _node_to_id: Dictionary = {}
# Location markers: id -> Vector3 position
var location_markers: Dictionary = {}
# Entity metadata: id -> Dictionary with type, stats, inventory, etc.
var entity_data: Dictionary = {}

# --- Entity Registry ---

func register_entity(id: String, node: Node3D, data: Dictionary = {}) -> void:
	entities[id] = node
	_node_to_id[node] = id
	entity_data[id] = data

func unregister_entity(id: String) -> void:
	var node = entities.get(id)
	if node:
		_node_to_id.erase(node)
	entities.erase(id)
	entity_data.erase(id)

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

# --- Spatial Queries ---

func get_nearby_entities(pos: Vector3, radius: float) -> Array:
	var result: Array = []
	var radius_sq := radius * radius
	for id in entities:
		var node: Node3D = entities[id]
		if node and is_instance_valid(node):
			var dist_sq := node.global_position.distance_squared_to(pos)
			if dist_sq <= radius_sq:
				result.append({"id": id, "node": node, "distance": sqrt(dist_sq)})
	result.sort_custom(func(a, b): return a.distance < b.distance)
	return result

func get_npc_perception(npc_id: String, radius: float = 15.0) -> Dictionary:
	var npc_node: Node3D = get_entity(npc_id)
	if not npc_node:
		return {}
	var nearby := get_nearby_entities(npc_node.global_position, radius)
	var npcs: Array = []
	var monsters: Array = []
	var items: Array = []
	var objects: Array = []
	var locations: Array = []
	var vendors: Array = []
	for entry in nearby:
		if entry.id == npc_id:
			continue
		var data := get_entity_data(entry.id)
		var entity_type: String = data.get("type", "unknown")
		match entity_type:
			"npc", "player":
				if data.get("vending", false):
					vendors.append({"id": entry.id, "distance": snapped(entry.distance, 0.1), "name": data.get("name", entry.id), "shop_title": data.get("shop_title", "")})
				else:
					var info := {"id": entry.id, "distance": snapped(entry.distance, 0.1), "state": data.get("state", "idle")}
					info["name"] = data.get("name", entry.id)
					info["level"] = data.get("level", 1)
					info["hp"] = data.get("hp", 0)
					info["max_hp"] = data.get("max_hp", 0)
					npcs.append(info)
			"monster":
				var info := {"id": entry.id, "distance": snapped(entry.distance, 0.1)}
				info["name"] = data.get("name", entry.id)
				info["hp"] = data.get("hp", 0)
				info["max_hp"] = data.get("max_hp", 0)
				info["level"] = data.get("level", 1)
				monsters.append(info)
			"item":
				items.append({"id": entry.id, "distance": snapped(entry.distance, 0.1), "name": data.get("name", entry.id)})
			"object":
				objects.append({"id": entry.id, "distance": snapped(entry.distance, 0.1), "name": data.get("name", entry.id)})
	for loc_id in location_markers:
		var dist := npc_node.global_position.distance_to(location_markers[loc_id])
		if dist <= radius:
			locations.append({"id": loc_id, "distance": snapped(dist, 0.1)})
	return {
		"npcs": npcs,
		"monsters": monsters,
		"items": items,
		"objects": objects,
		"locations": locations,
		"vendors": vendors,
	}

# --- Alive Check (convenience) ---

func is_alive(entity_id: String) -> bool:
	var entity := get_entity(entity_id)
	if entity and is_instance_valid(entity):
		var stats = entity.get_node_or_null("StatsComponent")
		if stats:
			return stats.is_alive()
	return false
