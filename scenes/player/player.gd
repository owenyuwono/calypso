extends CharacterBody3D
## Player controller with WASD movement, left-click melee attack, and death/respawn.
## Uses Meshy AI swordsman model with separate animation files.

const SPEED: float = 7.2
const GRAVITY: float = 9.8
const MODEL_SCALE: float = 1.5
const DEATH_GOLD_PENALTY_RATIO: float = 0.1
const RESPAWN_TIME: float = 3.0

const ModelHelper = preload("res://scripts/utils/model_helper.gd")
const EntityVisuals = preload("res://scripts/components/entity_visuals.gd")
const StatsComponent = preload("res://scripts/components/stats_component.gd")
const InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const EquipmentComponent = preload("res://scripts/components/equipment_component.gd")
const CombatComponent = preload("res://scripts/components/combat_component.gd")
const AutoAttackComponent = preload("res://scripts/components/auto_attack_component.gd")
const PerceptionComponent = preload("res://scripts/components/perception_component.gd")
const SfxDatabase = preload("res://scripts/audio/sfx_database.gd")
const HitVFX = preload("res://scripts/vfx/hit_vfx.gd")

const ItemDatabase = preload("res://scripts/data/item_database.gd")

var entity_id: String = "player"

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# Navigation
var _is_navigating: bool = false
var _stuck_timer: float = 0.0
var _last_nav_pos: Vector3 = Vector3.ZERO
var _was_moving: bool = false

# Combat
var _attack_target: String = ""
var _is_dead: bool = false
var _respawn_timer: float = 0.0
var _stagger_timer: float = 0.0
var _hitstop_timer: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _last_damage_time: int = 0
var _hp_regen_accumulator: float = 0.0
var _is_attacking: bool = false
var _attack_anim_timer: float = 0.0
var _attack_hit_pending: bool = false
var _attack_hit_timer: float = 0.0

# Gun mode
var _combat_mode: String = "melee"  # "melee" or "gun"
var _gun_cooldown_timer: float = 0.0
var _player_yaw: float = 0.0  # mouse-controlled facing angle
const MOUSE_SENSITIVITY: float = 0.003
var _gun_fire_rate: float = 0.12  # seconds between shots
var _crosshair: Label = null
var _mode_label: Label = null
var _mode_label_timer: float = 0.0

# Combo system
var _combo_step: int = 0
var _combo_window_timer: float = 0.0
var _combo_buffered: bool = false
const COMBO_WINDOW: float = 0.4

# Idle variation
var _idle_timer: float = 0.0
var _idle_next_variation: float = 8.0
const IDLE_ANIMS: PackedStringArray = ["Idle", "Idle_Breathing", "Idle_Breathing_2", "Idle_Breathing_3"]
const IDLE_RARE_ANIMS: PackedStringArray = ["Idle_Rare_Happy", "Idle_Rare_Bored", "Idle_Rare_Looking", "Idle_Rare_Look"]
const IDLE_TIRED_ANIMS: PackedStringArray = ["Idle_Tired_Sweat", "Idle_Tired_Shoulder", "Idle_Tired_Neck"]

# Audio component
var _audio: Node

# Visuals component
var _visuals: Node
var _stats: Node
var _inventory: Node
var _equipment: Node
var _combat: Node
var _auto_attack: Node
var _perception: Node
var _stamina: Node
var _ammo: Node

# Child subsystem nodes
var _hover: Node
var _debug_block_ring: MeshInstance3D = null

# UI references (set by main scene setup)
var game_menu: Node


