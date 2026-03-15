extends RefCounted
## Static proficiency skill definitions for the use-based proficiency system.

const MAX_LEVEL: int = 10

const CATEGORIES: Array = ["weapon", "attribute", "gathering", "production"]

const SKILLS: Dictionary = {
	# Weapon skills — XP per hit dealt with that weapon type
	"sword": {
		"name": "Sword",
		"category": "weapon",
		"description": "Melee damage with swords. Levels up by fighting with swords.",
	},
	"axe": {
		"name": "Axe",
		"category": "weapon",
		"description": "Melee damage with axes. Levels up by fighting with axes.",
	},
	"mace": {
		"name": "Mace",
		"category": "weapon",
		"description": "Melee damage with maces. Levels up by fighting with maces.",
	},
	"dagger": {
		"name": "Dagger",
		"category": "weapon",
		"description": "Melee damage with daggers. Levels up by fighting with daggers.",
	},
	"staff": {
		"name": "Staff",
		"category": "weapon",
		"description": "Magical damage with staves. Levels up by fighting with staves.",
	},
	# Attribute skills
	"constitution": {
		"name": "Constitution",
		"category": "attribute",
		"description": "Endurance and vitality. Levels up by taking hits in combat.",
	},
	"agility": {
		"name": "Agility",
		"category": "attribute",
		"description": "Speed and mobility. Levels up by traveling distances.",
	},
	# Gathering skills — XP per gather action (future)
	"mining": {
		"name": "Mining",
		"category": "gathering",
		"description": "Extracting ore and minerals from rocks. Levels up by mining.",
	},
	"woodcutting": {
		"name": "Woodcutting",
		"category": "gathering",
		"description": "Felling trees and harvesting logs. Levels up by chopping wood.",
	},
	"fishing": {
		"name": "Fishing",
		"category": "gathering",
		"description": "Catching fish from bodies of water. Levels up by fishing.",
	},
	# Production skills — XP per craft action (future)
	"smithing": {
		"name": "Smithing",
		"category": "production",
		"description": "Forging weapons and armor from metal. Levels up by smithing.",
	},
	"cooking": {
		"name": "Cooking",
		"category": "production",
		"description": "Preparing food and consumables. Levels up by cooking.",
	},
	"crafting": {
		"name": "Crafting",
		"category": "production",
		"description": "Creating items from gathered materials. Levels up by crafting.",
	},
}

static func get_skill(skill_id: String) -> Dictionary:
	return SKILLS.get(skill_id, {})

static func get_xp_to_next_level(current_level: int) -> int:
	return current_level * 50

static func get_all_skills() -> Dictionary:
	return SKILLS

static func get_skills_by_category(category: String) -> Dictionary:
	var result: Dictionary = {}
	for skill_id in SKILLS:
		if SKILLS[skill_id].get("category", "") == category:
			result[skill_id] = SKILLS[skill_id]
	return result

static func get_default_proficiencies() -> Dictionary:
	var result: Dictionary = {}
	for skill_id in SKILLS:
		result[skill_id] = {"level": 1, "xp": 0}
	return result
