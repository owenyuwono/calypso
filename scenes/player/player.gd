extends CharacterBody3D
## Player controller with point-and-click movement, click-to-attack/interact, and death/respawn.
## Uses Meshy AI swordsman model with separate animation files.

const SPEED: float = 7.2
const GRAVITY: float = 9.8
const INTERACT_RANGE: float = 4.0
const MODEL_SCALE: float = 1.5
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
const PerceptionComponent = preload("res://scripts/components/perception_component.gd")
const LevelData = preload("res://scripts/data/level_data.gd")
const CursorManager = preload("res://scripts/utils/cursor_manager.gd")
const SfxDatabase = preload("res://scripts/audio/sfx_database.gd")

var entity_id: String = "player"

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var _cursor_manager: RefCounted

# Navigation
var _is_navigating: bool = false
var _interact_target: String = ""
var _stuck_timer: float = 0.0
var _last_nav_pos: Vector3 = Vector3.ZERO
var _was_moving: bool = false

# Combat
var _attack_target: String = ""
var _is_dead: bool = false
var _respawn_timer: float = 0.0
var _stagger_timer: float = 0.0
var _last_damage_time: int = 0
var _hp_regen_accumulator: float = 0.0

# AGI travel XP
var _combat_distance_traveled: float = 0.0
var _last_position: Vector3

# Harvesting
var _harvest_target: String = ""
var _chop_timer: float = 0.0
var _chop_interval: float = 2.0
var _chop_hit_pending: bool = false
var _chop_hit_timer: float = 0.0

# Audio component
var _audio: Node

# Visuals component
var _visuals: Node
var _stats: Node
var _inventory: Node
var _equipment: Node
var _combat: Node
var _progression: Node
var _skills_comp: Node
var _auto_attack: Node
var _perception: Node
var _stamina: Node
var _quest_comp: Node

# Child subsystem nodes
var _hover: Node
var _player_input: Node

# UI references (set by main scene setup)
var shop_panel: Control
var skill_hotbar: Control
var npc_info_panel: Control
var dialogue_panel: Node
var crafting_panel: Control
var game_menu: Node
var relationship_panel: Node
var interior_manager: Node

# Dialogue bubble above head
var _dialogue_bubble: Node3D


func _exit_tree() -> void:
	if _cursor_manager:
		_cursor_manager.cleanup()

func _ready() -> void:
	add_to_group("player")
	collision_layer |= (1 << 8)

	_visuals = EntityVisuals.new()
	add_child(_visuals)
	_visuals.setup_model_with_anims(
		"res://assets/models/characters/swordsman_m.glb",
		{
			"Walking_A": "res://assets/models/characters/swordsman_m_walk.glb",
			"Running_A": "res://assets/models/characters/swordsman_m_run.glb",
		},
		MODEL_SCALE,
		Color(0.2, 0.4, 0.7)
	)

	_audio = preload("res://scripts/audio/audio_component.gd").new()
	_audio.name = "AudioComponent"
	add_child(_audio)
	_audio.setup(self)

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
	_equipment.setup({
		"head": "", "torso": "", "legs": "", "gloves": "",
		"feet": "", "back": "", "main_hand": "", "off_hand": "",
	}, _inventory)

	_progression = ProgressionComponent.new()
	_progression.name = "ProgressionComponent"
	add_child(_progression)
	_progression.setup(_stats, {}, _equipment)

	# DEBUG: Override stats for testing combat mechanics — remove when done
	_progression.set_debug_overrides({"evasion": 50, "crit_rate": 50})

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
	stats["equipment"] = {"head": "", "torso": "", "legs": "", "gloves": "", "feet": "", "back": "", "main_hand": "", "off_hand": ""}
	stats["skills"] = {}
	stats["hotbar"] = ["", "", "", "", ""]
	WorldState.register_entity("player", self, stats)

	# Add StaminaComponent
	var stamina_comp := preload("res://scripts/components/stamina_component.gd").new()
	stamina_comp.name = "StaminaComponent"
	add_child(stamina_comp)
	stamina_comp.setup_rest_spots(["TownWell", "TownInn"])
	_stamina = stamina_comp

	var quest_comp: Node = QuestComponent.new()
	quest_comp.name = "QuestComponent"
	add_child(quest_comp)
	_quest_comp = quest_comp

	var perception_comp := PerceptionComponent.new()
	perception_comp.name = "PerceptionComponent"
	add_child(perception_comp)
	perception_comp.setup()
	_perception = perception_comp

	_cursor_manager = CursorManager.new()

	# Hover subsystem
	_hover = preload("res://scenes/player/player_hover.gd").new()
	_hover.name = "PlayerHover"
	add_child(_hover)
	_hover.setup(self, _cursor_manager)

	_skills_comp.setup_execution(_combat, _stats, _progression, _visuals, _perception, _auto_attack)

	# Skills input adapter
	_player_input = preload("res://scripts/components/player_input_component.gd").new()
	_player_input.name = "PlayerInputComponent"
	add_child(_player_input)
	_player_input.setup(self, _skills_comp)


	_setup_dialogue_bubble()

	# Player HP is shown in HUD, no 3D bar needed

	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_damaged.connect(_on_entity_damaged)
	GameEvents.proficiency_level_up.connect(_on_proficiency_level_up)
	GameEvents.attack_missed.connect(_on_attack_missed)

	_last_position = global_position