func _ready() -> void:
	add_to_group("player")
	collision_layer |= (1 << 8)

	_visuals = EntityVisuals.new()
	_visuals.name = "EntityVisuals"
	add_child(_visuals)
	_visuals.setup_model_with_anims(
		"res://assets/models/characters/player.fbx",
		ModelHelper.DEFAULT_ANIM_PATHS,
		MODEL_SCALE,
		Color(0.2, 0.4, 0.7)
	)

	_audio = preload("res://scripts/audio/audio_component.gd").new()
	_audio.name = "AudioComponent"
	add_child(_audio)
	_audio.setup(self)

	var base_stats: Dictionary = {
		"hp": 50, "max_hp": 50, "atk": 5, "def": 3,
		"attack_speed": 1.5, "attack_speed_mult": 1.0,
		"attack_range": 2.5, "move_speed": 1.0,
		"max_stamina": 100, "stamina_regen": 1.0, "hp_regen": 0.0,
		"level": 1, "gold": 100,
	}

	_stats = StatsComponent.new()
	_stats.name = "StatsComponent"
	add_child(_stats)
	_stats.setup(base_stats)

	_inventory = InventoryComponent.new()
	_inventory.name = "InventoryComponent"
	add_child(_inventory)
	_inventory.setup({"basic_sword": 1}, base_stats.get("gold", 100))

	_equipment = EquipmentComponent.new()
	_equipment.name = "EquipmentComponent"
	add_child(_equipment)
	_equipment.setup({
		"head": "", "torso": "", "legs": "", "gloves": "",
		"feet": "", "back": "", "main_hand": "", "off_hand": "",
	}, _inventory)
	_equipment.equipment_changed.connect(_on_equipment_changed)

	_combat = CombatComponent.new()
	_combat.name = "CombatComponent"
	add_child(_combat)
	_combat.setup(_stats, _equipment)

	_auto_attack = AutoAttackComponent.new()
	_auto_attack.name = "AutoAttackComponent"
	add_child(_auto_attack)
	_auto_attack.setup(_visuals, _combat, nav_agent)
	_auto_attack.attack_landed.connect(_on_auto_attack_landed)
	_auto_attack.target_lost.connect(_on_auto_attack_target_lost)

	var entity_stats: Dictionary = base_stats.duplicate()
	entity_stats["type"] = "player"
	entity_stats["name"] = "Player"
	entity_stats["inventory"] = {}
	entity_stats["equipment"] = {"head": "", "torso": "", "legs": "", "gloves": "", "feet": "", "back": "", "main_hand": "", "off_hand": ""}
	WorldState.register_entity("player", self, entity_stats)

	# Add StaminaComponent
	var stamina_comp := preload("res://scripts/components/stamina_component.gd").new()
	stamina_comp.name = "StaminaComponent"
	add_child(stamina_comp)
	stamina_comp.setup_rest_spots(["TownWell", "TownInn"])
	_stamina = stamina_comp
	_combat.set_stamina(_stamina)

	var perception_comp := PerceptionComponent.new()
	perception_comp.name = "PerceptionComponent"
	add_child(perception_comp)
	perception_comp.setup()
	_perception = perception_comp

	var ammo_comp := preload("res://scripts/components/ammo_component.gd").new()
	ammo_comp.name = "AmmoComponent"
	add_child(ammo_comp)
	ammo_comp.setup("player", 12, 1.5, 48)
	_ammo = ammo_comp

	# Hover subsystem
	_hover = preload("res://scenes/player/player_hover.gd").new()
	_hover.name = "PlayerHover"
	add_child(_hover)
	_hover.setup(self)

	# Player HP is shown in HUD, no 3D bar needed

	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_damaged.connect(_on_entity_damaged)
	GameEvents.damage_defended.connect(_on_damage_defended)

	# Crosshair (only visible in gun mode)
	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.add_theme_font_size_override("font_size", 32)
	_crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.anchors_preset = Control.PRESET_CENTER
	_crosshair.visible = false
	# Need a CanvasLayer to show it on screen
	var crosshair_layer := CanvasLayer.new()
	crosshair_layer.layer = 10
	add_child(crosshair_layer)
	crosshair_layer.add_child(_crosshair)

	# Mode label (temporary popup)
	_mode_label = Label.new()
	_mode_label.add_theme_font_size_override("font_size", 24)
	_mode_label.add_theme_color_override("font_color", Color(1, 1, 0.5))
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.anchors_preset = Control.PRESET_CENTER_TOP
	_mode_label.position.y = 60
	_mode_label.visible = false
	crosshair_layer.add_child(_mode_label)

