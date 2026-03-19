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
	"cleave": {
		"name": "Cleave",
		"description": "A wide slash that hits nearby enemies.",
		"type": "aoe_melee",
		"max_level": 5,
		"required_proficiency": {"skill": "sword", "level": 4},
		"cooldown": 5.0,
		"damage_multiplier": 1.0,
		"damage_multiplier_per_level": 0.08,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.9, 0.6, 0.2),
		"aoe_radius": 3.0,
		"aoe_center": "target",
	},
	"rend": {
		"name": "Rend",
		"description": "A vicious cut that causes bleeding.",
		"type": "bleed",
		"max_level": 5,
		"required_proficiency": {"skill": "sword", "level": 6},
		"cooldown": 6.0,
		"damage_multiplier": 0.6,
		"damage_multiplier_per_level": 0.06,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.8, 0.2, 0.2),
		"bleed_ticks": 3,
		"bleed_duration": 3.0,
		"bleed_multiplier_per_tick": 0.3,
	},
	"chop": {
		"name": "Chop",
		"description": "A heavy downward chop.",
		"type": "melee_attack",
		"max_level": 5,
		"required_proficiency": {"skill": "axe", "level": 2},
		"cooldown": 3.0,
		"damage_multiplier": 1.6,
		"damage_multiplier_per_level": 0.1,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.7, 0.5, 0.2),
	},
	"whirlwind": {
		"name": "Whirlwind",
		"description": "Spin attack hitting all nearby enemies.",
		"type": "aoe_melee",
		"max_level": 5,
		"required_proficiency": {"skill": "axe", "level": 4},
		"cooldown": 5.0,
		"damage_multiplier": 1.1,
		"damage_multiplier_per_level": 0.08,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.7, 0.7, 0.3),
		"aoe_radius": 3.5,
		"aoe_center": "self",
	},
	"execute": {
		"name": "Execute",
		"description": "A devastating blow that pierces armor.",
		"type": "armor_pierce",
		"max_level": 5,
		"required_proficiency": {"skill": "axe", "level": 6},
		"cooldown": 7.0,
		"damage_multiplier": 1.8,
		"damage_multiplier_per_level": 0.1,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.6, 0.1, 0.1),
		"def_ignore_percent": 0.75,
	},
	"crush": {
		"name": "Crush",
		"description": "A crushing blow.",
		"type": "melee_attack",
		"max_level": 5,
		"required_proficiency": {"skill": "mace", "level": 2},
		"cooldown": 3.0,
		"damage_multiplier": 1.5,
		"damage_multiplier_per_level": 0.1,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.5, 0.5, 0.7),
	},
	"shatter": {
		"name": "Shatter",
		"description": "Shatters the target's defenses.",
		"type": "armor_pierce",
		"max_level": 5,
		"required_proficiency": {"skill": "mace", "level": 4},
		"cooldown": 5.0,
		"damage_multiplier": 1.3,
		"damage_multiplier_per_level": 0.08,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.4, 0.4, 0.8),
		"def_ignore_percent": 0.5,
	},
	"quake": {
		"name": "Quake",
		"description": "Slams the ground, damaging all nearby.",
		"type": "aoe_melee",
		"max_level": 5,
		"required_proficiency": {"skill": "mace", "level": 6},
		"cooldown": 6.0,
		"damage_multiplier": 0.9,
		"damage_multiplier_per_level": 0.07,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.6, 0.4, 0.3),
		"aoe_radius": 4.0,
		"aoe_center": "self",
	},
	"stab": {
		"name": "Stab",
		"description": "A quick precise strike.",
		"type": "melee_attack",
		"max_level": 5,
		"required_proficiency": {"skill": "dagger", "level": 2},
		"cooldown": 2.0,
		"damage_multiplier": 1.3,
		"damage_multiplier_per_level": 0.1,
		"cooldown_reduction_per_level": 0.15,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.3, 0.7, 0.3),
	},
	"lacerate": {
		"name": "Lacerate",
		"description": "Slashes that cause deep bleeding.",
		"type": "bleed",
		"max_level": 5,
		"required_proficiency": {"skill": "dagger", "level": 4},
		"cooldown": 4.0,
		"damage_multiplier": 0.5,
		"damage_multiplier_per_level": 0.05,
		"cooldown_reduction_per_level": 0.15,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.7, 0.2, 0.3),
		"bleed_ticks": 4,
		"bleed_duration": 4.0,
		"bleed_multiplier_per_tick": 0.25,
	},
	"backstab": {
		"name": "Backstab",
		"description": "A lethal strike that bypasses all armor.",
		"type": "armor_pierce",
		"max_level": 5,
		"required_proficiency": {"skill": "dagger", "level": 6},
		"cooldown": 5.0,
		"damage_multiplier": 2.0,
		"damage_multiplier_per_level": 0.12,
		"cooldown_reduction_per_level": 0.15,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.2, 0.2, 0.2),
		"def_ignore_percent": 1.0,
	},
	"arcane_bolt": {
		"name": "Arcane Bolt",
		"description": "A burst of arcane energy.",
		"type": "melee_attack",
		"max_level": 5,
		"required_proficiency": {"skill": "staff", "level": 2},
		"cooldown": 2.5,
		"damage_multiplier": 1.4,
		"damage_multiplier_per_level": 0.1,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.5, 0.3, 0.9),
	},
	"flame_burst": {
		"name": "Flame Burst",
		"description": "An explosion of flame around the target.",
		"type": "aoe_melee",
		"max_level": 5,
		"required_proficiency": {"skill": "staff", "level": 4},
		"cooldown": 5.0,
		"damage_multiplier": 0.8,
		"damage_multiplier_per_level": 0.06,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.9, 0.3, 0.1),
		"aoe_radius": 3.5,
		"aoe_center": "target",
	},
	"drain": {
		"name": "Drain",
		"description": "Dark magic that saps life over time.",
		"type": "bleed",
		"max_level": 5,
		"required_proficiency": {"skill": "staff", "level": 6},
		"cooldown": 6.0,
		"damage_multiplier": 0.5,
		"damage_multiplier_per_level": 0.05,
		"cooldown_reduction_per_level": 0.2,
		"animation": "1H_Melee_Attack_Chop",
		"color": Color(0.4, 0.1, 0.5),
		"bleed_ticks": 3,
		"bleed_duration": 3.0,
		"bleed_multiplier_per_tick": 0.35,
	},
}