func _setup_dialogue_bubble() -> void:
	var bubble_scene := preload("res://scenes/ui/dialogue_bubble.tscn")
	_dialogue_bubble = bubble_scene.instantiate()
	add_child(_dialogue_bubble)
	_dialogue_bubble.position = Vector3(0, 2.2, 0)


func _physics_process(delta: float) -> void:
	if _is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		return

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
		# WASD cancels any click-based navigation/combat/harvest
		if _is_navigating:
			_stop_navigation()
		if not _attack_target.is_empty():
			_cancel_attack()
		if not _harvest_target.is_empty():
			_cancel_harvest()
		# Camera-relative direction
		var cam := get_viewport().get_camera_3d()
		var cam_basis := cam.global_transform.basis
		var cam_fwd := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
		var cam_right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		var move_dir := (cam_right * input_dir.x + cam_fwd * -input_dir.y).normalized()
		var effective_speed: float = SPEED * _stats.move_speed
		if _stamina:
			effective_speed *= _stamina.get_fatigue_multiplier("move_speed")
		if Input.is_action_pressed("sprint"):
			effective_speed *= 1.5
		velocity.x = move_dir.x * effective_speed
		velocity.z = move_dir.z * effective_speed
		_visuals.face_direction(move_dir)
		is_moving = true
	elif not _attack_target.is_empty():
		is_moving = _process_combat(delta)
	elif not _harvest_target.is_empty():
		is_moving = _process_harvesting(delta)
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
			_on_arrived()
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	move_and_slide()

	# Safety teleport if fallen off the world (skip when inside an interior at Y=-50)
	if global_position.y < -10.0 and not (interior_manager and interior_manager.is_inside()):
		global_position = Vector3(0.0, 2.0, 0.0)
		velocity = Vector3.ZERO

	# AGI travel XP: 1 XP per 10m traveled while in combat
	if not _attack_target.is_empty():
		var dist: float = global_position.distance_to(_last_position)
		_combat_distance_traveled += dist
		if _combat_distance_traveled >= 10.0:
			if _progression:
				_progression.grant_proficiency_xp("agi", 1)
			_combat_distance_traveled -= 10.0
	_last_position = global_position

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

	# Update animation
	if _attack_target.is_empty() and _harvest_target.is_empty():
		if is_moving:
			_visuals.play_anim("Running_A")
		else:
			_visuals.play_anim("Idle")

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

	# While a skill hit is pending, handle it here — auto-attack is suppressed
	if _player_input.pending_skill_hit:
		return _player_input.process_skill_hit(delta, attack_range)

	# Normal auto-attack: delegate to component
	var result: Dictionary = _auto_attack.process_attack(
		delta, _attack_target, global_position, effective_move_speed, attack_range, effective_attack_speed
	)
	# Keep locked target's HP bar updated
	if not _attack_target.is_empty():
		_show_target_hp_bar(_attack_target)
	return result.get("is_moving", false)

