extends CharacterBody3D
## Player controller with point-and-click movement, click-to-attack/interact, and death/respawn.
## Uses KayKit Knight 3D model with animations.

const SPEED: float = 7.2
const GRAVITY: float = 9.8
const INTERACT_RANGE: float = 4.0
const HOVER_RAY_LENGTH: float = 100.0
const MODEL_SCALE: float = 0.7
const DEATH_GOLD_PENALTY_RATIO: float = 0.1
const CONSTITUTION_XP_PER_HIT: int = 3
const RESPAWN_TIME: float = 3.0

const EntityVisuals = preload("res://scripts/components/entity_visuals.gd")
const StatsComponent = preload("res://scripts/components/stats_component.gd")
const InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const EquipmentComponent = preload("res://scripts/components/equipment_component.gd")
const CombatComponent = preload("res://scripts/components/combat_component.gd")
const ProgressionComponent = preload("res://scripts/components/progression_component.gd")
const SkillsComponent = preload("res://scripts/components/skills_component.gd")
const AutoAttackComponent = preload("res://scripts/components/auto_attack_component.gd")
const VendingComponent = preload("res://scripts/components/vending_component.gd")
const LevelData = preload("res://scripts/data/level_data.gd")
const SkillDatabase = preload("res://scripts/data/skill_database.gd")
const CursorManager = preload("res://scripts/utils/cursor_manager.gd")

var entity_id: String = "player"

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var _cursor_manager: RefCounted

# Navigation
var _is_navigating: bool = false
var _interact_target: String = ""

# Vending
var _is_vending: bool = false

# Combat
var _attack_target: String = ""
var _is_dead: bool = false
var _respawn_timer: float = 0.0

# Visuals component
var _visuals: Node
var _stats: Node
var _inventory: Node
var _equipment: Node
var _combat: Node
var _progression: Node
var _skills_comp: Node
var _auto_attack: Node

# Child subsystem nodes
var _hover: Node
var _player_skills: Node

# UI references (set by main scene setup)
var shop_panel: Control
var inventory_panel: Control
var status_panel: Control
var chat_input: Control
var skill_hotbar: Control:
	set(value):
		skill_hotbar = value
		if _player_skills:
			_player_skills.set_skill_hotbar(value)
var skill_panel: Control
var npc_info_panel: Control
var vend_setup_panel: Control

# Click marker (reused single instance)
var _click_marker: MeshInstance3D
var _click_marker_material: StandardMaterial3D
var _click_marker_tween: Tween

# Dialogue bubble above head
var _dialogue_bubble: Node3D


# Conversation awareness
var _nearby_conversation_id: String = ""
var _conv_manager: Node = null
var _conv_scan_timer: float = 0.0

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

	_progression = ProgressionComponent.new()
	_progression.name = "ProgressionComponent"
	add_child(_progression)
	_progression.setup(_stats, {}, _equipment)

	_combat = CombatComponent.new()
	_combat.name = "CombatComponent"
	add_child(_combat)
	_combat.setup(_stats, _equipment, _progression)

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

	var _vending_comp := VendingComponent.new()
	_vending_comp.name = "VendingComponent"
	add_child(_vending_comp)

	# Add StaminaComponent
	var stamina_comp := preload("res://scripts/components/stamina_component.gd").new()
	stamina_comp.name = "StaminaComponent"
	add_child(stamina_comp)
	stamina_comp.setup_rest_spots(["TownWell", "TownInn"])

	_cursor_manager = CursorManager.new()

	# Hover subsystem
	_hover = preload("res://scenes/player/player_hover.gd").new()
	_hover.name = "PlayerHover"
	add_child(_hover)
	_hover.setup(self, _cursor_manager)

	# Skills subsystem
	_player_skills = preload("res://scenes/player/player_skills.gd").new()
	_player_skills.name = "PlayerSkills"
	add_child(_player_skills)
	_player_skills.setup(self, _combat, _stats, _skills_comp, _progression, _visuals)

	_setup_dialogue_bubble()
	_setup_click_marker()

	_visuals.setup_hp_bar()
	_visuals.set_hp_bar_visible(false)

	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_damaged.connect(_on_entity_damaged)
	GameEvents.entity_healed.connect(_on_entity_healed)
	GameEvents.proficiency_level_up.connect(_on_proficiency_level_up)
	GameEvents.vending_started.connect(_on_vending_started)
	GameEvents.vending_stopped.connect(_on_vending_stopped)

	_conv_manager = get_tree().get_first_node_in_group("conversation_manager")

