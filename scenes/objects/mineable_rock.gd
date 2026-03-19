extends StaticBody3D
## Mineable rock entity. Spawned by the rock spawner into the world.
## Registers with WorldState for hover and NPC targeting.
## Uses procedural sphere-cluster geometry — no external model files.
## Depletion shrinks + darkens the rock; respawn restores scale and color.

const OreDatabase = preload("res://scripts/data/ore_database.gd")
const HarvestableComponent = preload("res://scripts/components/harvestable_component.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")

const TIER_COLORS: Dictionary = {
	"copper": Color(0.72, 0.45, 0.2),
	"iron": Color(0.55, 0.56, 0.62),
	"gold": Color(0.85, 0.65, 0.13),
}

static var _next_id: int = 1
static var _ore_mats: Dictionary = {}  # tier → StandardMaterial3D
static var _highlight_mat: StandardMaterial3D = null

var entity_id: String = ""
var rock_tier: String = ""
var rock_name: String = ""
var _scale_val: float = 1.0
var _rock_mesh_root: Node3D = null
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
	_build_rock_mesh()
	_add_harvestable_component()

	WorldState.register_entity(entity_id, self, {
		"type": "rock",
		"name": rock_name,
		"rock_tier": rock_tier,
		"harvestable": true,
	})


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.2
	col.shape = shape
	col.position = Vector3(0.0, 0.8, 0.0)
	add_child(col)
	collision_layer = 1
	collision_mask = 0


func _build_rock_mesh() -> void:
	_rock_mesh_root = Node3D.new()
	_rock_mesh_root.scale = Vector3.ONE * _scale_val
	add_child(_rock_mesh_root)
	_original_scale = _rock_mesh_root.scale

	var mat: StandardMaterial3D = _get_ore_material(rock_tier)

	var main: MeshInstance3D = _create_sphere(Vector3(0.0, 0.6, 0.0), 0.8, mat)
	var bump1: MeshInstance3D = _create_sphere(Vector3(0.5, 0.4, 0.3), 0.5, mat)
	var bump2: MeshInstance3D = _create_sphere(Vector3(-0.4, 0.3, -0.3), 0.45, mat)
	var bump3: MeshInstance3D = _create_sphere(Vector3(0.1, 0.9, -0.2), 0.4, mat)

	_mesh_instances = [main, bump1, bump2, bump3]


func _create_sphere(pos: Vector3, radius: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mi.mesh = sphere
	mi.material_override = mat
	mi.position = pos
	_rock_mesh_root.add_child(mi)
	return mi


func _get_ore_material(tier: String) -> StandardMaterial3D:
	if _ore_mats.has(tier):
		return _ore_mats[tier]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TIER_COLORS.get(tier, Color.GRAY)
	mat.roughness = 0.85
	mat.metallic = 0.1
	_ore_mats[tier] = mat
	return mat


func _add_harvestable_component() -> void:
	var comp := HarvestableComponent.new()
	comp.name = "HarvestableComponent"
	add_child(comp)
	comp.setup(rock_tier, "mining", OreDatabase.get_ore)
	_harvestable = comp
	comp.depleted.connect(_on_depleted)
	comp.respawned.connect(_on_respawned)


func _on_depleted() -> void:
	WorldState.set_entity_data(entity_id, "harvestable", false)
	if _rock_mesh_root:
		var tween := create_tween()
		tween.tween_property(_rock_mesh_root, "scale", _original_scale * 0.3, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		for mi in _mesh_instances:
			if is_instance_valid(mi):
				var dark_mat := StandardMaterial3D.new()
				dark_mat.albedo_color = _base_color.darkened(0.6)
				dark_mat.roughness = 0.9
				mi.material_override = dark_mat


func _on_respawned() -> void:
	WorldState.set_entity_data(entity_id, "harvestable", true)
	if _rock_mesh_root:
		var tween := create_tween()
		tween.tween_property(_rock_mesh_root, "scale", _original_scale, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		var mat: StandardMaterial3D = _get_ore_material(rock_tier)
		for mi in _mesh_instances:
			if is_instance_valid(mi):
				mi.material_override = mat


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
