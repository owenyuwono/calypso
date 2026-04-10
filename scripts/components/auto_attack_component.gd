extends BaseComponent
## Reusable auto-attack loop component shared by player, NPC, and monster.
## Handles: target validation, range check, chase navigation, animation-synced
## pending hit, attack timer, and damage dealing.
## Visual feedback (damage numbers, flash, shouts) is left to the owner via signals.

signal attack_started(target_id: String)
signal attack_landed(target_id: String, damage: int, target_pos: Vector3)
signal target_lost()

var attack_anim: String = "Attack"
var chase_anim: String = "Running"

# Armor/phys-type resistance table (inlined from deleted SkillEffectResolver)
const _RESISTANCE_MULTIPLIERS: Dictionary = {
	"fatal": 2.0, "weak": 1.5, "neutral": 1.0, "resist": 0.5, "immune": 0.0
}
const _ARMOR_PHYS_TYPE_TABLE: Dictionary = {
	"heavy":  {"slash": "resist", "pierce": "neutral", "blunt": "weak"},
	"medium": {"slash": "neutral", "pierce": "weak",   "blunt": "neutral"},
	"light":  {"slash": "weak",   "pierce": "neutral", "blunt": "neutral"},
}

var _visuals: Node          # EntityVisuals ref
var _combat: Node           # CombatComponent ref
var _nav_agent: Node        # NavigationAgent3D ref (declared as Node for duck typing)

var _attack_timer: float = 0.0
var _pending_hit: bool = false
var _hit_time: float = 0.0
var _last_nav_target_pos: Vector3 = Vector3.INF
var _chase_stuck_timer: float = 0.0
var _chase_last_pos: Vector3 = Vector3.ZERO

func setup(visuals: Node, combat: Node, nav_agent: Node) -> void:
	_visuals = visuals
	_combat = combat
	_nav_agent = nav_agent
	_attack_timer = randf()  # stagger so groups don't all attack on the same frame

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
		_chase(delta, target_node, move_speed, speed_multiplier)

		# Stuck detection: if no positional progress for 2s, disengage
		var parent: Node3D = get_parent() as Node3D
		if parent:
			if parent.global_position.distance_to(_chase_last_pos) > 0.2:
				_chase_last_pos = parent.global_position
				_chase_stuck_timer = 0.0
			else:
				_chase_stuck_timer += delta
				if _chase_stuck_timer >= 2.0:
					target_lost.emit()
					return {"is_moving": false, "is_chasing": false}

		return {"is_moving": true, "is_chasing": true}

	# In range — reset stuck timer and attack
	_chase_stuck_timer = 0.0
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
		if anim_player and anim_player.current_animation == attack_anim:
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
			_visuals.play_anim(attack_anim, true)
			_pending_hit = true
			_hit_time = _visuals.get_hit_delay(attack_anim)
			attack_started.emit(target_id)

	return {"is_moving": false, "is_chasing": false}

## Cancel any in-progress attack and reset state.
func cancel() -> void:
	_attack_timer = 0.0
	_pending_hit = false
	_hit_time = 0.0
	_last_nav_target_pos = Vector3.INF
	_chase_stuck_timer = 0.0
	_chase_last_pos = Vector3.ZERO

# --- Private ---

func _chase(delta: float, target_node: Node3D, move_speed: float, speed_multiplier: float) -> void:
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
				var target_vx: float = dir.x * move_speed * speed_multiplier
				var target_vz: float = dir.z * move_speed * speed_multiplier
				# Lerp for smooth acceleration into chase rather than snapping velocity
				parent.velocity.x = lerpf(parent.velocity.x, target_vx, delta * 8.0)
				parent.velocity.z = lerpf(parent.velocity.z, target_vz, delta * 8.0)
				_visuals.face_direction(dir)
				_visuals.play_anim(chase_anim)

func _fire_hit(target_id: String, target_node: Node3D) -> void:
	# Re-validate target hasn't died between animation start and hit point
	if not WorldState.is_alive(target_id):
		target_lost.emit()
		return
	var target_pos: Vector3 = target_node.global_position if is_instance_valid(target_node) else Vector3.ZERO
	var attacker_id: String = _get_entity_id()

	# Calculate damage with phys_type resistance
	var target_combat: Node = target_node.get_node_or_null("CombatComponent") if is_instance_valid(target_node) else null
	var atk: int = _combat.get_effective_atk()
	var def: int = target_combat.get_effective_def() if target_combat else 0
	var raw_damage: float = maxf(1.0, atk - def)

	# Physical type modifier (weapon phys_type vs target armor type)
	var phys_type: String = _combat.get_equipped_phys_type()
	var armor_type: String = target_combat.get_armor_type() if target_combat else "light"
	var armor_table: Dictionary = _ARMOR_PHYS_TYPE_TABLE.get(armor_type, {})
	var phys_level: String = armor_table.get(phys_type, "neutral")
	var phys_mod: float = _RESISTANCE_MULTIPLIERS.get(phys_level, 1.0)

	# Element resistance (auto-attacks use target's resistances for phys_type)
	var target_resistances: Dictionary = {}
	var entity_data: Dictionary = WorldState.get_entity_data(target_id)
	if entity_data.has("resistances"):
		target_resistances = entity_data["resistances"]
	var resist_mod: float = 1.0
	if target_resistances.has(phys_type):
		resist_mod = _RESISTANCE_MULTIPLIERS.get(target_resistances[phys_type], 1.0)

	var combined_mod: float = phys_mod * resist_mod
	var damage: int = maxi(1, int(raw_damage * combined_mod)) if combined_mod > 0.0 else 0

	# Apply and emit — use actual damage dealt (0 if parried, reduced if blocked)
	var actual_damage: int = 0
	if damage > 0:
		actual_damage = _combat.apply_flat_damage_to(target_id, damage)
	attack_landed.emit(target_id, actual_damage, target_pos)
