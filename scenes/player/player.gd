extends CharacterBody3D
## Player controller with point-and-click movement, click-to-attack/interact, and death/respawn.
## Uses KayKit Knight 3D model with animations.

const SPEED: float = 7.2
const GRAVITY: float = 9.8
const INTERACT_RANGE: float = 4.0
const HOVER_RAY_LENGTH: float = 100.0
const TOOLTIP_OFFSET: Vector2 = Vector2(16, 16)
const MODEL_SCALE: float = 0.7

const EntityVisuals = preload("res://scripts/components/entity_visuals.gd")
const StatsComponent = preload("res://scripts/components/stats_component.gd")
const InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const EquipmentComponent = preload("res://scripts/components/equipment_component.gd")
const CombatComponent = preload("res://scripts/components/combat_component.gd")
const ProgressionComponent = preload("res://scripts/components/progression_component.gd")
const SkillsComponent = preload("res://scripts/components/skills_component.gd")
const AutoAttackComponent = preload("res://scripts/components/auto_attack_component.gd")
const LevelData = preload("res://scripts/data/level_data.gd")
const ItemDatabase = preload("res://scripts/data/item_database.gd")
const SkillDatabase = preload("res://scripts/data/skill_database.gd")
const CursorManager = preload("res://scripts/utils/cursor_manager.gd")
const NpcTraits = preload("res://scripts/data/npc_traits.gd")
const PromptBuilder = preload("res://scripts/llm/prompt_builder.gd")
const MonsterDatabase = preload("res://scripts/data/monster_database.gd")
const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")

var entity_id: String = "player"

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var _cursor_manager: RefCounted
var _hover_ring: MeshInstance3D
var _hover_ring_material: StandardMaterial3D

var _hovered_entity_id: String = ""
var _ring_target_id: String = ""
var _tooltip_label: Label
var _tooltip_panel: PanelContainer
var _hover_timer: float = 0.0

# Navigation
var _is_navigating: bool = false
var _interact_target: String = ""

# Combat
var _attack_target: String = ""
var _is_dead: bool = false
var _respawn_timer: float = 0.0
var _pending_skill_hit: bool = false
var _pending_skill_damage: int = 0
var _pending_skill_id: String = ""
var _pending_skill_anim: String = ""
var _skill_hit_time: float = 0.0

# Visuals component
var _visuals: Node
var _stats: Node
var _inventory: Node
var _equipment: Node
var _combat: Node
var _progression: Node
var _skills_comp: Node
var _auto_attack: Node

# UI references (set by main scene setup)
var shop_panel: Control
var inventory_panel: Control
var status_panel: Control
var chat_input: Control
var skill_hotbar: Control
var skill_panel: Control
var npc_info_panel: Control

# Dialogue bubble above head
var _dialogue_bubble: Node3D

# Pending NPC conversation (set when player clicks NPC, cleared after chat sent)
var _pending_talk_target_id: String = ""

func _exit_tree() -> void:
	if _cursor_manager:
		_cursor_manager.cleanup()