func _cancel_attack() -> void:
	_hide_target_hp_bar(_attack_target)
	_attack_target = ""
	_auto_attack.cancel()
	_player_input.cancel_pending()
	_hover.clear_ring()
	_combat_distance_traveled = 0.0
	if _audio:
		_audio.stop_combat_loop()

func _show_target_hp_bar(target_id: String) -> void:
	var target: Node3D = WorldState.get_entity(target_id)
	if target:
		var visuals: Node = target.get_node_or_null("EntityVisuals")
		if visuals:
			var stats: Node = target.get_node_or_null("StatsComponent")
			if stats:
				visuals.set_hp_bar_visible(true)
				visuals.update_hp_bar_combat(stats.hp, stats.max_hp, true)

func _hide_target_hp_bar(target_id: String) -> void:
	if target_id.is_empty():
		return
	var target: Node3D = WorldState.get_entity(target_id)
	if target:
		var visuals: Node = target.get_node_or_null("EntityVisuals")
		if visuals:
			visuals.set_hp_bar_visible(false)

func _get_approach_pos(target_pos: Vector3, standoff: float) -> Vector3:
	var offset: Vector3 = global_position - target_pos
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		offset = Vector3(1.0, 0.0, 0.0)
	return target_pos + offset.normalized() * standoff

func _cancel_harvest() -> void:
	_harvest_target = ""
	_chop_timer = _chop_interval
	_chop_hit_pending = false
	_chop_hit_timer = 0.0
	_hover.clear_ring()

func _process_harvesting(delta: float) -> bool:
	# Validate target still exists and is harvestable
	if not WorldState.get_entity(_harvest_target):
		_cancel_harvest()
		return false

	var resource_node: Node = WorldState.get_entity(_harvest_target)
	if not is_instance_valid(resource_node):
		_cancel_harvest()
		return false

	var harvestable: Node = resource_node.get_node_or_null("HarvestableComponent")
	if not harvestable:
		_cancel_harvest()
		return false

	if not harvestable.can_harvest("player"):
		_cancel_harvest()
		return false

	# Move toward resource if out of range
	var dist: float = global_position.distance_to(resource_node.global_position)
	if dist > 3.0:
		nav_agent.target_position = _get_approach_pos(resource_node.global_position, 2.5)
		_is_navigating = true
		_last_nav_pos = global_position
		var next_pos: Vector3 = nav_agent.get_next_path_position()
		var dir: Vector3 = next_pos - global_position
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			dir = dir.normalized()
			var harvest_speed: float = SPEED * _stats.move_speed
			if _stamina:
				harvest_speed *= _stamina.get_fatigue_multiplier("move_speed")
			velocity.x = dir.x * harvest_speed
			velocity.z = dir.z * harvest_speed
			_visuals.face_direction(dir)
		return true

	# In range — stop moving and chop
	_is_navigating = false
	velocity.x = move_toward(velocity.x, 0.0, SPEED)
	velocity.z = move_toward(velocity.z, 0.0, SPEED)

	# Face the resource
	var face_dir: Vector3 = resource_node.global_position - global_position
	face_dir.y = 0.0
	if face_dir.length_squared() > 0.01:
		_visuals.face_direction(face_dir.normalized())

	# Advance chop timer
	_chop_timer += delta
	if _chop_timer >= _chop_interval:
		_chop_timer = 0.0
		_visuals.play_anim("1H_Melee_Attack_Chop")
		_chop_hit_pending = true
		_chop_hit_timer = _visuals.get_hit_delay("1H_Melee_Attack_Chop")

	# Resolve hit frame
	if _chop_hit_pending:
		_chop_hit_timer -= delta
		if _chop_hit_timer <= 0.0:
			_chop_hit_pending = false
			var result: Dictionary = harvestable.process_chop("player")
			if result.is_empty():
				_cancel_harvest()
				return false
			var skill_id: String = harvestable.get_skill_id()
			_progression.grant_proficiency_xp(skill_id, result.xp)
			resource_node.last_chopper_pos = global_position
			resource_node.shake()
			if _audio:
				var gather_key: String = ""
				match skill_id:
					"woodcutting": gather_key = "gather_tree_chop"
					"mining": gather_key = "gather_rock_mine"
					"fishing": gather_key = "gather_fishing_cast"
				if gather_key != "":
					_audio.play_oneshot(gather_key)
			if result.depleted:
				resource_node.spawn_loot(result.item_id, result.bonus_item)
				_cancel_harvest()

	return false

