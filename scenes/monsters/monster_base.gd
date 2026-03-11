extends CharacterBody3D
## Monster entity with aggro AI, auto-attack, death, and loot.
## Dynamically loads 3D models based on monster type from MonsterDatabase.

const MonsterDatabase = preload("res://scripts/data/monster_database.gd")
const ItemDatabase = preload("res://scripts/data/item_database.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")

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
var _death_tween: Tween
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

# 3D Model
var _model: Node3D
var _mesh_instances: Array[MeshInstance3D] = []
var _overlay_material: StandardMaterial3D
var _anim_player: AnimationPlayer
var _current_anim: String = ""
var _hp_bar: Node3D

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

	# Setup 3D model
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
	_setup_hp_bar()

	# Connect signals
	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_damaged.connect(_on_entity_damaged)
	GameEvents.entity_healed.connect(_on_entity_healed)

func _setup_model(stats: Dictionary) -> void:
	var model_scene_path: String = stats.get("model_scene", "")
	var scale_val: float = stats.get("model_scale", 0.7)

	if model_scene_path.is_empty():
		# No model defined — create colored mesh fallback
		_create_fallback_mesh(stats)
		return

	if model_scene_path == "SLIME_PROCEDURAL":
		_create_slime_mesh(stats)
		return

	var result := ModelHelper.instantiate_model(model_scene_path, scale_val)
	if result.model == null:
		_create_fallback_mesh(stats)
		return

	_model = result.model
	add_child(_model)
	_anim_player = result.anim_player

	_mesh_instances = ModelHelper.find_mesh_instances(_model)
	_overlay_material = ModelHelper.create_overlay_material()
	ModelHelper.apply_overlay(_mesh_instances, _overlay_material)
	ModelHelper.apply_toon_to_model(_model)

	# Apply color tint overlay for recolored monsters (goblin, dark_mage)
	var tint_color: Color = stats.get("model_tint", Color(0, 0, 0, 0))
	if tint_color.a > 0:
		_overlay_material.albedo_color = tint_color

	if _anim_player:
		_play_anim("Idle")

func _create_slime_mesh(stats: Dictionary) -> void:
	_model = Node3D.new()
	add_child(_model)

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

	_model.add_child(mesh_inst)
	_mesh_instances = [mesh_inst]
	_overlay_material = ModelHelper.create_overlay_material()
	ModelHelper.apply_overlay(_mesh_instances, _overlay_material)
	ModelHelper.apply_toon_to_model(_model)

	# Wobble animation via tween
	var tween := create_tween().set_loops()
	tween.tween_property(_model, "scale", Vector3(1.1, 0.9, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_model, "scale", Vector3(0.9, 1.1, 0.9), 0.5).set_trans(Tween.TRANS_SINE)

func _create_fallback_mesh(stats: Dictionary) -> void:
	var result := ModelHelper.create_fallback_mesh(self, stats.get("color", Color.WHITE), true)
	_model = result.model
	_mesh_instances = result.mesh_instances
	_overlay_material = result.overlay

func _play_anim(anim_name: String, force: bool = false) -> void:
	if not _anim_player:
		return
	if not force and _current_anim == anim_name and _anim_player.is_playing():
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)
		_current_anim = anim_name

func _face_direction(dir: Vector3) -> void:
	ModelHelper.face_direction(_model, dir)

func _setup_hp_bar() -> void:
	_hp_bar = ModelHelper.create_hp_bar(self, 2.0)

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
		_play_anim("Walking_A")
	else:
		_play_anim("Idle")

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
		_face_direction(dir)

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
			_face_direction(dir)
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
	_face_direction(to_target)

	# Check animation position for hit event before starting new attacks
	if _pending_hit:
		if _anim_player and _anim_player.current_animation == "1H_Melee_Attack_Chop":
			if _anim_player.current_animation_position >= _hit_time:
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
			_play_anim("1H_Melee_Attack_Chop", true)
			_pending_hit = true
			_hit_time = _get_hit_delay("1H_Melee_Attack_Chop")

func _perform_attack() -> void:
	if not WorldState.is_alive(aggro_target):
		_drop_aggro()
		return
	var damage := WorldState.deal_damage(monster_id, aggro_target)
	_spawn_damage_number(aggro_target, damage)
	_flash_target(aggro_target)

func _drop_aggro() -> void:
	aggro_target = ""
	state = "idle"
	_pending_hit = false
	_wander_timer = randf_range(1.0, 3.0)
	_last_nav_target_pos = Vector3.INF
	# Return to spawn area
	nav_agent.target_position = spawn_point

func _on_entity_damaged(target_id: String, _attacker_id: String, _damage: int, _remaining_hp: int) -> void:
	if target_id == monster_id:
		_update_hp_bar()

func _on_entity_healed(entity_id: String, _amount: int, _current_hp: int) -> void:
	if entity_id == monster_id:
		_update_hp_bar()

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
	_play_anim("Death_A")
	if _death_tween:
		_death_tween.kill()
	_death_tween = ModelHelper.fade_out(_mesh_instances, self)

	if _hp_bar:
		_hp_bar.visible = false
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
	_current_anim = ""
	global_position = spawn_point
	collision_shape.disabled = false

	# Restore model visuals
	if _model:
		_model.scale = Vector3.ONE * stats.get("model_scale", 0.7)
	ModelHelper.restore_materials(_mesh_instances)
	if _overlay_material:
		# Restore tint if applicable
		var tint_color: Color = stats.get("model_tint", Color(0, 0, 0, 0))
		_overlay_material.albedo_color = tint_color

	if _hp_bar:
		_hp_bar.visible = true
	if name_label:
		name_label.visible = true

	_play_anim("Idle")
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
	_update_hp_bar()

func _update_hp_bar() -> void:
	if state == "dead":
		return
	ModelHelper.update_entity_hp_bar(_hp_bar, monster_id)

func _spawn_damage_number(target_id: String, damage: int) -> void:
	ModelHelper.spawn_damage_number(self, target_id, damage, Color(1, 0.2, 0.2))

func _flash_target(target_id: String) -> void:
	ModelHelper.flash_target(target_id)

# --- Hover Highlight ---

func highlight() -> void:
	if _overlay_material:
		ModelHelper.set_highlight(_overlay_material, true)

func unhighlight() -> void:
	if _overlay_material:
		ModelHelper.set_highlight(_overlay_material, false)

func flash_hit() -> void:
	if not _overlay_material:
		return
	ModelHelper.flash_hit(_overlay_material, self)

func _get_hit_delay(anim_name: String) -> float:
	return ModelHelper.get_hit_delay(_anim_player, anim_name)

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