func _ready() -> void:
	_visuals = EntityVisuals.new()
	add_child(_visuals)
	_visuals.setup_model("res://assets/models/characters/Knight.glb", MODEL_SCALE, Color(0.2, 0.4, 0.7))

	_stats = StatsComponent.new()
	_stats.name = "StatsComponent"
	add_child(_stats)
	_stats.setup(LevelData.BASE_PLAYER_STATS)

	_inventory = InventoryComponent.new()
	_inventory.name = "InventoryComponent"
	add_child(_inventory)
	_inventory.setup({}, LevelData.BASE_PLAYER_STATS.get("gold", 100))

	_equipment = EquipmentComponent.new()
	_equipment.name = "EquipmentComponent"
	add_child(_equipment)
	_equipment.setup({"weapon": "", "armor": ""}, _inventory)

	_combat = CombatComponent.new()
	_combat.name = "CombatComponent"
	add_child(_combat)
	_combat.setup(_stats, _equipment)

	_progression = ProgressionComponent.new()
	_progression.name = "ProgressionComponent"
	add_child(_progression)
	_progression.setup(_stats)

	_skills_comp = SkillsComponent.new()
	_skills_comp.name = "SkillsComponent"
	add_child(_skills_comp)
	_skills_comp.setup({}, ["", "", "", "", ""])

	_auto_attack = AutoAttackComponent.new()
	_auto_attack.name = "AutoAttackComponent"
	add_child(_auto_attack)
	_auto_attack.setup(_visuals, _combat, nav_agent)
	_auto_attack.attack_landed.connect(_on_auto_attack_landed)
	_auto_attack.target_lost.connect(_on_auto_attack_target_lost)

	var stats := LevelData.BASE_PLAYER_STATS.duplicate()
	stats["type"] = "player"
	stats["name"] = "Player"
	stats["inventory"] = {}
	stats["equipment"] = {"weapon": "", "armor": ""}
	stats["skills"] = {}
	stats["hotbar"] = ["", "", "", "", ""]
	WorldState.register_entity("player", self, stats)

	# Add StaminaComponent
	var stamina_comp := preload("res://scripts/components/stamina_component.gd").new()
	stamina_comp.name = "StaminaComponent"
	add_child(stamina_comp)

	_cursor_manager = CursorManager.new()
	_setup_hover_ring()
	_setup_tooltip()
	_setup_dialogue_bubble()

	_visuals.setup_hp_bar()
	_visuals.set_hp_bar_visible(false)

	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_damaged.connect(_on_entity_damaged)
	GameEvents.entity_healed.connect(_on_entity_healed)
	GameEvents.proficiency_level_up.connect(_on_proficiency_level_up)

func _setup_tooltip() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	UIHelper.set_corner_radius(style, 4)
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

func _setup_dialogue_bubble() -> void:
	var bubble_scene := preload("res://scenes/ui/dialogue_bubble.tscn")
	_dialogue_bubble = bubble_scene.instantiate()
	add_child(_dialogue_bubble)
	_dialogue_bubble.position = Vector3(0, 2.2, 0)