func _setup_click_marker() -> void:
	_click_marker = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.5
	_click_marker.mesh = torus
	_click_marker.top_level = true

	_click_marker_material = StandardMaterial3D.new()
	_click_marker_material.albedo_color = Color(0.3, 1.0, 0.4, 0.0)
	_click_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_click_marker_material.no_depth_test = true
	_click_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_click_marker.material_override = _click_marker_material

	_click_marker.visible = false
	add_child(_click_marker)


func _setup_dialogue_bubble() -> void:
	var bubble_scene := preload("res://scenes/ui/dialogue_bubble.tscn")
	_dialogue_bubble = bubble_scene.instantiate()
	add_child(_dialogue_bubble)
	_dialogue_bubble.position = Vector3(0, 2.2, 0)

func show_chat(text: String) -> void:
	_show_bubble(text)
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

	if _is_vending or _is_ui_open():
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

	_conv_scan_timer += delta
	if _conv_scan_timer < 0.5:
		return
	_conv_scan_timer = 0.0

	# Scan for nearby active conversations to allow the player to join
	_nearby_conversation_id = ""
	if _conv_manager:
		for conv_id in _conv_manager.active_conversations:
			var state: ConversationState = _conv_manager.active_conversations[conv_id]
			if not state:
				continue
			for pid in state.participant_ids:
				var entity: Node = WorldState.get_entity(pid)
				if entity and global_position.distance_to(entity.global_position) < 15.0:
					_nearby_conversation_id = conv_id
					break
			if not _nearby_conversation_id.is_empty():
				break

		# Auto-leave if all conversation participants moved out of range
		var player_conv_id: String = _conv_manager.entity_to_conversation.get("player", "")
		if not player_conv_id.is_empty() and _conv_manager.active_conversations.has(player_conv_id):
			var player_state: ConversationState = _conv_manager.active_conversations[player_conv_id]
			var all_far: bool = true
			for pid in player_state.participant_ids:
				if pid == "player":
					continue
				var entity: Node = WorldState.get_entity(pid)
				if entity and global_position.distance_to(entity.global_position) < 15.0:
					all_far = false
					break
			if all_far:
				_conv_manager.leave_conversation(player_conv_id, "player")

func _process_combat(delta: float) -> bool:
	var attack_range: float = _stats.attack_range
	var attack_speed: float = _stats.attack_speed

	# While a skill hit is pending, handle it here — auto-attack is suppressed
	if _player_skills.pending_skill_hit:
		return _player_skills.process_skill_hit(delta, attack_range)

	# Normal auto-attack: delegate to component
	var result: Dictionary = _auto_attack.process_attack(
		delta, _attack_target, global_position, SPEED, attack_range, attack_speed
	)
	return result.get("is_moving", false)

func _cancel_attack() -> void:
	_attack_target = ""
	_auto_attack.cancel()
	_player_skills.cancel_pending()
	_hover.clear_ring()

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
	elif etype == "npc":
		if _hover.pending_vend_sign_click:
			_hover.pending_vend_sign_click = false
			var vending_comp: Node = target_node.get_node_or_null("VendingComponent") if target_node else null
			if vending_comp and vending_comp.is_vending():
				_open_shop(_interact_target)
		elif npc_info_panel and npc_info_panel.has_method("show_npc"):
			npc_info_panel.show_npc(_interact_target)

	_interact_target = ""

