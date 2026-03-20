class_name AssetSpawner
## Static utility class for model spawning and material operations.
## All methods take ctx as first parameter and operate on WorldBuilderContext state.

const FOLIAGE_DIR := "res://assets/models/environment/nature/foliage/"
const TREE_DIR := "res://assets/models/environment/nature/trees/stylized/"
const TREE_TEX_DIR := "res://assets/models/environment/nature/trees/stylized/textures/"
const DUNGEON_DIR := "res://assets/models/environment/dungeon/"
const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")

static func load_texture(ctx: WorldBuilderContext, path: String) -> Texture2D:
	if ctx.texture_cache.has(path):
		return ctx.texture_cache[path]
	var tex := load(path) as Texture2D
	if tex:
		ctx.texture_cache[path] = tex
	else:
		push_warning("Failed to load texture: " + path)
	return tex

static func spawn_model(ctx: WorldBuilderContext, path: String, pos: Vector3, rot_y: float = 0.0, scale_val: float = 1.0, parent: Node = null) -> Node3D:
	var scene := ModelHelper.load_model(path)
	if not scene:
		return null
	var instance: Node3D = scene.instantiate()
	# Snap to terrain height when placed at ground level
	if pos.y == 0.0 and ctx.terrain_noise:
		var height_scale := ctx.terrain_height_scale_field
		# Use city height scale for city area
		if ctx.is_in_city(pos):
			height_scale = ctx.terrain_height_scale_city
		pos.y = TerrainGenerator.get_height_at(ctx.terrain_noise, pos.x, pos.z, height_scale)
	instance.position = pos
	if rot_y != 0.0:
		instance.rotation.y = rot_y
	if scale_val != 1.0:
		instance.scale = Vector3.ONE * scale_val
	var target_parent := parent if parent else ctx.nav_region
	target_parent.add_child(instance)
	return instance

