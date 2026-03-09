extends Node
## Global entity registry, spatial queries, inventory, and perception system.

# Entity registry: id -> Node3D reference
var entities: Dictionary = {}
# Location markers: id -> Vector3 position
var location_markers: Dictionary = {}
# Entity metadata: id -> Dictionary with type, inventory, etc.
var entity_data: Dictionary = {}

# --- Entity Registry ---

func register_entity(id: String, node: Node3D, data: Dictionary = {}) -> void:
	entities[id] = node
	entity_data[id] = data

func unregister_entity(id: String) -> void:
	entities.erase(id)
	entity_data.erase(id)

func get_entity(id: String) -> Node3D:
	return entities.get(id)

func get_entity_data(id: String) -> Dictionary:
	return entity_data.get(id, {})

func get_entity_id_for_node(node: Node3D) -> String:
	for id in entities:
		if entities[id] == node:
			return id
	return ""

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

func get_all_locations() -> Dictionary:
	return location_markers

# --- Spatial Queries ---

func get_nearby_entities(pos: Vector3, radius: float) -> Array:
	var result: Array = []
	for id in entities:
		var node: Node3D = entities[id]
		if node and is_instance_valid(node):
			if node.global_position.distance_to(pos) <= radius:
				result.append({"id": id, "node": node, "distance": node.global_position.distance_to(pos)})
	result.sort_custom(func(a, b): return a.distance < b.distance)
	return result

func get_npc_perception(npc_id: String, radius: float = 15.0) -> Dictionary:
	var npc_node: Node3D = get_entity(npc_id)
	if not npc_node:
		return {}
	var nearby := get_nearby_entities(npc_node.global_position, radius)
	var npcs: Array = []
	var items: Array = []
	var objects: Array = []
	var locations: Array = []
	for entry in nearby:
		if entry.id == npc_id:
			continue
		var data := get_entity_data(entry.id)
		var entity_type: String = data.get("type", "unknown")
		match entity_type:
			"npc":
				npcs.append({"id": entry.id, "distance": snapped(entry.distance, 0.1), "state": data.get("state", "idle")})
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
		"items": items,
		"objects": objects,
		"locations": locations,
	}

# --- Inventory ---

func get_inventory(entity_id: String) -> Array:
	var data := get_entity_data(entity_id)
	return data.get("inventory", [])

func add_to_inventory(entity_id: String, item_id: String) -> void:
	if not entity_data.has(entity_id):
		return
	if not entity_data[entity_id].has("inventory"):
		entity_data[entity_id]["inventory"] = []
	entity_data[entity_id]["inventory"].append(item_id)

func remove_from_inventory(entity_id: String, item_id: String) -> bool:
	if not entity_data.has(entity_id):
		return false
	var inv: Array = entity_data[entity_id].get("inventory", [])
	var idx := inv.find(item_id)
	if idx >= 0:
		inv.remove_at(idx)
		return true
	return false
