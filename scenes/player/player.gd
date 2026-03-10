extends CharacterBody3D
## Player controller with point-and-click movement, click-to-attack/interact, and death/respawn.
## Uses KayKit Knight 3D model with animations.

const SPEED: float = 6.0
const GRAVITY: float = 9.8
const INTERACT_RANGE: float = 4.0
const HOVER_RAY_LENGTH: float = 100.0
const TOOLTIP_OFFSET: Vector2 = Vector2(16, 16)
const MODEL_SCALE: float = 0.7

const LevelData = preload("res://scripts/data/level_data.gd")
const ItemDatabase = preload("res://scripts/data/item_database.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var _hovered_entity_id: String = ""
var _tooltip_label: Label
var _tooltip_panel: PanelContainer
var _hover_timer: float = 0.0

# Navigation
var _is_navigating: bool = false
var _interact_target: String = ""

# Combat
var _attack_target: String = ""
var _attack_timer: float = 0.0
var _is_dead: bool = false
var _respawn_timer: float = 0.0
var _last_nav_target_pos: Vector3 = Vector3.INF

# 3D Model
var _model: Node3D
var _mesh_instances: Array[MeshInstance3D] = []
var _overlay_material: StandardMaterial3D
var _anim_player: AnimationPlayer
var _current_anim: String = ""

# HP bar above player
var _hp_bar: Node3D

# UI references (set by main scene setup)
var shop_panel: Control
var inventory_panel: Control

func _ready() -> void:
	_setup_model()

	var stats := LevelData.BASE_PLAYER_STATS.duplicate()
	stats["type"] = "player"
	stats["name"] = "Player"
	stats["inventory"] = {}
	stats["equipment"] = {"weapon": "", "armor": ""}
	WorldState.register_entity("player", self, stats)

	_setup_tooltip()
	_setup_hp_bar()

	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_damaged.connect(_on_entity_damaged)
	GameEvents.entity_healed.connect(_on_entity_healed)

func _setup_model() -> void:
	var result := ModelHelper.instantiate_model("res://assets/models/characters/Knight.glb", MODEL_SCALE)
	if result.model == null:
		push_warning("Player: Could not load Knight model, using fallback")
		_create_fallback_mesh()
		return

	_model = result.model
	add_child(_model)
	_anim_player = result.anim_player

	_mesh_instances = ModelHelper.find_mesh_instances(_model)
	_overlay_material = ModelHelper.create_overlay_material()
	ModelHelper.apply_overlay(_mesh_instances, _overlay_material)
	ModelHelper.apply_toon_to_model(_model)

	if _anim_player:
		_play_anim("Idle")

func _create_fallback_mesh() -> void:
	_model = Node3D.new()
	add_child(_model)
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.2
	mesh_inst.mesh = capsule
	mesh_inst.position.y = 0.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.4, 0.7)
	mesh_inst.mesh.surface_set_material(0, mat)
	_model.add_child(mesh_inst)
	_mesh_instances = [mesh_inst]
	_overlay_material = ModelHelper.create_overlay_material()
	ModelHelper.apply_overlay(_mesh_instances, _overlay_material)
	ModelHelper.apply_toon_to_model(_model)

func _play_anim(anim_name: String) -> void:
	if not _anim_player:
		return
	if _current_anim == anim_name and _anim_player.is_playing():
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)
		_current_anim = anim_name

func _setup_tooltip() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	_tooltip_label = Label.new()
	_tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	_tooltip_label.add_theme_font_size_override("font_size", 14)
	_tooltip_panel.add_child(_tooltip_label)

	canvas_layer.add_child(_tooltip_panel)

func _setup_hp_bar() -> void:
	var hp_bar_scene := preload("res://scenes/ui/hp_bar_3d.tscn")
	_hp_bar = hp_bar_scene.instantiate()
	add_child(_hp_bar)
	_hp_bar.position = Vector3(0, 1.8, 0)
	_hp_bar.visible = false

func _physics_process(delta: float) -> void:
	if _is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	var is_moving := false

	if _is_ui_open():
		_stop_navigation()
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
	elif not _attack_target.is_empty():
		is_moving = _process_combat(delta)
	elif _is_navigating and not nav_agent.is_navigation_finished():
		var next_pos := nav_agent.get_next_path_position()
		var dir := (next_pos - global_position)
		dir.y = 0.0
		dir = dir.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		_face_direction(dir)
		is_moving = true
	else:
		if _is_navigating:
			_is_navigating = false
			_on_arrived()
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	move_and_slide()

	# Safety teleport if fallen off the world
	if global_position.y < -10.0:
		global_position = Vector3(0.0, 2.0, 0.0)
		velocity = Vector3.ZERO

	# Update animation
	if _attack_target.is_empty():
		if is_moving:
			_play_anim("Walking_A")
		else:
			_play_anim("Idle")

