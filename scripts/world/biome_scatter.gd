class_name BiomeScatter
## Static utility class for exclusion zones and biome scatter algorithm.
## Manages path/building exclusion and density-modulated scatter placement.

const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")

static func setup_exclusion_zones(ctx: WorldBuilderContext) -> void:
	# City roads
	ctx.path_lines = [
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

	ctx.building_zones = [
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
		# House 6
		{"center": Vector2(-62, -20), "radius": 3.5},
		# House 7
		{"center": Vector2(-38, -40), "radius": 3.5},
		# Well
		{"center": Vector2(-42, -35), "radius": 2.0},
		# Bakery
		{"center": Vector2(-30, 30), "radius": 3.5},
		# Storage Shed
		{"center": Vector2(-65, 15), "radius": 3.0},
		# Market Stall 5
		{"center": Vector2(-48, 42), "radius": 3.0},
		# Library
		{"center": Vector2(0, -20), "radius": 4.5},
		# Chapel Annex
		{"center": Vector2(18, -40), "radius": 3.0},
		# Stables
		{"center": Vector2(-15, 20), "radius": 4.5},
		# Storage Hut
		{"center": Vector2(20, 38), "radius": 2.5},
		# Guard Tower
		{"center": Vector2(30, 40), "radius": 3.0},
		# Armory
		{"center": Vector2(55, 25), "radius": 4.0},
		# Gazebo
		{"center": Vector2(35, -20), "radius": 3.5},
		# Gatehouse Storage
		{"center": Vector2(60, -7), "radius": 2.5},
		# Cluster A: Commerce Row
		{"center": Vector2(-36, 5), "radius": 3.5},
		{"center": Vector2(-30, 5), "radius": 3.0},
		{"center": Vector2(-24, 5), "radius": 3.0},
		# Cluster B: Artisan Quarter
		{"center": Vector2(-47, -14), "radius": 3.0},
		{"center": Vector2(-41, -14), "radius": 3.0},
		{"center": Vector2(-36, -14), "radius": 2.5},
		# Cluster C: Civic District
		{"center": Vector2(6, -26), "radius": 3.5},
		{"center": Vector2(18, -35), "radius": 3.0},
		# Cluster D: Craft Row
		{"center": Vector2(-4, 26), "radius": 3.5},
		{"center": Vector2(-4, 33), "radius": 3.0},
		{"center": Vector2(-4, 38), "radius": 2.5},
		# Cluster E: Military Compound
		{"center": Vector2(38, 30), "radius": 3.5},
		{"center": Vector2(52, 32), "radius": 3.0},
		# Cluster F: Gate District
		{"center": Vector2(49, -4), "radius": 3.0},
		{"center": Vector2(55, -4), "radius": 3.0},
		# Cluster P: Park Area
		{"center": Vector2(40, -38), "radius": 3.0},
		# Central Plaza buildings
		{"center": Vector2(-12, -7), "radius": 5.8},
		{"center": Vector2(15, 7), "radius": 4.2},
		{"center": Vector2(-12, 7), "radius": 3.8},
		{"center": Vector2(15, -5), "radius": 3.1},
		# Market district buildings
		{"center": Vector2(-50, 20), "radius": 4.2},
		{"center": Vector2(-38, 25), "radius": 4.3},
		{"center": Vector2(-62, 25), "radius": 4.2},
		{"center": Vector2(-28, 20), "radius": 3.8},
		{"center": Vector2(-50, 40), "radius": 5.4},
		{"center": Vector2(-35, 45), "radius": 3.8},
		{"center": Vector2(-28, 45), "radius": 3.8},
		{"center": Vector2(-65, 35), "radius": 4.3},
		{"center": Vector2(-24, 15), "radius": 3.8},
		{"center": Vector2(-65, 45), "radius": 3.8},
		# Residential district buildings
		{"center": Vector2(-28, -30), "radius": 4.3},
		{"center": Vector2(-58, -42), "radius": 4.2},
		{"center": Vector2(-32, -35), "radius": 4.0},
		{"center": Vector2(-40, -28), "radius": 4.3},
		{"center": Vector2(-55, -30), "radius": 4.2},
		{"center": Vector2(-28, -45), "radius": 3.6},
		{"center": Vector2(-65, -42), "radius": 3.8},
		{"center": Vector2(-48, -35), "radius": 4.2},
		# Noble district buildings
		{"center": Vector2(-15, -25), "radius": 5.0},
		{"center": Vector2(-15, -35), "radius": 4.9},
		{"center": Vector2(20, -20), "radius": 4.5},
		{"center": Vector2(-5, -43), "radius": 3.6},
		{"center": Vector2(10, -18), "radius": 3.8},
		{"center": Vector2(22, -45), "radius": 3.6},
		# Park district buildings
		{"center": Vector2(30, -15), "radius": 4.2},
		{"center": Vector2(55, -25), "radius": 4.7},
		{"center": Vector2(60, -40), "radius": 4.3},
		{"center": Vector2(50, -40), "radius": 3.6},
		{"center": Vector2(30, -42), "radius": 3.6},
		# Craft district buildings
		{"center": Vector2(15, 20), "radius": 4.7},
		{"center": Vector2(8, 38), "radius": 4.0},
		{"center": Vector2(5, 18), "radius": 4.2},
		{"center": Vector2(-10, 42), "radius": 3.6},
		{"center": Vector2(-15, 40), "radius": 4.2},
		{"center": Vector2(20, 30), "radius": 3.6},
		# Garrison district buildings
		{"center": Vector2(35, 35), "radius": 4.3},
		{"center": Vector2(60, 35), "radius": 4.3},
		{"center": Vector2(60, 42), "radius": 4.7},
		{"center": Vector2(42, 42), "radius": 4.2},
		{"center": Vector2(65, 42), "radius": 3.3},
		# Gate district buildings
		{"center": Vector2(56, 4), "radius": 4.2},
		{"center": Vector2(49, 4), "radius": 4.3},
		{"center": Vector2(62, 4), "radius": 3.1},
		{"center": Vector2(-3, -47), "radius": 2.9},
		{"center": Vector2(3, -47), "radius": 2.9},
		{"center": Vector2(-8, -46), "radius": 3.8},
		{"center": Vector2(8, -46), "radius": 3.6},
		{"center": Vector2(-3, 47), "radius": 2.9},
		{"center": Vector2(3, 47), "radius": 2.9},
		{"center": Vector2(-8, 46), "radius": 3.8},
		{"center": Vector2(8, 46), "radius": 3.6},
	]

	# Decoration density noise
	ctx.deco_noise = FastNoiseLite.new()
	ctx.deco_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ctx.deco_noise.seed = 137
	ctx.deco_noise.frequency = 0.08

static func point_to_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var t := clampf(ap.dot(ab) / ab.dot(ab), 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func is_position_blocked(ctx: WorldBuilderContext, pos: Vector2) -> bool:
	for line in ctx.path_lines:
		if point_to_segment_dist(pos, line["start"], line["end"]) < line["buffer"]:
			return true
	for zone in ctx.building_zones:
		if pos.distance_to(zone["center"]) < zone["radius"]:
			return true
	return false

static func _generate_candidate(biome: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	if biome.has("center") and biome.has("radius"):
		# Circle shape
		var angle := rng.randf() * TAU
		var dist: float = sqrt(rng.randf()) * float(biome["radius"])
		return Vector2(
			biome["center"].x + cos(angle) * dist,
			biome["center"].y + sin(angle) * dist
		)
	else:
		# Rect shape: [x, z, width, height]
		var bounds: Array = biome["bounds"]
		return Vector2(
			bounds[0] + rng.randf() * bounds[2],
			bounds[1] + rng.randf() * bounds[3]
		)

static func _passes_noise(ctx: WorldBuilderContext, x: float, z: float, threshold: float) -> bool:
	return ctx.deco_noise.get_noise_2d(x, z) >= threshold

static func _passes_spacing(ctx: WorldBuilderContext, pos: Vector2, min_spacing: float) -> bool:
	for existing in ctx.spawned_positions:
		if pos.distance_to(existing) < min_spacing:
			return false
	return true

static func _spawn_recipe(ctx: WorldBuilderContext, recipe: Dictionary, x: float, z: float, rng: RandomNumberGenerator) -> void:
	var rot_y := rng.randf() * TAU
	var scale_val: float = recipe.get("scale", 0.25)
	var type: String = recipe["type"]
	var files: Array = recipe.get("files", [])
	var colors: Array = recipe.get("colors", [])
	var file: String = files[rng.randi() % files.size()] if files.size() > 0 else ""
	var color: Color = colors[rng.randi() % colors.size()] if colors.size() > 0 else Color.WHITE

	match type:
		"tree":
			AssetSpawner.spawn_tree(ctx, file, Vector3(x, 0, z), rot_y, scale_val, color)
		"foliage":
			AssetSpawner.spawn_foliage(ctx, file, Vector3(x, 0, z), color, rot_y, scale_val)
		"rock_cluster":
			create_rock_cluster(ctx, Vector3(x, 0, z))
		"stump", "fallen":
			var inst := AssetSpawner.spawn_model(ctx, AssetSpawner.TREE_DIR + file, Vector3(x, 0, z), rot_y, scale_val)
			if inst:
				var muted_leaf := Color(0.15, 0.35, 0.1)
				AssetSpawner.apply_tree_materials(ctx, inst, muted_leaf, true)

static func scatter_biome(ctx: WorldBuilderContext, biome: Dictionary, rng: RandomNumberGenerator) -> int:
	var total_placed := 0
	var recipes: Array = biome["recipes"]
	var noise_threshold: float = biome.get("noise_threshold", -0.1)

	for recipe in recipes:
		var count: int = recipe["count"]
		var min_spacing: float = recipe.get("min_spacing", 2.0)
		var placed := 0
		var max_attempts := count * 15

		for attempt in max_attempts:
			if placed >= count:
				break
			var candidate := _generate_candidate(biome, rng)
			if not _passes_noise(ctx, candidate.x, candidate.y, noise_threshold):
				continue
			if is_position_blocked(ctx, candidate):
				continue
			if not _passes_spacing(ctx, candidate, min_spacing):
				continue
			_spawn_recipe(ctx, recipe, candidate.x, candidate.y, rng)
			ctx.spawned_positions.append(candidate)
			placed += 1

		total_placed += placed
	return total_placed

static func create_rock_cluster(ctx: WorldBuilderContext, center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x * 100 + center.z * 10)
	var rock_mat := AssetSpawner.get_or_create_color_mat(ctx, Color(0.4, 0.38, 0.36))
	for i in 2:
		var offset := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
		var radius := rng.randf_range(0.3, 0.7)
		var pos := center + offset
		var terrain_y: float = TerrainGenerator.get_height_at(ctx.terrain_noise, pos.x, pos.z, ctx.terrain_height_scale_field)
		pos.y = terrain_y + radius * 0.3

		var rock := StaticBody3D.new()
		rock.position = pos
		ctx.nav_region.add_child(rock)

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
