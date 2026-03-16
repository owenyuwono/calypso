extends CharacterBody3D
## NPC base — state machine, navigation, perception, combat, and LLM brain integration.
## Uses KayKit 3D character models with overlay-based visual effects.

const EntityVisuals = preload("res://scripts/components/entity_visuals.gd")
const StatsComponent = preload("res://scripts/components/stats_component.gd")
const InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const EquipmentComponent = preload("res://scripts/components/equipment_component.gd")
const CombatComponent = preload("res://scripts/components/combat_component.gd")
const ProgressionComponent = preload("res://scripts/components/progression_component.gd")
const AutoAttackComponent = preload("res://scripts/components/auto_attack_component.gd")
const VendingComponent = preload("res://scripts/components/vending_component.gd")
const NpcIdentity = preload("res://scripts/components/npc_identity.gd")
const PerceptionComponent = preload("res://scripts/components/perception_component.gd")
const RelationshipComponent = preload("res://scripts/components/relationship_component.gd")
const ItemDatabase = preload("res://scripts/data/item_database.gd")
const LevelData = preload("res://scripts/data/level_data.gd")
const NpcTraits = preload("res://scripts/data/npc_traits.gd")
const MonsterDatabase = preload("res://scripts/data/monster_database.gd")
const NpcIdentityDatabase = preload("res://scripts/data/npc_identity_database.gd")
const SkillsComponent = preload("res://scripts/components/skills_component.gd")
const SkillDatabase = preload("res://scripts/data/skill_database.gd")

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
var _respawn_timer: float = 0.0
var _combat_tracker: Dictionary = {"damage_dealt": 0, "damage_taken": 0, "hits_dealt": 0, "hits_taken": 0}

# Stuck detection
var _stuck_timer: float = 0.0
var _last_nav_pos: Vector3 = Vector3.ZERO

# Navigation & UI
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var dialogue_bubble: Node3D = $DialogueBubble
@onready var name_label: Label3D = $NameLabel

const MOVE_SPEED: float = 7.2
const ARRIVAL_THRESHOLD: float = 1.0
const GRAVITY: float = 9.8
const PERSONAL_SPACE: float = 2.5
const SEPARATION_FORCE: float = 2.0
const DEATH_GOLD_PENALTY_RATIO: float = 0.1
const CONSTITUTION_XP_PER_HIT: int = 3
const RESPAWN_TIME: float = 5.0

# Visuals component
var _visuals: Node
var _stats: Node
var _inventory: Node
var _equipment: Node
var _combat: Node
var _progression: Node
var _auto_attack: Node
var _npc_skills: Node = null
var _perception: Node

