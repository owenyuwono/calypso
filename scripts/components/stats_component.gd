extends BaseComponent
## Component that owns combat stats for an entity.
## Bridge: _sync() writes back to WorldState.entity_data on every mutation.

const DEFAULT_ATTACK_SPEED: float = 1.0
const DEFAULT_ATTACK_RANGE: float = 4.0

var hp: int = 0
var max_hp: int = 0
var atk: int = 0
var def: int = 0
var level: int = 1
var attack_speed: float = DEFAULT_ATTACK_SPEED
var attack_range: float = DEFAULT_ATTACK_RANGE

var move_speed: float = 1.0   # multiplier
var max_stamina: float = 100.0
var stamina_regen: float = 1.0 # multiplier
var hp_regen: float = 0.0     # per second (out of combat only)
var attack_speed_mult: float = 1.0   # multiplier (effective_cd = attack_speed / attack_speed_mult)

func setup(stats: Dictionary) -> void:
	hp = stats.get("hp", 0)
	max_hp = stats.get("max_hp", 0)
	atk = stats.get("atk", 0)
	def = stats.get("def", 0)
	level = stats.get("level", 1)
	attack_speed = stats.get("attack_speed", DEFAULT_ATTACK_SPEED)
	attack_range = stats.get("attack_range", DEFAULT_ATTACK_RANGE)
	move_speed = stats.get("move_speed", 1.0)
	max_stamina = stats.get("max_stamina", 100.0)
	stamina_regen = stats.get("stamina_regen", 1.0)
	hp_regen = stats.get("hp_regen", 0.0)
	attack_speed_mult = stats.get("attack_speed_mult", 1.0)

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
	WorldState.set_entity_data(eid, "move_speed", move_speed)
	WorldState.set_entity_data(eid, "max_stamina", max_stamina)
	WorldState.set_entity_data(eid, "stamina_regen", stamina_regen)
	WorldState.set_entity_data(eid, "hp_regen", hp_regen)
	WorldState.set_entity_data(eid, "attack_speed_mult", attack_speed_mult)