static func get_or_create_color_mat(ctx: WorldBuilderContext, color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if ctx.color_mat_cache.has(key):
		return ctx.color_mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	ctx.color_mat_cache[key] = mat
	return mat

static func get_or_create_emissive_mat(ctx: WorldBuilderContext, albedo: Color, emission: Color, emission_energy: float) -> StandardMaterial3D:
	var key := "emissive_" + albedo.to_html() + "_" + emission.to_html() + "_" + str(emission_energy)
	if ctx.color_mat_cache.has(key):
		return ctx.color_mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = emission_energy
	ctx.color_mat_cache[key] = mat
	return mat

static func apply_color_to_model(ctx: WorldBuilderContext, instance: Node3D, color: Color) -> void:
	var mat := get_or_create_color_mat(ctx, color)
	apply_material_recursive(instance, mat)

static func apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		for i in mesh_inst.get_surface_override_material_count():
			mesh_inst.set_surface_override_material(i, mat)
	for child in node.get_children():
		apply_material_recursive(child, mat)

static func create_bark_material(ctx: WorldBuilderContext, misc: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load_texture(ctx, TREE_TEX_DIR + "trunk_alb.png")
	return mat

static func create_leaf_material(ctx: WorldBuilderContext, color: Color = Color(0.18, 0.55, 0.12)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	# Stylized textures have pre-baked color; no albedo_color tint needed
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.albedo_texture = load_texture(ctx, TREE_TEX_DIR + "leaf_alb.png")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func apply_tree_materials(ctx: WorldBuilderContext, instance: Node3D, leaf_color: Color, use_misc_bark: bool = false) -> void:
	var bark_mat := create_bark_material(ctx, use_misc_bark)
	var leaf_mat := create_leaf_material(ctx, leaf_color)
	apply_tree_materials_recursive(instance, bark_mat, leaf_mat)

static func apply_tree_materials_recursive(node: Node, bark_mat: Material, leaf_mat: Material) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var surface_count := mesh_inst.get_surface_override_material_count()
		var found_leaf := false

		# Single pass: assign by material name
		for i in surface_count:
			var orig_mat := mesh_inst.mesh.surface_get_material(i)
			var mat_name := orig_mat.resource_name.to_lower() if orig_mat else ""
			if "leaf" in mat_name or "leaves" in mat_name:
				mesh_inst.set_surface_override_material(i, leaf_mat)
				found_leaf = true
			else:
				mesh_inst.set_surface_override_material(i, bark_mat)

		# Fallback: no leaf names found, 2+ surfaces -> last surface is leaves
		if not found_leaf and surface_count >= 2:
			mesh_inst.set_surface_override_material(surface_count - 1, leaf_mat)

	for child in node.get_children():
		apply_tree_materials_recursive(child, bark_mat, leaf_mat)

static func spawn_foliage(ctx: WorldBuilderContext, filename: String, pos: Vector3, color: Color, rot_y: float = 0.0, scale_val: float = 0.25) -> Node3D:
	var instance := spawn_model(ctx, FOLIAGE_DIR + filename, pos, rot_y, scale_val)
	if instance:
		apply_color_to_model(ctx, instance, color)
		disable_shadows_recursive(instance)
	return instance

static func spawn_tree(ctx: WorldBuilderContext, filename: String, pos: Vector3, rot_y: float = 0.0, scale_val: float = 0.25, leaf_color: Color = Color(0.18, 0.55, 0.12)) -> Node3D:
	var instance := spawn_model(ctx, TREE_DIR + filename, pos, rot_y, scale_val)
	if instance:
		apply_tree_materials(ctx, instance, leaf_color)
		# Add trunk collision for navmesh
		var body := StaticBody3D.new()
		body.position = Vector3(0, 1.5, 0)
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.3
		shape.height = 3.0
		col.shape = shape
		body.add_child(col)
		instance.add_child(body)
	return instance

static func spawn_choppable_tree(ctx: WorldBuilderContext, filename: String, pos: Vector3, rot_y: float, scale_val: float, leaf_color: Color, tier: String) -> StaticBody3D:
	const ChoppableTree = preload("res://scenes/objects/choppable_tree.gd")
	var tree := StaticBody3D.new()
	tree.set_script(ChoppableTree)
	if pos.y == 0.0 and ctx.terrain_noise:
		var height_scale := ctx.terrain_height_scale_field
		if ctx.is_in_city(pos):
			height_scale = ctx.terrain_height_scale_city
		pos.y = TerrainGenerator.get_height_at(ctx.terrain_noise, pos.x, pos.z, height_scale)
	tree.position = pos
	ctx.nav_region.add_child(tree)
	tree.setup(tier, TREE_DIR + filename, rot_y, scale_val, leaf_color)
	return tree

static func spawn_mineable_rock(ctx: WorldBuilderContext, pos: Vector3, rot_y: float, scale_val: float, tier: String) -> StaticBody3D:
	const MineableRock = preload("res://scenes/objects/mineable_rock.gd")
	var rock := StaticBody3D.new()
	rock.set_script(MineableRock)
	if pos.y == 0.0 and ctx.terrain_noise:
		var height_scale := ctx.terrain_height_scale_field
		if ctx.is_in_city(pos):
			height_scale = ctx.terrain_height_scale_city
		pos.y = TerrainGenerator.get_height_at(ctx.terrain_noise, pos.x, pos.z, height_scale)
	rock.position = pos
	rock.rotation.y = rot_y
	ctx.nav_region.add_child(rock)
	rock.setup(tier, scale_val)
	return rock

static func spawn_fishing_spot(ctx: WorldBuilderContext, pos: Vector3, tier: String) -> StaticBody3D:
	const FishingSpot = preload("res://scenes/objects/fishing_spot.gd")
	var spot := StaticBody3D.new()
	spot.set_script(FishingSpot)
	if pos.y == 0.0 and ctx.terrain_noise:
		var height_scale := ctx.terrain_height_scale_field
		if ctx.is_in_city(pos):
			height_scale = ctx.terrain_height_scale_city
		pos.y = TerrainGenerator.get_height_at(ctx.terrain_noise, pos.x, pos.z, height_scale)
	spot.position = pos
	ctx.nav_region.add_child(spot)
	spot.setup(tier)
	return spot


static func spawn_dungeon_model(ctx: WorldBuilderContext, filename: String, pos: Vector3, rot_y: float = 0.0, scale_val: float = 1.0) -> Node3D:
	var instance: Node3D = spawn_model(ctx, DUNGEON_DIR + filename, pos, rot_y, scale_val)
	if instance:
		disable_shadows_recursive(instance)
	return instance

static func disable_shadows_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		disable_shadows_recursive(child)

