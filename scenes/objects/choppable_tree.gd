extends StaticBody3D
## Choppable tree entity. Spawned by the tree spawner into the world.
## Registers with WorldState for perception and hover system integration.
## Swaps between tree and stump mesh on depletion/respawn.

const ModelHelper = preload("res://scripts/utils/model_helper.gd")
const AssetSpawner = preload("res://scripts/world/asset_spawner.gd")
const TreeDatabase = preload("res://scripts/data/tree_database.gd")
const HarvestableComponent = preload("res://scripts/components/harvestable_component.gd")

const TREE_TEX_DIR := "res://assets/models/environment/nature/trees/textures/"
const STUMP_MODEL_PATH := "res://assets/models/environment/nature/trees/fir/SM_FirStump1.FBX"

static var _next_id: int = 1

var entity_id: String = ""
var tree_tier: String = ""
var tree_name: String = ""

var _model_path: String = ""
var _leaf_color: Color = Color(0.18, 0.55, 0.12)
var _scale_val: float = 1.0

var _tree_model: Node3D = null
var _stump_model: Node3D = null
var _overlay: StandardMaterial3D = null
var _mesh_instances: Array[MeshInstance3D] = []

var _harvestable: Node = null
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
	_build_perception_area()
	_load_tree_model()
	_build_overlay()
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
	shape.radius = 0.3
	shape.height = 3.0
	col.shape = shape
	col.position = Vector3(0.0, 1.5, 0.0)
	add_child(col)
	collision_layer = 1
	collision_mask = 0


func _build_perception_area() -> void:
	var area := Area3D.new()
	area.name = "PerceptionShape"
	area.collision_layer = (1 << 8)
	area.collision_mask = 0
	area.monitorable = true
	area.monitoring = false

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	col.shape = shape
	area.add_child(col)

	add_child(area)


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


func _load_stump_model() -> void:
	var scene := ModelHelper.load_model(STUMP_MODEL_PATH)
	if not scene:
		push_warning("ChoppableTree: failed to load stump model")
		return

	var instance: Node3D = scene.instantiate()
	instance.scale = Vector3.ONE * _scale_val
	add_child(instance)
	_stump_model = instance

	_apply_tree_materials(instance)


func _apply_tree_materials(instance: Node3D) -> void:
	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_texture = load(TREE_TEX_DIR + "T_FirBark_BC.PNG") as Texture2D

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = _leaf_color
	leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaf_mat.alpha_scissor_threshold = 0.5
	leaf_mat.albedo_texture = load(TREE_TEX_DIR + "T_Leaf_Fir_Filled.PNG") as Texture2D
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	AssetSpawner.apply_tree_materials_recursive(instance, bark_mat, leaf_mat)


func _build_overlay() -> void:
	_overlay = ModelHelper.create_overlay_material()
	_refresh_mesh_instances()


func _refresh_mesh_instances() -> void:
	_mesh_instances.clear()
	if _tree_model:
		var tree_meshes := ModelHelper.find_mesh_instances(_tree_model)
		_mesh_instances.append_array(tree_meshes)
	if _stump_model:
		var stump_meshes := ModelHelper.find_mesh_instances(_stump_model)
		_mesh_instances.append_array(stump_meshes)
	if _overlay:
		ModelHelper.apply_overlay(_mesh_instances, _overlay)


func _add_harvestable_component() -> void:
	var comp := HarvestableComponent.new()
	comp.name = "HarvestableComponent"
	add_child(comp)
	comp.setup(tree_tier)
	_harvestable = comp
	comp.depleted.connect(_on_depleted)
	comp.respawned.connect(_on_respawned)


func _on_depleted() -> void:
	WorldState.set_entity_data(entity_id, "harvestable", false)
	if _tree_model:
		_play_fall_animation()
	else:
		_swap_to_stump()


func _play_fall_animation() -> void:
	# Compute fall direction: away from last chopper
	var fall_dir: Vector3 = global_position - last_chopper_pos
	fall_dir.y = 0.0
	if fall_dir.length_squared() < 0.01:
		fall_dir = Vector3(0.0, 0.0, 1.0)
	fall_dir = fall_dir.normalized()

	# Convert fall direction to a rotation axis (perpendicular to fall dir, in XZ plane)
	var fall_angle: float = atan2(fall_dir.x, fall_dir.z)

	var tween := create_tween()
	# Tilt tree ~80 degrees away from chopper over 0.8s, then swap to stump
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
		var loot := Area3D.new()
		loot.set_script(loot_scene)
		loot.item_id = item_id
		loot.item_count = 1
		loot.gold_amount = 0
		var offset := Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
		loot.position = global_position + offset
		get_tree().current_scene.call_deferred("add_child", loot)
	if not bonus_item.is_empty():
		var bonus := Area3D.new()
		bonus.set_script(loot_scene)
		bonus.item_id = bonus_item
		bonus.item_count = 1
		bonus.gold_amount = 0
		bonus.position = global_position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		get_tree().current_scene.call_deferred("add_child", bonus)


func highlight() -> void:
	if _overlay:
		ModelHelper.set_highlight(_overlay, true)


func unhighlight() -> void:
	if _overlay:
		ModelHelper.set_highlight(_overlay, false)


func shake() -> void:
	var tween := create_tween()
	tween.tween_property(self, "rotation:z", deg_to_rad(2.5), 0.07)
	tween.tween_property(self, "rotation:z", deg_to_rad(-2.5), 0.07)
	tween.tween_property(self, "rotation:z", deg_to_rad(1.5), 0.06)
	tween.tween_property(self, "rotation:z", 0.0, 0.06)
