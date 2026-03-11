extends Node3D
## Game world — town, field, and dungeon zones with shops, monsters, and adventurer NPCs.
## Spawns environment decoration (trees, rocks, dungeon props) programmatically.

# Asset directories
const FOLIAGE_DIR := "res://assets/models/environment/nature/foliage/"
const TREE_DIR := "res://assets/models/environment/nature/trees/fir/"
const DUNGEON_DIR := "res://assets/models/environment/dungeon/"
const TREE_TEX_DIR := "res://assets/models/environment/nature/trees/textures/"
const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")

# Terrain noise (shared for height queries)
var _terrain_noise: FastNoiseLite
var _terrain_height_scale_town: float = 0.3
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

	# Build procedural terrain (replaces old flat BoxMesh grounds + path meshes)
	_build_terrain()

	# Spawn environment decorations
	_build_dungeon_walls()
	_spawn_dungeon_decorations()
	_setup_exclusion_zones()
	_decorate_town_biomes()
	_place_town_props()
	_decorate_field_biomes()

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

	# --- Town Terrain (70x70, center at origin) ---
	var town_rules: Array = [
		# North-south road through town center
		{"type": "line", "start": Vector2(0, -30), "end": Vector2(0, 30), "width": 1.5, "channel": 0, "falloff": 0.5},
		# East-west road through town center
		{"type": "line", "start": Vector2(-30, 0), "end": Vector2(30, 0), "width": 1.5, "channel": 0, "falloff": 0.5},
		# Path to field (east side)
		{"type": "line", "start": Vector2(10, 5), "end": Vector2(35, 5), "width": 1.5, "channel": 0, "falloff": 0.5},
		# Flatten around weapon shop (-8, -5)
		{"type": "flatten", "center": Vector2(-8, -5), "radius": 4.0},
		# Flatten around item shop (8, -6)
		{"type": "flatten", "center": Vector2(8, -6), "radius": 4.0},
		# Flatten around well (3, -1)
		{"type": "flatten", "center": Vector2(3, -1), "radius": 2.0},
		# Flatten town center
		{"type": "flatten", "center": Vector2(0, 0), "radius": 3.0},
	]
	var town := TerrainGenerator.generate_terrain(
		Vector3(0, 0, 0), Vector2(70, 70), Vector2i(35, 35),
		_terrain_noise, _terrain_height_scale_town, town_rules
	)

	# --- Field Terrain (80x80, center at 75,0,5) ---
	var field_rules: Array = [
		# Main path from town border to dungeon entrance
		{"type": "line", "start": Vector2(38, 5), "end": Vector2(65, 5), "width": 1.5, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(65, 5), "end": Vector2(118, 5), "width": 1.5, "channel": 0, "falloff": 0.5},
		# Branch to north
		{"type": "line", "start": Vector2(65, 5), "end": Vector2(75, 30), "width": 1.0, "channel": 0, "falloff": 0.5},
		# Branch to south
		{"type": "line", "start": Vector2(65, 5), "end": Vector2(85, -25), "width": 1.0, "channel": 0, "falloff": 0.5},
	]
	var field := TerrainGenerator.generate_terrain(
		Vector3(75, 0, 5), Vector2(80, 80), Vector2i(40, 40),
		_terrain_noise, _terrain_height_scale_field, field_rules
	)

	# --- Dungeon Terrain (50x50, flat stone) ---
	var dungeon_rules: Array = [
		{"type": "fill", "channel": 1, "strength": 1.0},
	]
	var dungeon := TerrainGenerator.generate_terrain(
		Vector3(140, 0, 5), Vector2(50, 50), Vector2i(1, 1),
		_terrain_noise, 0.0, dungeon_rules
	)

	# Apply shader material to each terrain mesh
	for terrain_data in [town, field, dungeon]:
		var mat := ShaderMaterial.new()
		mat.shader = terrain_shader
		if tex_grass:
			mat.set_shader_parameter("texture_grass", tex_grass)
		if tex_dirt:
			mat.set_shader_parameter("texture_dirt", tex_dirt)
		if tex_stone:
			mat.set_shader_parameter("texture_stone", tex_stone)
		mat.set_shader_parameter("uv_scale", 0.5)
		mat.set_shader_parameter("blend_sharpness", 3.0)
		var mi: MeshInstance3D = terrain_data["mesh_instance"]
		mi.mesh.surface_set_material(0, mat)
		$NavigationRegion3D.add_child(mi)
		$NavigationRegion3D.add_child(terrain_data["static_body"])

