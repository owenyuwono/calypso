extends BaseComponent
## Self-managing stamina component. Add as child to player or NPC.
## Drains only from explicit drain_flat() calls (skills).
## Regenerates at different rates based on combat state and rest spots.

const REGEN_IDLE: float = 1.0
const REGEN_REST: float = 3.0
const REGEN_COMBAT: float = 0.3
const REST_SPOT_RANGE: float = 4.0
const VELOCITY_THRESHOLD: float = 0.5

const FATIGUE_MIN_MULTIPLIERS: Dictionary = {
	"atk": 0.90,
	"move_speed": 0.80,
	"attack_speed": 0.85,
}

var _rest_spots: Array = []
var _process_timer: float = 0.0
const PROCESS_INTERVAL: float = 0.2

var stamina: float = 100.0
var _last_threshold: int = 10  # tracks 10% threshold crossings
var _entity_id: String = ""
var _is_resting: bool = false
var _stats: Node  # StatsComponent ref (optional)

func setup_rest_spots(spots: Array) -> void:
	_rest_spots = spots

func _ready() -> void:
	var parent := get_parent()
	if "npc_id" in parent:
		_entity_id = parent.npc_id
	elif parent.name == "Player" or (parent is CharacterBody3D and WorldState.get_entity_id_for_node(parent) == "player"):
		_entity_id = "player"
	_stats = parent.get_node_or_null("StatsComponent")
	stamina = get_max_stamina()

func _process(delta: float) -> void:
	_process_timer += delta
	if _process_timer < PROCESS_INTERVAL:
		return
	var elapsed: float = _process_timer
	_process_timer = 0.0

	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	if "_is_dead" in parent and parent._is_dead:
		return

	var vel_length: float = parent.velocity.length() if "velocity" in parent else 0.0
	var state: String = ""
	if "current_state" in parent:
		state = parent.current_state

	_is_resting = false

	var stamina_regen_mult: float = _stats.stamina_regen if _stats else 1.0
	var max_st: float = get_max_stamina()

	# Regen
	var in_combat: bool = state == "combat" or (state == "" and "_attack_target" in parent and not parent._attack_target.is_empty())
	if in_combat:
		stamina += REGEN_COMBAT * stamina_regen_mult * elapsed
	elif vel_length <= VELOCITY_THRESHOLD and state in ["idle", ""] and _is_near_rest_spot():
		stamina += REGEN_REST * stamina_regen_mult * elapsed
		_is_resting = true
	else:
		stamina += REGEN_IDLE * stamina_regen_mult * elapsed

	stamina = clampf(stamina, 0.0, max_st)

	# Emit signal on 10% threshold crossings
	var new_threshold := int(get_stamina_percent() * 10.0)
	if new_threshold != _last_threshold:
		_last_threshold = new_threshold
		GameEvents.stamina_changed.emit(_entity_id, stamina, max_st)

func _is_near_rest_spot() -> bool:
	var parent := get_parent()
	if not is_instance_valid(parent) or not "global_position" in parent:
		return false
	var pos: Vector3 = parent.global_position
	for spot_id in _rest_spots:
		if WorldState.has_location(spot_id):
			var spot_pos := WorldState.get_location(spot_id)
			if pos.distance_to(spot_pos) < REST_SPOT_RANGE:
				return true
	return false

func get_stamina() -> float:
	return stamina

func get_stamina_percent() -> float:
	var max_st: float = get_max_stamina()
	if max_st <= 0.0:
		return 0.0
	return stamina / max_st

func get_max_stamina() -> float:
	if _stats:
		return _stats.max_stamina
	return 100.0

func get_fatigue_multiplier(stat_type: String) -> float:
	var min_mult: float = FATIGUE_MIN_MULTIPLIERS.get(stat_type, 1.0)
	var stamina_pct: float = get_stamina_percent()
	return 1.0 - (1.0 - min_mult) * (1.0 - stamina_pct)

func drain_flat(amount: float) -> void:
	stamina = clampf(stamina - amount, 0.0, get_max_stamina())
	var new_threshold := int(get_stamina_percent() * 10.0)
	if new_threshold != _last_threshold:
		_last_threshold = new_threshold
		GameEvents.stamina_changed.emit(_entity_id, stamina, get_max_stamina())
