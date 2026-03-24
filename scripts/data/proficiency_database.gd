extends RefCounted
## Static proficiency skill definitions for the use-based proficiency system.

const MAX_LEVEL: int = 10

const CATEGORIES: Array = ["weapon", "attribute", "magic", "gathering", "production", "social"]

# Attribute display order within the attribute category
const ATTRIBUTE_ORDER: Array = ["str", "con", "agi", "int", "dex", "wis"]

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
	"bow": {
		"name": "Bow",
		"category": "weapon",
		"description": "Ranged physical combat. Levels up by dealing damage with bow.",
	},
	"spear": {
		"name": "Spear",
		"category": "weapon",
		"description": "Extended melee reach. Levels up by dealing damage with spear.",
	},
	# Attribute skills
	"str": {
		"name": "Strength",
		"category": "attribute",
		"description": "Raw physical power. Muscles trained through combat. Levels up by dealing physical damage.",
	},
	"con": {
		"name": "Constitution",
		"category": "attribute",
		"description": "Toughness. Bodies hardened by punishment. Levels up by taking damage.",
	},
	"agi": {
		"name": "Agility",
		"category": "attribute",
		"description": "Reflexes. Trained by surviving danger. Levels up by dodging attacks and combat movement.",
	},
	"int": {
		"name": "Intelligence",
		"category": "attribute",
		"description": "Arcane knowledge. Power through understanding. Levels up by dealing magical damage.",
	},
	"dex": {
		"name": "Dexterity",
		"category": "attribute",
		"description": "Precision. Eyes and hands trained by practice. Levels up by landing hits.",
	},
	"wis": {
		"name": "Wisdom",
		"category": "attribute",
		"description": "Mental discipline. Focus sharpened through practice. Levels up by using skills.",
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
	# Magic skills — XP per magical hit with that element
	"fire": {
		"name": "Fire",
		"category": "magic",
		"description": "Mastery of fire spells. Increases fire damage.",
	},
	"ice": {
		"name": "Ice",
		"category": "magic",
		"description": "Mastery of ice spells. Increases ice damage.",
	},
	"lightning": {
		"name": "Lightning",
		"category": "magic",
		"description": "Mastery of lightning spells. Increases lightning damage.",
	},
	"earth": {
		"name": "Earth",
		"category": "magic",
		"description": "Mastery of earth spells. Increases earth damage.",
	},
	"light": {
		"name": "Light",
		"category": "magic",
		"description": "Mastery of holy spells. Increases light damage.",
	},
	"dark": {
		"name": "Dark",
		"category": "magic",
		"description": "Mastery of dark spells. Increases dark damage.",
	},
	"arcane": {
		"name": "Arcane",
		"category": "magic",
		"description": "Mastery of arcane spells. Increases arcane damage.",
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
	# Social skills — XP per successful social interaction
	"charisma": {
		"name": "Charisma",
		"category": "social",
		"description": "Your natural likeability and social warmth.",
	},
	"persuasion": {
		"name": "Persuasion",
		"category": "social",
		"description": "Your ability to influence others.",
	},
	"intimidation": {
		"name": "Intimidation",
		"category": "social",
		"description": "Your ability to coerce others through force of will.",
	},
}

static func get_skill(skill_id: String) -> Dictionary:
	return SKILLS.get(skill_id, {})

static func get_xp_to_next_level(current_level: int) -> int:
	return current_level * 50

static func get_xp_fill_percent(level: int, xp: int, xp_to_next: int) -> float:
	if level >= MAX_LEVEL:
		return 1.0
	if xp_to_next <= 0:
		return 0.0
	return clampf(float(xp) / float(xp_to_next), 0.0, 1.0)

static func get_skills_by_category(category: String) -> Dictionary:
	var result: Dictionary = {}
	for skill_id in SKILLS:
		if SKILLS[skill_id].get("category", "") == category:
			result[skill_id] = SKILLS[skill_id]
	return result

static func get_default_proficiencies() -> Dictionary:
	var result: Dictionary = {}
	for skill_id in SKILLS:
		var skill: Dictionary = SKILLS[skill_id]
		var starting_level: int = 1
		result[skill_id] = {"level": starting_level, "xp": 0}
	return result
