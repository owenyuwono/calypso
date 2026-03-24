extends Node
## Thin AI adapter for NPC skill use. Handles skill selection and global
## cooldown gating only. All execution (hit resolution, bleeds, XP, cooldowns)
## delegates to SkillsComponent.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")

const GLOBAL_COOLDOWN: float = 4.0
const MAGIC_PROFICIENCIES: Array = ["fire", "ice", "lightning", "earth", "light", "dark", "arcane"]

var _entity: Node = null
var _combat: Node = null
var _skills_comp: Node = null
var _perception: Node = null


func setup(entity: Node, combat: Node, skills_comp: Node, perception: Node) -> void:
	_entity = entity
	_combat = combat
	_skills_comp = skills_comp
	_perception = perception


func try_use_skill(target_id: String) -> bool:
	if not _skills_comp or _skills_comp.is_skill_pending():
		return false
	if _skills_comp.is_global_cooldown_active():
		return false

	var skill_id: String = _pick_best_skill(target_id)
	if skill_id.is_empty():
		return false

	var success: bool = _skills_comp.begin_skill_use(skill_id, target_id)
	if success:
		_skills_comp.set_global_cooldown(GLOBAL_COOLDOWN)
		var skill_data: Dictionary = SkillDatabase.get_skill(skill_id)
		var entity_id: String = WorldState.get_entity_id_for_node(_entity)
		GameEvents.npc_spoke.emit(entity_id, "%s!" % skill_data.get("name", skill_id), target_id)
	return success


func is_skill_active() -> bool:
	return _skills_comp.is_skill_pending() if _skills_comp else false


# --- AI skill selection ---

func _pick_best_skill(target_id: String) -> String:
	# Determine equipped weapon type for matching skills to proficiency
	var weapon_type: String = _combat.get_equipped_weapon_type()

	# Count alive enemies nearby to decide if AoE is preferred
	var nearby: Array = _perception.get_nearby(8.0)
	var nearby_enemy_count: int = 0
	for entry in nearby:
		var eid: String = entry.get("id", "")
		if eid.begins_with("monster_") and WorldState.is_alive(eid):
			nearby_enemy_count += 1

	var best_aoe_id: String = ""
	var best_aoe_multiplier: float = -1.0
	var best_single_id: String = ""
	var best_single_multiplier: float = -1.0

	for skill_id in SkillDatabase.SKILLS:
		var skill_data: Dictionary = SkillDatabase.SKILLS[skill_id]

		# Must be unlocked and have skill level > 0
		if not _skills_comp.has_skill(skill_id):
			continue

		var skill_level: int = _skills_comp.get_skill_level(skill_id)
		if skill_level <= 0:
			continue

		# Must not be on cooldown
		if _skills_comp.is_on_cooldown(skill_id):
			continue

		# Must require the NPC's current weapon proficiency
		if not skill_data.has("synergy"):
			continue
		if skill_data.synergy.primary.get("skill", "") != weapon_type:
			continue

		var skill_type: String = skill_data.get("type", "")
		var multiplier: float = SkillDatabase.get_effective_multiplier(skill_id, skill_level)

		if skill_type == "aoe_melee":
			if multiplier > best_aoe_multiplier:
				best_aoe_multiplier = multiplier
				best_aoe_id = skill_id
		else:
			if multiplier > best_single_multiplier:
				best_single_multiplier = multiplier
				best_single_id = skill_id

	# Second pass: magic proficiency skills (fire/ice/lightning/earth/light/dark/arcane)
	# These have synergy.primary.skill set to an element proficiency, not a weapon type
	var progression: Node = _entity.get_node_or_null("ProgressionComponent")
	if progression:
		for skill_id in SkillDatabase.SKILLS:
			var skill_data: Dictionary = SkillDatabase.SKILLS[skill_id]

			if not _skills_comp.has_skill(skill_id):
				continue

			var skill_level: int = _skills_comp.get_skill_level(skill_id)
			if skill_level <= 0:
				continue

			if _skills_comp.is_on_cooldown(skill_id):
				continue

			if not skill_data.has("synergy"):
				continue

			var primary_skill: String = skill_data.synergy.primary.get("skill", "")
			if primary_skill not in MAGIC_PROFICIENCIES:
				continue

			var required_level: int = skill_data.synergy.primary.get("level", 1)
			if progression.get_proficiency_level(primary_skill) < required_level:
				continue

			var skill_type: String = skill_data.get("type", "")
			var multiplier: float = SkillDatabase.get_effective_multiplier(skill_id, skill_level)

			if skill_type == "aoe_melee":
				if multiplier > best_aoe_multiplier:
					best_aoe_multiplier = multiplier
					best_aoe_id = skill_id
			else:
				if multiplier > best_single_multiplier:
					best_single_multiplier = multiplier
					best_single_id = skill_id

	# Prefer AoE when multiple enemies are nearby
	if nearby_enemy_count >= 2 and not best_aoe_id.is_empty():
		return best_aoe_id

	if not best_single_id.is_empty():
		return best_single_id

	# Fall back to AoE even with a single target if it's the only option
	return best_aoe_id
