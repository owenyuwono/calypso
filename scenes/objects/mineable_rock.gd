extends StaticBody3D
## Mineable rock entity. Spawned by the rock spawner into the world.
## Registers with WorldState for hover and NPC targeting.
## Renders using FBX rock models; falls back to a single sphere if assets fail to load.
## Depletion shrinks + darkens the rock; destroy+respawn creates a fresh instance on respawn.

const OreDatabase = preload("res://scripts/data/ore_database.gd")
const HarvestableComponent = preload("res://scripts/components/harvestable_component.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")

const ROCK_DIR := "res://assets/models/environment/nature/rocks/"
const ROCK_TEXTURE_PATH := "res://assets/models/environment/nature/rocks/textures/rock_alb.png"
const ROCK_MODELS: Dictionary = {
	"copper": "rock_01.fbx",
	"iron": "rock_01.fbx",
	"gold": "rock_01.fbx",
}

const TIER_COLORS: Dictionary = {
	"copper": Color(0.72, 0.45, 0.2),
	"iron": Color(0.55, 0.56, 0.62),
	"gold": Color(0.85, 0.65, 0.13),
}

signal rock_depleted(tier: String, respawn_time: float)

static var _next_id: int = 1
static var _ore_mats: Dictionary = {}  # tier → ShaderMaterial
static var _rock_texture: Texture2D = null
static var _highlight_mat: StandardMaterial3D = null

var entity_id: String = ""
var rock_tier: String = ""
var rock_name: String = ""
var _scale_val: float = 1.0
var _model_instance: Node3D = null
var _mesh_instances: Array[MeshInstance3D] = []
var _harvestable: Node = null
var last_chopper_pos: Vector3 = Vector3.ZERO
var _original_scale: Vector3 = Vector3.ONE
var _base_color: Color = Color.GRAY


func setup(tier: String, scale_val: float = 1.0) -> void:
	entity_id = "rock_%03d" % _next_id
	_next_id += 1
	rock_tier = tier
	_scale_val = scale_val

	var ore_data: Dictionary = OreDatabase.get_ore(tier)
	rock_name = ore_data.get("name", "Rock")
	_base_color = TIER_COLORS.get(tier, Color.GRAY)

	_build_collision()
	_load_rock_model()
	_add_harvestable_component()

	WorldState.register_entity(entity_id, self, {
		"type": "rock",
		"name": rock_name,
		"rock_tier": rock_tier,
		"harvestable": true,
	})


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 1.5, 1.5) * _scale_val
	col.shape = shape
	col.position = Vector3(0.0, 0.75 * _scale_val, 0.0)
	add_child(col)
	collision_layer = 1
	collision_mask = 0


func _load_rock_model() -> void:
	var model_file: String = ROCK_MODELS.get(rock_tier, "rock_01.fbx")
	var model_path: String = ROCK_DIR + model_file
	var scene: PackedScene = ModelHelper.load_model(model_path)

	if scene:
		_model_instance = scene.instantiate()
		_model_instance.scale = Vector3.ONE * _scale_val / 3.0
		add_child(_model_instance)
		_mesh_instances = ModelHelper.find_mesh_instances(_model_instance)
		_apply_tier_material()
	else:
		_build_fallback_sphere()

	_original_scale = _model_instance.scale


func _apply_tier_material() -> void:
	var mat: ShaderMaterial = _get_ore_material(rock_tier)
	for mi in _mesh_instances:
		if is_instance_valid(mi):
			mi.material_override = mat


func _get_ore_material(tier: String) -> ShaderMaterial:
	if _ore_mats.has(tier):
		return _ore_mats[tier]

	# Load the shared rock albedo texture once
	if _rock_texture == null and ResourceLoader.exists(ROCK_TEXTURE_PATH):
		_rock_texture = load(ROCK_TEXTURE_PATH) as Texture2D

	var color: Color = TIER_COLORS.get(tier, Color.GRAY)
	var mat: ShaderMaterial = ModelHelper.create_toon_material_color(color)

	if _rock_texture:
		mat.set_shader_parameter("albedo_texture", _rock_texture)
		mat.set_shader_parameter("use_texture", true)
		# albedo_color multiplies the texture — tints it to the tier color
		mat.set_shader_parameter("albedo_color", color)

	_ore_mats[tier] = mat
	return mat