func _setup_hover_ring() -> void:
	_hover_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.6
	_hover_ring.mesh = torus
	_hover_ring.top_level = true

	_hover_ring_material = StandardMaterial3D.new()
	_hover_ring_material.albedo_color = Color(1.0, 0.3, 0.2, 0.6)
	_hover_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hover_ring_material.no_depth_test = true
	_hover_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_ring.material_override = _hover_ring_material

	_hover_ring.visible = false
	add_child(_hover_ring)

	# Looping pulse tween
	var tween := get_tree().create_tween().set_loops()
	tween.tween_property(_hover_ring, "scale", Vector3(1.15, 1.0, 1.15), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_hover_ring, "scale", Vector3(1.0, 1.0, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func show_chat(text: String) -> void:
	_show_bubble(text)
	# If there's a pending NPC conversation, send the message to them
	if not _pending_talk_target_id.is_empty():
		var npc_id := _pending_talk_target_id
		var npc_node := WorldState.get_entity(npc_id)
		_pending_talk_target_id = ""
		if npc_node and is_instance_valid(npc_node):
			_send_message_to_npc(text, npc_id, npc_node)
			return
	# Proximity: auto-target nearest NPC if within range
	_send_to_nearby_npc(text)

func _send_to_nearby_npc(text: String) -> void:
	var nearby := WorldState.get_nearby_entities(global_position, INTERACT_RANGE)
	for entry in nearby:
		if entry.id == "player":
			continue
		var data := WorldState.get_entity_data(entry.id)
		var etype: String = data.get("type", "")
		if etype == "npc":
			_send_message_to_npc(text, entry.id, entry.node)
			return

func _show_bubble(text: String) -> void:
	if _dialogue_bubble:
		_dialogue_bubble.show_dialogue(text)

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
		_visuals.face_direction(dir)
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
			_visuals.play_anim("Walking_A")
		else:
			_visuals.play_anim("Idle")

func _process(delta: float) -> void:
	if _is_dead:
		return

	# Track ring to locked target every frame
	if _hover_ring.visible and _ring_target_id != "":
		var entity := WorldState.get_entity(_ring_target_id)
		if entity and is_instance_valid(entity) and WorldState.is_alive(_ring_target_id):
			_hover_ring.global_position = entity.global_position + Vector3(0, 0.05, 0)
		else:
			_hover_ring.visible = false
			_ring_target_id = ""

	_hover_timer -= delta
	if _hover_timer <= 0.0:
		_hover_timer = 0.1
		_process_hover()
	elif _tooltip_panel.visible:
		# Keep tooltip following mouse between raycast ticks
		_tooltip_panel.position = get_viewport().get_mouse_position() + TOOLTIP_OFFSET

func _process_combat(delta: float) -> bool:
	var attack_range: float = WorldState.get_entity_data("player").get("attack_range", 2.0)
	var attack_speed: float = WorldState.get_entity_data("player").get("attack_speed", 1.0)

	# While a skill hit is pending, handle it here — auto-attack is suppressed
	if _pending_skill_hit:
		return _process_skill_hit(delta, attack_range)

	# Normal auto-attack: delegate to component
	var result: Dictionary = _auto_attack.process_attack(
		delta, _attack_target, global_position, SPEED, attack_range, attack_speed
	)
	return result.get("is_moving", false)

## Handles the pending skill hit timing while suppressing auto-attack.
## Returns true if the player is moving (chasing out-of-range target).
func _process_skill_hit(delta: float, attack_range: float) -> bool:
	# Validate target first
	var target_node := WorldState.get_entity(_attack_target)
	if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(_attack_target):
		_cancel_attack()
		return false

	# If out of range, chase the target (without auto-attack accumulating)
	var dist: float = global_position.distance_to(target_node.global_position)
	if dist > attack_range:
		nav_agent.target_position = target_node.global_position
		if not nav_agent.is_navigation_finished():
			var next_pos := nav_agent.get_next_path_position()
			var dir := (next_pos - global_position)
			dir.y = 0.0
			if dir.length_squared() > 0.01:
				dir = dir.normalized()
				velocity.x = dir.x * SPEED
				velocity.z = dir.z * SPEED
				_visuals.face_direction(dir)
				_visuals.play_anim("Running_A")
		return true

	# In range — resolve skill hit timing
	velocity.x = 0.0
	velocity.z = 0.0
	var to_target := (target_node.global_position - global_position)
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		_visuals.face_direction(to_target.normalized())

	var anim_player: AnimationPlayer = _visuals.get_anim_player()
	if anim_player and anim_player.current_animation == _pending_skill_anim:
		if anim_player.current_animation_position >= _skill_hit_time:
			_pending_skill_hit = false
			_execute_skill_hit()
	else:
		# Fallback countdown when skill animation isn't playing
		_skill_hit_time -= delta
		if _skill_hit_time <= 0.0:
			_pending_skill_hit = false
			_execute_skill_hit()
	return false

func _cancel_attack() -> void:
	_attack_target = ""
	_auto_attack.cancel()
	_pending_skill_hit = false
	_pending_skill_damage = 0
	_pending_skill_id = ""
	_pending_skill_anim = ""
	_ring_target_id = ""
	_hover_ring.visible = false

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

	if etype == "loot_drop":
		if target_node and is_instance_valid(target_node) and target_node.has_method("pickup"):
			target_node.pickup("player")
	elif etype == "shop_npc":
		_open_shop(_interact_target)
	elif etype == "npc":
		if npc_info_panel and npc_info_panel.has_method("show_npc"):
			npc_info_panel.show_npc(_interact_target)

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

	# Update tooltip, cursor, and hover ring
	if _hovered_entity_id != "":
		var data := WorldState.get_entity_data(_hovered_entity_id)
		var display_name: String = data.get("name", _hovered_entity_id)
		var entity_type: String = data.get("type", "")
		if entity_type == "monster":
			var hp: int = data.get("hp", 0)
			var max_hp: int = data.get("max_hp", 0)
			display_name += " (HP: %d/%d)" % [hp, max_hp]
			_cursor_manager.set_cursor("attack")
		elif entity_type == "loot_drop":
			display_name += " [Loot]"
			_cursor_manager.set_cursor("move")
		elif entity_type == "npc":
			var npc_node := WorldState.get_entity(_hovered_entity_id)
			var tooltip_lines: Array = [display_name + "  Lv.%d" % data.get("level", 1)]
			if npc_node and is_instance_valid(npc_node) and "trait_profile" in npc_node:
				var trait_summary: String = NpcTraits.get_trait_summary(npc_node.trait_profile)
				if not trait_summary.is_empty():
					tooltip_lines.append(trait_summary)
			var goal: String = data.get("goal", "idle")
			tooltip_lines.append(PromptBuilder.get_activity_description(goal))
			if npc_node and is_instance_valid(npc_node) and "current_mood" in npc_node:
				var mood: String = npc_node.current_mood
				if not mood.is_empty() and mood != "neutral":
					tooltip_lines.append("Mood: %s" % mood)
			display_name = "\n".join(tooltip_lines)
			_cursor_manager.set_cursor("talk")
		elif entity_type == "shop_npc":
			display_name += " [Shop]"
			_cursor_manager.set_cursor("talk")
		else:
			_cursor_manager.set_cursor("default")
		_tooltip_label.text = display_name
		_tooltip_panel.visible = true
		_tooltip_panel.position = mouse_pos + TOOLTIP_OFFSET
	else:
		_tooltip_panel.visible = false
		_cursor_manager.set_cursor("default")

func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return

	if not _is_ui_open():
		for i in range(5):
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				_try_use_hotbar_slot(i)
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("chat_submit"):
		if chat_input and not chat_input.is_open() and not _is_ui_open():
			chat_input.open()
			get_viewport().set_input_as_handled()
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
			# Click monster: walk to + auto-attack, lock ring on target
			_interact_target = ""
			_attack_target = _hovered_entity_id
			_auto_attack.cancel()
			_is_navigating = false
			_ring_target_id = _hovered_entity_id
			_hover_ring_material.albedo_color = Color(1.0, 0.3, 0.2, 0.6)
			var target_node := WorldState.get_entity(_ring_target_id)
			if target_node:
				_hover_ring.global_position = target_node.global_position + Vector3(0, 0.05, 0)
				_hover_ring.visible = true
			return

		if etype == "loot_drop":
			# Click loot: walk to + pick up on arrival
			_cancel_attack()
			_interact_target = _hovered_entity_id
			var target_node := WorldState.get_entity(_hovered_entity_id)
			if target_node and is_instance_valid(target_node):
				var dist := global_position.distance_to(target_node.global_position)
				if dist <= INTERACT_RANGE:
					_on_arrived()
					return
				_navigate_to(target_node.global_position)
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

	# Click on ground: move there, cancel target lock, close NPC info
	if npc_info_panel and npc_info_panel.has_method("close") and npc_info_panel.is_open():
		npc_info_panel.close()
	var ground_pos := _raycast_ground()
	if ground_pos != Vector3.INF:
		_cancel_attack()
		_interact_target = ""
		_ring_target_id = ""
		_hover_ring.visible = false
		_spawn_click_marker(ground_pos)
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
			_command_npc_follow(entry.node)
			return

func _command_npc_follow(npc_node: Node3D) -> void:
	if npc_node.has_method("set_goal"):
		npc_node.set_goal("follow_player")

func _talk_to_npc(target_npc_id: String, target_node: Node3D) -> void:
	# Open chat input so player can type what they want to say
	if chat_input and not chat_input.is_open():
		_pending_talk_target_id = target_npc_id
		chat_input.open()
		return
	# Fallback if no chat input available
	_send_message_to_npc("Hello there!", target_npc_id, target_node)

func _send_message_to_npc(text: String, npc_id: String, npc_node: Node3D) -> void:
	GameEvents.npc_spoke.emit("player", text, npc_id)
	var brain: Node = npc_node.get_node_or_null("NPCBrain")
	if brain and brain.has_method("request_reactive_response"):
		brain.request_reactive_response("player", text)

func _open_shop(shop_id: String) -> void:
	if shop_panel:
		shop_panel.open_shop(shop_id)

func _is_ui_open() -> bool:
	for panel in [shop_panel, inventory_panel, status_panel, chat_input, skill_panel]:
		if panel and panel.is_open():
			return true
	return false

# --- Death / Respawn ---

func _on_entity_died(entity_id: String, _killer_id: String) -> void:
	if entity_id == _ring_target_id:
		_ring_target_id = ""
		_hover_ring.visible = false
	if entity_id != "player":
		return
	_die()

func _die() -> void:
	_is_dead = true
	_cancel_attack()
	_stop_navigation()
	velocity = Vector3.ZERO
	_cursor_manager.reset()

	# Lose 10% gold
	var gold: int = _inventory.get_gold_amount()
	var lost := int(gold * 0.1)
	_inventory.remove_gold_amount(lost)

	# Visual: death animation + fade out
	_visuals.play_anim("Death_A")
	_visuals.fade_out()

	_respawn_timer = 3.0

func _respawn() -> void:
	_is_dead = false
	_visuals.reset_anim()
	# Teleport to town
	global_position = Vector3(0, 1, 0)
	velocity = Vector3.ZERO

	# Restore HP via StatsComponent (source of truth)
	_stats.restore_full_hp()

	# Visual: restore materials and play idle
	_visuals.restore_materials()
	_visuals.play_anim("Idle")

	GameEvents.entity_respawned.emit("player")
	_visuals.update_hp_bar("player")

func _on_entity_damaged(target_id: String, _attacker_id: String, _damage: int, _remaining_hp: int) -> void:
	if target_id == "player":
		flash_hit()
		_visuals.update_hp_bar("player")
		_progression.grant_proficiency_xp("constitution", 3)

func _on_entity_healed(entity_id: String, _amount: int, _current_hp: int) -> void:
	if entity_id == "player":
		_visuals.update_hp_bar("player")

func _on_proficiency_level_up(entity_id: String, skill_id: String, new_level: int) -> void:
	if entity_id != "player":
		return
	# Check if any active skills should be unlocked
	for active_skill_id in SkillDatabase.SKILLS:
		var skill: Dictionary = SkillDatabase.SKILLS[active_skill_id]
		var req: Dictionary = skill.get("required_proficiency", {})
		if req.get("skill", "") == skill_id and req.get("level", 1) <= new_level:
			if not _skills_comp.has_skill(active_skill_id):
				_skills_comp.unlock_skill(active_skill_id)

# --- Duck typing delegations ---

func flash_hit() -> void:
	_visuals.flash_hit()

func _try_use_hotbar_slot(slot: int) -> void:
	var hotbar: Array = _skills_comp.get_hotbar()
	if slot < 0 or slot >= hotbar.size():
		return
	var skill_id: String = hotbar[slot]
	if skill_id.is_empty():
		return
	if skill_hotbar and skill_hotbar.is_on_cooldown(skill_id):
		return
	_use_skill(skill_id)

func _use_skill(skill_id: String) -> void:
	var skill := SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		return
	var skill_level: int = _skills_comp.get_skill_level(skill_id)
	if skill_level <= 0:
		return
	var skill_type: String = skill.get("type", "")
	if skill_type == "melee_attack":
		if _attack_target.is_empty():
			return
		var target_node := WorldState.get_entity(_attack_target)
		if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(_attack_target):
			return
		var dist := global_position.distance_to(target_node.global_position)
		var attack_range: float = WorldState.get_entity_data("player").get("attack_range", 2.0)
		if dist > attack_range:
			return
		var multiplier := SkillDatabase.get_effective_multiplier(skill_id, skill_level)
		var raw_damage := floori(_combat.get_effective_atk() * multiplier)
		var anim_name: String = skill.get("animation", "1H_Melee_Attack_Chop")
		_pending_skill_hit = true
		_pending_skill_damage = raw_damage
		_pending_skill_id = skill_id
		_pending_skill_anim = anim_name
		_visuals.play_anim(anim_name, true)
		_skill_hit_time = _visuals.get_hit_delay(anim_name)
		_auto_attack.cancel()
		# Drain stamina for skill use
		var stamina_comp_node = get_node_or_null("StaminaComponent")
		if stamina_comp_node:
			stamina_comp_node.drain_flat(5.0)
		# Start cooldown
		var cooldown := SkillDatabase.get_effective_cooldown(skill_id, skill_level)
		if skill_hotbar:
			skill_hotbar.start_cooldown(skill_id, cooldown)

func _execute_skill_hit() -> void:
	if _attack_target.is_empty():
		return
	if not WorldState.is_alive(_attack_target):
		return
	var target_node := WorldState.get_entity(_attack_target)
	var target_pos := target_node.global_position if target_node else global_position
	var actual_damage: int = _combat.deal_damage_amount_to(_attack_target, _pending_skill_damage)
	_visuals.spawn_damage_number(_attack_target, actual_damage, Color(1, 1, 1), target_pos)
	_visuals.flash_target(_attack_target)
	GameEvents.skill_used.emit("player", _pending_skill_id)
	# Grant skill XP for use-based leveling
	_skills_comp.grant_skill_xp(_pending_skill_id, 5)
	# Grant weapon XP for skill hits too
	var target_data := WorldState.get_entity_data(_attack_target)
	var monster_type: String = target_data.get("monster_type", "")
	if not monster_type.is_empty():
		var monster_stats := MonsterDatabase.get_monster(monster_type)
		var prof_xp: int = monster_stats.get("proficiency_xp", 3)
		var weapon_type: String = _combat.get_equipped_weapon_type()
		_progression.grant_proficiency_xp(weapon_type, prof_xp)
	_pending_skill_damage = 0
	_pending_skill_id = ""

func _on_auto_attack_landed(target_id: String, damage: int, target_pos: Vector3) -> void:
	_visuals.spawn_damage_number(target_id, damage, Color(1, 1, 1), target_pos)
	_visuals.flash_target(target_id)
	# Grant weapon proficiency XP
	var target_data := WorldState.get_entity_data(target_id)
	var monster_type: String = target_data.get("monster_type", "")
	if not monster_type.is_empty():
		var monster_stats := MonsterDatabase.get_monster(monster_type)
		var prof_xp: int = monster_stats.get("proficiency_xp", 3)
		var weapon_type: String = _combat.get_equipped_weapon_type()
		_progression.grant_proficiency_xp(weapon_type, prof_xp)

func _on_auto_attack_target_lost() -> void:
	_cancel_attack()

func _spawn_click_marker(pos: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.5
	marker.mesh = torus
	marker.rotation.x = 0.0  # Torus is already flat by default

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1.0, 0.4, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mat

	marker.position = Vector3(pos.x, pos.y + 0.05, pos.z)
	get_tree().current_scene.add_child(marker)

	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.tween_property(marker, "scale", Vector3(0.3, 0.3, 0.3), 0.6)
	tween.chain().tween_callback(marker.queue_free)
