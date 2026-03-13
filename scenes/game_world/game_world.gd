extends Node3D
## Game world — walled city and field zones with shops, monsters, and adventurer NPCs.
## Spawns environment decoration (trees, rocks, city props) programmatically.

# Asset directories
const FOLIAGE_DIR := "res://assets/models/environment/nature/foliage/"
const TREE_DIR := "res://assets/models/environment/nature/trees/fir/"
const DUNGEON_DIR := "res://assets/models/environment/dungeon/"
const TREE_TEX_DIR := "res://assets/models/environment/nature/trees/textures/"
const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")

# Terrain noise (shared for height queries)
var _terrain_noise: FastNoiseLite
var _terrain_height_scale_city: float = 0.15
var _terrain_height_scale_field: float = 0.5

var _texture_cache: Dictionary = {}
var _color_mat_cache: Dictionary = {}
var _deco_noise: FastNoiseLite          # density modulation noise
var _spawned_positions: Array = []       # Vector2 tracking for min-spacing checks
var _path_lines: Array = []              # [{start: Vector2, end: Vector2, buffer: float}]
var _building_zones: Array = []          # [{center: Vector2, radius: float}]

func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex := load(path) as Texture2D
	if tex:
		_texture_cache[path] = tex
	else:
		push_warning("Failed to load texture: " + path)
	return tex

func _ready() -> void:
	# Register location markers with WorldState
	for marker in $LocationMarkers.get_children():
		WorldState.register_location(marker.name, marker.global_position)

	_build_terrain()
	_build_city_walls()
	_setup_exclusion_zones()
	_decorate_city_biomes()
	_place_city_props()
	_decorate_field_biomes()

	# Build district buildings via CityBuilder
	const CityBuilder = preload("res://scripts/world/city_builder.gd")
	CityBuilder.build_all_districts($NavigationRegion3D, _terrain_noise, _terrain_height_scale_city)

	# Bake navmesh after environment is ready
	var nav_region := $NavigationRegion3D
	nav_region.bake_finished.connect(_on_navmesh_baked)
	await get_tree().create_timer(0.5).timeout
	nav_region.bake_navigation_mesh()

func _on_navmesh_baked() -> void:
	var nav_mesh: NavigationMesh = $NavigationRegion3D.navigation_mesh
	var poly_count: int = nav_mesh.get_polygon_count()
	if poly_count == 0:
		push_warning("[NavMesh] WARNING: Navmesh is EMPTY!")
	_setup_adventurer_npcs()

