extends Node
## Reusable auto-attack loop component shared by player, NPC, and monster.
## Handles: target validation, range check, chase navigation, animation-synced
## pending hit, attack timer, and damage dealing.
## Visual feedback (damage numbers, flash, shouts) is left to the owner via signals.

signal attack_landed(target_id: String, damage: int, target_pos: Vector3)
signal target_lost()

const ATTACK_ANIM: String = "1H_Melee_Attack_Chop"

var _visuals: Node          # EntityVisuals ref
var _combat: Node           # CombatComponent ref
var _nav_agent: Node        # NavigationAgent3D ref (declared as Node for duck typing)

var _attack_timer: float = 0.0
var _pending_hit: bool = false
var _hit_time: float = 0.0
var _last_nav_target_pos: Vector3 = Vector3.INF

func setup(visuals: Node, combat: Node, nav_agent: Node) -> void:
	_visuals = visuals
	_combat = combat
	_nav_agent = nav_agent

## Process one frame of auto-attack logic.
## owner_pos: attacker's global_position
## move_speed: movement speed for chasing
## attack_range: distance threshold for in-range attack
## attack_speed: cooldown between attacks in seconds
## speed_multiplier: optional speed multiplier for chasing (e.g. 1.1 for NPC combat sprint)
## Returns {"is_moving": bool, "is_chasing": bool}
func process_attack(
	delta: float,
	target_id: String,
	owner_pos: Vector3,
	move_speed: float,
	attack_range: float,
	attack_speed: float,
	speed_multiplier: float = 1.0
) -> Dictionary:
	# Validate target
	var target_node = WorldState.get_entity(target_id)
	if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(target_id):
		target_lost.emit()
		return {"is_moving": false, "is_chasing": false}

	var dist: float = owner_pos.distance_to(target_node.global_position)

	if dist > attack_range:
		# Out of range — chase target
		_chase(target_node, move_speed, speed_multiplier)
		return {"is_moving": true, "is_chasing": true}

	# In range — stop and attack
	var parent: Node3D = get_parent() as Node3D
	if parent:
		parent.velocity.x = 0.0
		parent.velocity.z = 0.0

	# Face the target
	var to_target: Vector3 = (target_node.global_position - owner_pos)
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		_visuals.face_direction(to_target.normalized())

	# Resolve pending hit via animation position or fallback countdown
	var anim_player: AnimationPlayer = _visuals.get_anim_player()
	if _pending_hit:
		if anim_player and anim_player.current_animation == ATTACK_ANIM:
			if anim_player.current_animation_position >= _hit_time:
				_pending_hit = false
				_fire_hit(target_id, target_node)
		else:
			# Fallback countdown for entities without the attack animation (e.g. slime)
			_hit_time -= delta
			if _hit_time <= 0.0:
				_pending_hit = false
				_fire_hit(target_id, target_node)

	# Accumulate attack cooldown only after pending hit has landed
	if not _pending_hit:
		_attack_timer += delta
		if _attack_timer >= attack_speed:
			_attack_timer = 0.0
			_visuals.play_anim(ATTACK_ANIM, true)
			_pending_hit = true
			_hit_time = _visuals.get_hit_delay(ATTACK_ANIM)

	return {"is_moving": false, "is_chasing": false}

## Cancel any in-progress attack and reset state.
func cancel() -> void:
	_attack_timer = 0.0
	_pending_hit = false
	_hit_time = 0.0
	_last_nav_target_pos = Vector3.INF

## Returns true if an attack animation is in-flight and the hit has not landed yet.
func is_pending_hit() -> bool:
	return _pending_hit

# --- Private ---

func _chase(target_node: Node3D, move_speed: float, speed_multiplier: float) -> void:
	# Only update nav target if target moved significantly (avoids nav spam)
	var target_pos: Vector3 = target_node.global_position
	if _last_nav_target_pos.distance_to(target_pos) > 1.0:
		_last_nav_target_pos = target_pos
		_nav_agent.target_position = target_pos

	if not _nav_agent.is_navigation_finished():
		var next_pos: Vector3 = _nav_agent.get_next_path_position()
		var parent: Node3D = get_parent() as Node3D
		if parent:
			var dir: Vector3 = (next_pos - parent.global_position)
			dir.y = 0.0
			if dir.length_squared() > 0.01:
				dir = dir.normalized()
				parent.velocity.x = dir.x * move_speed * speed_multiplier
				parent.velocity.z = dir.z * move_speed * speed_multiplier
				_visuals.face_direction(dir)
				_visuals.play_anim("Running_A")

func _fire_hit(target_id: String, target_node: Node3D) -> void:
	# Re-validate target hasn't died between animation start and hit point
	if not WorldState.is_alive(target_id):
		target_lost.emit()
		return
	var target_pos: Vector3 = target_node.global_position if is_instance_valid(target_node) else Vector3.ZERO
	var damage: int = _combat.deal_damage_to(target_id)
	attack_landed.emit(target_id, damage, target_pos)
