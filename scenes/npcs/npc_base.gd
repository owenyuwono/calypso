extends CharacterBody3D
## NPC base — state machine, navigation, perception, combat, and LLM brain integration.
## Uses KayKit 3D character models with overlay-based visual effects.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")

@export var npc_id: String = ""
@export var npc_name: String = ""
@export var personality: String = ""
@export var starting_goal: String = ""
@export var npc_color: Color = Color(0.6, 0.3, 0.3, 1.0)
@export var model_path: String = "res://assets/models/characters/Knight.glb"
@export var model_scale: float = 0.7

# States as strings to avoid cross-script class_name issues
const STATE_IDLE: String = "idle"
const STATE_THINKING: String = "thinking"
const STATE_MOVING: String = "moving"
const STATE_TALKING: String = "talking"
const STATE_INTERACTING: String = "interacting"
const STATE_FAILED: String = "failed"
const STATE_COMBAT: String = "combat"
const STATE_DEAD: String = "dead"

var current_state: String = STATE_IDLE
var current_goal: String = ""
var current_action: String = ""
var current_target: String = ""
var last_thought: String = ""
var _suppress_nav_complete: bool = false
var _nav_started: bool = false
var _nav_wait_frames: int = 0

# Combat
var combat_target: String = ""
var _attack_timer: float = 0.0
var _respawn_timer: float = 0.0
var _last_nav_target_pos: Vector3 = Vector3.INF
var _interaction_prompt_timer: float = 0.0

# Navigation & UI
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var dialogue_bubble: Node3D = $DialogueBubble
@onready var name_label: Label3D = $NameLabel
@onready var interaction_prompt: Label3D = $InteractionPrompt

const MOVE_SPEED: float = 3.0
const ARRIVAL_THRESHOLD: float = 1.0
const GRAVITY: float = 9.8

# 3D Model
var _model: Node3D
var _mesh_instances: Array[MeshInstance3D] = []
var _overlay_material: StandardMaterial3D
var _anim_player: AnimationPlayer
var _current_anim: String = ""

# State overlay colors
const STATE_COLORS: Dictionary = {
	"idle": Color(0, 0, 0, 0),
	"moving": Color(0, 0, 0, 0),
	"interacting": Color(0, 0, 0, 0),
	"thinking": Color(0.5, 0.5, 1.0, 0.15),
	"talking": Color(0.2, 0.7, 0.3, 0.15),
	"failed": Color(0.7, 0.2, 0.2, 0.2),
	"combat": Color(0.8, 0.2, 0.1, 0.15),
}

var _hp_bar: Node3D

func _ready() -> void:
	current_goal = starting_goal
	_setup_model()
	_register_with_world()

	nav_agent.navigation_finished.connect(_on_navigation_finished)
	nav_agent.target_desired_distance = ARRIVAL_THRESHOLD
	nav_agent.path_desired_distance = ARRIVAL_THRESHOLD

	if name_label:
		name_label.text = npc_name

	GameEvents.npc_spoke.connect(_on_any_npc_spoke)
	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_damaged.connect(_on_entity_damaged)
	GameEvents.entity_healed.connect(_on_entity_healed)

	_setup_hp_bar()

func _setup_model() -> void:
	var result := ModelHelper.instantiate_model(model_path, model_scale)
	if result.model == null:
		push_warning("NPC %s: Could not load model '%s', using fallback" % [npc_id, model_path])
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
	mat.albedo_color = npc_color
	mesh_inst.mesh.surface_set_material(0, mat)
	_model.add_child(mesh_inst)
	_mesh_instances = [mesh_inst]
	_overlay_material = ModelHelper.create_overlay_material()
	ModelHelper.apply_overlay(_mesh_instances, _overlay_material)
	ModelHelper.apply_toon_to_model(_model)

func _play_anim(anim_name: String) -> void:
	if not _anim_player or _current_anim == anim_name:
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)
		_current_anim = anim_name

func _face_direction(dir: Vector3) -> void:
	if _model and dir.length() > 0.1:
		_model.rotation.y = atan2(dir.x, dir.z)

func _register_with_world() -> void:
	WorldState.register_entity(npc_id, self, {
		"type": "npc",
		"name": npc_name,
		"personality": personality,
		"state": STATE_IDLE,
		"goal": current_goal,
		"inventory": {},
		"equipment": {"weapon": "", "armor": ""},
		"hp": 50, "max_hp": 50,
		"atk": 10, "def": 5,
		"level": 1, "xp": 0,
		"gold": 80,
		"attack_speed": 1.0, "attack_range": 2.0,
	})