func _build_terrain() -> void:
	# Shared noise for all terrain patches and height queries
	_terrain_noise = FastNoiseLite.new()
	_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_terrain_noise.frequency = 0.05
	_terrain_noise.fractal_octaves = 2
	_terrain_noise.seed = 42

	# Load terrain shader + textures
	var terrain_shader := load("res://assets/shaders/terrain_blend.gdshader") as Shader
	var tex_grass := load("res://assets/textures/terrain/grass_albedo.png") as Texture2D
	var tex_dirt := load("res://assets/textures/terrain/dirt_albedo.png") as Texture2D
	var tex_stone := load("res://assets/textures/terrain/stone_albedo.png") as Texture2D
	var tex_cobble: Texture2D = null
	var tex_packed_earth: Texture2D = null
	if ResourceLoader.exists("res://assets/textures/terrain/cobble_albedo.png"):
		tex_cobble = load("res://assets/textures/terrain/cobble_albedo.png") as Texture2D
	if ResourceLoader.exists("res://assets/textures/terrain/packed_earth_albedo.png"):
		tex_packed_earth = load("res://assets/textures/terrain/packed_earth_albedo.png") as Texture2D

	# --- City Terrain (140x100, center at origin) ---
	var city_rules: Array = [
		# Main E-W road (gate road through center)
		{"type": "line", "start": Vector2(-65, 0), "end": Vector2(65, 0), "width": 2.0, "channel": 0, "falloff": 0.5},
		# Main N-S road
		{"type": "line", "start": Vector2(0, -45), "end": Vector2(0, 45), "width": 2.0, "channel": 0, "falloff": 0.5},
		# Secondary roads along district boundaries
		{"type": "line", "start": Vector2(-65, -10), "end": Vector2(65, -10), "width": 1.2, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(-65, 10), "end": Vector2(65, 10), "width": 1.2, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(-20, -45), "end": Vector2(-20, 45), "width": 1.2, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(25, -45), "end": Vector2(25, 45), "width": 1.2, "channel": 0, "falloff": 0.5},
		# Gate road (wider near gate)
		{"type": "line", "start": Vector2(55, 0), "end": Vector2(75, 0), "width": 3.0, "channel": 0, "falloff": 0.3},
		# Diagonal secondary paths
		{"type": "line", "start": Vector2(0, 0), "end": Vector2(-35, 20), "width": 1.0, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(0, 0), "end": Vector2(35, -25), "width": 1.0, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(55, 0), "end": Vector2(45, 25), "width": 1.0, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(-40, -15), "end": Vector2(-55, -30), "width": 0.8, "channel": 0, "falloff": 0.5},

		# District ground textures (cobblestone via channel 2)
		{"type": "circle", "center": Vector2(0, 0), "radius": 12.0, "channel": 2, "falloff": 0.3},
		{"type": "circle", "center": Vector2(-45, 25), "radius": 18.0, "channel": 2, "falloff": 0.4},
		{"type": "circle", "center": Vector2(0, -30), "radius": 16.0, "channel": 2, "falloff": 0.4},
		# City Gate area — stone (channel 1)
		{"type": "circle", "center": Vector2(60, 0), "radius": 10.0, "channel": 1, "falloff": 0.3},
		# Craft/Workshop — packed earth (channel 3)
		{"type": "circle", "center": Vector2(0, 30), "radius": 14.0, "channel": 3, "falloff": 0.4},
		# Garrison — packed earth
		{"type": "circle", "center": Vector2(45, 30), "radius": 16.0, "channel": 3, "falloff": 0.4},

		# Flatten building sites
		{"type": "flatten", "center": Vector2(-45, 20), "radius": 6.0},
		{"type": "flatten", "center": Vector2(-55, 30), "radius": 5.0},
		{"type": "flatten", "center": Vector2(0, 0), "radius": 8.0},
		{"type": "flatten", "center": Vector2(0, -35), "radius": 8.0},
		{"type": "flatten", "center": Vector2(15, -25), "radius": 6.0},
		{"type": "flatten", "center": Vector2(-10, -40), "radius": 6.0},
		{"type": "flatten", "center": Vector2(0, 30), "radius": 6.0},
		{"type": "flatten", "center": Vector2(45, 35), "radius": 8.0},
	]
	var city := TerrainGenerator.generate_terrain(
		Vector3(0, 0, 0), Vector2(140, 100), Vector2i(70, 50),
		_terrain_noise, 0.15, city_rules
	)

	# --- Field Terrain (80x80, center at 110,0,0) ---
	var field_rules: Array = [
		# Flatten field terrain at gate boundary so heights match city terrain
		{"type": "flatten", "center": Vector2(75, 0), "radius": 8.0},
		{"type": "line", "start": Vector2(70, 0), "end": Vector2(100, 0), "width": 1.5, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(100, 0), "end": Vector2(145, 0), "width": 1.5, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(100, 0), "end": Vector2(110, 25), "width": 1.0, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(100, 0), "end": Vector2(120, -20), "width": 1.0, "channel": 0, "falloff": 0.5},
	]
	var field := TerrainGenerator.generate_terrain(
		Vector3(110, 0, 0), Vector2(80, 80), Vector2i(40, 40),
		_terrain_noise, _terrain_height_scale_field, field_rules
	)

	# Apply shader material to each terrain mesh
	for terrain_data in [city, field]:
		var mat := ShaderMaterial.new()
		mat.shader = terrain_shader
		if tex_grass:
			mat.set_shader_parameter("texture_grass", tex_grass)
		if tex_dirt:
			mat.set_shader_parameter("texture_dirt", tex_dirt)
		if tex_stone:
			mat.set_shader_parameter("texture_stone", tex_stone)
		if tex_cobble:
			mat.set_shader_parameter("texture_cobble", tex_cobble)
		if tex_packed_earth:
			mat.set_shader_parameter("texture_packed_earth", tex_packed_earth)
		mat.set_shader_parameter("uv_scale", 0.5)
		mat.set_shader_parameter("blend_sharpness", 3.0)
		var mi: MeshInstance3D = terrain_data["mesh_instance"]
		mi.mesh.surface_set_material(0, mat)
		$NavigationRegion3D.add_child(mi)
		$NavigationRegion3D.add_child(terrain_data["static_body"])

