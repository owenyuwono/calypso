extends Node
## Component that owns skill state for an entity.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")

var _skills: Dictionary = {}
var _hotbar: Array = ["", "", "", "", ""]
var _skill_points: int = 0

func setup(skills: Dictionary, hotbar: Array, skill_points: int) -> void:
	_skills = skills.duplicate()
	_hotbar = hotbar.duplicate()
	_skill_points = skill_points

func learn_skill(skill_id: String) -> bool:
	if _skill_points <= 0:
		return false
	var skill := SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		return false
	# Check required level
	var parent := get_parent()
	if parent:
		var stats = parent.get_node_or_null("StatsComponent")
		if stats and stats.level < skill.get("required_level", 1):
			return false
	var current_level: int = _skills.get(skill_id, 0)
	if current_level >= skill.get("max_level", 5):
		return false
	_skills[skill_id] = current_level + 1
	_skill_points -= 1
	_sync()
	if parent and "entity_id" in parent:
		GameEvents.skill_learned.emit(parent.entity_id, skill_id, current_level + 1)
	return true

func get_skill_level(skill_id: String) -> int:
	return _skills.get(skill_id, 0)

func get_skill_points() -> int:
	return _skill_points

func add_skill_points(amount: int) -> void:
	_skill_points += amount
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
	WorldState.set_entity_data(eid, "skill_points", _skill_points)
