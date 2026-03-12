extends CharacterBody3D
## NPC base — state machine, navigation, perception, combat, and LLM brain integration.
## Uses KayKit 3D character models with overlay-based visual effects.

const EntityVisuals = preload("res://scripts/components/entity_visuals.gd")
const StatsComponent = preload("res://scripts/components/stats_component.gd")
const InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const EquipmentComponent = preload("res://scripts/components/equipment_component.gd")
const CombatComponent = preload("res://scripts/components/combat_component.gd")
const ProgressionComponent = preload("res://scripts/components/progression_component.gd")
const ItemDatabase = preload("res://scripts/data/item_database.gd")
const LevelData = preload("res://scripts/data/level_data.gd")

@export var npc_id: String = ""
@export var npc_name: String = ""
@export var personality: String = ""
@export var starting_goal: String = ""
@export var npc_color: Color = Color(0.6, 0.3, 0.3, 1.0)
@export var model_path: String = "res://assets/models/characters/Knight.glb"
@export var model_scale: float = 0.7
@export var trait_profile: String = ""

var entity_id: String = ""

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
var current_mood: String = ""
var _suppress_nav_complete: bool = false
var _nav_started: bool = false
var _nav_wait_frames: int = 0

# Combat
var combat_target: String = ""
var _attack_timer: float = 0.0
var _respawn_timer: float = 0.0
var _last_nav_target_pos: Vector3 = Vector3.INF
var _pending_hit: bool = false
var _hit_time: float = 0.0

# Navigation & UI
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var dialogue_bubble: Node3D = $DialogueBubble
@onready var name_label: Label3D = $NameLabel

const MOVE_SPEED: float = 3.6
const ARRIVAL_THRESHOLD: float = 1.0
const GRAVITY: float = 9.8
const PERSONAL_SPACE: float = 2.5
const SEPARATION_FORCE: float = 2.0

# Visuals component
var _visuals: Node
var _stats: Node
var _inventory: Node
var _equipment: Node
var _combat: Node
var _progression: Node

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

func _ready() -> void:
	entity_id = npc_id
	current_goal = starting_goal

	_visuals = EntityVisuals.new()
	add_child(_visuals)
	_visuals.setup_model(model_path, model_scale, npc_color)

	_stats = StatsComponent.new()
	_stats.name = "StatsComponent"
	add_child(_stats)
	_stats.setup(LevelData.BASE_ADVENTURER_STATS)

	_inventory = InventoryComponent.new()
	_inventory.name = "InventoryComponent"
	add_child(_inventory)
	_inventory.setup({}, LevelData.BASE_ADVENTURER_STATS.get("gold", 80))

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

	_visuals.setup_hp_bar()
	_visuals.set_hp_bar_visible(false)

func _get_separation_velocity() -> Vector3:
	var sep := Vector3.ZERO
	for eid in WorldState.entities:
		if eid == npc_id:
			continue
		var data: Dictionary = WorldState.get_entity_data(eid)
		if data.get("type", "") != "npc":
			continue
		if not WorldState.is_alive(eid):
			continue
		var other: Node3D = WorldState.get_entity(eid)
		if not other or not is_instance_valid(other):
			continue
		var diff := global_position - other.global_position
		diff.y = 0.0
		var dist := diff.length()
		if dist < 0.01 or dist >= PERSONAL_SPACE:
			continue
		# Closer = stronger push (inverse linear)
		var strength: float = SEPARATION_FORCE * (1.0 - dist / PERSONAL_SPACE)
		sep += diff.normalized() * strength
	return sep


func _register_with_world() -> void:
	var stats := LevelData.BASE_ADVENTURER_STATS.duplicate()
	stats["type"] = "npc"
	stats["name"] = npc_name
	stats["personality"] = personality
	stats["state"] = STATE_IDLE
	stats["goal"] = current_goal
	stats["inventory"] = {}
	stats["equipment"] = {"weapon": "", "armor": ""}
	WorldState.register_entity(npc_id, self, stats)

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

	# Apply separation force to avoid NPC overlap (not in combat)
	if current_state != STATE_COMBAT:
		var sep := _get_separation_velocity()
		velocity.x += sep.x
		velocity.z += sep.z

	move_and_slide()

	# Update animation based on movement
	if current_state == STATE_COMBAT:
		pass  # Combat handles its own anims
	elif current_state == STATE_DEAD:
		pass
	elif is_moving:
		_visuals.play_anim("Walking_A")
	else:
		_visuals.play_anim("Idle")

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
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		_visuals.face_direction(dir)
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
			if dir.length_squared() > 0.01:
				dir = dir.normalized()
				velocity.x = dir.x * MOVE_SPEED * 1.1
				velocity.z = dir.z * MOVE_SPEED * 1.1
				_visuals.face_direction(dir)
				_visuals.play_anim("Running_A")
		return true

	# In range — auto-attack
	velocity.x = 0.0
	velocity.z = 0.0
	# Face the target
	var to_target := (target_node.global_position - global_position).normalized()
	_visuals.face_direction(to_target)

	# Check animation position for hit event before starting new attacks
	var anim_player: AnimationPlayer = _visuals.get_anim_player()
	if _pending_hit:
		if anim_player and anim_player.current_animation == "1H_Melee_Attack_Chop":
			if anim_player.current_animation_position >= _hit_time:
				_pending_hit = false
				_do_combat_attack()
		else:
			# Fallback countdown when attack animation isn't playing
			_hit_time -= delta
			if _hit_time <= 0.0:
				_pending_hit = false
				_do_combat_attack()

	# Only accumulate attack cooldown after the pending hit has landed
	if not _pending_hit:
		var attack_speed: float = WorldState.get_entity_data(npc_id).get("attack_speed", 1.0)
		_attack_timer += delta
		if _attack_timer >= attack_speed:
			_attack_timer = 0.0
			_visuals.play_anim("1H_Melee_Attack_Chop", true)
			_pending_hit = true
			_hit_time = _visuals.get_hit_delay("1H_Melee_Attack_Chop")
	return false

