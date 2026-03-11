extends CharacterBody3D
## Monster entity with aggro AI, auto-attack, death, and loot.
## Dynamically loads 3D models based on monster type from MonsterDatabase.

const EntityVisuals = preload("res://scripts/components/entity_visuals.gd")
const MonsterDatabase = preload("res://scripts/data/monster_database.gd")
const ItemDatabase = preload("res://scripts/data/item_database.gd")

@export var monster_type: String = "slime"
@export var monster_id: String = ""

const GRAVITY: float = 9.8
const MOVE_SPEED: float = 3.0
const WANDER_INTERVAL_MIN: float = 3.0
const WANDER_INTERVAL_MAX: float = 5.0

# States
var state: String = "idle"  # idle, wandering, aggro, attacking, dead
var spawn_point: Vector3
var aggro_target: String = ""
var _attack_timer: float = 0.0
var _wander_timer: float = 0.0
var _respawn_timer: float = 0.0
var _nav_started: bool = false
var _nav_wait_frames: int = 0
var _aggro_check_timer: float = 0.0
var _last_nav_target_pos: Vector3 = Vector3.INF
var _pending_hit: bool = false
var _hit_time: float = 0.0

# Cached stats
var _aggro_range: float = 6.0
var _attack_range: float = 2.0
var _attack_speed: float = 1.5
var _wander_radius: float = 5.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var name_label: Label3D = $NameLabel

# Visuals component
var _visuals: Node

func _ready() -> void:
	spawn_point = global_position
	var stats := MonsterDatabase.get_monster(monster_type)
	if stats.is_empty():
		push_warning("MonsterBase: Unknown monster type '%s'" % monster_type)
		queue_free()
		return

	if monster_id.is_empty():
		monster_id = "%s_%d" % [monster_type, get_instance_id()]

	_aggro_range = stats.get("aggro_range", 6.0)
	_attack_range = stats.get("attack_range", 2.0)
	_attack_speed = stats.get("attack_speed", 1.5)
	_wander_radius = stats.get("wander_radius", 5.0)

	# Setup visuals
	_visuals = EntityVisuals.new()
	add_child(_visuals)
	_setup_model(stats)

	if name_label:
		name_label.text = stats.get("name", monster_type)

	nav_agent.target_desired_distance = 1.0
	nav_agent.path_desired_distance = 1.0

	# Register with WorldState
	WorldState.register_entity(monster_id, self, {
		"type": "monster",
		"name": stats.get("name", monster_type),
		"monster_type": monster_type,
		"hp": stats.get("hp", 0),
		"max_hp": stats.get("hp", 0),
		"atk": stats.get("atk", 0),
		"def": stats.get("def", 0),
		"level": 1,
		"attack_speed": _attack_speed,
		"attack_range": _attack_range,
	})

	_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	_aggro_check_timer = randf() * 0.3  # Stagger initial timer

	# Create HP bar
	_visuals.setup_hp_bar(2.0)

	# Connect signals
	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_damaged.connect(_on_entity_damaged)
	GameEvents.entity_healed.connect(_on_entity_healed)

func _setup_model(stats: Dictionary) -> void:
	var model_scene_path: String = stats.get("model_scene", "")
	var scale_val: float = stats.get("model_scale", 0.7)

	if model_scene_path.is_empty():
		# No model defined — create colored mesh fallback
		_visuals.setup_model("", scale_val, stats.get("color", Color.WHITE), true)
		return

	if model_scene_path == "SLIME_PROCEDURAL":
		_create_slime_mesh(stats)
		return

	_visuals.setup_model(model_scene_path, scale_val, stats.get("color", Color.WHITE), true)

	# Apply color tint overlay for recolored monsters (goblin, dark_mage)
	var tint_color: Color = stats.get("model_tint", Color(0, 0, 0, 0))
	if tint_color.a > 0:
		_visuals.apply_tint(tint_color)