# Debug
var _perception_circle: MeshInstance3D
const PERCEPTION_RADIUS: float = 15.0
const LOD_FULL_DIST: float = 30.0
const LOD_REDUCED_DIST: float = 60.0
const LOD_CHECK_INTERVAL: float = 0.5
var _lod_level: int = 0
var _lod_timer: float = 0.0

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

	collision_layer |= (1 << 8)

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
	_equipment.setup({
		"head": "", "torso": "", "legs": "", "gloves": "",
		"feet": "", "back": "", "main_hand": "", "off_hand": "",
	}, _inventory)

	# Equip starting weapon from trait profile
	if not trait_profile.is_empty():
		var profile: Dictionary = NpcTraits.get_profile(trait_profile)
		var weapon_type: String = profile.get("weapon_type", "")
		if not weapon_type.is_empty():
			var weapon_id: String = "basic_" + weapon_type
			_inventory.add_item(weapon_id)
			_equipment.equip(weapon_id)

	_progression = ProgressionComponent.new()
	_progression.name = "ProgressionComponent"
	add_child(_progression)
	# Get starting proficiencies from trait profile
	var initial_profs: Dictionary = {}
	if not trait_profile.is_empty():
		var profile: Dictionary = NpcTraits.get_profile(trait_profile)
		initial_profs = profile.get("starting_proficiencies", {})
	_progression.setup(_stats, initial_profs, _equipment)

	_combat = CombatComponent.new()
	_combat.name = "CombatComponent"
	add_child(_combat)
	_combat.setup(_stats, _equipment, _progression)

	_auto_attack = AutoAttackComponent.new()
	_auto_attack.name = "AutoAttackComponent"
	add_child(_auto_attack)
	_auto_attack.setup(_visuals, _combat, nav_agent)
	_auto_attack.attack_landed.connect(_on_auto_attack_landed)
	_auto_attack.target_lost.connect(_on_auto_attack_target_lost)

	_register_with_world()

	var skills_comp: Node = SkillsComponent.new()
	skills_comp.name = "SkillsComponent"
	add_child(skills_comp)
	skills_comp.setup({}, ["", "", "", "", ""])

	# Auto-unlock skills that match current proficiency levels
	for skill_id in SkillDatabase.SKILLS:
		var skill_data: Dictionary = SkillDatabase.SKILLS[skill_id]
		if skill_data.has("required_proficiency"):
			var req: Dictionary = skill_data.required_proficiency
			var prof_level: int = _progression.get_proficiency_level(req.skill)
			if prof_level >= req.get("level", 1):
				skills_comp.unlock_skill(skill_id)

	var _vending_comp := VendingComponent.new()
	_vending_comp.name = "VendingComponent"
	add_child(_vending_comp)

	# Add StaminaComponent
	var stamina_comp := preload("res://scripts/components/stamina_component.gd").new()
	stamina_comp.name = "StaminaComponent"
	add_child(stamina_comp)
	stamina_comp.setup_rest_spots(["TownWell", "TownInn"])

	var identity := NpcIdentity.new()
	identity.name = "NpcIdentity"
	add_child(identity)
	var id_data: Dictionary = NpcIdentityDatabase.get_identity(npc_id)
	if not id_data.is_empty():
		identity.setup(id_data)
		# Shop NPCs register as "shop_npc" type so player.gd can open the shop panel
		var shop_type: String = id_data.get("shop_type", "")
		if not shop_type.is_empty():
			WorldState.set_entity_data(npc_id, "type", "shop_npc")
			WorldState.set_entity_data(npc_id, "shop_type", shop_type)
			WorldState.set_entity_data(npc_id, "shop_items", id_data.get("shop_items", []).duplicate())

	var rel := RelationshipComponent.new()
	rel.name = "RelationshipComponent"
	add_child(rel)

	var perception_comp := PerceptionComponent.new()
	perception_comp.name = "PerceptionComponent"
	add_child(perception_comp)
	perception_comp.setup()
	_perception = perception_comp

	_npc_skills = preload("res://scenes/npcs/npc_skills.gd").new()
	add_child(_npc_skills)
	_npc_skills.setup(self, _combat, skills_comp, perception_comp, _visuals, _auto_attack)

	nav_agent.navigation_finished.connect(_on_navigation_finished)
	nav_agent.target_desired_distance = ARRIVAL_THRESHOLD
	nav_agent.path_desired_distance = ARRIVAL_THRESHOLD
	_lod_timer = randf_range(0.0, LOD_CHECK_INTERVAL)

	if name_label:
		name_label.text = npc_name

	GameEvents.npc_spoke.connect(_on_any_npc_spoke)
	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_damaged.connect(_on_entity_damaged)
	GameEvents.entity_healed.connect(_on_entity_healed)
	GameEvents.vending_started.connect(_on_vending_started)
	GameEvents.vending_stopped.connect(_on_vending_stopped)
	GameEvents.proficiency_level_up.connect(_on_proficiency_level_up)

	_visuals.setup_hp_bar()
	_visuals.set_hp_bar_visible(false)

	_setup_perception_circle()

func _setup_perception_circle() -> void:
	var im := ImmediateMesh.new()
	var segments: int = 64
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in segments + 1:
		var angle: float = TAU * float(i) / float(segments)
		im.surface_add_vertex(Vector3(cos(angle) * PERCEPTION_RADIUS, 0, sin(angle) * PERCEPTION_RADIUS))
	im.surface_end()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.85, 1.0, 0.35)

	_perception_circle = MeshInstance3D.new()
	_perception_circle.mesh = im
	_perception_circle.material_override = mat
	_perception_circle.position = Vector3(0, 0.05, 0)
	_perception_circle.visible = false
	add_child(_perception_circle)


