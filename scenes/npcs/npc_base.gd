extends CharacterBody3D
## NPC base — state machine, navigation, perception, and LLM brain integration.

@export var npc_id: String = ""
@export var npc_name: String = ""
@export var personality: String = ""
@export var starting_goal: String = ""
@export var npc_color: Color = Color(0.6, 0.3, 0.3, 1.0)

# States as strings to avoid cross-script class_name issues
const STATE_IDLE: String = "idle"
const STATE_THINKING: String = "thinking"
const STATE_MOVING: String = "moving"
const STATE_TALKING: String = "talking"
const STATE_INTERACTING: String = "interacting"
const STATE_FAILED: String = "failed"

var current_state: String = STATE_IDLE
var current_goal: String = ""
var current_action: String = ""
var current_target: String = ""
var last_thought: String = ""
var _suppress_nav_complete: bool = false
var _nav_started: bool = false
var _nav_wait_frames: int = 0

# Navigation & UI
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var body_mesh: CSGCylinder3D = $Body
@onready var head_mesh: CSGSphere3D = $Head
@onready var dialogue_bubble: Node3D = $DialogueBubble
@onready var name_label: Label3D = $NameLabel
@onready var interaction_prompt: Label3D = $InteractionPrompt

const MOVE_SPEED: float = 3.0
const ARRIVAL_THRESHOLD: float = 1.0
const GRAVITY: float = 9.8

# State materials
var _material_idle: StandardMaterial3D
var _material_thinking: StandardMaterial3D
var _material_talking: StandardMaterial3D
var _material_failed: StandardMaterial3D

func _ready() -> void:
	current_goal = starting_goal
	_setup_materials()
	_register_with_world()

	nav_agent.navigation_finished.connect(_on_navigation_finished)
	nav_agent.target_desired_distance = ARRIVAL_THRESHOLD
	nav_agent.path_desired_distance = ARRIVAL_THRESHOLD

	# Set name label
	if name_label:
		name_label.text = npc_name

	# Connect to dialogue events for bubble display
	GameEvents.npc_spoke.connect(_on_any_npc_spoke)

func _setup_materials() -> void:
	_material_idle = StandardMaterial3D.new()
	_material_idle.albedo_color = npc_color
	body_mesh.material = _material_idle

	_material_thinking = StandardMaterial3D.new()
	_material_thinking.albedo_color = npc_color.lightened(0.3)

	_material_talking = StandardMaterial3D.new()
	_material_talking.albedo_color = Color(0.2, 0.7, 0.3, 1.0)

	_material_failed = StandardMaterial3D.new()
	_material_failed.albedo_color = Color(0.7, 0.2, 0.2, 1.0)

func _register_with_world() -> void:
	WorldState.register_entity(npc_id, self, {
		"type": "npc",
		"name": npc_name,
		"personality": personality,
		"state": STATE_IDLE,
		"goal": current_goal,
		"inventory": [],
	})

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if current_state == STATE_MOVING:
		_process_movement()
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED)

	move_and_slide()
	_update_interaction_prompt()

func _process_movement() -> void:
	if not _nav_started:
		if not nav_agent.is_navigation_finished():
			_nav_started = true
			print("[%s] Nav path ready, starting movement" % npc_id)
		else:
			_nav_wait_frames += 1
			if _nav_wait_frames > 60:
				print("[%s] Nav path TIMEOUT after 60 frames — no path computed" % npc_id)
				change_state(STATE_IDLE)
				GameEvents.npc_action_completed.emit(npc_id, "move_to", false)
			return

	if nav_agent.is_navigation_finished():
		change_state(STATE_IDLE)
		GameEvents.npc_action_completed.emit(npc_id, "move_to", true)
		return

	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var dir: Vector3 = (next_pos - global_position)
	dir.y = 0.0
	dir = dir.normalized()

	if dir.length() > 0.1:
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED

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

	match new_state:
		STATE_IDLE, STATE_MOVING, STATE_INTERACTING:
			body_mesh.material = _material_idle
		STATE_THINKING:
			body_mesh.material = _material_thinking
		STATE_TALKING:
			body_mesh.material = _material_talking
		STATE_FAILED:
			body_mesh.material = _material_failed

	GameEvents.npc_state_changed.emit(npc_id, old_state, new_state)

func _on_any_npc_spoke(speaker_id: String, dialogue: String, _target_id: String) -> void:
	if speaker_id == npc_id and dialogue_bubble:
		dialogue_bubble.show_dialogue(dialogue)

# --- Actions ---

func navigate_to(target_pos: Vector3) -> void:
	print("[%s] navigate_to(%s) from %s" % [npc_id, target_pos, global_position])
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

# --- Hover Highlight ---

func highlight() -> void:
	if body_mesh and body_mesh.material:
		body_mesh.material.emission_enabled = true
		body_mesh.material.emission = Color(1.0, 1.0, 0.8)
		body_mesh.material.emission_energy_multiplier = 0.3

func unhighlight() -> void:
	if body_mesh and body_mesh.material:
		body_mesh.material.emission_enabled = false
