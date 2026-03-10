extends Node
## Global entity registry, spatial queries, combat stats, inventory, and progression.

const LevelData = preload("res://scripts/data/level_data.gd")
const ItemDatabase = preload("res://scripts/data/item_database.gd")
const SkillDatabase = preload("res://scripts/data/skill_database.gd")

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

func get_all_locations() -> Dictionary:
	return location_markers

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
	var shop_npcs: Array = []
	for entry in nearby:
		if entry.id == npc_id:
			continue
		var data := get_entity_data(entry.id)
		var entity_type: String = data.get("type", "unknown")
		match entity_type:
			"npc", "player":
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
			"shop_npc":
				shop_npcs.append({"id": entry.id, "distance": snapped(entry.distance, 0.1), "name": data.get("name", entry.id), "shop_type": data.get("shop_type", "")})
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
		"shop_npcs": shop_npcs,
	}

# --- Count-Based Inventory ---
# Inventory is now Dictionary: {item_type_id: count}

func get_inventory(entity_id: String) -> Dictionary:
	var data := get_entity_data(entity_id)
	return data.get("inventory", {})

func add_to_inventory(entity_id: String, item_id: String, count: int = 1) -> void:
	if not entity_data.has(entity_id):
		return
	if not entity_data[entity_id].has("inventory"):
		entity_data[entity_id]["inventory"] = {}
	var inv: Dictionary = entity_data[entity_id]["inventory"]
	inv[item_id] = inv.get(item_id, 0) + count

func remove_from_inventory(entity_id: String, item_id: String, count: int = 1) -> bool:
	if not entity_data.has(entity_id):
		return false
	var inv: Dictionary = entity_data[entity_id].get("inventory", {})
	var current: int = inv.get(item_id, 0)
	if current < count:
		return false
	current -= count
	if current <= 0:
		inv.erase(item_id)
	else:
		inv[item_id] = current
	return true

func has_item(entity_id: String, item_id: String, count: int = 1) -> bool:
	var inv := get_inventory(entity_id)
	return inv.get(item_id, 0) >= count

func get_item_count(entity_id: String, item_id: String) -> int:
	var inv := get_inventory(entity_id)
	return inv.get(item_id, 0)

# --- Combat Stats ---

func get_stat(entity_id: String, stat: String, default: int = 0) -> int:
	var data := get_entity_data(entity_id)
	return data.get(stat, default)

func get_effective_atk(entity_id: String) -> int:
	var data := get_entity_data(entity_id)
	var base_atk: int = data.get("atk", 0)
	var equipment: Dictionary = data.get("equipment", {})
	var weapon_id: String = equipment.get("weapon", "")
	if not weapon_id.is_empty():
		var item := ItemDatabase.get_item(weapon_id)
		base_atk += item.get("atk_bonus", 0)
	return base_atk

func get_effective_def(entity_id: String) -> int:
	var data := get_entity_data(entity_id)
	var base_def: int = data.get("def", 0)
	var equipment: Dictionary = data.get("equipment", {})
	var armor_id: String = equipment.get("armor", "")
	if not armor_id.is_empty():
		var item := ItemDatabase.get_item(armor_id)
		base_def += item.get("def_bonus", 0)
	return base_def

func deal_damage(attacker_id: String, target_id: String) -> int:
	var atk := get_effective_atk(attacker_id)
	var def := get_effective_def(target_id)
	var damage := maxi(1, atk - def)
	var target_data := get_entity_data(target_id)
	var hp: int = target_data.get("hp", 0)
	hp = maxi(0, hp - damage)
	set_entity_data(target_id, "hp", hp)
	GameEvents.entity_damaged.emit(target_id, attacker_id, damage, hp)
	if hp <= 0:
		GameEvents.entity_died.emit(target_id, attacker_id)
	return damage

func deal_damage_amount(attacker_id: String, target_id: String, amount: int) -> int:
	var def := get_effective_def(target_id)
	var damage := maxi(1, amount - def)
	var target_data := get_entity_data(target_id)
	var hp: int = target_data.get("hp", 0)
	hp = maxi(0, hp - damage)
	set_entity_data(target_id, "hp", hp)
	GameEvents.entity_damaged.emit(target_id, attacker_id, damage, hp)
	if hp <= 0:
		GameEvents.entity_died.emit(target_id, attacker_id)
	return damage

func heal_entity(entity_id: String, amount: int) -> int:
	var data := get_entity_data(entity_id)
	var hp: int = data.get("hp", 0)
	var max_hp: int = data.get("max_hp", 1)
	var healed := mini(amount, max_hp - hp)
	var new_hp := hp + healed
	set_entity_data(entity_id, "hp", new_hp)
	if healed > 0:
		GameEvents.entity_healed.emit(entity_id, healed, new_hp)
	return healed

# --- Gold ---

func get_gold(entity_id: String) -> int:
	return get_entity_data(entity_id).get("gold", 0)

