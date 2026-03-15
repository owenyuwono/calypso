class_name TownBuilder
## Static utility class for city zone decoration: walls, biomes, and props.

static func build_walls(ctx: WorldBuilderContext) -> void:
	var wall_color := Color(0.45, 0.42, 0.38)
	var wall_mat := AssetSpawner.get_or_create_color_mat(ctx, wall_color)
	var wall_height := 4.0
	var wall_thickness := 1.0

	# North wall: z=-50, x from -70 to 70
	_place_wall_segment(ctx, Vector3(-70, 0, -50), Vector3(70, 0, -50), wall_height, wall_thickness, wall_mat)
	# South wall: z=50
	_place_wall_segment(ctx, Vector3(-70, 0, 50), Vector3(70, 0, 50), wall_height, wall_thickness, wall_mat)
	# West wall: x=-70
	_place_wall_segment(ctx, Vector3(-70, 0, -50), Vector3(-70, 0, 50), wall_height, wall_thickness, wall_mat)
	# East wall with gate gap: x=70, z:-50..-5 and z:5..50
	_place_wall_segment(ctx, Vector3(70, 0, -50), Vector3(70, 0, -5), wall_height, wall_thickness, wall_mat)
	_place_wall_segment(ctx, Vector3(70, 0, 5), Vector3(70, 0, 50), wall_height, wall_thickness, wall_mat)

	# Corner towers
	for corner in [Vector3(-70, 0, -50), Vector3(70, 0, -50), Vector3(70, 0, 50), Vector3(-70, 0, 50)]:
		_build_tower(ctx, corner, 5.5, 3.0, wall_mat)

	# Gate towers — placed outside the gap so they don't block passage
	_build_tower(ctx, Vector3(70, 0, -7), 6.0, 3.0, wall_mat)
	_build_tower(ctx, Vector3(70, 0, 7), 6.0, 3.0, wall_mat)

	# Gatehouse archway — visual only (no collision), placed above walking height
	var arch := MeshInstance3D.new()
	var arch_mesh := BoxMesh.new()
	arch_mesh.size = Vector3(wall_thickness, 1.5, 10.0)
	arch.mesh = arch_mesh
	arch.position = Vector3(70, wall_height + 0.75, 0)
	arch.set_surface_override_material(0, wall_mat)
	ctx.world_root.add_child(arch)  # Add to scene root, not nav region

	# Gate torches
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(69, 0, -4))
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(69, 0, 4))
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(71, 0, -4))
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(71, 0, 4))

static func _place_wall_segment(ctx: WorldBuilderContext, start: Vector3, end: Vector3, height: float, thickness: float, mat: Material) -> void:
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

	ctx.nav_region.add_child(wall)

static func _build_tower(ctx: WorldBuilderContext, pos: Vector3, height: float, width: float, mat: Material) -> void:
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

	ctx.nav_region.add_child(tower)

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
		ctx.nav_region.add_child(cren)

static func decorate_biomes(ctx: WorldBuilderContext) -> void:
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
		total += BiomeScatter.scatter_biome(ctx, biome, rng)
	print("[City] Biome scatter placed %d objects" % total)

static func place_props(ctx: WorldBuilderContext) -> void:
	# Market district props
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(-42, 0, 22))
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(-48, 0, 18), 0.3)
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_small.gltf.glb", Vector3(-53, 0, 28))
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(-58, 0, 32))

	# Torches at shops
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(-43, 0, 18))
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(-47, 0, 18))
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(-53, 0, 28))
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(-57, 0, 28))

	# Temple/Noble quarter
	AssetSpawner.spawn_dungeon_model(ctx, "pillar_decorated.gltf.glb", Vector3(-2, 0, -33))
	AssetSpawner.spawn_dungeon_model(ctx, "pillar_decorated.gltf.glb", Vector3(2, 0, -33))
	AssetSpawner.spawn_dungeon_model(ctx, "banner_red.gltf.glb", Vector3(15, 0, -23))

	# Craft district
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(-2, 0, 28))
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(3, 0, 32), 0.5)

	# Garrison
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(38, 0, 28))
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(52, 0, 28))
	AssetSpawner.spawn_dungeon_model(ctx, "banner_red.gltf.glb", Vector3(45, 0, 33))

	# Central plaza — flowers near well/fountain
	var flower_pink := Color(0.85, 0.4, 0.55)
	var flower_yellow := Color(0.9, 0.85, 0.3)
	AssetSpawner.spawn_foliage(ctx, "SM_Flower_Daisies1.FBX", Vector3(3, 0, 2), Color(0.9, 0.9, 0.85))
	AssetSpawner.spawn_foliage(ctx, "SM_FlowerBush01.FBX", Vector3(-3, 0, -2), flower_pink)
	AssetSpawner.spawn_foliage(ctx, "SM_Flower_TulipsYellow.FBX", Vector3(2, 0, -3), flower_yellow)

	# House 6 — torch near door
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(-60, 0, -18))

	# House 7 — barrel near wall
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(-36, 0, -38))

	# Bakery — barrel + crate near entrance
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(-28, 0, 32))
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(-32, 0, 32), 0.3)

	# Storage Shed — 2 crates nearby
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(-63, 0, 17), 0.3)
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(-67, 0, 17), 0.3)

	# Library — torch at entrance
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(2, 0, -18))

	# Chapel Annex — torch at entrance
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(20, 0, -38))

	# Stables — barrel + crate
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(-13, 0, 22))
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(-17, 0, 22), 0.3)

	# Guard Tower — 2 torches flanking entrance
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(28, 0, 42))
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(32, 0, 42))

	# Armory — barrel + crate + torch
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(53, 0, 27))
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(57, 0, 27), 0.3)
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(55, 0, 23))

	# Gazebo — torch near path
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(37, 0, -18))

	# Gatehouse Storage — crate nearby
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(62, 0, -5), 0.3)

	# A1 Merchant Office — torch at door
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(-36, 0, 7))

	# A2 Tax Office — barrel near wall
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(-30, 0, 7))

	# A3 Courier Post — crate near door
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(-24, 0, 7), 0.3)

	# B1 Boarding House — torch at entrance
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(-47, 0, -16))

	# B2 Tailor Shop — barrel
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(-41, 0, -16))

	# B3 Cobbler — crate
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(-36, 0, -16), 0.3)

	# C1 Scriptorium — torch + barrel
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(6, 0, -24))
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(8, 0, -24))

	# C2 Records Hall — torch at entrance
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(18, 0, -33))

	# D1 Tannery — barrel + crate
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(-2, 0, 26))
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(-2, 0, 28), 0.3)

	# D2 Potter Shop — crate
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(-2, 0, 33), 0.3)

	# D3 Weaver Hut — barrel
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(-2, 0, 38))

	# E1 Quartermaster — barrel + crate + torch
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(38, 0, 26))
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(40, 0, 28), 0.3)
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(36, 0, 28))

	# E2 Mess Hall — 2 barrels
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(50, 0, 30))
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(54, 0, 30))

	# F1 Waystation — torch
	AssetSpawner.spawn_dungeon_model(ctx, "torch_lit.gltf.glb", Vector3(49, 0, -2))

	# F2 Gatehouse Office — crate
	AssetSpawner.spawn_dungeon_model(ctx, "crates_stacked.gltf.glb", Vector3(55, 0, -2), 0.3)

	# P1 Gardener Cottage — barrel
	AssetSpawner.spawn_dungeon_model(ctx, "barrel_large.gltf.glb", Vector3(40, 0, -36))
