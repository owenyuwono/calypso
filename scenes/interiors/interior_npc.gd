extends StaticBody3D
## Lightweight NPC for building interiors (innkeeper, shopkeeper).
## No AI, no pathfinding, no LLM. Stands still, shows model, optionally vends.
## Greets the player on proximity entry via an Area3D trigger.

const EntityVisuals = preload("res://scripts/components/entity_visuals.gd")
const VendingComponent = preload("res://scripts/components/vending_component.gd")
const DialogueBubbleScene = preload("res://scenes/ui/dialogue_bubble.tscn")

@export var npc_name: String = "Innkeeper"
@export var npc_role: String = "innkeeper"  # "innkeeper" or "shopkeeper"
@export var npc_color: Color = Color(0.6, 0.4, 0.3, 1.0)

const GREETINGS_INNKEEPER: Array[String] = [
	"Welcome to the inn!",
	"Make yourself at home.",
	"Rest your weary bones here.",
	"A warm bed awaits you.",
]

const GREETINGS_SHOPKEEPER: Array[String] = [
	"Browse my wares!",
	"Fine goods, fair prices.",
	"What can I get you?",
	"Everything you need, right here.",
]

# Minimum seconds between successive greetings for the same player visit
const GREET_COOLDOWN: float = 8.0

# Exposed as `entity_id` (no underscore) so BaseComponent._get_entity_id() resolves correctly
var entity_id: String = ""
var _visuals: Node
var _vending: Node
var _dialogue_bubble: Node3D
var _name_label: Label3D
var _greet_timer: float = 0.0


func _ready() -> void:
	entity_id = "interior_" + npc_name.to_lower().replace(" ", "_")

	_setup_collision()
	_setup_visuals()
	_setup_name_label()
	_setup_dialogue_bubble()
	_setup_proximity_trigger()

	if npc_role == "shopkeeper" or npc_role == "innkeeper":
		_setup_vending()

	_face_entrance()
	_register_with_world()


func _process(delta: float) -> void:
	if _greet_timer > 0.0:
		_greet_timer -= delta


func _exit_tree() -> void:
	WorldState.unregister_entity(entity_id)


# --- Setup helpers ------------------------------------------------------------

func _setup_collision() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.6
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.8
	add_child(col)


func _setup_visuals() -> void:
	_visuals = EntityVisuals.new()
	add_child(_visuals)
	_visuals.setup_model_with_anims(
		"res://assets/models/characters/player.fbx",
		{
			"Running": "res://assets/animation/player/running.fbx",
			"Attack": "res://assets/animation/player/attack_slash.fbx",
			"Hit": "res://assets/animation/player/hit_impact.fbx",
			"Idle_Breathing": "res://assets/animation/player/idle_breathing.fbx",
			"Idle_Breathing_2": "res://assets/animation/player/idle_breathing_2.fbx",
			"Idle_Breathing_3": "res://assets/animation/player/idle_breathing_3.fbx",
			"Idle_Rare_Happy": "res://assets/animation/player/idle_rare_happy.fbx",
			"Idle_Rare_Bored": "res://assets/animation/player/idle_rare_bored.fbx",
			"Idle_Rare_Looking": "res://assets/animation/player/idle_rare_looking_around.fbx",
			"Idle_Rare_Look": "res://assets/animation/player/idle_rare_look_around.fbx",
			"Idle_Tired_Sweat": "res://assets/animation/player/idle_tired_wiping_sweat.fbx",
			"Idle_Tired_Shoulder": "res://assets/animation/player/idle_tired_shoulder_rub.fbx",
			"Idle_Tired_Neck": "res://assets/animation/player/idle_tired_neck_stretch.fbx",
		},
		1.5,
		npc_color
	)


func _setup_name_label() -> void:
	_name_label = Label3D.new()
	_name_label.text = npc_name
	_name_label.position = Vector3(0.0, 2.0, 0.0)
	_name_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
	_name_label.font_size = 32
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	add_child(_name_label)


func _setup_dialogue_bubble() -> void:
	_dialogue_bubble = DialogueBubbleScene.instantiate()
	_dialogue_bubble.position = Vector3(0.0, 2.4, 0.0)
	add_child(_dialogue_bubble)


func _setup_proximity_trigger() -> void:
	# Area3D parented directly to self (Node3D) so it follows global_position correctly
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1  # detect physics layer (player/NPCs)
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	var area_col := CollisionShape3D.new()
	area_col.shape = sphere
	area_col.position.y = 0.8
	area.add_child(area_col)
	add_child(area)
	area.body_entered.connect(_on_proximity_body_entered)


func _setup_vending() -> void:
	_vending = VendingComponent.new()
	_vending.name = "VendingComponent"
	add_child(_vending)
	var shop_title: String = npc_name + "'s " + ("Inn" if npc_role == "innkeeper" else "Shop")
	_vending.setup_shop(shop_title)


func _face_entrance() -> void:
	# Interior spawn point is at +Z, so NPC faces toward +Z (toward entering player)
	look_at(global_position + Vector3(0.0, 0.0, 1.0), Vector3.UP)


func _register_with_world() -> void:
	WorldState.register_entity(entity_id, self, {
		"type": "interior_npc",
		"name": npc_name,
		"role": npc_role,
		"position": global_position,
	})


# --- Interaction --------------------------------------------------------------

func _on_proximity_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _greet_timer > 0.0:
		return
	_greet_timer = GREET_COOLDOWN
	_say_greeting()


func _say_greeting() -> void:
	var pool: Array[String] = GREETINGS_INNKEEPER if npc_role == "innkeeper" else GREETINGS_SHOPKEEPER
	var text: String = pool[randi() % pool.size()]
	if _dialogue_bubble:
		_dialogue_bubble.show_dialogue(text)
	GameEvents.npc_spoke.emit(entity_id, text, "")