func _create_slime_mesh(stats: Dictionary) -> void:
	var model := Node3D.new()
	add_child(model)

	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 0.8
	mesh_inst.mesh = sphere
	mesh_inst.position.y = 0.4

	var slime_color: Color = stats.get("color", Color(0.2, 0.8, 0.2))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = slime_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	mesh_inst.set_surface_override_material(0, mat)

	model.add_child(mesh_inst)
	var mesh_instances: Array[MeshInstance3D] = [mesh_inst]
	_visuals.setup_custom_model(model, mesh_instances)

	# Wobble animation via tween
	var tween := create_tween().set_loops()
	tween.tween_property(model, "scale", Vector3(1.1, 0.9, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(model, "scale", Vector3(0.9, 1.1, 0.9), 0.5).set_trans(Tween.TRANS_SINE)

func _physics_process(delta: float) -> void:
	if state == "dead":
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	# Tick aggro check timer
	_aggro_check_timer -= delta

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var is_moving := false
	match state:
		"idle":
			_process_idle(delta)
		"wandering":
			is_moving = _process_wander_movement()
		"aggro":
			is_moving = _process_aggro(delta)
		"attacking":
			_process_attacking(delta)

	if state == "idle" and is_on_floor():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		move_and_slide()

	# Update animation
	if state == "attacking":
		pass  # Attack handles its own anims
	elif state == "dead":
		pass
	elif is_moving:
		_visuals.play_anim("Walking_A")
	else:
		_visuals.play_anim("Idle")

func _process_idle(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_start_wander()

	# Throttled aggro check (every 0.3s)
	if _aggro_check_timer <= 0.0:
		_aggro_check_timer = 0.3
		_check_aggro()

func _start_wander() -> void:
	_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	var offset := Vector3(
		randf_range(-_wander_radius, _wander_radius),
		0,
		randf_range(-_wander_radius, _wander_radius)
	)
	var target_pos := spawn_point + offset
	state = "wandering"
	_nav_started = false
	_nav_wait_frames = 0
	nav_agent.target_position = target_pos

func _process_wander_movement() -> bool:
	if not _nav_started:
		if not nav_agent.is_navigation_finished():
			_nav_started = true
		else:
			_nav_wait_frames += 1
			if _nav_wait_frames > 30:
				state = "idle"
			return false

	if nav_agent.is_navigation_finished():
		state = "idle"
		_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
		return false

	var next_pos := nav_agent.get_next_path_position()
	var dir := (next_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		_visuals.face_direction(dir)

	# Throttled aggro check while wandering
	if _aggro_check_timer <= 0.0:
		_aggro_check_timer = 0.3
		_check_aggro()
	return true

func _check_aggro() -> void:
	var nearby := WorldState.get_nearby_entities(global_position, _aggro_range)
	for entry in nearby:
		if entry.id == monster_id:
			continue
		var data := WorldState.get_entity_data(entry.id)
		var etype: String = data.get("type", "")
		if etype in ["player", "npc"] and WorldState.is_alive(entry.id):
			aggro_target = entry.id
			state = "aggro"
			return

func _process_aggro(delta: float) -> bool:
	var target_node := WorldState.get_entity(aggro_target)
	if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(aggro_target):
		_drop_aggro()
		return false

	var dist := global_position.distance_to(target_node.global_position)

	# Lost interest if too far from spawn
	if global_position.distance_to(spawn_point) > _aggro_range * 3.0:
		_drop_aggro()
		return false

	if dist <= _attack_range:
		state = "attacking"
		_attack_timer = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		return false

	# Chase target — only update nav if target moved significantly
	var target_pos := target_node.global_position
	if _last_nav_target_pos.distance_to(target_pos) > 1.0:
		_last_nav_target_pos = target_pos
		nav_agent.target_position = target_pos
	if not nav_agent.is_navigation_finished():
		var next_pos := nav_agent.get_next_path_position()
		var dir := (next_pos - global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			dir = dir.normalized()
			velocity.x = dir.x * MOVE_SPEED * 1.2
			velocity.z = dir.z * MOVE_SPEED * 1.2
			_visuals.face_direction(dir)
			return true
	return false

func _process_attacking(delta: float) -> void:
	var target_node := WorldState.get_entity(aggro_target)
	if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(aggro_target):
		_drop_aggro()
		return

	var dist := global_position.distance_to(target_node.global_position)
	if dist > _attack_range * 1.5:
		state = "aggro"
		return

	# Face the target
	var to_target := (target_node.global_position - global_position).normalized()
	_visuals.face_direction(to_target)

	# Check animation position for hit event before starting new attacks
	var anim_player: AnimationPlayer = _visuals.get_anim_player()
	if _pending_hit:
		if anim_player and anim_player.current_animation == "1H_Melee_Attack_Chop":
			if anim_player.current_animation_position >= _hit_time:
				_pending_hit = false
				_perform_attack()
		else:
			# Fallback countdown for monsters without attack animation (e.g. slime)
			_hit_time -= delta
			if _hit_time <= 0.0:
				_pending_hit = false
				_perform_attack()

	# Only accumulate attack cooldown after the pending hit has landed
	if not _pending_hit:
		_attack_timer += delta
		if _attack_timer >= _attack_speed:
			_attack_timer = 0.0
			_visuals.play_anim("1H_Melee_Attack_Chop", true)
			_pending_hit = true
			_hit_time = _visuals.get_hit_delay("1H_Melee_Attack_Chop")

func _perform_attack() -> void:
	if not WorldState.is_alive(aggro_target):
		_drop_aggro()
		return
	var target_node := WorldState.get_entity(aggro_target)
	var target_pos := target_node.global_position if target_node else global_position
	var damage := WorldState.deal_damage(monster_id, aggro_target)
	_visuals.spawn_damage_number(aggro_target, damage, Color(1, 0.2, 0.2), target_pos)
	_visuals.flash_target(aggro_target)

func _drop_aggro() -> void:
	aggro_target = ""
	state = "idle"
	_pending_hit = false
	_wander_timer = randf_range(1.0, 3.0)
	_last_nav_target_pos = Vector3.INF
	# Return to spawn area
	nav_agent.target_position = spawn_point

func _on_entity_damaged(target_id: String, _attacker_id: String, _damage: int, _remaining_hp: int) -> void:
	if target_id == monster_id and state != "dead":
		_visuals.update_hp_bar(monster_id)

func _on_entity_healed(entity_id: String, _amount: int, _current_hp: int) -> void:
	if entity_id == monster_id and state != "dead":
		_visuals.update_hp_bar(monster_id)

func _on_entity_died(entity_id: String, killer_id: String) -> void:
	if entity_id == monster_id:
		_die(killer_id)
	elif entity_id == aggro_target:
		_drop_aggro()

func _die(killer_id: String) -> void:
	state = "dead"
	aggro_target = ""
	collision_shape.disabled = true
	velocity = Vector3.ZERO

	# Spawn physical loot drops
	var stats := MonsterDatabase.get_monster(monster_type)
	var gold: int = stats.get("gold", 0)
	var drop_index := 0
	if gold > 0:
		_spawn_loot_drop(global_position, "", 0, gold, drop_index)
		drop_index += 1

	var drops: Array = stats.get("drops", [])
	for drop in drops:
		if randf() <= drop.get("chance", 0.0):
			var item_id: String = drop.get("item", "")
			if not item_id.is_empty():
				_spawn_loot_drop(global_position, item_id, 1, 0, drop_index)
				drop_index += 1

	# Grant XP
	var xp: int = stats.get("xp", 0)
	WorldState.grant_xp(killer_id, xp)

	# Death visual: animation + fade
	_visuals.play_anim("Death_A")
	_visuals.fade_out()

	_visuals.set_hp_bar_visible(false)
	if name_label:
		name_label.visible = false

	# Start respawn timer
	_respawn_timer = randf_range(30.0, 60.0)

	# Unregister temporarily
	WorldState.unregister_entity(monster_id)

func _respawn() -> void:
	var stats := MonsterDatabase.get_monster(monster_type)
	if stats.is_empty():
		push_warning("MonsterBase: Cannot respawn, unknown type '%s'" % monster_type)
		return
	state = "idle"
	_visuals.reset_anim()
	global_position = spawn_point
	collision_shape.disabled = false

	# Restore model visuals
	var model: Node3D = _visuals.get_model()
	if model:
		model.scale = Vector3.ONE * stats.get("model_scale", 0.7)
	_visuals.restore_materials()
	# Restore tint if applicable
	var tint_color: Color = stats.get("model_tint", Color(0, 0, 0, 0))
	_visuals.apply_tint(tint_color)

	_visuals.set_hp_bar_visible(true)
	if name_label:
		name_label.visible = true

	_visuals.play_anim("Idle")
	_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)

	# Re-register
	WorldState.register_entity(monster_id, self, {
		"type": "monster",
		"name": stats.get("name", monster_type),
		"monster_type": monster_type,
		"hp": stats.get("hp", 0),
		"max_hp": stats.get("hp", 0),
		"atk": stats.get("atk", 0),
		"def": stats.get("def", 0),
		"level": 1,
		"attack_speed": _attack_speed,
		"attack_range": _attack_range,
	})

	GameEvents.entity_respawned.emit(monster_id)
	_visuals.update_hp_bar(monster_id)

# --- Hover Highlight (duck typing delegations) ---

func highlight() -> void:
	_visuals.highlight()

func unhighlight() -> void:
	_visuals.unhighlight()

func flash_hit() -> void:
	_visuals.flash_hit()

func _spawn_loot_drop(origin: Vector3, item_id: String, item_count: int, gold: int, index: int) -> void:
	var loot_scene := preload("res://scenes/objects/loot_drop.gd")
	var loot := StaticBody3D.new()
	loot.set_script(loot_scene)
	loot.item_id = item_id
	loot.item_count = item_count
	loot.gold_amount = gold
	# Scatter so multiple drops don't stack
	var offset := Vector3(
		randf_range(-0.8, 0.8),
		0,
		randf_range(-0.8, 0.8)
	)
	if index > 0:
		offset += Vector3(float(index) * 0.5, 0, 0)
	loot.position = origin + offset
	get_tree().current_scene.call_deferred("add_child", loot)