func _stop_navigation() -> void:
	_is_navigating = false
	_interact_target = ""

func _navigate_to(pos: Vector3) -> void:
	nav_agent.target_position = pos
	_is_navigating = true
	_last_nav_pos = global_position
	_stuck_timer = 0.0

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
		if dialogue_panel and target_node and is_instance_valid(target_node):
			dialogue_panel.open_dialogue(_interact_target, target_node)
		elif npc_info_panel and npc_info_panel.has_method("show_npc"):
			npc_info_panel.show_npc(_interact_target)
		_hover.clear_ring()
	elif etype == "interior_npc":
		if dialogue_panel and target_node and is_instance_valid(target_node):
			dialogue_panel.open_dialogue(_interact_target, target_node)
		else:
			var vending_comp: Node = target_node.get_node_or_null("VendingComponent") if target_node else null
			if vending_comp and vending_comp.get_listings().size() > 0:
				_open_shop(_interact_target)
		_hover.clear_ring()
	elif etype == "crafting_station":
		if crafting_panel and target_node and is_instance_valid(target_node):
			var stype: String = data.get("station_type", "")
			var sname: String = data.get("name", "Crafting")
			crafting_panel.open(stype, sname)
		_hover.clear_ring()
	elif etype == "door":
		if interior_manager and target_node and is_instance_valid(target_node):
			var btype: String = data.get("building_type", "")
			interior_manager.enter_interior(btype, target_node.global_position)
		_hover.clear_ring()

	_interact_target = ""

func _input(event: InputEvent) -> void:
	if _is_dead:
		return
	if event.is_action_pressed("ui_cancel") and dialogue_panel and dialogue_panel.visible:
		dialogue_panel.close_dialogue()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and interior_manager and interior_manager.is_inside():
		interior_manager.exit_interior()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return

	if not _is_ui_open():
		for i in range(5):
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				_player_input.try_use_hotbar_slot(i)
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("interact"):
		_interact_with_nearest()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_ui_open():
				return
			_handle_left_click()

