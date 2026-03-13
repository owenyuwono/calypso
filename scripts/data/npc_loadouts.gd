extends RefCounted
## Starting loadouts for adventurer NPCs — trait profiles, inventory, equipment, gold, and goal.
## gold: -1 means "keep default" (no set_gold_amount call).

class_name NpcLoadouts

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
		"trait_profile": "boisterous_brawler",
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
		"items": {"healing_potion": 2},
		"equip": [],
		"gold": 70,
		"default_goal": "hunt_field",
	},
	"mira": {
		"trait_profile": "cheerful_scholar",
		"items": {"healing_potion": 3},
		"equip": [],
		"gold": 60,
		"default_goal": "idle",
	},
	"dusk": {
		"trait_profile": "mysterious_loner",
		"items": {"healing_potion": 2},
		"equip": [],
		"gold": 50,
		"default_goal": "hunt_field",
	},
}
