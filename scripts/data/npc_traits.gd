extends RefCounted
## Static NPC trait profiles — personality axes that drive behavior and LLM prompts.

# Trait axes (0.0–1.0):
# boldness: 0=cautious, 1=reckless — affects retreat HP%, aggro willingness
# sociability: 0=introverted, 1=extroverted — affects social chat cooldown
# generosity: 0=selfish, 1=generous — future use (trade willingness)
# curiosity: 0=focused, 1=exploratory — future use (goal switching)

const PROFILES: Dictionary = {
	"bold_warrior": {
		"boldness": 0.85, "sociability": 0.7, "generosity": 0.5, "curiosity": 0.3,
		"weapon_type": "sword",
		"starting_proficiencies": {"sword": 3, "str": 3, "con": 2, "agi": 1, "int": 1, "dex": 2, "wis": 1},
	},
	"cautious_mage": {
		"boldness": 0.2, "sociability": 0.4, "generosity": 0.6, "curiosity": 0.7,
		"weapon_type": "staff",
		"starting_proficiencies": {"staff": 3, "str": 1, "con": 1, "agi": 1, "int": 3, "dex": 1, "wis": 3, "arcane": 2, "fire": 1},
	},
	"sly_rogue": {
		"boldness": 0.5, "sociability": 0.8, "generosity": 0.2, "curiosity": 0.6,
		"weapon_type": "dagger",
		"starting_proficiencies": {"dagger": 3, "str": 1, "con": 1, "agi": 3, "int": 1, "dex": 3, "wis": 1},
	},
	"stoic_knight": {
		"boldness": 0.6, "sociability": 0.25, "generosity": 0.7, "curiosity": 0.2,
		"weapon_type": "spear",
		"starting_proficiencies": {"spear": 3, "str": 2, "con": 3, "agi": 1, "int": 1, "dex": 2, "wis": 1},
	},
	"stern_guardian": {
		"boldness": 0.7, "sociability": 0.2, "generosity": 0.75, "curiosity": 0.15,
		"weapon_type": "sword",
		"starting_proficiencies": {"sword": 4, "str": 2, "con": 3, "agi": 1, "int": 1, "dex": 1, "wis": 2},
	},
	"gentle_healer": {
		"boldness": 0.15, "sociability": 0.75, "generosity": 0.95, "curiosity": 0.5,
		"weapon_type": "staff",
		"starting_proficiencies": {"staff": 2, "str": 1, "con": 2, "agi": 1, "int": 2, "dex": 1, "wis": 3, "light": 2, "arcane": 1},
	},
	"charming_bard": {
		"boldness": 0.45, "sociability": 0.95, "generosity": 0.55, "curiosity": 0.8,
		"weapon_type": "dagger",
		"starting_proficiencies": {"dagger": 2, "str": 1, "con": 1, "agi": 2, "int": 2, "dex": 2, "wis": 2, "arcane": 1, "lightning": 1},
	},
	"wild_berserker": {
		"boldness": 0.75, "sociability": 0.9, "generosity": 0.6, "curiosity": 0.4,
		"weapon_type": "axe",
		"starting_proficiencies": {"axe": 3, "str": 3, "con": 2, "agi": 2, "int": 1, "dex": 1, "wis": 1},
	},
	"keen_archer": {
		"boldness": 0.6, "sociability": 0.5, "generosity": 0.5, "curiosity": 0.6,
		"weapon_type": "bow",
		"starting_proficiencies": {"bow": 3, "str": 1, "con": 1, "agi": 2, "int": 1, "dex": 3, "wis": 2},
	},
	"earnest_apprentice": {
		"boldness": 0.5, "sociability": 0.6, "generosity": 0.7, "curiosity": 0.55,
		"weapon_type": "mace",
		"starting_proficiencies": {"mace": 2, "str": 2, "con": 2, "agi": 1, "int": 1, "dex": 2, "wis": 2, "fire": 1},
	},
	"devout_cleric": {
		"boldness": 0.4, "sociability": 0.85, "generosity": 0.8, "curiosity": 0.9,
		"weapon_type": "staff",
		"starting_proficiencies": {"staff": 3, "str": 1, "con": 2, "agi": 1, "int": 2, "dex": 1, "wis": 3, "light": 2, "dark": 1},
	},
	"shadow_stalker": {
		"boldness": 0.55, "sociability": 0.15, "generosity": 0.3, "curiosity": 0.5,
		"weapon_type": "dagger",
		"starting_proficiencies": {"dagger": 3, "str": 2, "con": 1, "agi": 3, "int": 1, "dex": 2, "wis": 1},
	},
	"merchant": {
		"boldness": 0.3, "sociability": 0.85, "generosity": 0.6, "curiosity": 0.4,
		"weapon_type": "sword",
		"starting_proficiencies": {"sword": 2, "str": 2, "con": 2, "agi": 1, "int": 1, "dex": 2, "wis": 2},
	},
}

# Label mappings for compact LLM trait summaries
const BOLDNESS_LABELS: Array = [
	[0.3, "cautious"], [0.6, "steady"], [1.0, "bold"],
]
const SOCIABILITY_LABELS: Array = [
	[0.3, "quiet"], [0.6, "moderate"], [1.0, "talkative"],
]

static func get_profile(id: String) -> Dictionary:
	return PROFILES.get(id, {})

static func get_trait(id: String, trait_name: String, default: float = 0.5) -> float:
	var profile := PROFILES.get(id, {}) as Dictionary
	return profile.get(trait_name, default)