func _physics_process(delta: float) -> void:
	if _gun_cooldown_timer > 0.0:
		_gun_cooldown_timer -= delta
	if _mode_label_timer > 0.0:
		_mode_label_timer -= delta
		if _mode_label_timer <= 0.0:
			_mode_label.visible = false

	if _hitstop_timer > 0.0:
		_hitstop_timer -= delta
		# Freeze animation for hit stop effect
		var anim_p: AnimationPlayer = _visuals.get_anim_player() if _visuals else null
		if anim_p:
			anim_p.speed_scale = 0.0
		if _hitstop_timer <= 0.0 and anim_p:
			anim_p.speed_scale = 1.0
		return

	if _is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.lerp(Vector3.ZERO, 0.15)
		move_and_slide()
		return

	# Block/parry input (F key)
	var was_blocking: bool = _combat.is_blocking()
	if not _is_ui_open():
		if Input.is_action_pressed("defend"):
			if not _combat.is_blocking() and not _combat.is_guard_broken():
				_combat.start_blocking()
				if not _attack_target.is_empty():
					_cancel_attack()
				_is_attacking = false
		elif _combat.is_blocking():
			_combat.stop_blocking()
			_visuals.clear_overlay()
	elif _combat.is_blocking():
		_combat.stop_blocking()
		_visuals.clear_overlay()

	# Update block tint every frame based on parry window state
	if _combat.is_blocking():
		if _combat.is_in_parry_window():
			_visuals.set_state_tint(Color(0.0, 0.9, 1.0, 0.5))
		else:
			_visuals.set_state_tint(Color(0.3, 0.5, 1.0, 0.4))

	if _combat.is_blocking() or _combat.is_guard_broken():
		_combat.tick_block(delta)
		# Check if guard just broke
		if was_blocking and not _combat.is_blocking() and _combat.is_guard_broken():
			_visuals.set_state_tint(Color(1.0, 0.2, 0.1, 0.5))
			if _audio:
				_audio.play_oneshot("combat_guard_break")
			var tween := create_tween()
			tween.tween_callback(_visuals.clear_overlay).set_delay(0.5)

	_update_debug_block_ring()

	# Face mouse cursor — raycast from camera through mouse position to ground plane (Y=0)
	_update_facing_to_mouse()

	# Auto-fire gun while holding left mouse button
	if _combat_mode == "gun" and not _is_ui_open() and not _combat.is_blocking() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_fire_gun()

	var is_moving := false

	# WASD input (camera-relative direct movement)
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)
	var wasd_active: bool = input_dir.length_squared() > 0.01 and not _is_ui_open()

	if _is_ui_open():
		_stop_navigation()
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
	elif wasd_active:
		# WASD cancels any active navigation/combat
		if _is_navigating:
			_stop_navigation()
		if not _attack_target.is_empty():
			_cancel_attack()
		_is_attacking = false
		_combo_step = 0
		_combo_window_timer = 0.0
		_combo_buffered = false
		# Absolute direction (W=north, S=south, A=west, D=east)
		var move_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()
		var effective_speed: float = SPEED * _stats.move_speed
		if _stamina:
			effective_speed *= _stamina.get_fatigue_multiplier("move_speed")
		if _combat.is_blocking():
			effective_speed *= _combat.get_block_move_speed_mult()
		elif Input.is_action_pressed("sprint"):
			effective_speed *= 1.5
		velocity.x = move_dir.x * effective_speed
		velocity.z = move_dir.z * effective_speed
		is_moving = true
	elif not _attack_target.is_empty():
		is_moving = _process_combat(delta)
	elif _is_navigating and not nav_agent.is_navigation_finished():
		var next_pos := nav_agent.get_next_path_position()
		var dir := (next_pos - global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			dir = dir.normalized()
		var dist_to_target: float = global_position.distance_to(nav_agent.get_final_position())
		var arrive_radius: float = 2.0
		var speed_factor: float = 1.0
		if dist_to_target < arrive_radius:
			speed_factor = clampf(dist_to_target / arrive_radius, 0.15, 1.0)
		var effective_speed: float = SPEED * _stats.move_speed
		if _stamina:
			effective_speed *= _stamina.get_fatigue_multiplier("move_speed")
		velocity.x = dir.x * effective_speed * speed_factor
		velocity.z = dir.z * effective_speed * speed_factor
		_visuals.face_direction(dir)
		is_moving = true
		# Stuck detection: if we haven't moved 0.1 units in 1.5 seconds, abort navigation
		if global_position.distance_to(_last_nav_pos) > 0.1:
			_last_nav_pos = global_position
			_stuck_timer = 0.0
		else:
			_stuck_timer += delta
			if _stuck_timer >= 1.5:
				_stuck_timer = 0.0
				_stop_navigation()
	else:
		if _is_navigating:
			_is_navigating = false
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	move_and_slide()

	# Safety teleport if fallen off the world (skip when inside an interior at Y=-50)
	if global_position.y < -10.0:
		global_position = Vector3(0.0, 2.0, 0.0)
		velocity = Vector3.ZERO

	# HP Regen (out of combat only, 5 second delay after last damage)
	if _stats and _stats.hp_regen > 0 and _stats.hp < _stats.max_hp:
		var can_regen: bool = _last_damage_time == 0 or (Time.get_ticks_msec() - _last_damage_time) > 5000
		if can_regen:
			var regen_amount: float = _stats.hp_regen * delta
			_hp_regen_accumulator += regen_amount
			if _hp_regen_accumulator >= 1.0:
				var heal_amount: int = int(_hp_regen_accumulator)
				_stats.heal(heal_amount)
				_hp_regen_accumulator -= heal_amount

	# Melee attack animation lock
	if _is_attacking:
		_attack_anim_timer -= delta
		# Hit detection at the swing's impact point
		if _attack_hit_pending:
			_attack_hit_timer -= delta
			if _attack_hit_timer <= 0.0:
				_attack_hit_pending = false
				_resolve_melee_hit()
		if _attack_anim_timer <= 0.0:
			_is_attacking = false
			var ap: AnimationPlayer = _visuals.get_anim_player() if _visuals else null
			if ap:
				ap.speed_scale = 1.0
			# Check for buffered combo input
			if _combo_buffered and _combo_step == 0:
				_start_attack(1)
			elif _combo_step == 0:
				_combo_window_timer = COMBO_WINDOW
				_visuals.crossfade_anim("Idle", 0.15)
			else:
				_combo_step = 0
				_combo_window_timer = 0.0
				_visuals.crossfade_anim("Idle", 0.15)

	# Tick combo window timer
	if _combo_window_timer > 0.0 and not _is_attacking:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			_combo_step = 0

	# Update animation
	if not _is_attacking and _attack_target.is_empty():
		if is_moving:
			_idle_timer = 0.0
			# Check actual AnimationPlayer state to avoid desyncs
			var ap: AnimationPlayer = _visuals.get_anim_player() if _visuals else null
			if not ap or ap.current_animation != "Running" or not ap.is_playing():
				_visuals.play_anim("Running")
		else:
			_idle_timer += delta
			if _idle_timer >= _idle_next_variation:
				_idle_timer = 0.0
				_idle_next_variation = randf_range(5.0, 12.0)
				_visuals.crossfade_anim(_pick_idle_anim(), 0.5, true)
			elif _was_moving:
				_idle_next_variation = randf_range(5.0, 12.0)
				_visuals.crossfade_anim("Idle", 0.15)

	# Footstep audio: trigger on movement state transitions
	if is_moving and not _was_moving:
		if _audio:
			_audio.start_footsteps("stone")
	elif not is_moving and _was_moving:
		if _audio:
			_audio.stop_footsteps()
	_was_moving = is_moving


func _process_combat(delta: float) -> bool:
	var attack_range: float = _stats.attack_range
	var effective_attack_speed: float = _stats.attack_speed / _stats.attack_speed_mult
	if _stamina:
		effective_attack_speed /= _stamina.get_fatigue_multiplier("attack_speed")
	var effective_move_speed: float = SPEED * _stats.move_speed
	if _stamina:
		effective_move_speed *= _stamina.get_fatigue_multiplier("move_speed")

	# Normal auto-attack: delegate to component
	var result: Dictionary = _auto_attack.process_attack(
		delta, _attack_target, global_position, effective_move_speed, attack_range, effective_attack_speed
	)
	return result.get("is_moving", false)

func _cancel_attack() -> void:
	_attack_target = ""
	_auto_attack.cancel()
	_combo_step = 0
	_combo_window_timer = 0.0
	_combo_buffered = false
	if _audio:
		_audio.stop_combat_loop()

func _get_attack_anim(combo_step: int) -> String:
	if _equipment and not _equipment.get_weapon().is_empty():
		return "Attack" if combo_step == 0 else "Attack_Slash_02"
	else:
		return "Punch_01" if combo_step == 0 else "Punch_02"

func _start_attack(step: int) -> void:
	var anim_name: String = _get_attack_anim(step)
	var is_unarmed: bool = not _equipment or _equipment.get_weapon().is_empty()
	var anim_speed: float = 2.5 if is_unarmed else 2.0
	_visuals.play_anim(anim_name, true, anim_speed)
	_is_attacking = true
	_combo_step = step
	_combo_buffered = false
	_combo_window_timer = 0.0
	var hit_delay: float = _visuals.get_hit_delay(anim_name) * 0.5
	_attack_anim_timer = hit_delay * 2.0
	_attack_hit_pending = true
	_attack_hit_timer = hit_delay
	if _audio:
		_audio.start_combat_loop()

func _update_facing_to_mouse() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_from: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_pos)
	# Intersect with Y=0 ground plane
	if absf(ray_dir.y) < 0.001:
		return
	var t: float = -ray_from.y / ray_dir.y
	if t < 0.0:
		return
	var ground_point: Vector3 = ray_from + ray_dir * t
	var dir: Vector3 = ground_point - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		return
	dir = dir.normalized()
	_player_yaw = atan2(dir.x, dir.z)
	_visuals.face_direction(dir)


