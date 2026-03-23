class_name NpcLoadouts
## Starting loadouts for adventurer NPCs — trait profiles, inventory, equipment, gold, and goal.
## gold: -1 means "keep default" (no set_gold_amount call).

const LOADOUTS: Dictionary = {
	"kael": {
		"trait_profile": "bold_warrior",
		"items": {"basic_sword": 1, "healing_potion": 3},
		"equip": ["basic_sword"],
		"gold": -1,
		"default_goal": "hunt_field",
	},
	"lyra": {
		"trait_profile": "cautious_mage",
		"items": {"healing_potion": 5},
		"equip": [],
		"gold": 60,
		"default_goal": "idle",
	},
	"bjorn": {
		"trait_profile": "wild_berserker",
		"items": {"healing_potion": 3},
		"equip": [],
		"gold": 80,
		"default_goal": "hunt_field",
	},
	"sera": {
		"trait_profile": "sly_rogue",
		"items": {"healing_potion": 2},
		"equip": [],
		"gold": 100,
		"default_goal": "patrol",
	},
	"thane": {
		"trait_profile": "stoic_knight",
		"items": {"basic_spear": 1, "healing_potion": 2},
		"equip": ["basic_spear"],
		"gold": 70,
		"default_goal": "hunt_field",
	},
	"mira": {
		"trait_profile": "devout_cleric",
		"items": {"healing_potion": 3},
		"equip": [],
		"gold": 60,
		"default_goal": "idle",
	},
	"dusk": {
		"trait_profile": "shadow_stalker",
		"items": {"healing_potion": 2},
		"equip": [],
		"gold": 50,
		"default_goal": "hunt_field",
	},
	"garen": {
		"trait_profile": "stern_guardian",
		"items": {"basic_sword": 1, "healing_potion": 2},
		"equip": ["basic_sword"],
		"gold": 90,
		"default_goal": "patrol",
	},
	"garrick": {
		"trait_profile": "merchant",
		"items": {
			"basic_sword": 5, "iron_sword": 3, "steel_sword": 2,
			"basic_axe": 3, "iron_axe": 2,
			"basic_mace": 3, "iron_mace": 2,
			"basic_dagger": 3, "iron_dagger": 2,
			"basic_staff": 3, "iron_staff": 2,
			"basic_bow": 3, "basic_spear": 3,
		},
		"equip": ["iron_sword"],
		"gold": 500,
		"default_goal": "idle",
	},
	"elara": {
		"trait_profile": "merchant",
		"items": {"healing_potion": 20},
		"equip": [],
		"gold": 300,
		"default_goal": "idle",
	},
	"finn": {
		"trait_profile": "charming_bard",
		"items": {"healing_potion": 2},
		"equip": [],
		"gold": 30,
		"default_goal": "idle",
	},
	"rook": {
		"trait_profile": "earnest_apprentice",
		"items": {"healing_potion": 3},
		"equip": [],
		"gold": 25,
		"default_goal": "idle",
	},
}
