extends BaseComponent
## Component that owns skill state for an entity.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")

var _skills: Dictionary = {}  # skill_id -> level (int)
var _skill_xp: Dictionary = {}  # skill_id -> current xp (int)
var _hotbar: Array = ["", "", "", "", ""]

func setup(skills: Dictionary, hotbar: Array) -> void:
	# Initialize all skills at minimum level 1
	for skill_id in SkillDatabase.SKILLS:
		_skills[skill_id] = maxi(1, skills.get(skill_id, 1))
	_hotbar = hotbar.duplicate()
	for skill_id in SkillDatabase.SKILLS:
		_skill_xp[skill_id] = 0
	_sync()

func get_skill_level(skill_id: String) -> int:
	if not SkillDatabase.SKILLS.has(skill_id):
		return 0
	return maxi(1, _skills.get(skill_id, 1))

func has_skill(skill_id: String) -> bool:
	return SkillDatabase.SKILLS.has(skill_id)

func grant_skill_xp(skill_id: String, amount: int) -> void:
	## Grant XP to an active skill. Levels up using same curve as proficiencies.
	var skill: Dictionary = SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		return
	var current_level: int = _skills.get(skill_id, 1)
	var max_level: int = skill.get("max_level", 5)
	if current_level >= max_level:
		return

	var xp: int = _skill_xp.get(skill_id, 0) + amount
	var xp_needed: int = current_level * 50  # Same curve as proficiencies

	var parent := get_parent()
	var entity_id: String = parent.entity_id if parent and "entity_id" in parent else ""

	while xp >= xp_needed and current_level < max_level:
		xp -= xp_needed
		current_level += 1
		_skills[skill_id] = current_level
		if not entity_id.is_empty():
			GameEvents.skill_learned.emit(entity_id, skill_id, current_level)
		xp_needed = current_level * 50

	_skill_xp[skill_id] = xp
	_sync()

func get_skill_xp(skill_id: String) -> int:
	return _skill_xp.get(skill_id, 0)

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
	WorldState.set_entity_data(eid, "skill_xp", _skill_xp)