func _get_facing_dir() -> Vector3:
	return Vector3(sin(_player_yaw), 0.0, cos(_player_yaw))

func _show_debug_hitbox(half_width: float, depth: float, forward_offset: float, duration: float = 0.2) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(half_width * 2.0, 1.5, depth)
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	# Position box in front of player along facing direction
	var facing: Vector3 = _get_facing_dir()
	get_tree().current_scene.add_child(mesh_inst)
	mesh_inst.global_position = global_position + facing * forward_offset + Vector3(0, 0.75, 0)
	mesh_inst.rotation.y = _visuals.get_model().rotation.y if _visuals and _visuals.get_model() else 0.0
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.tween_callback(mesh_inst.queue_free)

func _update_debug_block_ring() -> void:
	if not OS.is_debug_build():
		return
	var should_show: bool = _combat.is_blocking() or _combat.is_guard_broken()
	if should_show:
		if not _debug_block_ring or not is_instance_valid(_debug_block_ring):
			_debug_block_ring = MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 1.2
			torus.outer_radius = 1.5
			torus.rings = 32
			torus.ring_segments = 16
			_debug_block_ring.mesh = torus
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_debug_block_ring.material_override = mat
			get_tree().current_scene.add_child(_debug_block_ring)
		_debug_block_ring.global_position = global_position + Vector3(0, 0.05, 0)
		_debug_block_ring.rotation.x = -PI / 2.0  # Lay flat
		var mat: StandardMaterial3D = _debug_block_ring.material_override
		if _combat.is_guard_broken():
			mat.albedo_color = Color(1.0, 0.2, 0.1, 0.35)
		elif _combat.is_in_parry_window():
			mat.albedo_color = Color(0.0, 1.0, 1.0, 0.4)
		else:
			mat.albedo_color = Color(0.2, 0.4, 1.0, 0.25)
	elif _debug_block_ring and is_instance_valid(_debug_block_ring):
		_debug_block_ring.queue_free()
		_debug_block_ring = null

