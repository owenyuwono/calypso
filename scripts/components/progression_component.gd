extends BaseComponent
## Component that owns proficiency state and XP/level-up logic for an entity.

const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")
const MonsterDatabase = preload("res://scripts/data/monster_database.gd")

var _stats: Node  # StatsComponent ref
var _proficiencies: Dictionary = {}  # skill_id -> {level: int, xp: int}

func setup(stats_component: Node, initial_proficiencies: Dictionary = {}) -> void:
	_stats = stats_component
	if initial_proficiencies.is_empty():
		_proficiencies = ProficiencyDatabase.get_default_proficiencies()
	else:
		# Start with defaults, then override with initial values
		_proficiencies = ProficiencyDatabase.get_default_proficiencies()
		for skill_id in initial_proficiencies:
			if _proficiencies.has(skill_id):
				_proficiencies[skill_id]["level"] = initial_proficiencies[skill_id]
	_recalculate_stats()

func grant_combat_xp(monster_type: String, weapon_type: String) -> void:
	## Grant weapon proficiency XP based on monster type killed.
	var monster_stats: Dictionary = MonsterDatabase.get_monster(monster_type)
	var prof_xp: int = monster_stats.get("proficiency_xp", 3)
	grant_proficiency_xp(weapon_type, prof_xp)

func grant_proficiency_xp(skill_id: String, amount: int) -> void:
	if not _proficiencies.has(skill_id):
		return
	var prof: Dictionary = _proficiencies[skill_id]
	if prof["level"] >= ProficiencyDatabase.MAX_LEVEL:
		return
	prof["xp"] += amount
	var entity_id := _get_entity_id()

	# Check for level ups
	var xp_needed: int = ProficiencyDatabase.get_xp_to_next_level(prof["level"])
	while prof["xp"] >= xp_needed and prof["level"] < ProficiencyDatabase.MAX_LEVEL:
		prof["xp"] -= xp_needed
		prof["level"] += 1
		_recalculate_stats()
		if not entity_id.is_empty():
			GameEvents.proficiency_level_up.emit(entity_id, skill_id, prof["level"])
		xp_needed = ProficiencyDatabase.get_xp_to_next_level(prof["level"])

	_sync()
	if not entity_id.is_empty():
		GameEvents.proficiency_xp_gained.emit(entity_id, skill_id, amount, prof["xp"])

func get_proficiency_level(skill_id: String) -> int:
	if _proficiencies.has(skill_id):
		return _proficiencies[skill_id]["level"]
	return 1

func get_proficiency_xp(skill_id: String) -> Dictionary:
	if _proficiencies.has(skill_id):
		var prof: Dictionary = _proficiencies[skill_id]
		return {
			"xp": prof["xp"],
			"xp_to_next": ProficiencyDatabase.get_xp_to_next_level(prof["level"]),
			"level": prof["level"],
		}
	return {"xp": 0, "xp_to_next": 50, "level": 1}

func get_total_level() -> int:
	var total: int = 0
	for skill_id in _proficiencies:
		total += _proficiencies[skill_id]["level"]
	return total

func get_proficiencies() -> Dictionary:
	return _proficiencies

func _recalculate_stats() -> void:
	## Derive stats from proficiency levels. Call after any proficiency level change.
	if not _stats:
		return
	# Get the weapon proficiency level (from equipped weapon type)
	var weapon_level: int = _get_active_weapon_proficiency_level()
	var con_level: int = get_proficiency_level("constitution")

	# ATK = 5 + weapon_proficiency_level * 2
	_stats.atk = 5 + weapon_level * 2
	# DEF = 3 + constitution_level * 1
	_stats.def = 3 + con_level
	# Max HP = 40 + constitution_level * 10
	var new_max_hp: int = 40 + con_level * 10
	var hp_diff: int = new_max_hp - _stats.max_hp
	_stats.max_hp = new_max_hp
	if hp_diff > 0:
		_stats.hp = mini(_stats.hp + hp_diff, new_max_hp)
	elif _stats.hp > new_max_hp:
		_stats.hp = new_max_hp

	_stats.level = get_total_level()
	_stats._sync()

func _get_active_weapon_proficiency_level() -> int:
	## Get the proficiency level for the currently equipped weapon type.
	var parent := get_parent()
	if not parent:
		return 1
	var equipment = parent.get_node_or_null("EquipmentComponent")
	if equipment:
		var weapon_id: String = equipment.get_weapon()
		if not weapon_id.is_empty():
			var ItemDatabase = preload("res://scripts/data/item_database.gd")
			var item: Dictionary = ItemDatabase.get_item(weapon_id)
			var weapon_type: String = item.get("weapon_type", "sword")
			return get_proficiency_level(weapon_type)
	# Unarmed defaults to mace
	return get_proficiency_level("mace")

func _sync() -> void:
	var entity_id := _get_entity_id()
	if entity_id.is_empty():
		return
	WorldState.set_entity_data(entity_id, "proficiencies", _proficiencies)
	WorldState.set_entity_data(entity_id, "level", get_total_level())