func _handle_left_click() -> void:
	var hovered_entity_id: String = _hover.get_hovered_entity_id()
	if not hovered_entity_id.is_empty():
		var data := WorldState.get_entity_data(hovered_entity_id)
		var etype: String = data.get("type", "")

		if etype == "monster" and WorldState.is_alive(hovered_entity_id):
			# Click monster: walk to + auto-attack, lock ring on target
			_cancel_harvest()
			_interact_target = ""
			_cancel_attack()  # Hide HP bar on old target before switching
			_attack_target = hovered_entity_id
			_auto_attack.cancel()
			_is_navigating = false
			_hover.lock_ring(hovered_entity_id, Color(1.0, 0.3, 0.2, 0.6))
			# Show HP bar on locked target
			_show_target_hp_bar(hovered_entity_id)
			if _audio:
				_audio.start_combat_loop()
			return

		if etype == "loot_drop":
			# Click loot: walk to + pick up on arrival
			_cancel_attack()
			_cancel_harvest()
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
			_cancel_harvest()
			_interact_target = hovered_entity_id
			_hover.lock_ring(hovered_entity_id, Color(0.3, 0.6, 1.0, 0.6))
			var target_node := WorldState.get_entity(hovered_entity_id)
			if target_node and is_instance_valid(target_node):
				# Check if already in range
				var dist := global_position.distance_to(target_node.global_position)
				if dist <= INTERACT_RANGE:
					_on_arrived()
					return
				_navigate_to(target_node.global_position)
			return

		if etype == "interior_npc":
			# Click interior NPC: walk to + open shop on arrival
			_cancel_attack()
			_cancel_harvest()
			_interact_target = hovered_entity_id
			_hover.lock_ring(hovered_entity_id, Color(0.3, 0.6, 1.0, 0.6))
			var target_node := WorldState.get_entity(hovered_entity_id)
			if target_node and is_instance_valid(target_node):
				var dist := global_position.distance_to(target_node.global_position)
				if dist <= INTERACT_RANGE:
					_on_arrived()
					return
				_navigate_to(target_node.global_position)
			return

		if etype == "tree":
			# Click tree: walk to + chop when in range
			_cancel_attack()
			_cancel_harvest()
			_harvest_target = hovered_entity_id
			_hover.lock_ring(hovered_entity_id, Color(0.4, 0.8, 0.3, 0.6))
			var target_node := WorldState.get_entity(hovered_entity_id)
			if target_node and is_instance_valid(target_node):
				_navigate_to(_get_approach_pos(target_node.global_position, 2.5))
			return

		if etype == "rock":
			# Click rock: walk to + mine when in range
			_cancel_attack()
			_cancel_harvest()
			_harvest_target = hovered_entity_id
			_hover.lock_ring(hovered_entity_id, Color(0.8, 0.5, 0.2, 0.6))
			var target_node: Node = WorldState.get_entity(hovered_entity_id)
			if target_node and is_instance_valid(target_node):
				_navigate_to(_get_approach_pos(target_node.global_position, 2.5))
			return

		if etype == "fishing_spot":
			# Click fishing spot: walk to + fish when in range
			_cancel_attack()
			_cancel_harvest()
			_harvest_target = hovered_entity_id
			_hover.lock_ring(hovered_entity_id, Color(0.2, 0.5, 1.0, 0.6))
			var target_node: Node = WorldState.get_entity(hovered_entity_id)
			if target_node and is_instance_valid(target_node):
				_navigate_to(_get_approach_pos(target_node.global_position, 2.5))
			return

		if etype == "crafting_station":
			# Click crafting station: walk to + open panel on arrival
			_cancel_attack()
			_cancel_harvest()
			_interact_target = hovered_entity_id
			_hover.lock_ring(hovered_entity_id, Color(0.5, 0.8, 0.6, 0.6))
			var target_node: Node = WorldState.get_entity(hovered_entity_id)
			if target_node and is_instance_valid(target_node):
				var dist: float = global_position.distance_to(target_node.global_position)
				if dist <= INTERACT_RANGE:
					_on_arrived()
					return
				_navigate_to(_get_approach_pos(target_node.global_position, 2.0))
			return

		if etype == "door":
			# Guard: don't process door clicks while already inside
			if not interior_manager or interior_manager.is_inside():
				return
			# Click door: walk to + enter interior on arrival
			_cancel_attack()
			_cancel_harvest()
			_interact_target = hovered_entity_id
			_hover.lock_ring(hovered_entity_id, Color(0.9, 0.7, 0.3, 0.6))
			var target_node: Node = WorldState.get_entity(hovered_entity_id)
			if target_node and is_instance_valid(target_node):
				var dist: float = global_position.distance_to(target_node.global_position)
				if dist <= INTERACT_RANGE:
					_on_arrived()
					return
				_navigate_to(_get_approach_pos(target_node.global_position, 1.5))
			return

	# Click on empty space: no ground navigation (use WASD to move)