func _resolve_melee_hit() -> void:
	if not _perception or not _combat:
		return
	var attack_range: float = _stats.attack_range if _stats else 3.0
	var is_unarmed: bool = not _equipment or _equipment.get_weapon().is_empty()
	if is_unarmed:
		attack_range *= 0.75
	var facing: Vector3 = _get_facing_dir()
	var half_width: float = attack_range * 0.5
	var depth: float = attack_range
	var forward_offset: float = attack_range * 0.4
	_show_debug_hitbox(half_width, depth, forward_offset)
	# Only hit enemies in front of the player within the hitbox
	var hitbox_center: Vector3 = global_position + facing * forward_offset
	var nearby: Array = _perception.get_nearby(attack_range * 2.0)
	var hit_landed: bool = false
	for entity_data: Dictionary in nearby:
		var eid: String = entity_data.get("id", "")
		var edata: Dictionary = WorldState.get_entity_data(eid)
		if edata.get("type", "") != "monster":
			continue
		if not WorldState.is_alive(eid):
			continue
		var target_node: Node = WorldState.get_entity(eid)
		if not target_node or not is_instance_valid(target_node):
			continue
		# Check if target is inside the forward hitbox
		var to_target: Vector3 = target_node.global_position - hitbox_center
		to_target.y = 0.0
		# Project onto facing axis (depth) and perpendicular axis (width)
		var along: float = to_target.dot(facing)
		var perp: float = abs(to_target.dot(facing.cross(Vector3.UP)))
		if not (abs(along) <= depth * 0.5 and perp <= half_width):
			continue
		var target_pos: Vector3 = target_node.global_position

		# Base damage: effective ATK - target effective DEF
		var target_combat: Node = target_node.get_node_or_null("CombatComponent")
		var atk: int = _combat.get_effective_atk()
		var def: int = target_combat.get_effective_def() if target_combat else 0
		var raw_damage: float = maxf(1.0, atk - def)

		# Physical type modifier (weapon phys_type vs target armor type)
		var phys_type: String = _combat.get_equipped_phys_type()
		var armor_type: String = target_combat.get_armor_type() if target_combat else "light"
		var armor_table: Dictionary = ItemDatabase.ARMOR_PHYS_TYPE_TABLE.get(armor_type, {})
		var phys_level: String = armor_table.get(phys_type, "neutral")
		var phys_mod: float = ItemDatabase.RESISTANCE_MULTIPLIERS.get(phys_level, 1.0)

		# Element resistance (auto-attacks use target's per-phys_type resistance)
		var target_resistances: Dictionary = edata.get("resistances", {})
		var resist_mod: float = 1.0
		if target_resistances.has(phys_type):
			resist_mod = ItemDatabase.RESISTANCE_MULTIPLIERS.get(target_resistances[phys_type], 1.0)

		var combined_mod: float = phys_mod * resist_mod
		var damage: int = maxi(1, int(raw_damage * combined_mod)) if combined_mod > 0.0 else 0

		# Apply damage — use actual damage dealt (respects block/parry)
		var actual_damage: int = 0
		if damage > 0:
			actual_damage = _combat.apply_flat_damage_to(eid, damage)
			if actual_damage > 0 and not hit_landed:
				_hitstop_timer = 0.1
				hit_landed = true

		# VFX and flash
		if actual_damage > 0:
			var hit_vfx_pos: Vector3 = target_node.global_position + Vector3(0, 1.0, 0)
			HitVFX.spawn_hit_effect(self, hit_vfx_pos, facing)
			_visuals.flash_target(eid)

		# SFX
		if _audio:
			var weapon_type_sfx: String = _combat.get_equipped_weapon_type()
			var hit_key: String = "combat_hit_" + weapon_type_sfx
			if SfxDatabase.get_sfx(hit_key).is_empty():
				hit_key = "combat_hit_generic"
			_audio.play_oneshot(hit_key)