func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return

	if _is_vending:
		if event.is_action_pressed("ui_cancel"):
			if shop_panel and shop_panel.is_open():
				shop_panel.close_shop()
			else:
				stop_vending()
			get_viewport().set_input_as_handled()
		return

	if not _is_ui_open():
		for i in range(5):
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				_player_skills.try_use_hotbar_slot(i)
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("chat_submit"):
		if chat_input and not chat_input.is_open() and not _is_ui_open():
			chat_input.open()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("interact"):
		if _conv_manager:
			var player_conv_id: String = _conv_manager.entity_to_conversation.get("player", "")
			if not player_conv_id.is_empty():
				# Player is in a conversation — E key leaves it
				_conv_manager.leave_conversation(player_conv_id, "player")
				get_viewport().set_input_as_handled()
				return
			elif not _nearby_conversation_id.is_empty():
				# Nearby conversation exists — E key joins it
				_conv_manager.join_conversation(_nearby_conversation_id, "player")
				get_viewport().set_input_as_handled()
				return
		_interact_with_nearest()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_ui_open():
			return
		_handle_left_click()

func _handle_left_click() -> void:
	# Vend sign click — walk to vendor NPC, then open shop
	if _hover.hovered_vend_sign and not _hover.hovered_vend_sign_owner_id.is_empty() and _hover.hovered_vend_sign_owner_id != "player":
		_cancel_attack()
		_interact_target = _hover.hovered_vend_sign_owner_id
		_hover.pending_vend_sign_click = true
		var target_node := WorldState.get_entity(_hover.hovered_vend_sign_owner_id)
		if target_node and is_instance_valid(target_node):
			var dist := global_position.distance_to(target_node.global_position)
			if dist <= INTERACT_RANGE:
				_on_arrived()
				return
			_navigate_to(target_node.global_position)
		return

	var hovered_entity_id: String = _hover.get_hovered_entity_id()
	if not hovered_entity_id.is_empty():
		var data := WorldState.get_entity_data(hovered_entity_id)
		var etype: String = data.get("type", "")

		if etype == "monster" and WorldState.is_alive(hovered_entity_id):
			# Click monster: walk to + auto-attack, lock ring on target
			_interact_target = ""
			_attack_target = hovered_entity_id
			_auto_attack.cancel()
			_is_navigating = false
			_hover.lock_ring(hovered_entity_id, Color(1.0, 0.3, 0.2, 0.6))
			return

		if etype == "loot_drop":
			# Click loot: walk to + pick up on arrival
			_cancel_attack()
			_interact_target = hovered_entity_id
			var target_node := WorldState.get_entity(hovered_entity_id)
			if target_node and is_instance_valid(target_node):
				var dist := global_position.distance_to(target_node.global_position)
				if dist <= INTERACT_RANGE:
					_on_arrived()
					return
				_navigate_to(target_node.global_position)
			return

		if etype == "npc":
			# Click NPC: walk to + interact on arrival
			_cancel_attack()
			_interact_target = hovered_entity_id
			var target_node := WorldState.get_entity(hovered_entity_id)
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
		if etype == "npc":
			var vending_comp: Node = entry.node.get_node_or_null("VendingComponent") if entry.node else null
			if vending_comp and vending_comp.is_vending():
				_open_shop(entry.id)
				return
			_command_npc_follow(entry.node)
			return

func _command_npc_follow(npc_node: Node3D) -> void:
	if npc_node.has_method("set_goal"):
		npc_node.set_goal("follow_player")

func _send_message_to_npc(text: String, npc_id: String, npc_node: Node3D) -> void:
	GameEvents.npc_spoke.emit("player", text, npc_id)
	var brain: Node = npc_node.get_node_or_null("NPCBrain")
	if brain and brain.has_method("request_reactive_response"):
		brain.request_reactive_response("player", text)

func _open_shop(shop_id: String) -> void:
	if shop_panel:
		var vendor_node := WorldState.get_entity(shop_id)
		if vendor_node and is_instance_valid(vendor_node):
			enter_vending_state()
			shop_panel.open_shop(vendor_node)

func enter_vending_state() -> void:
	_is_vending = true
	_cancel_attack()
	_stop_navigation()
	velocity = Vector3.ZERO

func stop_vending() -> void:
	_is_vending = false
	var vending_comp: Node = get_node_or_null("VendingComponent")
	if vending_comp and vending_comp.is_vending():
		vending_comp.stop_vending()

