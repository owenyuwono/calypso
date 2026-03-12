extends StaticBody3D
## Scripted shop NPC — no AI, just a fixed position with shop interaction.
## Uses KayKit 3D character model with overlay effects.

const EntityVisuals = preload("res://scripts/components/entity_visuals.gd")
const ItemDatabase = preload("res://scripts/data/item_database.gd")

@export var shop_id: String = ""
@export var shop_name: String = "Shop"
@export var shop_type: String = "weapon"  # "weapon" or "item"
@export var npc_color: Color = Color(0.5, 0.5, 0.2)
@export var model_path: String = "res://assets/models/characters/Barbarian.glb"
@export var model_scale: float = 0.7

## Items this shop sells: Array of item_id strings
@export var shop_items: PackedStringArray = []

@onready var name_label: Label3D = $NameLabel

var entity_id: String = ""
var _visuals: Node

func _ready() -> void:
	entity_id = shop_id
	_visuals = EntityVisuals.new()
	add_child(_visuals)
	_visuals.setup_model(model_path, model_scale, npc_color)

	if name_label:
		name_label.text = shop_name

	WorldState.register_entity(shop_id, self, {
		"type": "shop_npc",
		"name": shop_name,
		"shop_type": shop_type,
		"shop_items": Array(shop_items),
	})

func get_shop_items() -> Array:
	return Array(shop_items)

# --- Hover Highlight (duck typing delegations) ---

func highlight() -> void:
	_visuals.highlight()

func unhighlight() -> void:
	_visuals.unhighlight()