func _fire_gun() -> void:
	if _gun_cooldown_timer > 0.0:
		return
	if not _stats or not _stats.is_alive():
		return
	if not _ammo.try_consume():
		if not _ammo.is_reloading() and _ammo.get_reserve() > 0:
			_ammo.start_reload()
		return

	_gun_cooldown_timer = _gun_fire_rate
	_visuals.play_anim("Punch_01", true, 3.0)

	# Bullet fires in player's facing direction
	var facing: Vector3 = _get_facing_dir()
	var muzzle_pos: Vector3 = global_position + facing * 1.0 + Vector3(0, 1.2, 0)

	_spawn_muzzle_flash(muzzle_pos)
	if _audio:
		_audio.play_oneshot("combat_hit_generic")

	# Spawn bullet — it detects enemies on its own as it flies
	var bullet_script: GDScript = preload("res://scenes/projectiles/bullet.gd")
	var bullet: Node3D = Node3D.new()
	bullet.set_script(bullet_script)
	bullet.direction = facing
	bullet.shooter_node = self
	bullet.shooter_rid = get_rid()
	bullet.atk = _combat.get_effective_atk()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle_pos

	# Auto-reload when magazine empties
	if _ammo.get_magazine_current() <= 0 and _ammo.get_reserve() > 0:
		_ammo.start_reload()


