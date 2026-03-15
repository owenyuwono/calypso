extends Node
## Component that owns combat stats for an entity.
## Bridge: _sync() writes back to WorldState.entity_data on every mutation.

const DEFAULT_ATTACK_SPEED: float = 1.0
const DEFAULT_ATTACK_RANGE: float = 2.0

var hp: int = 0
var max_hp: int = 0
var atk: int = 0
var def: int = 0
var level: int = 1
var attack_speed: float = DEFAULT_ATTACK_SPEED
var attack_range: float = DEFAULT_ATTACK_RANGE

func setup(stats: Dictionary) -> void:
	hp = stats.get("hp", 0)
	max_hp = stats.get("max_hp", 0)
	atk = stats.get("atk", 0)
	def = stats.get("def", 0)
	# level now represents total proficiency level (sum of all skill levels).
	# Default 13 = 13 proficiency skills each starting at level 1.
	level = stats.get("level", 13)
	attack_speed = stats.get("attack_speed", DEFAULT_ATTACK_SPEED)
	attack_range = stats.get("attack_range", DEFAULT_ATTACK_RANGE)

func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	_sync()

func heal(amount: int) -> int:
	var healed := mini(amount, max_hp - hp)
	hp += healed
	_sync()
	return healed

func restore_full_hp() -> void:
	hp = max_hp
	_sync()

func get_stats_dict() -> Dictionary:
	return {
		"hp": hp, "max_hp": max_hp,
		"atk": atk, "def": def,
		"level": level,
		"attack_speed": attack_speed, "attack_range": attack_range,
	}

func _sync() -> void:
	var parent := get_parent()
	if not parent or not ("entity_id" in parent):
		return
	var eid: String = parent.entity_id
	if eid.is_empty():
		return
	WorldState.set_entity_data(eid, "hp", hp)
	WorldState.set_entity_data(eid, "max_hp", max_hp)
	WorldState.set_entity_data(eid, "atk", atk)
	WorldState.set_entity_data(eid, "def", def)
	WorldState.set_entity_data(eid, "level", level)
	WorldState.set_entity_data(eid, "attack_speed", attack_speed)
	WorldState.set_entity_data(eid, "attack_range", attack_range)
