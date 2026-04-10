extends CharacterBody3D
## Zombie enemy entity. Wanders idly, aggroes on nearby player, chases and attacks.
## Uses the same component wiring pattern as player.gd and monster_base.gd.

const GRAVITY: float = 9.8
const MOVE_SPEED: float = 1.0
const WANDER_INTERVAL_MIN: float = 3.0
const WANDER_INTERVAL_MAX: float = 5.0
const AGGRO_RANGE: float = 15.0
const LEASH_RANGE: float = 30.0

const ModelHelper = preload("res://scripts/utils/model_helper.gd")
const EntityVisuals = preload("res://scripts/components/entity_visuals.gd")
const StatsComponent = preload("res://scripts/components/stats_component.gd")
const CombatComponent = preload("res://scripts/components/combat_component.gd")
const AutoAttackComponent = preload("res://scripts/components/auto_attack_component.gd")
const PerceptionComponent = preload("res://scripts/components/perception_component.gd")

@export var entity_id: String = ""

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var _state: String = "idle"
var _attack_target: String = ""
var _spawn_point: Vector3 = Vector3.ZERO

# Wander state
var _wander_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _is_wandering: bool = false
var _nav_wait_frames: int = 0

# Aggro check throttle
var _aggro_check_timer: float = 0.0
var _hit_stagger_timer: float = 0.0
var _last_attacker_id: String = ""
var _hurtbox_mesh: MeshInstance3D

# Components (declared as Node for duck typing)
var _visuals: Node
var _stats: Node
var _combat: Node
var _auto_attack: Node
var _perception: Node


func _ready() -> void:
	call_deferred("_capture_spawn_point")

	if entity_id.is_empty():
		entity_id = "zombie_%d" % get_instance_id()

	collision_layer = 1 | (1 << 8)

	_visuals = EntityVisuals.new()
	_visuals.name = "EntityVisuals"
	add_child(_visuals)
	_visuals.setup_model_with_anims(
		"res://assets/models/characters/zombie.fbx",
		ModelHelper.ZOMBIE_ANIM_PATHS,
		1.5,
		Color(0.4, 0.5, 0.3)
	)
	var base_stats: Dictionary = {
		"hp": 10, "max_hp": 10,
		"atk": 5, "def": 0,
		"attack_speed": 0.8, "attack_speed_mult": 1.0,
		"attack_range": 2.5,
		"move_speed": 0.7,
		"max_stamina": 0, "stamina_regen": 0,
		"hp_regen": 0,
		"level": 1,
	}

	_stats = StatsComponent.new()
	_stats.name = "StatsComponent"
	add_child(_stats)
	_stats.setup(base_stats)

	_combat = CombatComponent.new()
	_combat.name = "CombatComponent"
	add_child(_combat)
	_combat.setup(_stats, null)

	_auto_attack = AutoAttackComponent.new()
	_auto_attack.name = "AutoAttackComponent"
	_auto_attack.attack_anim = "Attack"
	_auto_attack.chase_anim = "Walk"
	add_child(_auto_attack)
	_auto_attack.setup(_visuals, _combat, nav_agent)
	_auto_attack.attack_landed.connect(_on_auto_attack_landed)
	_auto_attack.target_lost.connect(_on_auto_attack_target_lost)

	WorldState.register_entity(entity_id, self, {
		"type": "monster",
		"name": "Zombie",
		"hp": base_stats["hp"],
		"max_hp": base_stats["max_hp"],
		"atk": base_stats["atk"],
		"def": base_stats["def"],
		"level": base_stats["level"],
		"attack_speed": base_stats["attack_speed"],
		"attack_range": base_stats["attack_range"],
	})

	var perception_comp := PerceptionComponent.new()
	perception_comp.name = "PerceptionComponent"
	add_child(perception_comp)
	perception_comp.setup()
	_perception = perception_comp

	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.5
	nav_agent.target_desired_distance = 1.0
	nav_agent.path_desired_distance = 1.0

	# Debug hurtbox display
	_hurtbox_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.6
	capsule.height = 2.2
	_hurtbox_mesh.mesh = capsule
	_hurtbox_mesh.position.y = 1.1
	var hurtbox_mat := StandardMaterial3D.new()
	hurtbox_mat.albedo_color = Color(1, 0, 0, 0.15)
	hurtbox_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hurtbox_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hurtbox_mat.no_depth_test = true
	_hurtbox_mesh.material_override = hurtbox_mat
	add_child(_hurtbox_mesh)

	_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	_aggro_check_timer = randf() * 1.0

	GameEvents.entity_died.connect(_on_entity_died)


func _capture_spawn_point() -> void:
	_spawn_point = global_position


func _physics_process(delta: float) -> void:
	if _state == "dead":
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _hit_stagger_timer > 0.0:
		_hit_stagger_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	match _state:
		"idle":
			_process_idle(delta)
		"chase":
			_process_chase(delta)
		"combat":
			_process_combat(delta)
		"dead":
			return

	move_and_slide()


# --- State handlers ---

func _process_idle(delta: float) -> void:
	_aggro_check_timer -= delta
	if _aggro_check_timer <= 0.0:
		_aggro_check_timer = 1.0
		_check_aggro()

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_start_wander()

	if _is_wandering:
		_do_wander_movement()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_idle_desynced()


func _start_wander() -> void:
	_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	var offset := Vector3(
		randf_range(-5.0, 5.0),
		0.0,
		randf_range(-5.0, 5.0)
	)
	_wander_target = _spawn_point + offset
	_is_wandering = true
	_nav_wait_frames = 0
	nav_agent.target_position = _wander_target