func _spawn_muzzle_flash(pos: Vector3) -> void:
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh_inst.mesh = sphere
	mesh_inst.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 5.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	get_tree().current_scene.add_child(mesh_inst)
	var tween := mesh_inst.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.1)
	tween.tween_callback(mesh_inst.queue_free)


func _show_mode_label() -> void:
	_mode_label.text = "GUN" if _combat_mode == "gun" else "FISTS"
	_mode_label.visible = true
	_mode_label_timer = 1.5


func _get_approach_pos(target_pos: Vector3, standoff: float) -> Vector3:
	var offset: Vector3 = global_position - target_pos
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		offset = Vector3(1.0, 0.0, 0.0)
	return target_pos + offset.normalized() * standoff

func _stop_navigation() -> void:
	_is_navigating = false


func _input(event: InputEvent) -> void:
	if _is_dead:
		return


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if _combat_mode == "melee":
			_combat_mode = "gun"
			_crosshair.visible = true
		else:
			_combat_mode = "melee"
			_crosshair.visible = false
			_ammo.cancel_reload()
		GameEvents.combat_mode_changed.emit("player", _combat_mode)
		_show_mode_label()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_R and _combat_mode == "gun":
		_ammo.start_reload()
		get_viewport().set_input_as_handled()
		return

	if not _is_ui_open():
		if _combat.is_blocking():
			get_viewport().set_input_as_handled()
			return
		# Left-click basic attack (weapon or unarmed)
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _combat_mode == "gun":
				_fire_gun()
				# Longer initial cooldown so a single click doesn't double-fire
				# (click duration ~0.15s > normal fire_rate 0.12s)
				_gun_cooldown_timer = maxf(_gun_cooldown_timer, 0.25)
				get_viewport().set_input_as_handled()
				return
			if _is_attacking:
				_combo_buffered = true
				get_viewport().set_input_as_handled()
				return
			if _combo_window_timer > 0.0:
				_start_attack(1)
				get_viewport().set_input_as_handled()
				return
			_start_attack(0)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("interact") and not _is_ui_open():
		_interact_with_nearest()

func _interact_with_nearest() -> void:
	var target_id: String = _hover.get_proximity_target_id()
	if target_id.is_empty():
		return
	var data := WorldState.get_entity_data(target_id)
	var etype: String = data.get("type", "")
	var target_node := WorldState.get_entity(target_id)
	if not target_node or not is_instance_valid(target_node):
		return
	# Additional interact types (npc, door, etc.) handled by their own systems

func _is_ui_open() -> bool:
	if game_menu and game_menu.is_open():
		return true
	return false

# --- Death / Respawn ---

func _on_entity_died(eid: String, _killer_id: String) -> void:
	if eid == _attack_target:
		_attack_target = ""
	if eid != "player":
		return
	_die()

func _die() -> void:
	_is_dead = true
	_cancel_attack()
	_stop_navigation()
	_ammo.cancel_reload()
	velocity = Vector3.ZERO
	if _audio:
		_audio.play_oneshot("combat_death")
		_audio.stop_all_loops()

	# Lose 10% gold
	var lost := EntityHelpers.apply_death_gold_penalty(_inventory, DEATH_GOLD_PENALTY_RATIO)

	# Visual: death animation + fade out
	_visuals.play_anim("Death_A")
	_visuals.fade_out()

	_respawn_timer = RESPAWN_TIME