func _get_separation_velocity() -> Vector3:
	var sep := Vector3.ZERO
	if not _perception:
		return sep
	var nearby: Array = _perception.get_nearby(PERSONAL_SPACE)
	for entry in nearby:
		var other: Node3D = entry.node
		if not is_instance_valid(other):
			continue
		var data: Dictionary = WorldState.get_entity_data(entry.id)
		if data.get("type", "") != "npc":
			continue
		if not WorldState.is_alive(entry.id):
			continue
		var diff := global_position - other.global_position
		diff.y = 0.0
		var dist := diff.length()
		if dist < 0.01:
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
	stats["equipment"] = {"head": "", "torso": "", "legs": "", "gloves": "", "feet": "", "back": "", "main_hand": "", "off_hand": ""}
	WorldState.register_entity(npc_id, self, stats)

func _update_lod() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		_lod_level = 0
		return
	var dist := global_position.distance_to(cam.global_position)
	if dist < LOD_FULL_DIST:
		_lod_level = 0
	elif dist < LOD_REDUCED_DIST:
		_lod_level = 1
	else:
		_lod_level = 2

func _physics_process(delta: float) -> void:
	if current_state == STATE_DEAD:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	# LOD check (staggered)
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = LOD_CHECK_INTERVAL
		_update_lod()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var is_moving := false
	if current_state == STATE_MOVING:
		is_moving = _process_movement(delta)
	elif current_state == STATE_COMBAT:
		is_moving = _process_combat(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED)

	# Apply separation force to avoid NPC overlap (not in combat, close range only)
	if current_state != STATE_COMBAT and _lod_level == 0:
		var sep := _get_separation_velocity()
		velocity.x += sep.x
		velocity.z += sep.z

	move_and_slide()

	# Update animation based on movement (skip at high LOD)
	if _lod_level < 2:
		if current_state == STATE_COMBAT:
			pass  # Combat handles its own anims
		elif current_state == STATE_DEAD:
			pass
		elif is_moving:
			_visuals.play_anim("Walking_A")
		else:
			_visuals.play_anim("Idle")

func _process_movement(delta: float) -> bool:
	if not _nav_started:
		if not nav_agent.is_navigation_finished():
			_nav_started = true
			_stuck_timer = 0.0
			_last_nav_pos = global_position
		else:
			_nav_wait_frames += 1
			if _nav_wait_frames > 60:
				change_state(STATE_IDLE)
				GameEvents.npc_action_completed.emit(npc_id, "move_to", false)
			return false

	if nav_agent.is_navigation_finished():
		if _suppress_nav_complete:
			_suppress_nav_complete = false
			return false  # let the coroutine in npc_action_executor handle it
		change_state(STATE_IDLE)
		GameEvents.npc_action_completed.emit(npc_id, "move_to", true)
		return false

	# Stuck detection: if barely moved in 2 seconds, abort navigation
	_stuck_timer += delta
	if _stuck_timer >= 2.0:
		var moved: float = global_position.distance_to(_last_nav_pos)
		if moved < 0.1:
			if _suppress_nav_complete:
				_suppress_nav_complete = false
				return false  # let the coroutine in npc_action_executor handle it
			change_state(STATE_IDLE)
			GameEvents.npc_action_completed.emit(npc_id, "move_to", false)
			return false
		_stuck_timer = 0.0
		_last_nav_pos = global_position

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
	# Try to use a skill before falling through to auto-attack
	if _npc_skills and not _npc_skills.is_skill_active():
		_npc_skills.try_use_skill(combat_target)

	# While a skill hit is pending, hold position and let npc_skills resolve it
	if _npc_skills and _npc_skills.is_skill_active():
		return false

	var attack_range: float = _stats.attack_range
	var attack_speed: float = _stats.attack_speed
	# NPCs run slightly faster than base speed when chasing
	var result: Dictionary = _auto_attack.process_attack(
		delta, combat_target, global_position,
		MOVE_SPEED, attack_range, attack_speed, 1.1
	)
	return result.get("is_moving", false)