func _process(delta: float) -> void:
	if _is_dead:
		return
	_hover_timer -= delta
	if _hover_timer <= 0.0:
		_hover_timer = 0.1
		_process_hover()
	elif _tooltip_panel.visible:
		# Keep tooltip following mouse between raycast ticks
		_tooltip_panel.position = get_viewport().get_mouse_position() + TOOLTIP_OFFSET

func _face_direction(dir: Vector3) -> void:
	if _model and dir.length() > 0.1:
		_model.rotation.y = atan2(dir.x, dir.z)

func _process_combat(delta: float) -> bool:
	var target_node := WorldState.get_entity(_attack_target)
	if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(_attack_target):
		_cancel_attack()
		return false

	var dist := global_position.distance_to(target_node.global_position)
	var attack_range: float = WorldState.get_entity_data("player").get("attack_range", 2.0)

	if dist > attack_range:
		# Navigate toward target — only update nav if target moved significantly
		var target_pos := target_node.global_position
		if _last_nav_target_pos.distance_to(target_pos) > 1.0:
			_last_nav_target_pos = target_pos
			nav_agent.target_position = target_pos
		if not nav_agent.is_navigation_finished():
			var next_pos := nav_agent.get_next_path_position()
			var dir := (next_pos - global_position)
			dir.y = 0.0
			dir = dir.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			_face_direction(dir)
			_play_anim("Running_A")
		return true

	# In range — stop and auto-attack
	velocity.x = 0.0
	velocity.z = 0.0
	# Face the target
	var to_target := (target_node.global_position - global_position).normalized()
	_face_direction(to_target)

	var attack_speed: float = WorldState.get_entity_data("player").get("attack_speed", 1.0)
	_attack_timer += delta
	if _attack_timer >= attack_speed:
		_attack_timer = 0.0
		_perform_attack()
		_play_anim("1H_Melee_Attack_Chop")
	return false

func _perform_attack() -> void:
	if not WorldState.is_alive(_attack_target):
		_cancel_attack()
		return
	var damage := WorldState.deal_damage("player", _attack_target)
	_spawn_damage_number(_attack_target, damage)
	_flash_target(_attack_target)

func _cancel_attack() -> void:
	_attack_target = ""
	_attack_timer = 0.0
	_last_nav_target_pos = Vector3.INF

func _stop_navigation() -> void:
	_is_navigating = false
	_interact_target = ""

func _navigate_to(pos: Vector3) -> void:
	nav_agent.target_position = pos
	_is_navigating = true

func _on_arrived() -> void:
	if _interact_target.is_empty():
		return

	var data := WorldState.get_entity_data(_interact_target)
	var etype: String = data.get("type", "")
	var target_node := WorldState.get_entity(_interact_target)

	if etype == "shop_npc":
		_open_shop(_interact_target)
	elif etype == "npc":
		if target_node and is_instance_valid(target_node):
			_talk_to_npc(_interact_target, target_node)

	_interact_target = ""

func _process_hover() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * HOVER_RAY_LENGTH
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self.get_rid()]
	var result := space.intersect_ray(query)

	var new_entity_id: String = ""
	if result:
		var collider: Node = result.collider
		if collider is Node3D:
			new_entity_id = WorldState.get_entity_id_for_node(collider)
			if new_entity_id == "player" or new_entity_id == "":
				new_entity_id = ""

	if new_entity_id != _hovered_entity_id:
		if _hovered_entity_id != "":
			var prev_node := WorldState.get_entity(_hovered_entity_id)
			if prev_node and is_instance_valid(prev_node) and prev_node.has_method("unhighlight"):
				prev_node.unhighlight()
		if new_entity_id != "":
			var new_node := WorldState.get_entity(new_entity_id)
			if new_node and is_instance_valid(new_node) and new_node.has_method("highlight"):
				new_node.highlight()
		_hovered_entity_id = new_entity_id

	# Update tooltip
	if _hovered_entity_id != "":
		var data := WorldState.get_entity_data(_hovered_entity_id)
		var display_name: String = data.get("name", _hovered_entity_id)
		var entity_type: String = data.get("type", "")
		if entity_type == "monster":
			var hp: int = data.get("hp", 0)
			var max_hp: int = data.get("max_hp", 0)
			display_name += " (HP: %d/%d)" % [hp, max_hp]
		elif entity_type == "shop_npc":
			display_name += " [Shop]"
		_tooltip_label.text = display_name
		_tooltip_panel.visible = true
		_tooltip_panel.position = mouse_pos + TOOLTIP_OFFSET
	else:
		_tooltip_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return

	if event.is_action_pressed("interact"):
		_interact_with_nearest()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_ui_open():
			return
		_handle_left_click()

