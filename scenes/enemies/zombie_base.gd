extends CharacterBody3D
## Zombie enemy entity. Wanders idly, aggroes on nearby player, chases and attacks.
## Uses the same component wiring pattern as player.gd and monster_base.gd.

const GRAVITY: float = 9.8
const MOVE_SPEED: float = 4.0
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
		"res://assets/models/characters/player.fbx",
		ModelHelper.DEFAULT_ANIM_PATHS,
		1.5,
		Color(0.4, 0.5, 0.3)
	)

	var base_stats: Dictionary = {
		"hp": 30, "max_hp": 30,
		"atk": 5, "def": 2,
		"matk": 0, "mdef": 0,
		"crit_rate": 0, "crit_damage": 100,
		"attack_speed": 0.8, "attack_speed_mult": 1.0,
		"attack_range": 2.5,
		"move_speed": 0.7,
		"cast_speed": 1.0,
		"max_stamina": 0, "stamina_regen": 0,
		"hp_regen": 0, "cooldown_reduction": 0,
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

	_visuals.setup_hp_bar(2.0, "Zombie")

	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.5
	nav_agent.target_desired_distance = 1.0
	nav_agent.path_desired_distance = 1.0

	_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	_aggro_check_timer = randf() * 1.0

	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_damaged.connect(_on_entity_damaged)


func _capture_spawn_point() -> void:
	_spawn_point = global_position


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

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
		_visuals.play_anim("Idle_Breathing")


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
		_visuals.play_anim("Idle_Breathing")
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
		_visuals.play_anim("Running")


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
			_visuals.play_anim("Running")


func _process_combat(delta: float) -> void:
	var result: Dictionary = _auto_attack.process_attack(
		delta, _attack_target, global_position,
		MOVE_SPEED * _stats.move_speed,
		_stats.attack_range,
		_stats.attack_speed
	)
	_visuals.update_hp_bar_combat(_stats.hp, _stats.max_hp, true)

	if result.get("is_chasing", false):
		_state = "chase"


func _drop_aggro() -> void:
	_attack_target = ""
	_state = "idle"
	_auto_attack.cancel()
	_is_wandering = false
	_wander_timer = randf_range(1.0, 3.0)
	nav_agent.target_position = _spawn_point
	_visuals.set_hp_bar_visible(false)


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
	velocity = Vector3.ZERO
	_auto_attack.cancel()
	_visuals.play_anim("Hit")
	_visuals.fade_out()
	_visuals.set_hp_bar_visible(false)
	set_physics_process(false)

	await get_tree().create_timer(3.0).timeout
	WorldState.unregister_entity(entity_id)
	queue_free()


func _on_entity_damaged(target_id: String, attacker_id: String, _damage: int, _remaining_hp: int) -> void:
	if target_id != entity_id:
		return
	_visuals.flash_hit()
	_visuals.update_hp_bar_combat(_stats.hp, _stats.max_hp, true)
	# Reactive aggro: if idle and got hit, aggro on attacker
	if _state == "idle" and not attacker_id.is_empty() and WorldState.get_entity(attacker_id):
		_attack_target = attacker_id
		_is_wandering = false
		_state = "chase"


# --- Hover highlight (duck typing delegations) ---

func highlight() -> void:
	_visuals.highlight()


func unhighlight() -> void:
	_visuals.unhighlight()


func flash_hit() -> void:
	_visuals.flash_hit()
