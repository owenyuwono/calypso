extends RefCounted
## Base stat definitions. Stat growth is handled by the proficiency system.

## Base stats for a new player entity.
const BASE_PLAYER_STATS: Dictionary = {
	"hp": 65, "max_hp": 65,
	"atk": 10, "def": 5,
	"gold": 100,
	"attack_speed": 0.8, "attack_range": 2.0,
}

## Base stats for a new adventurer NPC entity.
const BASE_ADVENTURER_STATS: Dictionary = {
	"hp": 65, "max_hp": 65,
	"atk": 10, "def": 5,
	"gold": 80,
	"attack_speed": 0.8, "attack_range": 2.0,
}
