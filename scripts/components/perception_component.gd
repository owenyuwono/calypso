class_name PerceptionComponent
extends BaseComponent
## Per-entity Area3D-based perception. Replaces WorldState.get_npc_perception()
## with a local spatial cache built from physics overlap signals.

const AREA_RADIUS: float = 25.0
const DETECTABLE_LAYER: int = 8  # bit index — layer 9 in the editor

var _area: Area3D
var _tracked: Dictionary = {}  # entity_id (String) -> Node3D


func setup() -> void:
	_area = Area3D.new()
	_area.name = "PerceptionArea"
	_area.collision_layer = 0
	_area.collision_mask = (1 << DETECTABLE_LAYER)
	_area.monitoring = true
	_area.monitorable = false

	var shape := SphereShape3D.new()
	shape.radius = AREA_RADIUS
	var col := CollisionShape3D.new()
	col.shape = shape
	_area.add_child(col)

	# Add to the entity (Node3D parent), not this component (Node),
	# so the Area3D inherits the entity's spatial transform.
	get_parent().add_child(_area)

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_area.area_entered.connect(_on_area_entered)
	_area.area_exited.connect(_on_area_exited)


# --- Signal handlers ---

func _resolve_entity_id(node: Node) -> String:
	var check: Node = node
	while check and check is Node3D:
		var eid: String = WorldState.get_entity_id_for_node(check)
		if eid != "":
			return eid
		check = check.get_parent()
	return ""


func _on_body_entered(node: Node3D) -> void:
	var eid: String = _resolve_entity_id(node)
	if eid == "":
		return
	var own_id: String = _get_entity_id()
	if eid == own_id:
		return
	_tracked[eid] = node


func _on_body_exited(node: Node3D) -> void:
	# Iterate by value — node may be freed before ID can be re-resolved
	for eid in _tracked.keys():
		if _tracked[eid] == node:
			_tracked.erase(eid)
			return


func _on_area_entered(area: Area3D) -> void:
	_on_body_entered(area)


func _on_area_exited(area: Area3D) -> void:
	_on_body_exited(area)


# --- Queries ---

## Returns tracked entities within `radius`, sorted by distance ascending.
## Each entry: {id: String, node: Node3D, distance: float}
func get_nearby(radius: float = AREA_RADIUS) -> Array:
	var parent_node: Node3D = get_parent()
	if not parent_node:
		return []
	var own_pos: Vector3 = parent_node.global_position
	var result: Array = []
	var stale: Array = []
	for eid in _tracked:
		var node: Node3D = _tracked[eid]
		if not is_instance_valid(node) or WorldState.get_entity_data(eid).is_empty():
			stale.append(eid)
			continue
		var dist: float = own_pos.distance_to(node.global_position)
		if dist <= radius:
			result.append({"id": eid, "node": node, "distance": dist})
	for eid in stale:
		_tracked.erase(eid)
	result.sort_custom(func(a, b): return a.distance < b.distance)
	return result


## Produces the exact same dict shape as WorldState.get_npc_perception().
## Categorizes tracked entities into npcs, monsters, items, objects, vendors.
func get_perception(radius: float = 15.0) -> Dictionary:
	var parent_node: Node3D = get_parent()
	if not parent_node:
		return {}

	var own_pos: Vector3 = parent_node.global_position
	var own_id: String = WorldState.get_entity_id_for_node(parent_node)

	var npcs: Array = []
	var monsters: Array = []
	var items: Array = []
	var objects: Array = []
	var trees: Array = []
	var locations: Array = []
	var vendors: Array = []

	var stale: Array = []
	for eid in _tracked:
		if eid == own_id:
			continue
		var node: Node3D = _tracked[eid]
		if not is_instance_valid(node):
			stale.append(eid)
			continue
		var data: Dictionary = WorldState.get_entity_data(eid)
		if data.is_empty():
			stale.append(eid)
			continue
		var dist: float = own_pos.distance_to(node.global_position)
		if dist > radius:
			continue
		var entity_type: String = data.get("type", "unknown")
		match entity_type:
			"npc", "player":
				if data.get("vending", false):
					vendors.append({
						"id": eid,
						"distance": snapped(dist, 0.1),
						"name": data.get("name", eid),
						"shop_title": data.get("shop_title", ""),
					})
				else:
					var info: Dictionary = {
						"id": eid,
						"distance": snapped(dist, 0.1),
						"state": data.get("state", "idle"),
						"name": data.get("name", eid),
						"level": data.get("level", 1),
						"hp": data.get("hp", 0),
						"max_hp": data.get("max_hp", 0),
					}
					npcs.append(info)
			"monster":
				var info: Dictionary = {
					"id": eid,
					"distance": snapped(dist, 0.1),
					"name": data.get("name", eid),
					"hp": data.get("hp", 0),
					"max_hp": data.get("max_hp", 0),
					"level": data.get("level", 1),
				}
				monsters.append(info)
			"loot_drop", "item":
				items.append({
					"id": eid,
					"distance": snapped(dist, 0.1),
					"name": data.get("name", eid),
				})
			"object":
				objects.append({
					"id": eid,
					"distance": snapped(dist, 0.1),
					"name": data.get("name", eid),
				})
	for eid in stale:
		_tracked.erase(eid)

	npcs.sort_custom(func(a, b): return a.distance < b.distance)
	monsters.sort_custom(func(a, b): return a.distance < b.distance)
	items.sort_custom(func(a, b): return a.distance < b.distance)
	objects.sort_custom(func(a, b): return a.distance < b.distance)
	vendors.sort_custom(func(a, b): return a.distance < b.distance)

	# Trees are not tracked via Area3D — scan WorldState by position
	for tree_id in WorldState.entities:
		var tree_data: Dictionary = WorldState.entity_data.get(tree_id, {})
		if tree_data.get("type", "") != "tree":
			continue
		var tree_node: Node3D = WorldState.entities[tree_id]
		if not is_instance_valid(tree_node):
			continue
		var tree_dist: float = own_pos.distance_to(tree_node.global_position)
		if tree_dist <= radius:
			trees.append({
				"id": tree_id,
				"distance": snapped(tree_dist, 0.1),
				"name": tree_data.get("name", tree_id),
				"tree_tier": tree_data.get("tree_tier", ""),
				"harvestable": tree_data.get("harvestable", false),
			})
	trees.sort_custom(func(a, b): return a.distance < b.distance)

	# Location markers are not tracked via Area3D — scan directly from WorldState
	for loc_id in WorldState.location_markers:
		var dist: float = own_pos.distance_to(WorldState.location_markers[loc_id])
		if dist <= radius:
			locations.append({"id": loc_id, "distance": snapped(dist, 0.1)})
	locations.sort_custom(func(a, b): return a.distance < b.distance)

	return {
		"npcs": npcs,
		"monsters": monsters,
		"items": items,
		"objects": objects,
		"trees": trees,
		"locations": locations,
		"vendors": vendors,
	}


func is_tracking(entity_id: String) -> bool:
	return _tracked.has(entity_id)


func get_distance_to(entity_id: String) -> float:
	if not _tracked.has(entity_id):
		return INF
	var node: Node3D = _tracked[entity_id]
	if not is_instance_valid(node):
		return INF
	var parent_node: Node3D = get_parent()
	if not parent_node:
		return INF
	return parent_node.global_position.distance_to(node.global_position)