const SKILL_CATEGORIES: Dictionary = {
	"bash": "single_physical",
	"chop": "single_physical",
	"crush": "single_physical",
	"stab": "single_physical",
	"execute": "single_physical",
	"shatter": "single_physical",
	"backstab": "single_physical",
	"arcane_bolt": "single_magic",
	"cleave": "aoe_physical",
	"whirlwind": "aoe_physical",
	"quake": "aoe_physical",
	"flame_burst": "aoe_magic",
	"rend": "dot_physical",
	"lacerate": "dot_physical",
	"drain": "dot_magic",
}

static func get_skill(skill_id: String) -> Dictionary:
	return SKILLS.get(skill_id, {})

static func get_skill_category(skill_id: String) -> String:
	return SKILL_CATEGORIES.get(skill_id, "single_physical")

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

static func get_skills_for_proficiency(prof_id: String) -> Array:
	var result: Array = []
	for skill_id in SKILLS:
		var skill: Dictionary = SKILLS[skill_id]
		if skill.has("required_proficiency") and skill.required_proficiency.skill == prof_id:
			result.append(skill_id)
	return result

static func get_skill_ids_by_type(type: String) -> Array:
	var result: Array = []
	for skill_id in SKILLS:
		if SKILLS[skill_id].type == type:
			result.append(skill_id)
	return result