func _do_wander_movement() -> void:
	if nav_agent.is_navigation_finished():
		_is_wandering = false
		velocity.x = 0.0
		velocity.z = 0.0
		_play_idle_desynced()
		return

	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var dir: Vector3 = next_pos - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		var speed: float = MOVE_SPEED * _stats.move_speed
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_visuals.face_direction(dir)
		_visuals.play_anim("Walk")


func _check_aggro() -> void:
	var nearby: Array = _perception.get_nearby(AGGRO_RANGE)
	for entry in nearby:
		var data: Dictionary = WorldState.get_entity_data(entry.id)
		if data.get("type", "") == "player" and WorldState.is_alive(entry.id):
			_attack_target = entry.id
			_state = "chase"
			_is_wandering = false
			return


func _process_chase(delta: float) -> void:
	var target_node: Node3D = WorldState.get_entity(_attack_target)
	if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(_attack_target):
		_drop_aggro()
		return

	var dist: float = global_position.distance_to(target_node.global_position)

	if dist > LEASH_RANGE:
		_drop_aggro()
		return

	if dist <= _stats.attack_range:
		_state = "combat"
		velocity.x = 0.0
		velocity.z = 0.0
		return

	nav_agent.target_position = target_node.global_position

	if not nav_agent.is_navigation_finished():
		var next_pos: Vector3 = nav_agent.get_next_path_position()
		var dir: Vector3 = next_pos - global_position
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			dir = dir.normalized()
			var speed: float = MOVE_SPEED * _stats.move_speed
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_visuals.face_direction(dir)
			_visuals.play_anim("Walk")


func _process_combat(delta: float) -> void:
	var result: Dictionary = _auto_attack.process_attack(
		delta, _attack_target, global_position,
		MOVE_SPEED * _stats.move_speed,
		_stats.attack_range,
		_stats.attack_speed
	)
	if result.get("is_chasing", false):
		_state = "chase"


func _drop_aggro() -> void:
	_attack_target = ""
	_state = "idle"
	_auto_attack.cancel()
	_is_wandering = false
	_wander_timer = randf_range(1.0, 3.0)
	nav_agent.target_position = _spawn_point


# --- Signal handlers ---

func _on_auto_attack_landed(_target_id: String, _damage: int, _target_pos: Vector3) -> void:
	pass


func _on_auto_attack_target_lost() -> void:
	_drop_aggro()


func _on_entity_died(eid: String, _killer_id: String) -> void:
	if eid == entity_id:
		_die()
	elif eid == _attack_target:
		_drop_aggro()


func _die() -> void:
	_state = "dead"
	_auto_attack.cancel()
	_visuals.play_anim("Death")
	_visuals.fade_out()

	# Disable collision so dead zombie doesn't block movement or bullets
	collision_layer = 0
	collision_mask = 0
	var col_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if col_shape:
		col_shape.disabled = true
	if _hurtbox_mesh:
		_hurtbox_mesh.visible = false

	# Knockback away from killer
	var killer: Node3D = WorldState.get_entity(_last_attacker_id) as Node3D
	if killer and is_instance_valid(killer):
		var dir: Vector3 = global_position - killer.global_position
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			velocity = dir.normalized() * 4.0
		else:
			velocity = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 4.0
	else:
		velocity = Vector3.ZERO

	# Let knockback play out briefly before stopping physics
	await get_tree().create_timer(0.3).timeout
	velocity = Vector3.ZERO
	set_physics_process(false)

	await get_tree().create_timer(2.7).timeout
	WorldState.unregister_entity(entity_id)
	queue_free()


## Called directly by CombatComponent on the target entity (no global signal filtering).
func on_hit(attacker_id: String, _damage: int) -> void:
	if _state == "dead":
		return
	_last_attacker_id = attacker_id
	_auto_attack.cancel()
	_visuals.flash_hit()
	velocity = Vector3.ZERO
	# Play Hit at 2x speed; stagger lasts the full animation so it isn't cut short
	var hit_speed: float = 2.0
	var ap: AnimationPlayer = _visuals.get_anim_player()
	var hit_len: float = ap.get_animation("Hit").length / hit_speed if ap and ap.has_animation("Hit") else 0.3
	_hit_stagger_timer = hit_len
	_visuals.play_anim("Hit", true, hit_speed)
	# Reactive aggro: if idle and got hit, aggro on attacker
	if _state == "idle" and not attacker_id.is_empty() and WorldState.get_entity(attacker_id):
		_attack_target = attacker_id
		_is_wandering = false
		_state = "chase"


func _play_idle_desynced() -> void:
	## Play Idle at a random position so 100+ zombies don't all twitch in unison.
	var ap: AnimationPlayer = _visuals.get_anim_player()
	if ap and ap.current_animation != "Idle":
		_visuals.play_anim("Idle")
		if ap.current_animation_length > 0.0:
			ap.seek(randf() * ap.current_animation_length, true)
	elif not ap or not ap.is_playing():
		_visuals.play_anim("Idle")
		if ap and ap.current_animation_length > 0.0:
			ap.seek(randf() * ap.current_animation_length, true)


# --- Hover highlight (duck typing delegations) ---

func highlight() -> void:
	_visuals.highlight()


func unhighlight() -> void:
	_visuals.unhighlight()


func flash_hit() -> void:
	_visuals.flash_hit()