func _respawn() -> void:
	_is_dead = false
	_visuals.reset_anim()

	# Restore HP via StatsComponent (source of truth)
	_stats.restore_full_hp()

	# Visual: restore materials and play idle
	_visuals.restore_materials()
	_visuals.play_anim("Idle")

	GameEvents.entity_respawned.emit("player")

	var city_spawn: Vector3 = Vector3(0.0, 1.0, 0.0)
	var loaded_zone: Node3D = ZoneManager.get_loaded_zone()
	var current_zone_id: String = ""
	if loaded_zone and "zone_id" in loaded_zone:
		current_zone_id = loaded_zone.zone_id

	if current_zone_id == "zone_suburb":
		# Already in suburb — just teleport to spawn point
		global_position = city_spawn
		velocity = Vector3.ZERO
	elif not ZoneManager.is_transitioning():
		# In a field or unknown zone — load suburb
		ZoneManager.load_zone("zone_suburb", city_spawn)

func _on_entity_damaged(target_id: String, attacker_id: String, _damage: int, _remaining_hp: int) -> void:
	if target_id == "player":
		if _combat.is_blocking():
			# Block absorbs hit reaction — no stagger/knockback
			_last_damage_time = Time.get_ticks_msec()
			_hp_regen_accumulator = 0.0
			return
		flash_hit()
		_stagger_timer = 0.3
		_hitstop_timer = 0.1
		var attacker_node: Node3D = WorldState.get_entity(attacker_id) as Node3D
		if attacker_node and is_instance_valid(attacker_node):
			var dir: Vector3 = (global_position - attacker_node.global_position)
			dir.y = 0.0
			if dir.length_squared() > 0.01:
				_knockback_velocity = dir.normalized() * 5.0
		_visuals.play_anim("Hit", true)
		_last_damage_time = Time.get_ticks_msec()
		_hp_regen_accumulator = 0.0

func _on_damage_defended(target_id: String, _attacker_id: String, _amount_negated: int, defense_type: String) -> void:
	if target_id != "player":
		return
	if defense_type == "parried":
		_visuals.set_state_tint(Color(0.0, 1.0, 1.0, 0.7))
		var tween := create_tween()
		tween.tween_callback(_restore_block_tint).set_delay(0.3)
		if _audio:
			_audio.play_oneshot("combat_parry")
	elif defense_type == "blocked":
		if _audio:
			_audio.play_oneshot("combat_block")
	elif defense_type == "guard_break":
		_visuals.set_state_tint(Color(1.0, 0.2, 0.1, 0.5))
		var tween := create_tween()
		tween.tween_callback(_visuals.clear_overlay).set_delay(0.5)
		if _audio:
			_audio.play_oneshot("combat_guard_break")

func _on_auto_attack_landed(target_id: String, _damage: int, _target_pos: Vector3) -> void:
	_visuals.flash_target(target_id)
	var weapon_type: String = _combat.get_equipped_weapon_type() if _combat else "generic"
	if _audio:
		var hit_key: String = "combat_hit_" + weapon_type
		if SfxDatabase.get_sfx(hit_key).is_empty():
			hit_key = "combat_hit_generic"
		_audio.play_oneshot(hit_key)

func _on_auto_attack_target_lost() -> void:
	_cancel_attack()

func _on_equipment_changed(slot: String, item_id: String) -> void:
	if slot == "main_hand":
		_visuals.update_weapon_visual(not item_id.is_empty())

# --- Duck typing delegations ---

func flash_hit() -> void:
	_visuals.flash_hit()

func _restore_block_tint() -> void:
	if _combat.is_blocking():
		if _combat.is_in_parry_window():
			_visuals.set_state_tint(Color(0.0, 0.9, 1.0, 0.5))
		else:
			_visuals.set_state_tint(Color(0.3, 0.5, 1.0, 0.4))
	else:
		_visuals.clear_overlay()

func _pick_idle_anim() -> String:
	# If stamina is low, use tired idles
	if _stamina and _stamina.get_stamina_percent() < 0.3:
		return IDLE_TIRED_ANIMS[randi() % IDLE_TIRED_ANIMS.size()]
	# 20% chance for rare idle
	if randf() < 0.2:
		return IDLE_RARE_ANIMS[randi() % IDLE_RARE_ANIMS.size()]
	return IDLE_ANIMS[randi() % IDLE_ANIMS.size()]