func _setup_adventurer_npcs() -> void:
	# Kael (Warrior) — bold, charges into combat
	var kael: Node3D = $NPCs/Kael
	if kael:
		WorldState.add_to_inventory("kael", "basic_sword")
		WorldState.add_to_inventory("kael", "healing_potion", 3)
		WorldState.equip_item("kael", "basic_sword")

		kael.get_node("NPCBrain").set_use_llm(false)
		kael.get_node("NPCBrain").set_use_llm_chat(true)
		var kael_behavior = kael.get_node("NPCBehavior")
		kael_behavior.default_goal = "idle"
		kael.set_goal("idle")

	# Lyra (Mage) — cautious, strategic
	var lyra: Node3D = $NPCs/Lyra
	if lyra:
		WorldState.add_to_inventory("lyra", "healing_potion", 5)
		WorldState.set_entity_data("lyra", "gold", 60)

		lyra.get_node("NPCBrain").set_use_llm(false)
		lyra.get_node("NPCBrain").set_use_llm_chat(true)
		var lyra_behavior = lyra.get_node("NPCBehavior")
		lyra_behavior.default_goal = "idle"
		lyra.set_goal("idle")

	# Bjorn (Warrior) — boisterous storyteller
	var bjorn: Node3D = $NPCs/Bjorn
	if bjorn:
		WorldState.add_to_inventory("bjorn", "healing_potion", 3)
		WorldState.set_entity_data("bjorn", "gold", 80)

		bjorn.get_node("NPCBrain").set_use_llm(false)
		bjorn.get_node("NPCBrain").set_use_llm_chat(true)
		var bjorn_behavior = bjorn.get_node("NPCBehavior")
		bjorn_behavior.default_goal = "idle"
		bjorn.set_goal("idle")

	# Sera (Rogue) — quick-witted gossip
	var sera: Node3D = $NPCs/Sera
	if sera:
		WorldState.add_to_inventory("sera", "healing_potion", 2)
		WorldState.set_entity_data("sera", "gold", 100)

		sera.get_node("NPCBrain").set_use_llm(false)
		sera.get_node("NPCBrain").set_use_llm_chat(true)
		var sera_behavior = sera.get_node("NPCBehavior")
		sera_behavior.default_goal = "idle"
		sera.set_goal("idle")

	# Thane (Knight) — stoic and honorable
	var thane: Node3D = $NPCs/Thane
	if thane:
		WorldState.add_to_inventory("thane", "healing_potion", 2)
		WorldState.set_entity_data("thane", "gold", 70)

		thane.get_node("NPCBrain").set_use_llm(false)
		thane.get_node("NPCBrain").set_use_llm_chat(true)
		var thane_behavior = thane.get_node("NPCBehavior")
		thane_behavior.default_goal = "idle"
		thane.set_goal("idle")

	# Mira (Mage) — cheerful and curious
	var mira: Node3D = $NPCs/Mira
	if mira:
		WorldState.add_to_inventory("mira", "healing_potion", 3)
		WorldState.set_entity_data("mira", "gold", 60)

		mira.get_node("NPCBrain").set_use_llm(false)
		mira.get_node("NPCBrain").set_use_llm_chat(true)
		var mira_behavior = mira.get_node("NPCBehavior")
		mira_behavior.default_goal = "idle"
		mira.set_goal("idle")

	# Dusk (Rogue) — mysterious and quiet
	var dusk: Node3D = $NPCs/Dusk
	if dusk:
		WorldState.add_to_inventory("dusk", "healing_potion", 2)
		WorldState.set_entity_data("dusk", "gold", 50)

		dusk.get_node("NPCBrain").set_use_llm(false)
		dusk.get_node("NPCBrain").set_use_llm_chat(true)
		var dusk_behavior = dusk.get_node("NPCBehavior")
		dusk_behavior.default_goal = "idle"
		dusk.set_goal("idle")

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
		# Use town height scale for town area
		if pos.x >= -35 and pos.x <= 35 and pos.z >= -35 and pos.z <= 35:
			height_scale = _terrain_height_scale_town
		elif pos.x >= 115 and pos.x <= 165 and pos.z >= -20 and pos.z <= 30:
			height_scale = 0.0  # Dungeon: flat
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

