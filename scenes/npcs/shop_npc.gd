extends StaticBody3D
## Scripted shop NPC — no AI, just a fixed position with shop interaction.
## Uses KayKit 3D character model with overlay effects.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")

@export var shop_id: String = ""
@export var shop_name: String = "Shop"
@export var shop_type: String = "weapon"  # "weapon" or "item"
@export var npc_color: Color = Color(0.5, 0.5, 0.2)
@export var model_path: String = "res://assets/models/characters/Barbarian.glb"
@export var model_scale: float = 0.7

## Items this shop sells: Array of item_id strings
@export var shop_items: PackedStringArray = []

@onready var name_label: Label3D = $NameLabel

# 3D Model
var _model: Node3D
var _mesh_instances: Array[MeshInstance3D] = []
var _overlay_material: StandardMaterial3D
var _anim_player: AnimationPlayer

func _ready() -> void:
	_setup_model()

	if name_label:
		name_label.text = shop_name

	WorldState.register_entity(shop_id, self, {
		"type": "shop_npc",
		"name": shop_name,
		"shop_type": shop_type,
		"shop_items": Array(shop_items),
	})

func _setup_model() -> void:
	var result := ModelHelper.instantiate_model(model_path, model_scale)
	if result.model == null:
		push_warning("ShopNPC %s: Could not load model '%s', using fallback" % [shop_id, model_path])
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
		_anim_player.play("Idle")

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

func get_shop_items() -> Array:
	return Array(shop_items)

# --- Hover Highlight ---

func highlight() -> void:
	if _overlay_material:
		ModelHelper.set_highlight(_overlay_material, true)

func unhighlight() -> void:
	if _overlay_material:
		ModelHelper.set_highlight(_overlay_material, false)