func _setup_adventurer_npcs() -> void:
	for npc_id in NpcLoadouts.LOADOUTS:
		var loadout: Dictionary = NpcLoadouts.LOADOUTS[npc_id]
		var npc_name: String = npc_id.capitalize()
		var npc: Node3D = $NPCs.get_node_or_null(npc_name)
		if not npc:
			continue

		npc.trait_profile = loadout["trait_profile"]

		var inventory: Node = npc.get_node("InventoryComponent")
		for item_id in loadout["items"]:
			inventory.add_item(item_id, loadout["items"][item_id])

		var equipment: Node = npc.get_node("EquipmentComponent")
		for item_id in loadout["equip"]:
			equipment.equip(item_id)

		var gold: int = loadout["gold"]
		if gold != -1:
			inventory.set_gold_amount(gold)

		var brain: Node = npc.get_node_or_null("NPCBrain")
		if brain:
			brain.set_use_llm(false)
			brain.set_use_llm_chat(true)

		var goal: String = loadout["default_goal"]
		var behavior: Node = npc.get_node_or_null("NPCBehavior")
		if behavior:
			behavior.default_goal = goal
		npc.set_goal(goal)

# =============================================================================
# Asset Loading Infrastructure
# =============================================================================

func _spawn_model(path: String, pos: Vector3, rot_y: float = 0.0, scale_val: float = 1.0, parent: Node = null) -> Node3D:
	var scene := ModelHelper.load_model(path)
	if not scene:
		return null
	var instance: Node3D = scene.instantiate()
	# Snap to terrain height when placed at ground level
	if pos.y == 0.0 and _terrain_noise:
		var height_scale := _terrain_height_scale_field
		# Use city height scale for city area
		if pos.x >= -70 and pos.x <= 70 and pos.z >= -50 and pos.z <= 50:
			height_scale = _terrain_height_scale_city
		pos.y = TerrainGenerator.get_height_at(_terrain_noise, pos.x, pos.z, height_scale)
	instance.position = pos
	if rot_y != 0.0:
		instance.rotation.y = rot_y
	if scale_val != 1.0:
		instance.scale = Vector3.ONE * scale_val
	var target_parent := parent if parent else $NavigationRegion3D
	target_parent.add_child(instance)
	return instance

func _get_or_create_color_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _color_mat_cache.has(key):
		return _color_mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_color_mat_cache[key] = mat
	return mat

func _apply_color_to_model(instance: Node3D, color: Color) -> void:
	var mat := _get_or_create_color_mat(color)
	_apply_material_recursive(instance, mat)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		for i in mesh_inst.get_surface_override_material_count():
			mesh_inst.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _create_bark_material(misc: bool = false) -> StandardMaterial3D:
	var prefix := "T_FirBarkMisc" if misc else "T_FirBark"
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _load_texture(TREE_TEX_DIR + prefix + "_BC.PNG")
	return mat

