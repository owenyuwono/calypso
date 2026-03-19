extends RefCounted
## Static ore type definitions for the mining skill.

class_name OreDatabase

const ORES: Dictionary = {
	"copper": {
		"name": "Copper Ore",
		"chops": [3, 5],
		"xp_per_chop": 5,
		"required_level": 1,
		"drop": "copper_ore",
		"bonus_drop": "stone",
		"bonus_chance": 0.1,
		"respawn_time": 45.0,
	},
	"iron": {
		"name": "Iron Ore",
		"chops": [5, 8],
		"xp_per_chop": 12,
		"required_level": 3,
		"drop": "iron_ore",
		"bonus_drop": "stone",
		"bonus_chance": 0.15,
		"respawn_time": 60.0,
	},
	"gold": {
		"name": "Gold Ore",
		"chops": [8, 12],
		"xp_per_chop": 25,
		"required_level": 6,
		"drop": "gold_ore",
		"bonus_drop": "stone",
		"bonus_chance": 0.2,
		"respawn_time": 75.0,
	},
}

static func get_ore(tier: String) -> Dictionary:
	return ORES.get(tier, {})