func _build_fallback_sphere() -> void:
	_model_instance = Node3D.new()
	_model_instance.scale = Vector3.ONE * _scale_val
	add_child(_model_instance)

	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	sphere.radial_segments = 12
	sphere.rings = 6
	mi.mesh = sphere
	mi.position = Vector3(0.0, 0.8, 0.0)
	_model_instance.add_child(mi)

	var mat: ShaderMaterial = ModelHelper.create_toon_material_color(_base_color)
	mi.material_override = mat

	_mesh_instances = [mi]


func _add_harvestable_component() -> void:
	var comp := HarvestableComponent.new()
	comp.name = "HarvestableComponent"
	comp.respawn_mode = "destroy"
	add_child(comp)
	comp.setup(rock_tier, "mining", OreDatabase.get_ore)
	_harvestable = comp
	comp.depleted.connect(_on_depleted)


func _on_depleted() -> void:
	WorldState.set_entity_data(entity_id, "harvestable", false)
	if not _model_instance:
		return

	# Darken the rock immediately via a new toon material at reduced brightness
	var dark_color: Color = _base_color.darkened(0.6)
	var dark_mat: ShaderMaterial = ModelHelper.create_toon_material_color(dark_color)
	for mi in _mesh_instances:
		if is_instance_valid(mi):
			mi.material_override = dark_mat

	# Shrink animation, then emit signal and destroy
	var tween := create_tween()
	tween.tween_property(_model_instance, "scale", _original_scale * 0.3, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void:
		rock_depleted.emit(rock_tier, _harvestable.get_respawn_time())
		WorldState.unregister_entity(entity_id)
		queue_free()
	)


func spawn_loot(item_id: String, bonus_item: String = "") -> void:
	var ore_data: Dictionary = OreDatabase.get_ore(rock_tier)
	var max_chops: int = ore_data.get("chops", [3, 5])[1]
	var drop_count: int = maxi(max_chops / 2, 1)
	var loot_scene := preload("res://scenes/objects/loot_drop.gd")
	for i in drop_count:
		if item_id.is_empty():
			break
		var loot := Area3D.new()
		loot.set_script(loot_scene)
		loot.item_id = item_id
		loot.item_count = 1
		loot.gold_amount = 0
		var offset := Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
		loot.position = global_position + offset
		var loot_parent: Node = ZoneManager.get_loaded_zone()
		if not loot_parent:
			loot_parent = get_tree().current_scene
		loot_parent.call_deferred("add_child", loot)
	if not bonus_item.is_empty():
		var bonus := Area3D.new()
		bonus.set_script(loot_scene)
		bonus.item_id = bonus_item
		bonus.item_count = 1
		bonus.gold_amount = 0
		bonus.position = global_position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		var bonus_parent: Node = ZoneManager.get_loaded_zone()
		if not bonus_parent:
			bonus_parent = get_tree().current_scene
		bonus_parent.call_deferred("add_child", bonus)


func highlight() -> void:
	if not _highlight_mat:
		_highlight_mat = ModelHelper.create_overlay_material()
		ModelHelper.set_highlight(_highlight_mat, true)
	for mesh in _mesh_instances:
		if is_instance_valid(mesh):
			mesh.material_overlay = _highlight_mat


func unhighlight() -> void:
	for mesh in _mesh_instances:
		if is_instance_valid(mesh):
			mesh.material_overlay = null


func shake() -> void:
	var tween := create_tween()
	tween.tween_property(self, "rotation:z", deg_to_rad(2.5), 0.07)
	tween.tween_property(self, "rotation:z", deg_to_rad(-2.5), 0.07)
	tween.tween_property(self, "rotation:z", deg_to_rad(1.5), 0.06)
	tween.tween_property(self, "rotation:z", 0.0, 0.06)