func _create_leaf_material(color: Color = Color(0.18, 0.55, 0.12)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.albedo_texture = _load_texture(TREE_TEX_DIR + "T_Leaf_Fir_Filled.PNG")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _apply_tree_materials(instance: Node3D, leaf_color: Color, use_misc_bark: bool = false) -> void:
	var bark_mat := _create_bark_material(use_misc_bark)
	var leaf_mat := _create_leaf_material(leaf_color)
	_apply_tree_materials_recursive(instance, bark_mat, leaf_mat)

func _apply_tree_materials_recursive(node: Node, bark_mat: Material, leaf_mat: Material) -> void:
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
		_apply_tree_materials_recursive(child, bark_mat, leaf_mat)

func _spawn_foliage(filename: String, pos: Vector3, color: Color, rot_y: float = 0.0, scale_val: float = 0.25) -> Node3D:
	var instance := _spawn_model(FOLIAGE_DIR + filename, pos, rot_y, scale_val)
	if instance:
		_apply_color_to_model(instance, color)
	return instance

func _spawn_tree(filename: String, pos: Vector3, rot_y: float = 0.0, scale_val: float = 0.25, leaf_color: Color = Color(0.18, 0.55, 0.12)) -> Node3D:
	var instance := _spawn_model(TREE_DIR + filename, pos, rot_y, scale_val)
	if instance:
		_apply_tree_materials(instance, leaf_color)
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

# =============================================================================
# Biome Decoration Infrastructure
# =============================================================================

func _setup_exclusion_zones() -> void:
	_path_lines = [
		# City roads
		{"start": Vector2(-65, 0), "end": Vector2(65, 0), "buffer": 3.0},
		{"start": Vector2(0, -45), "end": Vector2(0, 45), "buffer": 3.0},
		{"start": Vector2(-65, -10), "end": Vector2(65, -10), "buffer": 2.0},
		{"start": Vector2(-65, 10), "end": Vector2(65, 10), "buffer": 2.0},
		{"start": Vector2(-20, -45), "end": Vector2(-20, 45), "buffer": 2.0},
		{"start": Vector2(25, -45), "end": Vector2(25, 45), "buffer": 2.0},
		# Diagonal secondary paths
		{"start": Vector2(0, 0), "end": Vector2(-35, 20), "buffer": 2.0},
		{"start": Vector2(0, 0), "end": Vector2(35, -25), "buffer": 2.0},
		{"start": Vector2(55, 0), "end": Vector2(45, 25), "buffer": 2.0},
		{"start": Vector2(-40, -15), "end": Vector2(-55, -30), "buffer": 1.5},
		# Gate road
		{"start": Vector2(55, 0), "end": Vector2(80, 0), "buffer": 3.5},
		# Field paths
		{"start": Vector2(73, 0), "end": Vector2(100, 0), "buffer": 2.5},
		{"start": Vector2(100, 0), "end": Vector2(145, 0), "buffer": 2.5},
		{"start": Vector2(100, 0), "end": Vector2(110, 25), "buffer": 2.0},
		{"start": Vector2(100, 0), "end": Vector2(120, -20), "buffer": 2.0},
	]
	_building_zones = [
		# Shops in market district
		{"center": Vector2(-45, 20), "radius": 6.0},
		{"center": Vector2(-55, 30), "radius": 5.0},
		# Central plaza
		{"center": Vector2(0, 0), "radius": 10.0},
		# Temple
		{"center": Vector2(0, -35), "radius": 8.0},
		{"center": Vector2(15, -25), "radius": 6.0},
		# Forge
		{"center": Vector2(0, 30), "radius": 6.0},
		# Barracks
		{"center": Vector2(45, 35), "radius": 8.0},
		# Fountain in park
		{"center": Vector2(45, -30), "radius": 5.0},
	]
	_deco_noise = FastNoiseLite.new()
	_deco_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_deco_noise.seed = 137
	_deco_noise.frequency = 0.08

func _point_to_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var t := clampf(ap.dot(ab) / ab.dot(ab), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _is_position_blocked(pos: Vector2) -> bool:
	for line in _path_lines:
		if _point_to_segment_dist(pos, line["start"], line["end"]) < line["buffer"]:
			return true
	for zone in _building_zones:
		if pos.distance_to(zone["center"]) < zone["radius"]:
			return true
	return false

func _scatter_biome(biome: Dictionary, rng: RandomNumberGenerator) -> int:
	var total_placed := 0
	var recipes: Array = biome["recipes"]
	var noise_threshold: float = biome.get("noise_threshold", -0.1)

	for recipe in recipes:
		var count: int = recipe["count"]
		var min_spacing: float = recipe.get("min_spacing", 2.0)
		var placed := 0
		var attempts := 0
		var max_attempts := count * 15

		while placed < count and attempts < max_attempts:
			attempts += 1

			# Generate random point within biome shape
			var x: float
			var z: float
			if biome.has("center") and biome.has("radius"):
				# Circle shape
				var angle := rng.randf() * TAU
				var dist: float = sqrt(rng.randf()) * float(biome["radius"])
				x = biome["center"].x + cos(angle) * dist
				z = biome["center"].y + sin(angle) * dist
			else:
				# Rect shape: [x, z, width, height]
				var bounds: Array = biome["bounds"]
				x = bounds[0] + rng.randf() * bounds[2]
				z = bounds[1] + rng.randf() * bounds[3]

			# Noise rejection
			if _deco_noise.get_noise_2d(x, z) < noise_threshold:
				continue

			var pos2d := Vector2(x, z)

			# Exclusion zone rejection
			if _is_position_blocked(pos2d):
				continue

			# Min-spacing rejection
			var too_close := false
			for existing in _spawned_positions:
				if pos2d.distance_to(existing) < min_spacing:
					too_close = true
					break
			if too_close:
				continue

			# Spawn based on type
			var rot_y := rng.randf() * TAU
			var scale_val: float = recipe.get("scale", 0.25)
			var type: String = recipe["type"]
			var files: Array = recipe.get("files", [])
			var colors: Array = recipe.get("colors", [])
			var file: String = files[rng.randi() % files.size()] if files.size() > 0 else ""
			var color: Color = colors[rng.randi() % colors.size()] if colors.size() > 0 else Color.WHITE

			match type:
				"tree":
					_spawn_tree(file, Vector3(x, 0, z), rot_y, scale_val, color)
				"foliage":
					_spawn_foliage(file, Vector3(x, 0, z), color, rot_y, scale_val)
				"rock_cluster":
					_create_rock_cluster(Vector3(x, 0, z))
				"stump", "fallen":
					var inst := _spawn_model(TREE_DIR + file, Vector3(x, 0, z), rot_y, scale_val)
					if inst:
						var muted_leaf := Color(0.15, 0.35, 0.1)
						_apply_tree_materials(inst, muted_leaf, true)

			_spawned_positions.append(pos2d)
			placed += 1

		total_placed += placed
	return total_placed

# =============================================================================
# City Walls
# =============================================================================

func _build_city_walls() -> void:
	var wall_color := Color(0.45, 0.42, 0.38)
	var wall_mat := _get_or_create_color_mat(wall_color)
	var wall_height := 4.0
	var wall_thickness := 1.0

	# North wall: z=-50, x from -70 to 70
	_place_city_wall_segment(Vector3(-70, 0, -50), Vector3(70, 0, -50), wall_height, wall_thickness, wall_mat)
	# South wall: z=50
	_place_city_wall_segment(Vector3(-70, 0, 50), Vector3(70, 0, 50), wall_height, wall_thickness, wall_mat)
	# West wall: x=-70
	_place_city_wall_segment(Vector3(-70, 0, -50), Vector3(-70, 0, 50), wall_height, wall_thickness, wall_mat)
	# East wall with gate gap: x=70, z:-50..-5 and z:5..50
	_place_city_wall_segment(Vector3(70, 0, -50), Vector3(70, 0, -5), wall_height, wall_thickness, wall_mat)
	_place_city_wall_segment(Vector3(70, 0, 5), Vector3(70, 0, 50), wall_height, wall_thickness, wall_mat)

	# Corner towers
	for corner in [Vector3(-70, 0, -50), Vector3(70, 0, -50), Vector3(70, 0, 50), Vector3(-70, 0, 50)]:
		_build_tower(corner, 5.5, 3.0, wall_mat)

	# Gate towers — placed outside the gap so they don't block passage
	_build_tower(Vector3(70, 0, -7), 6.0, 3.0, wall_mat)
	_build_tower(Vector3(70, 0, 7), 6.0, 3.0, wall_mat)

	# Gatehouse archway — visual only (no collision), placed above walking height
	var arch := MeshInstance3D.new()
	var arch_mesh := BoxMesh.new()
	arch_mesh.size = Vector3(wall_thickness, 1.5, 10.0)
	arch.mesh = arch_mesh
	arch.position = Vector3(70, wall_height + 0.75, 0)
	arch.set_surface_override_material(0, wall_mat)
	add_child(arch)  # Add to root, not NavigationRegion3D — so navmesh ignores it

	# Gate torches
	_spawn_model(DUNGEON_DIR + "torch_lit.gltf.glb", Vector3(69, 0, -4))
	_spawn_model(DUNGEON_DIR + "torch_lit.gltf.glb", Vector3(69, 0, 4))
	_spawn_model(DUNGEON_DIR + "torch_lit.gltf.glb", Vector3(71, 0, -4))
	_spawn_model(DUNGEON_DIR + "torch_lit.gltf.glb", Vector3(71, 0, 4))

func _place_city_wall_segment(start: Vector3, end: Vector3, height: float, thickness: float, mat: Material) -> void:
	var dir := end - start
	var length := dir.length()
	var center := (start + end) * 0.5
	center.y = height * 0.5

	var wall := StaticBody3D.new()
	wall.position = center

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	# Determine orientation
	if absf(dir.x) > absf(dir.z):
		box.size = Vector3(length, height, thickness)
	else:
		box.size = Vector3(thickness, height, length)
	mesh_inst.mesh = box
	mesh_inst.set_surface_override_material(0, mat)
	wall.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	wall.add_child(col)

	$NavigationRegion3D.add_child(wall)

func _build_tower(pos: Vector3, height: float, width: float, mat: Material) -> void:
	var tower := StaticBody3D.new()
	tower.position = Vector3(pos.x, height * 0.5, pos.z)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, width)
	mesh_inst.mesh = box
	mesh_inst.set_surface_override_material(0, mat)
	tower.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	tower.add_child(col)

	$NavigationRegion3D.add_child(tower)

	# Crenellations on top
	var cren_size := Vector3(0.4, 0.6, 0.4)
	var offsets := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]
	for offset in offsets:
		var cren := MeshInstance3D.new()
		var cren_mesh := BoxMesh.new()
		cren_mesh.size = cren_size
		cren.mesh = cren_mesh
		cren.position = Vector3(pos.x + offset.x, height + cren_size.y * 0.5, pos.z + offset.z)
		cren.set_surface_override_material(0, mat)
		$NavigationRegion3D.add_child(cren)

