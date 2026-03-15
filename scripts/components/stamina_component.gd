extends Node
## Self-managing stamina component. Add as child to player or NPC.
## Drains during combat/movement, regenerates at rest spots when idle.

const DRAIN_COMBAT: float = 0.5
const DRAIN_MOVEMENT: float = 0.15
const REGEN_REST: float = 3.0
const REST_SPOT_RANGE: float = 4.0
const VELOCITY_THRESHOLD: float = 0.5

const REST_SPOTS: Array = ["TownWell", "TownInn"]

var stamina: float = 100.0
var max_stamina: float = 100.0
var _last_threshold: int = 10  # tracks 10% threshold crossings
var _entity_id: String = ""
var _is_resting: bool = false

func _ready() -> void:
	var parent := get_parent()
	if "npc_id" in parent:
		_entity_id = parent.npc_id
	elif parent.name == "Player" or (parent is CharacterBody3D and WorldState.get_entity_id_for_node(parent) == "player"):
		_entity_id = "player"

func _process(delta: float) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return

	var vel_length: float = parent.velocity.length() if "velocity" in parent else 0.0
	var state: String = ""
	if "current_state" in parent:
		state = parent.current_state
	elif "_is_dead" in parent and parent._is_dead:
		return  # player dead, skip

	_is_resting = false
	var old_stamina := stamina

	# Drain
	if state == "combat" or (state == "" and "_attack_target" in parent and not parent._attack_target.is_empty()):
		stamina -= DRAIN_COMBAT * delta
	elif vel_length > VELOCITY_THRESHOLD:
		stamina -= DRAIN_MOVEMENT * delta

	# Regen at rest spots when idle
	if vel_length <= VELOCITY_THRESHOLD and state in ["idle", ""] and _is_near_rest_spot():
		stamina += REGEN_REST * delta
		_is_resting = true

	stamina = clampf(stamina, 0.0, max_stamina)

	# Emit signal on 10% threshold crossings
	var new_threshold := int(get_stamina_percent() * 10.0)
	if new_threshold != _last_threshold:
		_last_threshold = new_threshold
		GameEvents.stamina_changed.emit(_entity_id, stamina, max_stamina)

func _is_near_rest_spot() -> bool:
	var parent := get_parent()
	if not is_instance_valid(parent) or not "global_position" in parent:
		return false
	var pos: Vector3 = parent.global_position
	for spot_id in REST_SPOTS:
		if WorldState.has_location(spot_id):
			var spot_pos := WorldState.get_location(spot_id)
			if pos.distance_to(spot_pos) < REST_SPOT_RANGE:
				return true
	return false

func get_stamina() -> float:
	return stamina

func get_stamina_percent() -> float:
	if max_stamina <= 0.0:
		return 0.0
	return stamina / max_stamina

func get_max_stamina() -> float:
	return max_stamina

func drain_flat(amount: float) -> void:
	stamina = clampf(stamina - amount, 0.0, max_stamina)
	var new_threshold := int(get_stamina_percent() * 10.0)
	if new_threshold != _last_threshold:
		_last_threshold = new_threshold
		GameEvents.stamina_changed.emit(_entity_id, stamina, max_stamina)

