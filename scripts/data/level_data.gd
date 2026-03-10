extends RefCounted
## XP table and stat growth definitions.

const MAX_LEVEL: int = 10

## XP required to reach the NEXT level (indexed by current level).
## Level 1->2 = 100, 2->3 = 200, ..., 9->10 = 900
static func xp_to_next_level(current_level: int) -> int:
	return current_level * 100

## Stat gains on level up.
const HP_PER_LEVEL: int = 10
const ATK_PER_LEVEL: int = 2
const DEF_PER_LEVEL: int = 1

## Base stats for a new entity at level 1.
const BASE_PLAYER_STATS: Dictionary = {
	"hp": 50, "max_hp": 50,
	"atk": 10, "def": 5,
	"level": 1, "xp": 0,
	"gold": 100,
	"attack_speed": 1.0, "attack_range": 2.0,
}

const BASE_ADVENTURER_STATS: Dictionary = {
	"hp": 50, "max_hp": 50,
	"atk": 10, "def": 5,
	"level": 1, "xp": 0,
	"gold": 80,
	"attack_speed": 1.0, "attack_range": 2.0,
}