func _spawn_dungeon_model(filename: String, pos: Vector3, rot_y: float = 0.0, scale_val: float = 1.0) -> Node3D:
	return _spawn_model(DUNGEON_DIR + filename, pos, rot_y, scale_val)

# =============================================================================
# Biome Decoration Infrastructure
# =============================================================================

func _setup_exclusion_zones() -> void:
	# Path lines — same data as terrain paint rules
	_path_lines = [
		# Town paths
		{"start": Vector2(0, -30), "end": Vector2(0, 30), "buffer": 2.5},
		{"start": Vector2(-30, 0), "end": Vector2(30, 0), "buffer": 2.5},
		{"start": Vector2(10, 5), "end": Vector2(35, 5), "buffer": 2.5},
		# Field paths
		{"start": Vector2(38, 5), "end": Vector2(65, 5), "buffer": 2.5},
		{"start": Vector2(65, 5), "end": Vector2(118, 5), "buffer": 2.5},
		{"start": Vector2(65, 5), "end": Vector2(75, 30), "buffer": 2.0},
		{"start": Vector2(65, 5), "end": Vector2(85, -25), "buffer": 2.0},
	]

	# Building zones — from flatten rules
	_building_zones = [
		{"center": Vector2(-8, -5), "radius": 5.0},
		{"center": Vector2(8, -6), "radius": 5.0},
		{"center": Vector2(3, -1), "radius": 3.0},
		{"center": Vector2(0, 0), "radius": 4.0},
	]

	# Decoration density noise
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
	# Check path lines
	for line in _path_lines:
		if _point_to_segment_dist(pos, line["start"], line["end"]) < line["buffer"]:
			return true
	# Check building zones
	for zone in _building_zones:
		if pos.distance_to(zone["center"]) < zone["radius"]:
			return true
	# Fence at x=30
	if absf(pos.x - 30.0) < 1.0 and pos.y >= -22.0 and pos.y <= 25.0:
		return true
	# Dungeon boundary
	if pos.x > 113.0:
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
# Dungeon Zone
# =============================================================================

func _build_dungeon_walls() -> void:
	var walls_parent := $NavigationRegion3D/DungeonWalls

	# Measure wall tile width from model AABB
	var wall_scene := ModelHelper.load_model(DUNGEON_DIR + "wall.gltf.glb")
	var wall_width := 2.0  # default fallback
	if wall_scene:
		var temp := wall_scene.instantiate() as Node3D
		var aabb := _get_node_aabb(temp)
		if aabb.size.x > 0.1:
			wall_width = aabb.size.x
		elif aabb.size.z > 0.1:
			wall_width = aabb.size.z
		temp.queue_free()

	# Outer walls — x:115→165, z:-20→30
	# North wall: z=-20, x from 115 to 165
	_place_wall_line(Vector3(115, 0, -20), Vector3(165, 0, -20), wall_width, 0.0, walls_parent)
	# South wall: z=30, x from 115 to 165
	_place_wall_line(Vector3(115, 0, 30), Vector3(165, 0, 30), wall_width, PI, walls_parent)
	# East wall: x=165, z from -20 to 30
	_place_wall_line(Vector3(165, 0, -20), Vector3(165, 0, 30), wall_width, -PI / 2.0, walls_parent)
	# West wall with entrance gap: x=115, z=-20→-2 and z=8→30
	_place_wall_line(Vector3(115, 0, -20), Vector3(115, 0, -2), wall_width, PI / 2.0, walls_parent)
	_place_wall_line(Vector3(115, 0, 8), Vector3(115, 0, 30), wall_width, PI / 2.0, walls_parent)

	# Doorway at entrance
	var doorway := _spawn_dungeon_model("wall_doorway.glb", Vector3(115, 0, 3), PI / 2.0)
	if doorway:
		doorway.reparent(walls_parent)
		_add_wall_collision(doorway, Vector3(1, 3, 4))

	# Corners
	_spawn_dungeon_model("wall_corner.gltf.glb", Vector3(115, 0, -20), 0.0)
	_spawn_dungeon_model("wall_corner.gltf.glb", Vector3(165, 0, -20), -PI / 2.0)
	_spawn_dungeon_model("wall_corner.gltf.glb", Vector3(165, 0, 30), PI)
	_spawn_dungeon_model("wall_corner.gltf.glb", Vector3(115, 0, 30), PI / 2.0)

	# Inner walls — create rooms: entry chamber, south wing, north wing, deep chamber
	# Horizontal wall: x=125→135, z=-5
	_place_wall_line(Vector3(125, 0, -5), Vector3(135, 0, -5), wall_width, 0.0, walls_parent, true)
	# Horizontal wall: x=140→150, z=10
	_place_wall_line(Vector3(140, 0, 10), Vector3(150, 0, 10), wall_width, 0.0, walls_parent, true)
	# Vertical wall: x=135, z=-15→-5
	_place_wall_line(Vector3(135, 0, -15), Vector3(135, 0, -5), wall_width, PI / 2.0, walls_parent, true)
	# Vertical wall: x=150, z=10→20
	_place_wall_line(Vector3(150, 0, 10), Vector3(150, 0, 20), wall_width, PI / 2.0, walls_parent, true)