func _setup_hp_bar() -> void:
	var hp_bar_scene := preload("res://scenes/ui/hp_bar_3d.tscn")
	_hp_bar = hp_bar_scene.instantiate()
	add_child(_hp_bar)
	_hp_bar.position = Vector3(0, 1.8, 0)
	_hp_bar.visible = false

func _physics_process(delta: float) -> void:
	if current_state == STATE_DEAD:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var is_moving := false
	if current_state == STATE_MOVING:
		is_moving = _process_movement()
	elif current_state == STATE_COMBAT:
		is_moving = _process_combat(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED)

	move_and_slide()
	_interaction_prompt_timer -= delta
	if _interaction_prompt_timer <= 0.0:
		_interaction_prompt_timer = 0.5
		_update_interaction_prompt()

	# Update animation based on movement
	if current_state == STATE_COMBAT:
		pass  # Combat handles its own anims
	elif current_state == STATE_DEAD:
		pass
	elif is_moving:
		_play_anim("Walking_A")
	else:
		_play_anim("Idle")

func _process_movement() -> bool:
	if not _nav_started:
		if not nav_agent.is_navigation_finished():
			_nav_started = true
		else:
			_nav_wait_frames += 1
			if _nav_wait_frames > 60:
				change_state(STATE_IDLE)
				GameEvents.npc_action_completed.emit(npc_id, "move_to", false)
			return false

	if nav_agent.is_navigation_finished():
		change_state(STATE_IDLE)
		GameEvents.npc_action_completed.emit(npc_id, "move_to", true)
		return false

	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var dir: Vector3 = (next_pos - global_position)
	dir.y = 0.0
	dir = dir.normalized()

	if dir.length() > 0.1:
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		_face_direction(dir)
		return true
	return false

func _process_combat(delta: float) -> bool:
	var target_node := WorldState.get_entity(combat_target)
	if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(combat_target):
		# Target dead or gone — exit combat
		combat_target = ""
		change_state(STATE_IDLE)
		return false

	var dist := global_position.distance_to(target_node.global_position)
	var attack_range: float = WorldState.get_entity_data(npc_id).get("attack_range", 2.0)

	if dist > attack_range * 1.5:
		# Chase target — only update nav if target moved significantly
		var target_pos := target_node.global_position
		if _last_nav_target_pos.distance_to(target_pos) > 1.0:
			_last_nav_target_pos = target_pos
			nav_agent.target_position = target_pos
		if not nav_agent.is_navigation_finished():
			var next_pos := nav_agent.get_next_path_position()
			var dir := (next_pos - global_position)
			dir.y = 0.0
			dir = dir.normalized()
			if dir.length() > 0.1:
				velocity.x = dir.x * MOVE_SPEED * 1.1
				velocity.z = dir.z * MOVE_SPEED * 1.1
				_face_direction(dir)
				_play_anim("Running_A")
		return true

	# In range — auto-attack
	velocity.x = 0.0
	velocity.z = 0.0
	# Face the target
	var to_target := (target_node.global_position - global_position).normalized()
	_face_direction(to_target)

	var attack_speed: float = WorldState.get_entity_data(npc_id).get("attack_speed", 1.0)
	_attack_timer += delta
	if _attack_timer >= attack_speed:
		_attack_timer = 0.0
		_do_combat_attack()
		_play_anim("1H_Melee_Attack_Chop")
	return false

func _do_combat_attack() -> void:
	if not WorldState.is_alive(combat_target):
		return
	var damage := WorldState.deal_damage(npc_id, combat_target)
	_spawn_damage_number(combat_target, damage)
	_flash_target(combat_target)

	# Occasionally say something in combat
	if randf() < 0.15:
		var shouts := ["Take that!", "Ha!", "Got you!", "Come on!", "Not bad!"]
		var shout: String = shouts[randi() % shouts.size()]
		GameEvents.npc_spoke.emit(npc_id, shout, combat_target)

func _on_navigation_finished() -> void:
	if current_state == STATE_MOVING and _nav_started:
		if _suppress_nav_complete:
			_suppress_nav_complete = false
			return
		change_state(STATE_IDLE)
		GameEvents.npc_action_completed.emit(npc_id, "move_to", true)

# --- State Machine ---

func change_state(new_state: String) -> void:
	var old_state := current_state
	current_state = new_state
	WorldState.set_entity_data(npc_id, "state", new_state)

	# Update overlay tint based on state
	if _overlay_material:
		var tint: Color = STATE_COLORS.get(new_state, Color(0, 0, 0, 0))
		ModelHelper.set_state_tint(_overlay_material, tint)

	GameEvents.npc_state_changed.emit(npc_id, old_state, new_state)

