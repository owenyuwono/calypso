extends RefCounted
## Static fish tier definitions for the fishing skill.

class_name FishDatabase

const FISH: Dictionary = {
	"shallow": {
		"name": "Shallow Waters",
		"chops": [2, 4],
		"xp_per_chop": 4,
		"required_level": 1,
		"drop": "sardine",
		"bonus_drop": "",
		"bonus_chance": 0.0,
		"respawn_time": 30.0,
	},
	"medium": {
		"name": "Medium Waters",
		"chops": [4, 6],
		"xp_per_chop": 10,
		"required_level": 3,
		"drop": "trout",
		"bonus_drop": "sardine",
		"bonus_chance": 0.15,
		"respawn_time": 50.0,
	},
	"deep": {
		"name": "Deep Waters",
		"chops": [6, 9],
		"xp_per_chop": 20,
		"required_level": 6,
		"drop": "salmon",
		"bonus_drop": "trout",
		"bonus_chance": 0.1,
		"respawn_time": 75.0,
	},
}

static func get_fish(tier: String) -> Dictionary:
	return FISH.get(tier, {})