func _do_combat_attack() -> void:
	if not WorldState.is_alive(combat_target):
		return
	var target_node := WorldState.get_entity(combat_target)
	var target_pos := target_node.global_position if target_node else global_position
	var damage: int = _combat.deal_damage_to(combat_target)
	_visuals.spawn_damage_number(combat_target, damage, Color(1, 1, 1), target_pos)
	_visuals.flash_target(combat_target)

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
	var tint: Color = STATE_COLORS.get(new_state, Color(0, 0, 0, 0))
	_visuals.set_state_tint(tint)


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
	current_goal = new_goal
	WorldState.set_entity_data(npc_id, "goal", new_goal)

func enter_combat(target_id: String) -> void:
	combat_target = target_id
	_attack_timer = 0.0
	_last_nav_target_pos = Vector3.INF
	change_state(STATE_COMBAT)

# --- Death / Respawn ---

func _on_entity_died(entity_id: String, killer_id: String) -> void:
	if entity_id == npc_id:
		_die()
	elif entity_id == combat_target:
		# Target died — loot is handled by monster_base, just exit combat
		var memory_node = get_node_or_null("NPCMemory")
		if memory_node:
			var target_name: String = WorldState.get_entity_data(combat_target).get("name", combat_target)
			memory_node.add_observation("Killed %s in combat" % combat_target)
			if memory_node.has_method("add_key_memory") and not memory_node.has_key_memory_type("first_kill"):
				memory_node.add_key_memory("first_kill", "First kill: defeated a %s" % target_name)
		combat_target = ""
		_pending_hit = false
		change_state(STATE_IDLE)

func _die() -> void:
	change_state(STATE_DEAD)
	combat_target = ""
	_pending_hit = false
	velocity = Vector3.ZERO

	# Lose 10% gold
	var gold: int = _inventory.get_gold_amount()
	var lost := int(gold * 0.1)
	_inventory.remove_gold_amount(lost)

	var memory_node = get_node_or_null("NPCMemory")
	if memory_node:
		memory_node.add_observation("I died! Lost %d gold." % lost)
		if memory_node.has_method("add_key_memory"):
			memory_node.add_key_memory("death", "Died and lost %d gold" % lost)

	# Visual: death animation + fade out
	_visuals.play_anim("Death_A")
	_visuals.fade_out()

	_visuals.set_hp_bar_visible(false)

	_respawn_timer = 5.0

func _respawn() -> void:
	_visuals.reset_anim()
	# Teleport to town
	global_position = Vector3(randf_range(-2, 2), 1, randf_range(-2, 2))
	velocity = Vector3.ZERO

	# Restore HP
	var max_hp: int = WorldState.get_entity_data(npc_id).get("max_hp", 50)
	WorldState.set_entity_data(npc_id, "hp", max_hp)

	# Visual: restore materials and play idle
	_visuals.restore_materials()
	_visuals.clear_overlay()
	_visuals.play_anim("Idle")

	_visuals.set_hp_bar_visible(false)

	change_state(STATE_IDLE)
	GameEvents.entity_respawned.emit(npc_id)
	_visuals.update_hp_bar(npc_id)

	var memory_node = get_node_or_null("NPCMemory")
	if memory_node:
		memory_node.add_observation("Respawned in town after dying")

func _on_entity_damaged(target_id: String, _attacker_id: String, damage: int, _remaining_hp: int) -> void:
	if target_id == npc_id:
		flash_hit()
		_visuals.update_hp_bar(npc_id)

func _on_entity_healed(entity_id: String, _amount: int, _current_hp: int) -> void:
	if entity_id == npc_id:
		_visuals.update_hp_bar(npc_id)

# --- Duck typing delegations ---

func flash_hit() -> void:
	_visuals.flash_hit()

func highlight() -> void:
	_visuals.highlight()

func unhighlight() -> void:
	_visuals.unhighlight()