func _on_auto_attack_landed(target_id: String, damage: int, target_pos: Vector3) -> void:
	_visuals.spawn_damage_number(target_id, damage, Color(1, 1, 1), target_pos)
	_visuals.flash_target(target_id)
	# Grant weapon proficiency XP
	var target_data := WorldState.get_entity_data(target_id)
	var monster_type: String = target_data.get("monster_type", "")
	if not monster_type.is_empty():
		var weapon_type: String = _combat.get_equipped_weapon_type()
		_progression.grant_combat_xp(monster_type, weapon_type)
	_combat_tracker["damage_dealt"] += damage
	_combat_tracker["hits_dealt"] += 1
	# Occasionally say something in combat
	if randf() < 0.15:
		var shouts := ["Take that!", "Ha!", "Got you!", "Come on!", "Not bad!"]
		var shout: String = shouts[randi() % shouts.size()]
		GameEvents.npc_spoke.emit(npc_id, shout, target_id)

func _on_auto_attack_target_lost() -> void:
	combat_target = ""
	_combat_tracker = {"damage_dealt": 0, "damage_taken": 0, "hits_dealt": 0, "hits_taken": 0}
	WorldState.set_entity_data(npc_id, "combat_target", "")
	change_state(STATE_IDLE)

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

	# Show HP bar on combat entry, hide on exit if full HP
	if new_state == STATE_COMBAT:
		_visuals.set_hp_bar_visible(true)
	elif old_state == STATE_COMBAT:
		_visuals.set_hp_bar_visible(_stats.hp < _stats.max_hp)


func _on_any_npc_spoke(speaker_id: String, dialogue: String, _target_id: String) -> void:
	if speaker_id == npc_id and dialogue_bubble:
		dialogue_bubble.show_dialogue(dialogue)

# --- Actions ---

func navigate_to(target_pos: Vector3) -> void:
	change_state(STATE_MOVING)
	_nav_started = false
	_nav_wait_frames = 0
	_stuck_timer = 0.0
	_last_nav_pos = global_position
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
	_combat_tracker = {"damage_dealt": 0, "damage_taken": 0, "hits_dealt": 0, "hits_taken": 0}
	WorldState.set_entity_data(npc_id, "combat_target", target_id)
	_auto_attack.cancel()
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
			memory_node.add_memory("Killed %s in combat" % combat_target, memory_node.SOURCE_WITNESSED, memory_node.IMPORTANCE_LOW)
			if not memory_node.has_key_memory_type("first_kill"):
				memory_node.add_memory("First kill: defeated a %s" % target_name, memory_node.SOURCE_WITNESSED, memory_node.IMPORTANCE_HIGH, false, "first_kill")
		combat_target = ""
		WorldState.set_entity_data(npc_id, "combat_target", "")
		_auto_attack.cancel()
		change_state(STATE_IDLE)

func _die() -> void:
	var vc = get_node_or_null("VendingComponent")
	if vc and vc.is_vending():
		vc.stop_vending()
	change_state(STATE_DEAD)
	combat_target = ""
	_combat_tracker = {"damage_dealt": 0, "damage_taken": 0, "hits_dealt": 0, "hits_taken": 0}
	WorldState.set_entity_data(npc_id, "combat_target", "")
	_auto_attack.cancel()
	velocity = Vector3.ZERO

	# Lose 10% gold
	var lost := EntityHelpers.apply_death_gold_penalty(_inventory, DEATH_GOLD_PENALTY_RATIO)

	var memory_node = get_node_or_null("NPCMemory")
	if memory_node:
		memory_node.add_memory("Died and lost %d gold" % lost, memory_node.SOURCE_WITNESSED, memory_node.IMPORTANCE_HIGH, false, "death")

	# Visual: death animation + fade out
	_visuals.play_anim("Death_A")
	_visuals.fade_out()

	_visuals.set_hp_bar_visible(false)

	_respawn_timer = RESPAWN_TIME

func _respawn() -> void:
	_visuals.reset_anim()
	# Teleport to town
	# Respawn near town square, offset to avoid fountain
	global_position = Vector3(randf_range(-8, -4), 1, randf_range(-4, 4))
	velocity = Vector3.ZERO

	# Restore HP via StatsComponent (source of truth)
	_stats.restore_full_hp()

	# Visual: restore materials and play idle
	_visuals.restore_materials()
	_visuals.clear_overlay()
	_visuals.play_anim("Idle")

	_visuals.set_hp_bar_visible(false)

	change_state(STATE_IDLE)
	GameEvents.entity_respawned.emit(npc_id)
	_visuals.update_hp_bar_combat(_stats.hp, _stats.max_hp, false)

	var memory_node = get_node_or_null("NPCMemory")
	if memory_node:
		memory_node.add_memory("Respawned in town after dying", memory_node.SOURCE_WITNESSED, memory_node.IMPORTANCE_LOW)