func _interact_with_nearest() -> void:
	var nearby: Array = _perception.get_nearby(INTERACT_RANGE)
	for entry in nearby:
		if entry.id == "player":
			continue
		var data := WorldState.get_entity_data(entry.id)
		var etype: String = data.get("type", "")
		if etype == "npc":
			var vending_comp: Node = entry.node.get_node_or_null("VendingComponent") if entry.node else null
			if vending_comp and vending_comp.get_listings().size() > 0:
				_open_shop(entry.id)
				return
			_command_npc_follow(entry.node)
			return

func _command_npc_follow(npc_node: Node3D) -> void:
	if npc_node.has_method("set_goal"):
		npc_node.set_goal("follow_player")

func _open_shop(shop_id: String) -> void:
	if shop_panel:
		var vendor_node := WorldState.get_entity(shop_id)
		if vendor_node and is_instance_valid(vendor_node):
			enter_vending_state()
			shop_panel.open_shop(vendor_node)

func enter_vending_state() -> void:
	_cancel_attack()
	_cancel_harvest()
	_stop_navigation()
	velocity = Vector3.ZERO

func _is_ui_open() -> bool:
	if dialogue_panel and dialogue_panel.visible:
		return true
	if game_menu and game_menu.is_open():
		return true
	if shop_panel and shop_panel.is_open():
		return true
	if crafting_panel and crafting_panel.is_open():
		return true
	if relationship_panel and relationship_panel.is_open():
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
	_is_dead = true
	_cancel_attack()
	_cancel_harvest()
	_stop_navigation()
	velocity = Vector3.ZERO
	_cursor_manager.reset()
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

	var city_spawn: Vector3 = ZoneDatabase.ZONES["city"]["spawn_point"]
	var loaded_zone: Node3D = ZoneManager.get_loaded_zone()
	var current_zone_id: String = ""
	if loaded_zone and "zone_id" in loaded_zone:
		current_zone_id = loaded_zone.zone_id

	if current_zone_id == "city":
		# Already in city — just teleport to spawn point
		global_position = city_spawn
		velocity = Vector3.ZERO
	elif not ZoneManager.is_transitioning():
		# In a field or unknown zone — load city
		ZoneManager.load_zone("city", city_spawn)

func _on_entity_damaged(target_id: String, _attacker_id: String, _damage: int, _remaining_hp: int) -> void:
	if target_id == "player":
		flash_hit()
		_stagger_timer = 0.3
		_progression.grant_proficiency_xp("con", CONSTITUTION_XP_PER_HIT)
		_last_damage_time = Time.get_ticks_msec()
		_hp_regen_accumulator = 0.0

func _on_proficiency_level_up(eid: String, _skill_id: String, _new_level: int) -> void:
	if eid != "player":
		return

func _on_auto_attack_landed(target_id: String, damage: int, target_pos: Vector3) -> void:
	_visuals.flash_target(target_id)
	var weapon_type: String = _combat.get_equipped_weapon_type() if _combat else "generic"
	var target_data: Dictionary = WorldState.get_entity_data(target_id)
	var monster_type: String = target_data.get("monster_type", "")
	if not monster_type.is_empty():
		_progression.grant_combat_xp(monster_type, weapon_type)
	# STR XP: 3 per physical auto-attack hit
	if _progression:
		_progression.grant_proficiency_xp("str", 3)
		# DEX XP: 2 per hit landed
		_progression.grant_proficiency_xp("dex", 2)
	if _audio:
		var hit_key: String = "combat_hit_" + weapon_type
		if SfxDatabase.get_sfx(hit_key).is_empty():
			hit_key = "combat_hit_generic"
		_audio.play_oneshot(hit_key)

func _on_auto_attack_target_lost() -> void:
	_cancel_attack()
	_cancel_harvest()

func _on_attack_missed(target_id: String, _attacker_id: String) -> void:
	if target_id == entity_id and _progression:
		_progression.grant_proficiency_xp("agi", 5)

# --- Duck typing delegations ---

func flash_hit() -> void:
	_visuals.flash_hit()

