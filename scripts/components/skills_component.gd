extends Node
## Component that owns skill state for an entity.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")

var _skills: Dictionary = {}  # skill_id -> level (int)
var _hotbar: Array = ["", "", "", "", ""]

func setup(skills: Dictionary, hotbar: Array) -> void:
	_skills = skills.duplicate()
	_hotbar = hotbar.duplicate()

func get_skill_level(skill_id: String) -> int:
	return _skills.get(skill_id, 0)

func has_skill(skill_id: String) -> bool:
	return _skills.get(skill_id, 0) > 0

func unlock_skill(skill_id: String) -> void:
	## Called when proficiency milestone is reached.
	if _skills.get(skill_id, 0) <= 0:
		_skills[skill_id] = 1
		_sync()
		var parent := get_parent()
		if parent and "entity_id" in parent:
			GameEvents.skill_learned.emit(parent.entity_id, skill_id, 1)

func grant_skill_xp(skill_id: String, amount: int) -> void:
	## Grant XP to an active skill. Levels up using same curve as proficiencies.
	var current_level: int = _skills.get(skill_id, 0)
	if current_level <= 0:
		return  # Not learned
	var skill := SkillDatabase.get_skill(skill_id)
	var max_level: int = skill.get("max_level", 5)
	if current_level >= max_level:
		return

	# Use entity_data to track skill XP
	var parent := get_parent()
	if not parent or not ("entity_id" in parent):
		return
	var entity_id: String = parent.entity_id
	var data := WorldState.get_entity_data(entity_id)
	var skill_xp_key: String = "skill_xp_%s" % skill_id
	var xp: int = data.get(skill_xp_key, 0) + amount
	var xp_needed: int = current_level * 50  # Same curve as proficiencies

	while xp >= xp_needed and current_level < max_level:
		xp -= xp_needed
		current_level += 1
		_skills[skill_id] = current_level
		GameEvents.skill_learned.emit(entity_id, skill_id, current_level)
		xp_needed = current_level * 50

	WorldState.set_entity_data(entity_id, skill_xp_key, xp)
	_sync()

func set_hotbar_slot(index: int, skill_id: String) -> void:
	if index < 0 or index >= _hotbar.size():
		return
	# Remove skill from other slots first
	for i in range(_hotbar.size()):
		if _hotbar[i] == skill_id:
			_hotbar[i] = ""
	_hotbar[index] = skill_id
	_sync()

func get_hotbar() -> Array:
	return _hotbar

func _sync() -> void:
	var parent := get_parent()
	if not parent or not ("entity_id" in parent):
		return
	var eid: String = parent.entity_id
	if eid.is_empty():
		return
	WorldState.set_entity_data(eid, "skills", _skills)
	WorldState.set_entity_data(eid, "hotbar", _hotbar)
