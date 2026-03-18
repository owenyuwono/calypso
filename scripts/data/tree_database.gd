extends RefCounted
## Static tree type definitions for the woodcutting skill.

class_name TreeDatabase

const TREES: Dictionary = {
	"normal": {
		"name": "Fir Tree",
		"chops": [3, 5],
		"xp_per_chop": 5,
		"required_level": 1,
		"drop": "log",
		"bonus_drop": "branch",
		"bonus_chance": 0.1,
		"respawn_time": 60.0,
	},
	"mature": {
		"name": "Mature Fir",
		"chops": [5, 8],
		"xp_per_chop": 12,
		"required_level": 3,
		"drop": "oak_log",
		"bonus_drop": "branch",
		"bonus_chance": 0.15,
		"respawn_time": 75.0,
	},
	"ancient": {
		"name": "Ancient Fir",
		"chops": [8, 12],
		"xp_per_chop": 25,
		"required_level": 6,
		"drop": "ancient_log",
		"bonus_drop": "branch",
		"bonus_chance": 0.2,
		"respawn_time": 90.0,
	},
}

static func get_tree(tier: String) -> Dictionary:
	return TREES.get(tier, {})