func _is_ui_open() -> bool:
	for panel in [shop_panel, inventory_panel, status_panel, chat_input, skill_panel, vend_setup_panel]:
		if panel and panel.is_open():
			return true
	return false

# --- Death / Respawn ---

func _on_entity_died(eid: String, _killer_id: String) -> void:
	if eid == _attack_target:
		_hover.clear_ring()
	if eid != "player":
		return
	_die()

func _die() -> void:
	stop_vending()
	_is_dead = true
	_cancel_attack()
	_stop_navigation()
	velocity = Vector3.ZERO
	_cursor_manager.reset()

	# Lose 10% gold
	var lost := EntityHelpers.apply_death_gold_penalty(_inventory, DEATH_GOLD_PENALTY_RATIO)

	# Visual: death animation + fade out
	_visuals.play_anim("Death_A")
	_visuals.fade_out()

	_respawn_timer = RESPAWN_TIME

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
	_visuals.update_hp_bar(_stats.hp, _stats.max_hp)

func _on_entity_damaged(target_id: String, _attacker_id: String, _damage: int, _remaining_hp: int) -> void:
	if target_id == "player":
		flash_hit()
		_visuals.update_hp_bar(_stats.hp, _stats.max_hp)
		_progression.grant_proficiency_xp("constitution", CONSTITUTION_XP_PER_HIT)

func _on_entity_healed(eid: String, _amount: int, _current_hp: int) -> void:
	if eid == "player":
		_visuals.update_hp_bar(_stats.hp, _stats.max_hp)

func _on_proficiency_level_up(eid: String, skill_id: String, new_level: int) -> void:
	if eid != "player":
		return
	# Check if any active skills should be unlocked
	for active_skill_id in SkillDatabase.SKILLS:
		var skill: Dictionary = SkillDatabase.SKILLS[active_skill_id]
		var req: Dictionary = skill.get("required_proficiency", {})
		if req.get("skill", "") == skill_id and req.get("level", 1) <= new_level:
			if not _skills_comp.has_skill(active_skill_id):
				_skills_comp.unlock_skill(active_skill_id)

func _on_vending_started(eid: String, shop_title: String) -> void:
	if eid == entity_id:
		_visuals.show_vend_sign(shop_title)

func _on_vending_stopped(eid: String) -> void:
	if eid == entity_id:
		_visuals.hide_vend_sign()

func _on_auto_attack_landed(target_id: String, damage: int, target_pos: Vector3) -> void:
	_visuals.spawn_damage_number(target_id, damage, Color(1, 1, 1), target_pos)
	_visuals.flash_target(target_id)
	var target_data: Dictionary = WorldState.get_entity_data(target_id)
	var monster_type: String = target_data.get("monster_type", "")
	if not monster_type.is_empty():
		var weapon_type: String = _combat.get_equipped_weapon_type()
		_progression.grant_combat_xp(monster_type, weapon_type)

func _on_auto_attack_target_lost() -> void:
	_cancel_attack()

# --- Duck typing delegations ---

func flash_hit() -> void:
	_visuals.flash_hit()

func _spawn_click_marker(pos: Vector3) -> void:
	# Reuse a single marker instance — kill any in-progress tween first
	if _click_marker_tween and _click_marker_tween.is_valid():
		_click_marker_tween.kill()

	_click_marker.global_position = Vector3(pos.x, pos.y + 0.05, pos.z)
	_click_marker.scale = Vector3.ONE
	_click_marker_material.albedo_color = Color(0.3, 1.0, 0.4, 0.7)
	_click_marker.visible = true

	_click_marker_tween = get_tree().create_tween()
	_click_marker_tween.set_parallel(true)
	_click_marker_tween.tween_property(_click_marker_material, "albedo_color:a", 0.0, 0.6)
	_click_marker_tween.tween_property(_click_marker, "scale", Vector3(0.3, 0.3, 0.3), 0.6)
	_click_marker_tween.chain().tween_callback(func() -> void: _click_marker.visible = false)