func add_gold(entity_id: String, amount: int) -> void:
	var current := get_gold(entity_id)
	set_entity_data(entity_id, "gold", current + amount)

func remove_gold(entity_id: String, amount: int) -> bool:
	var current := get_gold(entity_id)
	if current < amount:
		return false
	set_entity_data(entity_id, "gold", current - amount)
	return true

# --- Equipment ---

func equip_item(entity_id: String, item_id: String) -> bool:
	var item := ItemDatabase.get_item(item_id)
	if item.is_empty():
		return false
	if not has_item(entity_id, item_id):
		return false

	var slot: String = ""
	match item.get("type", ""):
		"weapon": slot = "weapon"
		"armor": slot = "armor"
		_: return false

	var data := get_entity_data(entity_id)
	if not data.has("equipment"):
		data["equipment"] = {"weapon": "", "armor": ""}

	# Unequip current item in that slot
	var current: String = data["equipment"].get(slot, "")
	if not current.is_empty():
		add_to_inventory(entity_id, current)

	# Equip new item
	remove_from_inventory(entity_id, item_id)
	data["equipment"][slot] = item_id
	return true

func unequip_item(entity_id: String, slot: String) -> bool:
	var data := get_entity_data(entity_id)
	var equipment: Dictionary = data.get("equipment", {})
	var item_id: String = equipment.get(slot, "")
	if item_id.is_empty():
		return false
	equipment[slot] = ""
	add_to_inventory(entity_id, item_id)
	return true

# --- Progression ---

func grant_xp(entity_id: String, amount: int) -> void:
	var data := get_entity_data(entity_id)
	var level: int = data.get("level", 1)
	if level >= LevelData.MAX_LEVEL:
		return
	var xp: int = data.get("xp", 0) + amount
	set_entity_data(entity_id, "xp", xp)
	GameEvents.xp_gained.emit(entity_id, amount)

	# Check for level up
	var xp_needed := LevelData.xp_to_next_level(level)
	while xp >= xp_needed and level < LevelData.MAX_LEVEL:
		xp -= xp_needed
		level += 1
		set_entity_data(entity_id, "xp", xp)
		set_entity_data(entity_id, "level", level)
		# Apply stat gains (re-read current values each iteration for multi-level)
		var cur_max_hp: int = get_stat(entity_id, "max_hp", 50) + LevelData.HP_PER_LEVEL
		set_entity_data(entity_id, "max_hp", cur_max_hp)
		set_entity_data(entity_id, "hp", cur_max_hp)  # Full heal on level up
		set_entity_data(entity_id, "atk", get_stat(entity_id, "atk", 10) + LevelData.ATK_PER_LEVEL)
		set_entity_data(entity_id, "def", get_stat(entity_id, "def", 5) + LevelData.DEF_PER_LEVEL)
		set_entity_data(entity_id, "skill_points", get_entity_data(entity_id).get("skill_points", 0) + LevelData.SKILL_POINTS_PER_LEVEL)
		GameEvents.level_up.emit(entity_id, level)
		xp_needed = LevelData.xp_to_next_level(level)

func is_alive(entity_id: String) -> bool:
	return get_entity_data(entity_id).get("hp", 0) > 0

# --- Skills ---

func learn_skill(entity_id: String, skill_id: String) -> bool:
	var data := get_entity_data(entity_id)
	var sp: int = data.get("skill_points", 0)
	if sp <= 0:
		return false
	var skill := SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		return false
	var player_level: int = data.get("level", 1)
	if player_level < skill.get("required_level", 1):
		return false
	var skills: Dictionary = data.get("skills", {})
	var current_level: int = skills.get(skill_id, 0)
	if current_level >= skill.get("max_level", 5):
		return false
	skills[skill_id] = current_level + 1
	set_entity_data(entity_id, "skills", skills)
	set_entity_data(entity_id, "skill_points", sp - 1)
	GameEvents.skill_learned.emit(entity_id, skill_id, current_level + 1)
	return true

func get_skill_level(entity_id: String, skill_id: String) -> int:
	var data := get_entity_data(entity_id)
	var skills: Dictionary = data.get("skills", {})
	return skills.get(skill_id, 0)

func get_skill_points(entity_id: String) -> int:
	return get_entity_data(entity_id).get("skill_points", 0)

func set_hotbar_slot(entity_id: String, slot: int, skill_id: String) -> void:
	var data := get_entity_data(entity_id)
	var hotbar: Array = data.get("hotbar", ["", "", "", "", ""])
	if slot < 0 or slot >= hotbar.size():
		return
	# Remove skill from other slots first
	for i in range(hotbar.size()):
		if hotbar[i] == skill_id:
			hotbar[i] = ""
	hotbar[slot] = skill_id
	set_entity_data(entity_id, "hotbar", hotbar)

func get_hotbar(entity_id: String) -> Array:
	return get_entity_data(entity_id).get("hotbar", ["", "", "", "", ""])
