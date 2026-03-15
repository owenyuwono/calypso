extends RefCounted
## Static skill definitions.

const SKILLS: Dictionary = {
	"bash": {
		"name": "Bash",
		"description": "A powerful melee strike.",
		"type": "melee_attack",
		"max_level": 5,
		"required_proficiency": {"skill": "sword", "level": 2},
		"cooldown": 3.0,
		"damage_multiplier": 1.5,
		"damage_multiplier_per_level": 0.1,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.9, 0.4, 0.2),
	},
}

static func get_skill(skill_id: String) -> Dictionary:
	return SKILLS.get(skill_id, {})

static func get_effective_multiplier(skill_id: String, skill_level: int) -> float:
	var skill := get_skill(skill_id)
	var base: float = skill.get("damage_multiplier", 1.0)
	var per_level: float = skill.get("damage_multiplier_per_level", 0.0)
	return base + (skill_level - 1) * per_level

static func get_effective_cooldown(skill_id: String, skill_level: int) -> float:
	var skill := get_skill(skill_id)
	var base: float = skill.get("cooldown", 1.0)
	var per_level: float = skill.get("cooldown_reduction_per_level", 0.0)
	return maxf(0.5, base - (skill_level - 1) * per_level)
