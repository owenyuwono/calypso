extends RefCounted
## Base stat definitions. Stat growth is handled by the proficiency system.

## Base stats for a new player entity.
const BASE_PLAYER_STATS: Dictionary = {
	"hp": 50, "max_hp": 50,
	"atk": 7, "def": 4,
	"gold": 100,
	"attack_speed": 0.8, "attack_range": 2.0,
}

## Base stats for a new adventurer NPC entity.
const BASE_ADVENTURER_STATS: Dictionary = {
	"hp": 50, "max_hp": 50,
	"atk": 7, "def": 4,
	"gold": 80,
	"attack_speed": 0.8, "attack_range": 2.0,
}