func _handle_left_click() -> void:
	if not _hovered_entity_id.is_empty():
		var data := WorldState.get_entity_data(_hovered_entity_id)
		var etype: String = data.get("type", "")

		if etype == "monster" and WorldState.is_alive(_hovered_entity_id):
			# Click monster: walk to + auto-attack
			_interact_target = ""
			_attack_target = _hovered_entity_id
			_attack_timer = 0.0
			_is_navigating = false
			return

		if etype == "shop_npc" or etype == "npc":
			# Click NPC: walk to + interact on arrival
			_cancel_attack()
			_interact_target = _hovered_entity_id
			var target_node := WorldState.get_entity(_hovered_entity_id)
			if target_node and is_instance_valid(target_node):
				# Check if already in range
				var dist := global_position.distance_to(target_node.global_position)
				if dist <= INTERACT_RANGE:
					_on_arrived()
					return
				_navigate_to(target_node.global_position)
			return

	# Click on ground: move there
	var ground_pos := _raycast_ground()
	if ground_pos != Vector3.INF:
		_cancel_attack()
		_interact_target = ""
		_navigate_to(ground_pos)

func _raycast_ground() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return Vector3.INF

	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * HOVER_RAY_LENGTH
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self.get_rid()]
	var result := space.intersect_ray(query)

	if result:
		return result.position

	return Vector3.INF

func _interact_with_nearest() -> void:
	var nearby := WorldState.get_nearby_entities(global_position, INTERACT_RANGE)
	for entry in nearby:
		if entry.id == "player":
			continue
		var data := WorldState.get_entity_data(entry.id)
		var etype: String = data.get("type", "")
		if etype == "shop_npc":
			_open_shop(entry.id)
			return
		if etype == "npc":
			_talk_to_npc(entry.id, entry.node)
			return

func _talk_to_npc(target_npc_id: String, target_node: Node3D) -> void:
	GameEvents.npc_spoke.emit("player", "Hello there!", target_npc_id)
	var brain: Node = target_node.get_node_or_null("NPCBrain")
	if brain and brain.has_method("request_reactive_response"):
		brain.request_reactive_response("player", "Hello there!")

func _open_shop(shop_id: String) -> void:
	if shop_panel and shop_panel.has_method("open_shop"):
		shop_panel.open_shop(shop_id)

func _is_ui_open() -> bool:
	if shop_panel and shop_panel.has_method("is_open") and shop_panel.is_open():
		return true
	if inventory_panel and inventory_panel.has_method("is_open") and inventory_panel.is_open():
		return true
	return false

# --- Death / Respawn ---

func _on_entity_died(entity_id: String, _killer_id: String) -> void:
	if entity_id != "player":
		return
	_die()

func _die() -> void:
	_is_dead = true
	_cancel_attack()
	_stop_navigation()
	velocity = Vector3.ZERO

	# Lose 10% gold
	var gold := WorldState.get_gold("player")
	var lost := int(gold * 0.1)
	WorldState.remove_gold("player", lost)

	# Visual: death animation + fade out
	_play_anim("Death_A")
	ModelHelper.fade_out(_mesh_instances, self)

	_respawn_timer = 3.0

func _respawn() -> void:
	_is_dead = false
	_current_anim = ""
	# Teleport to town
	global_position = Vector3(0, 1, 0)
	velocity = Vector3.ZERO

	# Restore HP
	var max_hp: int = WorldState.get_entity_data("player").get("max_hp", 50)
	WorldState.set_entity_data("player", "hp", max_hp)

	# Visual: restore materials and play idle
	ModelHelper.restore_materials(_mesh_instances)
	_play_anim("Idle")

	GameEvents.entity_respawned.emit("player")
	_update_hp_bar()

func _on_entity_damaged(target_id: String, _attacker_id: String, _damage: int, _remaining_hp: int) -> void:
	if target_id == "player":
		flash_hit()
		_update_hp_bar()

func _on_entity_healed(entity_id: String, _amount: int, _current_hp: int) -> void:
	if entity_id == "player":
		_update_hp_bar()

func _update_hp_bar() -> void:
	if not _hp_bar:
		return
	var data := WorldState.get_entity_data("player")
	var hp: int = data.get("hp", 0)
	var max_hp: int = data.get("max_hp", 1)
	if _hp_bar.has_method("update_bar"):
		_hp_bar.update_bar(hp, max_hp)
	_hp_bar.visible = hp < max_hp

func flash_hit() -> void:
	if not _overlay_material:
		return
	ModelHelper.flash_hit(_overlay_material, self)

func _spawn_damage_number(target_id: String, damage: int) -> void:
	var target_node := WorldState.get_entity(target_id)
	if not target_node:
		return
	var dmg_scene := preload("res://scenes/ui/damage_number.tscn")
	var dmg := dmg_scene.instantiate()
	get_tree().current_scene.add_child(dmg)
	dmg.global_position = target_node.global_position + Vector3(0, 1.5, 0)
	dmg.setup(damage)

func _flash_target(target_id: String) -> void:
	var target_node := WorldState.get_entity(target_id)
	if not target_node or not is_instance_valid(target_node):
		return
	if target_node.has_method("flash_hit"):
		target_node.flash_hit()