func _on_entity_damaged(target_id: String, _attacker_id: String, damage: int, _remaining_hp: int) -> void:
	if target_id == npc_id:
		flash_hit()
		_visuals.update_hp_bar_combat(_stats.hp, _stats.max_hp, current_state == STATE_COMBAT)
		_progression.grant_proficiency_xp("constitution", CONSTITUTION_XP_PER_HIT)
		_combat_tracker["damage_taken"] += damage
		_combat_tracker["hits_taken"] += 1

func _on_entity_healed(entity_id: String, _amount: int, _current_hp: int) -> void:
	if entity_id == npc_id:
		_visuals.update_hp_bar_combat(_stats.hp, _stats.max_hp, current_state == STATE_COMBAT)

func _on_vending_started(eid: String, shop_title: String) -> void:
	if eid == npc_id:
		_visuals.show_vend_sign(shop_title)

func _on_vending_stopped(eid: String) -> void:
	if eid == npc_id:
		_visuals.hide_vend_sign()

func _on_proficiency_level_up(leveled_entity_id: String, prof_id: String, new_level: int) -> void:
	if leveled_entity_id != entity_id:
		return
	var skills_node: Node = get_node_or_null("SkillsComponent")
	if not skills_node:
		return
	for skill_id in SkillDatabase.SKILLS:
		var skill_data: Dictionary = SkillDatabase.SKILLS[skill_id]
		if not skill_data.has("required_proficiency"):
			continue
		var req: Dictionary = skill_data.required_proficiency
		if req.get("skill", "") == prof_id and new_level >= req.get("level", 1):
			if not skills_node.has_skill(skill_id):
				skills_node.unlock_skill(skill_id)

# --- Generated NPC initialization ---

## Apply a generated loadout dict after _ready() has run.
## Loadout format matches NpcGenerator output:
##   items: {item_id: count}, equip: [item_id, ...], gold: int, default_goal: String
func initialize_from_loadout(loadout: Dictionary) -> void:
	# Items
	var items: Dictionary = loadout.get("items", {})
	for item_id in items:
		_inventory.add_item(item_id, items[item_id])

	# Equipment
	var equip: Array = loadout.get("equip", [])
	for item_id in equip:
		_equipment.equip(item_id)

	# Gold
	var gold: int = loadout.get("gold", -1)
	if gold >= 0:
		_inventory.set_gold_amount(gold)

	# Goal
	var goal: String = loadout.get("default_goal", "")
	if not goal.is_empty():
		set_goal(goal)
		var behavior: Node = get_node_or_null("NPCBehavior")
		if behavior:
			behavior.default_goal = goal

	# Re-init proficiencies and skills (trait_profile is set after _ready)
	late_init_skills()

## Re-initialize proficiency levels and unlock skills based on current trait_profile.
## Must be called AFTER trait_profile is set (which happens after _ready()).
func late_init_skills() -> void:
	if trait_profile.is_empty():
		return
	# Re-apply starting proficiencies from trait profile
	var profile: Dictionary = NpcTraits.get_profile(trait_profile)
	var initial_profs: Dictionary = profile.get("starting_proficiencies", {})
	if not initial_profs.is_empty():
		_progression.setup(_stats, initial_profs, _equipment)
	# Unlock skills matching proficiency levels
	var skills_node: Node = get_node_or_null("SkillsComponent")
	if not skills_node:
		return
	for skill_id in SkillDatabase.SKILLS:
		var skill_data: Dictionary = SkillDatabase.SKILLS[skill_id]
		if skill_data.has("required_proficiency"):
			var req: Dictionary = skill_data.required_proficiency
			var prof_level: int = _progression.get_proficiency_level(req.skill)
			if prof_level >= req.get("level", 1) and not skills_node.has_skill(skill_id):
				skills_node.unlock_skill(skill_id)

# --- Duck typing delegations ---

func flash_hit() -> void:
	_visuals.flash_hit()

func highlight() -> void:
	_visuals.highlight()

func unhighlight() -> void:
	_visuals.unhighlight()

func get_combat_tracker() -> Dictionary:
	return _combat_tracker