func _on_any_npc_spoke(speaker_id: String, dialogue: String, _target_id: String) -> void:
	if speaker_id == npc_id and dialogue_bubble:
		dialogue_bubble.show_dialogue(dialogue)

# --- Actions ---

func navigate_to(target_pos: Vector3) -> void:
	change_state(STATE_MOVING)
	_nav_started = false
	_nav_wait_frames = 0
	nav_agent.target_position = target_pos

func navigate_to_entity(target_id: String) -> void:
	var target_node: Node3D = WorldState.get_entity(target_id)
	if target_node:
		navigate_to(target_node.global_position)
	elif WorldState.has_location(target_id):
		navigate_to(WorldState.get_location(target_id))
	else:
		change_state(STATE_FAILED)
		GameEvents.npc_action_completed.emit(npc_id, "move_to", false)

func set_goal(new_goal: String) -> void:
	var old_goal := current_goal
	current_goal = new_goal
	WorldState.set_entity_data(npc_id, "goal", new_goal)
	GameEvents.npc_goal_changed.emit(npc_id, old_goal, new_goal)

func enter_combat(target_id: String) -> void:
	combat_target = target_id
	_attack_timer = 0.0
	_last_nav_target_pos = Vector3.INF
	change_state(STATE_COMBAT)

func _update_interaction_prompt() -> void:
	if not interaction_prompt:
		return
	var player_node = WorldState.get_entity("player")
	if not player_node or not is_instance_valid(player_node):
		interaction_prompt.visible = false
		return
	var dist := global_position.distance_to(player_node.global_position)
	var in_range := dist <= 4.0
	var is_available := current_state in [STATE_IDLE, STATE_MOVING]
	interaction_prompt.visible = in_range and is_available

func _update_hp_bar() -> void:
	if not _hp_bar:
		return
	var data := WorldState.get_entity_data(npc_id)
	var hp: int = data.get("hp", 0)
	var max_hp: int = data.get("max_hp", 1)
	if _hp_bar.has_method("update_bar"):
		_hp_bar.update_bar(hp, max_hp)
	_hp_bar.visible = hp < max_hp

# --- Death / Respawn ---

func _on_entity_died(entity_id: String, killer_id: String) -> void:
	if entity_id == npc_id:
		_die()
	elif entity_id == combat_target:
		# Target died — loot is handled by monster_base, just exit combat
		var memory_node = get_node_or_null("NPCMemory")
		if memory_node:
			memory_node.add_observation("Killed %s in combat" % combat_target)
		combat_target = ""
		change_state(STATE_IDLE)

func _die() -> void:
	change_state(STATE_DEAD)
	combat_target = ""
	velocity = Vector3.ZERO

	# Lose 10% gold
	var gold := WorldState.get_gold(npc_id)
	var lost := int(gold * 0.1)
	WorldState.remove_gold(npc_id, lost)

	var memory_node = get_node_or_null("NPCMemory")
	if memory_node:
		memory_node.add_observation("I died! Lost %d gold." % lost)

	# Visual: death animation + fade out
	_play_anim("Death_A")
	ModelHelper.fade_out(_mesh_instances, self)

	if _hp_bar:
		_hp_bar.visible = false

	_respawn_timer = 5.0

func _respawn() -> void:
	_current_anim = ""
	# Teleport to town
	global_position = Vector3(randf_range(-2, 2), 1, randf_range(-2, 2))
	velocity = Vector3.ZERO

	# Restore HP
	var max_hp: int = WorldState.get_entity_data(npc_id).get("max_hp", 50)
	WorldState.set_entity_data(npc_id, "hp", max_hp)

	# Visual: restore materials and play idle
	ModelHelper.restore_materials(_mesh_instances)
	ModelHelper.clear_overlay(_overlay_material)
	_play_anim("Idle")

	if _hp_bar:
		_hp_bar.visible = false

	change_state(STATE_IDLE)
	GameEvents.entity_respawned.emit(npc_id)
	_update_hp_bar()

	var memory_node = get_node_or_null("NPCMemory")
	if memory_node:
		memory_node.add_observation("Respawned in town after dying")

func _on_entity_damaged(target_id: String, _attacker_id: String, damage: int, _remaining_hp: int) -> void:
	if target_id == npc_id:
		flash_hit()
		_update_hp_bar()

func _on_entity_healed(entity_id: String, _amount: int, _current_hp: int) -> void:
	if entity_id == npc_id:
		_update_hp_bar()

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

# --- Hover Highlight ---

func highlight() -> void:
	if _overlay_material:
		ModelHelper.set_highlight(_overlay_material, true)

func unhighlight() -> void:
	if _overlay_material:
		ModelHelper.set_highlight(_overlay_material, false)