func _place_wall_line(start: Vector3, end: Vector3, tile_w: float, rot_y: float, parent: Node, is_inner: bool = false) -> void:
	var direction := (end - start).normalized()
	var total_dist := start.distance_to(end)
	var count := int(total_dist / tile_w)
	if count < 1:
		count = 1

	for i in count:
		var pos := start + direction * (tile_w * i + tile_w * 0.5)
		# Every 4th-5th wall segment use broken variant for variety
		var wall_file := "wall.gltf.glb"
		if is_inner:
			wall_file = "wall_arched.gltf.glb"
		elif i % 5 == 3:
			wall_file = "wall_broken.gltf.glb"

		var wall := _spawn_dungeon_model(wall_file, pos, rot_y)
		if wall:
			wall.reparent(parent)
			_add_wall_collision(wall, Vector3(tile_w, 3, 1))

func _add_wall_collision(wall_node: Node3D, box_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0, box_size.y * 0.5, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	body.add_child(col)
	wall_node.add_child(body)

func _get_node_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_aabb: AABB = child.get_aabb()
			if not found:
				result = mesh_aabb
				found = true
			else:
				result = result.merge(mesh_aabb)
	if not found:
		for child in node.get_children():
			if child is Node3D:
				var child_aabb := _get_node_aabb(child)
				if child_aabb.size.length() > 0.01:
					if not found:
						result = child_aabb
						found = true
					else:
						result = result.merge(child_aabb)
	return result

func _spawn_dungeon_decorations() -> void:
	# Torches along walls — dungeon bounds x:115→165, z:-20→30
	var torch_positions := [
		# North wall torches (z=-20)
		Vector3(120, 0, -19.5), Vector3(128, 0, -19.5), Vector3(136, 0, -19.5),
		Vector3(144, 0, -19.5), Vector3(152, 0, -19.5), Vector3(160, 0, -19.5),
		# South wall torches (z=30)
		Vector3(120, 0, 29.5), Vector3(128, 0, 29.5), Vector3(136, 0, 29.5),
		Vector3(144, 0, 29.5), Vector3(152, 0, 29.5), Vector3(160, 0, 29.5),
		# East wall torches (x=165)
		Vector3(164.5, 0, -12), Vector3(164.5, 0, -2), Vector3(164.5, 0, 8),
		Vector3(164.5, 0, 18), Vector3(164.5, 0, 25),
		# West wall torches (x=115)
		Vector3(115.5, 0, -14), Vector3(115.5, 0, 14), Vector3(115.5, 0, 24),
		# Inner area torches
		Vector3(130, 0, 5), Vector3(140, 0, -8), Vector3(145, 0, 18),
		Vector3(155, 0, 5), Vector3(135, 0, 15), Vector3(125, 0, -10),
	]

	for pos in torch_positions:
		var rot := 0.0
		if pos.z < -19:  # North wall
			rot = PI
		elif pos.z > 29:  # South wall
			rot = 0.0
		elif pos.x > 164:  # East wall
			rot = PI / 2.0
		elif pos.x < 116:  # West wall
			rot = -PI / 2.0

		_spawn_dungeon_model("torch_mounted.gltf.glb", pos, rot)

	# Decorated pillars at room corners
	_spawn_dungeon_model("pillar_decorated.gltf.glb", Vector3(118, 0, -17))
	_spawn_dungeon_model("pillar_decorated.gltf.glb", Vector3(162, 0, -17))
	_spawn_dungeon_model("pillar_decorated.gltf.glb", Vector3(162, 0, 27))
	_spawn_dungeon_model("pillar_decorated.gltf.glb", Vector3(118, 0, 27))

	# Plain pillars at inner wall junctions
	_spawn_dungeon_model("pillar.gltf.glb", Vector3(125, 0, -5))
	_spawn_dungeon_model("pillar.gltf.glb", Vector3(135, 0, -5))
	_spawn_dungeon_model("pillar.gltf.glb", Vector3(135, 0, -15))
	_spawn_dungeon_model("pillar.gltf.glb", Vector3(140, 0, 10))
	_spawn_dungeon_model("pillar.gltf.glb", Vector3(150, 0, 10))
	_spawn_dungeon_model("pillar.gltf.glb", Vector3(150, 0, 20))

	# Banners at entrance and in rooms
	_spawn_dungeon_model("banner_red.gltf.glb", Vector3(115.5, 0, -1), -PI / 2.0)
	_spawn_dungeon_model("banner_red.gltf.glb", Vector3(115.5, 0, 7), -PI / 2.0)
	_spawn_dungeon_model("banner_red.gltf.glb", Vector3(158, 0, 26))

	# Storage clusters — SW corner
	_spawn_dungeon_model("barrel_large.gltf.glb", Vector3(117, 0, 26))
	_spawn_dungeon_model("barrel_small.gltf.glb", Vector3(118.5, 0, 27))
	_spawn_dungeon_model("crates_stacked.gltf.glb", Vector3(119, 0, 28), 0.3)
	# Storage clusters — NE corner
	_spawn_dungeon_model("barrel_large.gltf.glb", Vector3(162, 0, -17))
	_spawn_dungeon_model("crates_stacked.gltf.glb", Vector3(161, 0, -16), -0.5)

	# Chests — deep chamber + south wing
	_spawn_dungeon_model("chest.glb", Vector3(158, 0, 5), PI)
	_spawn_dungeon_model("chest.glb", Vector3(130, 0, -15), 0.0)

	# Ferns near entrance for transition feel
	var dark_green := Color(0.08, 0.18, 0.06)
	_spawn_foliage("SM_RedFern01.FBX", Vector3(114, 0, -1), dark_green, 0.0, 0.25)
	_spawn_foliage("SM_RedFern02.FBX", Vector3(114, 0, 7), dark_green, 1.2, 0.25)
	_spawn_foliage("SM_Fern1.FBX", Vector3(113, 0, 3), dark_green, 0.5, 0.25)

	# Dungeon atmosphere — dark ceiling
	_create_dungeon_ceiling()

func _create_dungeon_ceiling() -> void:
	var ceiling := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(50, 50)
	ceiling.mesh = mesh
	ceiling.position = Vector3(140, 3.5, 5)
	ceiling.rotation.x = PI  # Flip to face downward
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.08, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ceiling.material_override = mat
	$NavigationRegion3D.add_child(ceiling)

# =============================================================================
# Town Zone
# =============================================================================

func _decorate_town_biomes() -> void:
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
		# NW Outskirt — wild trees and ferns
		{
			"center": Vector2(-25, -25), "radius": 10.0, "noise_threshold": -0.1,
			"recipes": [
				{"type": "tree", "count": 5, "min_spacing": 3.0, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": bush_files, "colors": [green, dark_green], "scale": 0.25},
				{"type": "foliage", "count": 2, "min_spacing": 2.0, "files": fern_files, "colors": [dark_green], "scale": 0.25},
			]
		},
		# NE Outskirt — wild trees and ferns
		{
			"center": Vector2(22, -25), "radius": 10.0, "noise_threshold": -0.1,
			"recipes": [
				{"type": "tree", "count": 4, "min_spacing": 3.0, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 2, "min_spacing": 2.0, "files": bush_files, "colors": [green, dark_green], "scale": 0.25},
				{"type": "foliage", "count": 2, "min_spacing": 2.0, "files": fern_files, "colors": [dark_green], "scale": 0.25},
			]
		},
		# West Park — organized trees and flowers
		{
			"bounds": [-30, 5, 15, 20], "noise_threshold": 0.3,
			"recipes": [
				{"type": "tree", "count": 5, "min_spacing": 3.5, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 4, "min_spacing": 2.0, "files": flower_files, "colors": [flower_pink, flower_yellow, flower_white], "scale": 0.25},
				{"type": "foliage", "count": 6, "min_spacing": 2.0, "files": leafy_bush_files + ["SM_FlowerBush01.FBX", "SM_FlowerBush02.FBX"], "colors": [green, flower_pink], "scale": 0.25},
			]
		},
		# East Garden — flowers and some trees
		{
			"bounds": [18, -8, 12, 20], "noise_threshold": 0.2,
			"recipes": [
				{"type": "tree", "count": 4, "min_spacing": 3.5, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 5, "min_spacing": 2.0, "files": flower_files, "colors": [flower_pink, flower_yellow, flower_white], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": leafy_bush_files, "colors": [green, dark_green], "scale": 0.25},
			]
		},
		# SW Outskirt
		{
			"center": Vector2(-20, 28), "radius": 8.0, "noise_threshold": -0.1,
			"recipes": [
				{"type": "tree", "count": 4, "min_spacing": 3.0, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 2, "min_spacing": 2.0, "files": bush_files, "colors": [green, dark_green], "scale": 0.25},
				{"type": "foliage", "count": 2, "min_spacing": 2.0, "files": fern_files, "colors": [dark_green], "scale": 0.25},
			]
		},
		# SE Outskirt
		{
			"center": Vector2(20, 28), "radius": 8.0, "noise_threshold": -0.1,
			"recipes": [
				{"type": "tree", "count": 3, "min_spacing": 3.0, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 2, "min_spacing": 2.0, "files": bush_files, "colors": [green, dark_green], "scale": 0.25},
				{"type": "foliage", "count": 1, "min_spacing": 2.0, "files": fern_files, "colors": [dark_green], "scale": 0.25},
			]
		},
	]

	var total := 0
	for biome in biomes:
		total += _scatter_biome(biome, rng)
	print("[Town] Biome scatter placed %d objects" % total)

func _place_town_props() -> void:
	var green := Color(0.2, 0.45, 0.15)
	var dark_green := Color(0.15, 0.35, 0.1)
	var flower_pink := Color(0.85, 0.4, 0.55)
	var flower_yellow := Color(0.9, 0.85, 0.3)
	var flower_white := Color(0.9, 0.9, 0.85)

	# Shop props — barrels and crates outside weapon shop
	_spawn_dungeon_model("barrel_large.gltf.glb", Vector3(-5.5, 0, -3))
	_spawn_dungeon_model("crates_stacked.gltf.glb", Vector3(-10.5, 0, -3.5), 0.3)

	# Barrel outside item shop
	_spawn_dungeon_model("barrel_small.gltf.glb", Vector3(10, 0, -4))

	# Barrels/crates near path to field
	_spawn_dungeon_model("barrel_large.gltf.glb", Vector3(25, 0, 3))
	_spawn_dungeon_model("crates_stacked.gltf.glb", Vector3(27, 0, 4), 0.5)
	_spawn_dungeon_model("barrel_small.gltf.glb", Vector3(26, 0, 6))

	# Leafy bushes flanking shop entrances
	_spawn_foliage("SM_BushLeafy01.FBX", Vector3(-5.5, 0, -5), green, 0.0)
	_spawn_foliage("SM_BushLeafy02.FBX", Vector3(5.5, 0, -6), green, 1.0)

	# Torches at shop fronts
	_spawn_dungeon_model("torch_lit.gltf.glb", Vector3(-6.5, 0, -3))
	_spawn_dungeon_model("torch_lit.gltf.glb", Vector3(-9.5, 0, -3))
	_spawn_dungeon_model("torch_lit.gltf.glb", Vector3(6.5, 0, -4))
	_spawn_dungeon_model("torch_lit.gltf.glb", Vector3(9.5, 0, -4))

	# Bushes along fence line (x=30 border)
	_spawn_foliage("SM_BushChina01.FBX", Vector3(29, 0, -15), dark_green, 0.0)
	_spawn_foliage("SM_BushChina02.FBX", Vector3(29, 0, -3), dark_green, 1.2)
	_spawn_foliage("SM_BushChina03.FBX", Vector3(29, 0, 12), dark_green, 2.0)

	# Torches at field entrance gateposts (x≈30)
	_spawn_dungeon_model("torch_lit.gltf.glb", Vector3(30, 0, 4))
	_spawn_dungeon_model("torch_lit.gltf.glb", Vector3(30, 0, 8))

	# Flowers near well
	_spawn_foliage("SM_Flower_Daisies1.FBX", Vector3(4.5, 0, -1), flower_white, 0.0)
	_spawn_foliage("SM_FlowerBush01.FBX", Vector3(2, 0, -2.5), flower_pink, 0.5)

	# Flowers at shop fronts
	_spawn_foliage("SM_Flower_TulipsRed.FBX", Vector3(-6, 0, -3), flower_pink, 0.0)
	_spawn_foliage("SM_Flower_TulipsYellow.FBX", Vector3(6, 0, -4), flower_yellow, 0.0)

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
			"bounds": [38, 22, 22, 20], "noise_threshold": -0.1,
			"recipes": [
				{"type": "tree", "count": 14, "min_spacing": 2.5, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 8, "min_spacing": 1.5, "files": fern_files, "colors": [fern_color], "scale": 0.25},
				{"type": "foliage", "count": 4, "min_spacing": 2.0, "files": bush_files, "colors": [green, dark_green], "scale": 0.25},
			]
		},
		# Open Meadow — center-south, wildflowers and grass only
		{
			"center": Vector2(68, -15), "radius": 18.0, "noise_threshold": -0.2,
			"recipes": [
				{"type": "foliage", "count": 15, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 8, "min_spacing": 2.5, "files": flower_files, "colors": [flower_yellow, flower_orange, flower_pink, flower_white], "scale": 0.25},
			]
		},
		# Rocky Clearing — east field, rocks and stumps
		{
			"bounds": [82, -32, 30, 22], "noise_threshold": -0.2,
			"recipes": [
				{"type": "rock_cluster", "count": 8, "min_spacing": 4.0, "files": [], "colors": []},
				{"type": "stump", "count": 3, "min_spacing": 3.0, "files": ["SM_FirStump1.FBX"], "colors": [], "scale": 0.25},
				{"type": "fallen", "count": 2, "min_spacing": 4.0, "files": ["SM_FirFallen1.FBX", "SM_FirFallen2.FBX"], "colors": [], "scale": 0.25},
				{"type": "foliage", "count": 4, "min_spacing": 1.5, "files": fern_files, "colors": [fern_color], "scale": 0.25},
			]
		},
		# Transitional NE — sparse mix
		{
			"bounds": [75, 22, 30, 20], "noise_threshold": 0.0,
			"recipes": [
				{"type": "tree", "count": 6, "min_spacing": 3.0, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 1.5, "files": fern_files, "colors": [fern_color], "scale": 0.25},
			]
		},
		# Transitional SW — sparse mix near entrance
		{
			"bounds": [38, -10, 17, 20], "noise_threshold": 0.0,
			"recipes": [
				{"type": "tree", "count": 5, "min_spacing": 3.0, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 2, "min_spacing": 2.0, "files": bush_files, "colors": [green, dark_green], "scale": 0.25},
				{"type": "stump", "count": 1, "min_spacing": 3.0, "files": ["SM_FirStump1.FBX"], "colors": [], "scale": 0.25},
			]
		},
		# Path-edge scatter — sparse along main path
		{
			"bounds": [38, 0, 77, 10], "noise_threshold": 0.2,
			"recipes": [
				{"type": "tree", "count": 2, "min_spacing": 4.0, "files": sapling_files, "colors": [leaf_green], "scale": 0.25},
				{"type": "foliage", "count": 5, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": fern_files, "colors": [fern_color], "scale": 0.25},
			]
		},
		# Dungeon approach — eerie, stumps and rocks
		{
			"bounds": [100, -10, 15, 20], "noise_threshold": -0.1,
			"recipes": [
				{"type": "stump", "count": 3, "min_spacing": 3.0, "files": ["SM_FirStump1.FBX"], "colors": [], "scale": 0.25},
				{"type": "foliage", "count": 5, "min_spacing": 1.5, "files": fern_files, "colors": [fern_color], "scale": 0.25},
				{"type": "rock_cluster", "count": 2, "min_spacing": 4.0, "files": [], "colors": []},
			]
		},
	]

	var total := 0
	for biome in biomes:
		total += _scatter_biome(biome, rng)
	print("[Field] Biome scatter placed %d objects" % total)

	# Manual: torches flanking dungeon entrance
	_spawn_dungeon_model("torch_lit.gltf.glb", Vector3(116, 0, 2))
	_spawn_dungeon_model("torch_lit.gltf.glb", Vector3(116, 0, 8))