# =============================================================================
# City Zone
# =============================================================================

func _decorate_city_biomes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 200

	var leaf_green := Color(0.18, 0.55, 0.12)
	var dark_leaf := Color(0.12, 0.42, 0.08)
	var green := Color(0.2, 0.45, 0.15)
	var dark_green := Color(0.15, 0.35, 0.1)
	var flower_pink := Color(0.85, 0.4, 0.55)
	var flower_yellow := Color(0.9, 0.85, 0.3)
	var flower_white := Color(0.9, 0.9, 0.85)

	var tree_files := ["SM_FirTree1.FBX", "SM_FirTree2.FBX", "SM_FirTree3.FBX", "SM_FirTree4.FBX", "SM_FirTree5.FBX"]
	var bush_files := ["SM_Bush1.FBX", "SM_Bush2.FBX", "SM_Bush3.FBX"]
	var fern_files := ["SM_Fern1.FBX", "SM_Fern2.FBX", "SM_Fern3.FBX"]
	var flower_files := ["SM_FlowerBush01.FBX", "SM_FlowerBush02.FBX", "SM_Flower_Daisies1.FBX", "SM_Flower_TulipsRed.FBX", "SM_Flower_TulipsYellow.FBX"]
	var leafy_bush_files := ["SM_BushLeafy01.FBX", "SM_BushLeafy02.FBX"]

	var biomes := [
		# Park/Gardens district (x:25..70, z:-50..-10)
		{
			"center": Vector2(45, -30), "radius": 22.0, "noise_threshold": -0.2,
			"recipes": [
				{"type": "tree", "count": 10, "min_spacing": 3.5, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 8, "min_spacing": 2.0, "files": flower_files, "colors": [flower_pink, flower_yellow, flower_white], "scale": 0.25},
				{"type": "foliage", "count": 6, "min_spacing": 2.0, "files": leafy_bush_files, "colors": [green, dark_green], "scale": 0.25},
				{"type": "foliage", "count": 4, "min_spacing": 2.0, "files": fern_files, "colors": [dark_green], "scale": 0.25},
			]
		},
		# Residential gardens (x:-70..-20, z:-50..-10)
		{
			"bounds": [-66, -46, 44, 34], "noise_threshold": 0.1,
			"recipes": [
				{"type": "tree", "count": 6, "min_spacing": 4.0, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 4, "min_spacing": 2.0, "files": flower_files, "colors": [flower_pink, flower_yellow], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": bush_files, "colors": [green], "scale": 0.25},
			]
		},
		# Noble/Temple garden (x:-20..25, z:-50..-10) — sparse, manicured
		{
			"bounds": [-18, -48, 41, 36], "noise_threshold": 0.3,
			"recipes": [
				{"type": "tree", "count": 4, "min_spacing": 5.0, "files": tree_files, "colors": [leaf_green], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 3.0, "files": leafy_bush_files, "colors": [green], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 3.0, "files": flower_files, "colors": [flower_white, flower_pink], "scale": 0.25},
			]
		},
	]

	var total := 0
	for biome in biomes:
		total += _scatter_biome(biome, rng)
	print("[City] Biome scatter placed %d objects" % total)

func _place_city_props() -> void:
	# Market district props
	_spawn_model(DUNGEON_DIR + "barrel_large.gltf.glb", Vector3(-42, 0, 22))
	_spawn_model(DUNGEON_DIR + "crates_stacked.gltf.glb", Vector3(-48, 0, 18), 0.3)
	_spawn_model(DUNGEON_DIR + "barrel_small.gltf.glb", Vector3(-53, 0, 28))
	_spawn_model(DUNGEON_DIR + "barrel_large.gltf.glb", Vector3(-58, 0, 32))

	# Torches at shops
	_spawn_model(DUNGEON_DIR + "torch_lit.gltf.glb", Vector3(-43, 0, 18))
	_spawn_model(DUNGEON_DIR + "torch_lit.gltf.glb", Vector3(-47, 0, 18))
	_spawn_model(DUNGEON_DIR + "torch_lit.gltf.glb", Vector3(-53, 0, 28))
	_spawn_model(DUNGEON_DIR + "torch_lit.gltf.glb", Vector3(-57, 0, 28))

	# Temple/Noble quarter
	_spawn_model(DUNGEON_DIR + "pillar_decorated.gltf.glb", Vector3(-2, 0, -33))
	_spawn_model(DUNGEON_DIR + "pillar_decorated.gltf.glb", Vector3(2, 0, -33))
	_spawn_model(DUNGEON_DIR + "banner_red.gltf.glb", Vector3(15, 0, -23))

	# Craft district
	_spawn_model(DUNGEON_DIR + "barrel_large.gltf.glb", Vector3(-2, 0, 28))
	_spawn_model(DUNGEON_DIR + "crates_stacked.gltf.glb", Vector3(3, 0, 32), 0.5)

	# Garrison
	_spawn_model(DUNGEON_DIR + "torch_lit.gltf.glb", Vector3(38, 0, 28))
	_spawn_model(DUNGEON_DIR + "torch_lit.gltf.glb", Vector3(52, 0, 28))
	_spawn_model(DUNGEON_DIR + "banner_red.gltf.glb", Vector3(45, 0, 33))

	# Central plaza — flowers near well/fountain
	var flower_pink := Color(0.85, 0.4, 0.55)
	var flower_yellow := Color(0.9, 0.85, 0.3)
	_spawn_foliage("SM_Flower_Daisies1.FBX", Vector3(3, 0, 2), Color(0.9, 0.9, 0.85))
	_spawn_foliage("SM_FlowerBush01.FBX", Vector3(-3, 0, -2), flower_pink)
	_spawn_foliage("SM_Flower_TulipsYellow.FBX", Vector3(2, 0, -3), flower_yellow)

# =============================================================================
# Field Zone
# =============================================================================

func _create_rock_cluster(center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x * 100 + center.z * 10)
	var rock_mat := _get_or_create_color_mat(Color(0.4, 0.38, 0.36))
	for i in 2:
		var offset := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
		var radius := rng.randf_range(0.3, 0.7)
		var pos := center + offset
		var terrain_y := TerrainGenerator.get_height_at(_terrain_noise, pos.x, pos.z, _terrain_height_scale_field)
		pos.y = terrain_y + radius * 0.3

		var rock := StaticBody3D.new()
		rock.position = pos
		$NavigationRegion3D.add_child(rock)

		var mesh_inst := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * rng.randf_range(1.0, 1.6)
		mesh_inst.mesh = sphere
		mesh_inst.rotation.y = rng.randf() * TAU
		mesh_inst.rotation.x = rng.randf_range(-0.2, 0.2)
		mesh_inst.set_surface_override_material(0, rock_mat)
		rock.add_child(mesh_inst)

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = radius
		col.shape = shape
		rock.add_child(col)

func _decorate_field_biomes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 300

	var leaf_green := Color(0.18, 0.55, 0.12)
	var dark_leaf := Color(0.12, 0.42, 0.08)
	var green := Color(0.22, 0.48, 0.16)
	var dark_green := Color(0.15, 0.38, 0.1)
	var grass_color := Color(0.28, 0.52, 0.2)
	var fern_color := Color(0.18, 0.42, 0.12)
	var flower_yellow := Color(0.9, 0.85, 0.3)
	var flower_orange := Color(0.9, 0.6, 0.2)
	var flower_pink := Color(0.85, 0.4, 0.55)
	var flower_white := Color(0.9, 0.9, 0.85)

	var tree_files := ["SM_FirTree1.FBX", "SM_FirTree2.FBX", "SM_FirTree3.FBX", "SM_FirTree4.FBX", "SM_FirTree5.FBX"]
	var bush_files := ["SM_Bush1.FBX", "SM_Bush2.FBX", "SM_Bush3.FBX", "SM_BushLeafy01.FBX", "SM_BushLeafy02.FBX"]
	var fern_files := ["SM_Fern1.FBX", "SM_Fern2.FBX", "SM_Fern3.FBX"]
	var grass_files := ["SM_Grass1.FBX", "SM_Grass2.FBX"]
	var flower_files := ["SM_Flower_DaffodilsYellow.FBX", "SM_Flower_Sunflower1.FBX", "SM_Flower_Sunflower2.FBX", "SM_Flower_Sunflower3.FBX", "SM_Flower_TulipsRed.FBX", "SM_FlowerCrocus01.FBX", "SM_Flower_Allium.FBX", "SM_Flower_Foxtails1.FBX"]
	var sapling_files := ["SM_FirSapling1.FBX", "SM_FirSapling2.FBX"]

	var biomes := [
		# Dense Forest — NW field, thick trees
		{
			"bounds": [73, 22, 22, 20], "noise_threshold": -0.1,
			"recipes": [
				{"type": "tree", "count": 14, "min_spacing": 2.5, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 8, "min_spacing": 1.5, "files": fern_files, "colors": [fern_color], "scale": 0.25},
				{"type": "foliage", "count": 4, "min_spacing": 2.0, "files": bush_files, "colors": [green, dark_green], "scale": 0.25},
			]
		},
		# Open Meadow — center-south, wildflowers and grass only
		{
			"center": Vector2(103, -15), "radius": 18.0, "noise_threshold": -0.2,
			"recipes": [
				{"type": "foliage", "count": 15, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 8, "min_spacing": 2.5, "files": flower_files, "colors": [flower_yellow, flower_orange, flower_pink, flower_white], "scale": 0.25},
			]
		},
		# Rocky Clearing — east field, rocks and stumps
		{
			"bounds": [117, -32, 30, 22], "noise_threshold": -0.2,
			"recipes": [
				{"type": "rock_cluster", "count": 8, "min_spacing": 4.0, "files": [], "colors": []},
				{"type": "stump", "count": 3, "min_spacing": 3.0, "files": ["SM_FirStump1.FBX"], "colors": [], "scale": 0.25},
				{"type": "fallen", "count": 2, "min_spacing": 4.0, "files": ["SM_FirFallen1.FBX", "SM_FirFallen2.FBX"], "colors": [], "scale": 0.25},
				{"type": "foliage", "count": 4, "min_spacing": 1.5, "files": fern_files, "colors": [fern_color], "scale": 0.25},
			]
		},
		# Transitional NE — sparse mix
		{
			"bounds": [110, 22, 30, 20], "noise_threshold": 0.0,
			"recipes": [
				{"type": "tree", "count": 6, "min_spacing": 3.0, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 1.5, "files": fern_files, "colors": [fern_color], "scale": 0.25},
			]
		},
		# Transitional SW — sparse mix near entrance
		{
			"bounds": [73, -10, 17, 20], "noise_threshold": 0.0,
			"recipes": [
				{"type": "tree", "count": 5, "min_spacing": 3.0, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 2, "min_spacing": 2.0, "files": bush_files, "colors": [green, dark_green], "scale": 0.25},
				{"type": "stump", "count": 1, "min_spacing": 3.0, "files": ["SM_FirStump1.FBX"], "colors": [], "scale": 0.25},
			]
		},
		# Path-edge scatter — sparse along main path
		{
			"bounds": [73, 0, 77, 10], "noise_threshold": 0.2,
			"recipes": [
				{"type": "tree", "count": 2, "min_spacing": 4.0, "files": sapling_files, "colors": [leaf_green], "scale": 0.25},
				{"type": "foliage", "count": 5, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": fern_files, "colors": [fern_color], "scale": 0.25},
			]
		},
	]

	var total := 0
	for biome in biomes:
		total += _scatter_biome(biome, rng)
	print("[Field] Biome scatter placed %d objects" % total)
