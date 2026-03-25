extends StaticBody3D
## Choppable tree entity. Spawned by the tree spawner into the world.
## Registers with WorldState for hover and NPC targeting.
## Swaps between tree and stump mesh on depletion/respawn.

const ModelHelper = preload("res://scripts/utils/model_helper.gd")
const AssetSpawner = preload("res://scripts/world/asset_spawner.gd")
const TreeDatabase = preload("res://scripts/data/tree_database.gd")
const HarvestableComponent = preload("res://scripts/components/harvestable_component.gd")
const SfxDatabase = preload("res://scripts/audio/sfx_database.gd")

const TREE_TEX_DIR := "res://assets/models/environment/nature/trees/stylized/textures/"

static var _next_id: int = 1
static var _bark_mat: StandardMaterial3D = null
static var _leaf_mats: Dictionary = {}  # leaf_color.to_html() → StandardMaterial3D
static var _highlight_mat: StandardMaterial3D = null

var entity_id: String = ""
var tree_tier: String = ""
var tree_name: String = ""

var _model_path: String = ""
var _leaf_color: Color = Color(0.18, 0.55, 0.12)
var _scale_val: float = 1.0

var _tree_model: Node3D = null
var _stump_model: Node3D = null
var _mesh_instances: Array[MeshInstance3D] = []

var _harvestable: Node = null
var _depletion_player: AudioStreamPlayer3D = null
var last_chopper_pos: Vector3 = Vector3.ZERO


func setup(tier: String, model_path: String, rotation_y: float, scale_val: float, leaf_color: Color) -> void:
	entity_id = "tree_%03d" % _next_id
	_next_id += 1

	tree_tier = tier
	_model_path = model_path
	_leaf_color = leaf_color
	_scale_val = scale_val

	var tree_data: Dictionary = TreeDatabase.get_tree(tier)
	tree_name = tree_data.get("name", "Tree")

	rotation.y = rotation_y

	_build_trunk_collision()
	_load_tree_model()
	_add_harvestable_component()

	WorldState.register_entity(entity_id, self, {
		"type": "tree",
		"name": tree_name,
		"tree_tier": tree_tier,
		"harvestable": true,
	})


func _build_trunk_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 3.0
	col.shape = shape
	col.position = Vector3(0.0, 1.5, 0.0)
	add_child(col)
	collision_layer = 1
	collision_mask = 0


func _load_tree_model() -> void:
	var scene := ModelHelper.load_model(_model_path)
	if not scene:
		push_warning("ChoppableTree: failed to load model '%s'" % _model_path)
		return

	var instance: Node3D = scene.instantiate()
	instance.scale = Vector3.ONE * _scale_val
	add_child(instance)
	_tree_model = instance

	_apply_tree_materials(instance)
	_refresh_mesh_instances()


func _load_stump_model() -> void:
	# No stump model available — tree simply disappears on depletion
	pass


func _get_bark_material() -> StandardMaterial3D:
	if _bark_mat:
		return _bark_mat
	_bark_mat = StandardMaterial3D.new()
	_bark_mat.albedo_texture = load(TREE_TEX_DIR + "trunk_alb.png") as Texture2D
	return _bark_mat


func _get_leaf_material(color: Color) -> StandardMaterial3D:
	# Stylized textures have pre-baked color; cache on a single key since no tint is applied
	var key: String = "stylized"
	if _leaf_mats.has(key):
		return _leaf_mats[key]
	var mat := StandardMaterial3D.new()
	# No albedo_color tint — stylized leaf texture already carries its own color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.albedo_texture = load(TREE_TEX_DIR + "leaf_alb.png") as Texture2D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_leaf_mats[key] = mat
	return mat


func _apply_tree_materials(instance: Node3D) -> void:
	var bark: StandardMaterial3D = _get_bark_material()
	var leaf: StandardMaterial3D = _get_leaf_material(_leaf_color)
	AssetSpawner.apply_tree_materials_recursive(instance, bark, leaf)


func _refresh_mesh_instances() -> void:
	_mesh_instances.clear()
	if _tree_model:
		var tree_meshes := ModelHelper.find_mesh_instances(_tree_model)
		_mesh_instances.append_array(tree_meshes)
	if _stump_model:
		var stump_meshes := ModelHelper.find_mesh_instances(_stump_model)
		_mesh_instances.append_array(stump_meshes)


func _add_harvestable_component() -> void:
	_depletion_player = AudioStreamPlayer3D.new()
	_depletion_player.max_distance = 40.0
	_depletion_player.bus = &"SFX"
	add_child(_depletion_player)

	var comp := HarvestableComponent.new()
	comp.name = "HarvestableComponent"
	add_child(comp)
	comp.setup(tree_tier, "woodcutting", TreeDatabase.get_tree)
	_harvestable = comp
	comp.depleted.connect(_on_depleted)
	comp.respawned.connect(_on_respawned)


func _on_depleted() -> void:
	WorldState.set_entity_data(entity_id, "harvestable", false)
	var sfx: Dictionary = SfxDatabase.get_sfx("gather_tree_fall")
	if not sfx.is_empty():
		var stream: AudioStream = load(sfx["path"]) if ResourceLoader.exists(sfx["path"]) else null
		if stream:
			_depletion_player.stream = stream
			_depletion_player.volume_db = sfx["volume_db"]
			_depletion_player.play()
	if _tree_model:
		_play_fall_animation()
	else:
		_swap_to_stump()


func _play_fall_animation() -> void:
	var fall_dir: Vector3 = global_position - last_chopper_pos
	fall_dir.y = 0.0
	if fall_dir.length_squared() < 0.01:
		fall_dir = Vector3(0.0, 0.0, 1.0)
	fall_dir = fall_dir.normalized()

	var fall_angle: float = atan2(fall_dir.x, fall_dir.z)

	var tween := create_tween()
	tween.tween_property(_tree_model, "rotation:x", cos(fall_angle) * deg_to_rad(80.0), 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(_tree_model, "rotation:z", -sin(fall_angle) * deg_to_rad(80.0), 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_swap_to_stump)


func _swap_to_stump() -> void:
	if _tree_model:
		_tree_model.queue_free()
		_tree_model = null
	_load_stump_model()
	_refresh_mesh_instances()


func _on_respawned() -> void:
	if _stump_model:
		_stump_model.queue_free()
		_stump_model = null

	_load_tree_model()
	_refresh_mesh_instances()

	WorldState.set_entity_data(entity_id, "harvestable", true)


func spawn_loot(item_id: String, bonus_item: String = "") -> void:
	var tree_data: Dictionary = TreeDatabase.get_tree(tree_tier)
	var max_chops: int = tree_data.get("chops", [3, 5])[1]
	var drop_count: int = maxi(max_chops / 2, 1)
	var loot_scene := preload("res://scenes/objects/loot_drop.gd")
	for i in drop_count:
		if item_id.is_empty():
			break
		var loot := RigidBody3D.new()
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
		var bonus := RigidBody3D.new()
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
