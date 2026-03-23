## Central Plaza district builder (x:-15..20, z:-10..10).
class_name DistrictPlaza

const BuildingHelper = preload("res://scripts/world/building_helper.gd")
const CraftingStation = preload("res://scenes/objects/crafting_station.gd")
const AmbientEmitterScript = preload("res://scripts/audio/ambient_emitter.gd")


static func build(ctx: WorldBuilderContext) -> void:
	var nav_region: Node = ctx.nav_region
	var noise: FastNoiseLite = ctx.terrain_noise
	var hs: float = ctx.terrain_height_scale_city
	_build_fountain(ctx, nav_region, noise, hs)
	_build_crafting_stations(ctx, nav_region, noise, hs)
	_build_benches(ctx, nav_region, noise, hs)
	_build_street_lamps(ctx, nav_region, noise, hs)
	_build_town_hall(ctx, nav_region, noise, hs)
	_build_chapel(ctx, nav_region, noise, hs)
	_build_money_changer(ctx, nav_region, noise, hs)
	_build_notice_board_shelter(ctx, nav_region, noise, hs)
	_build_stalls(ctx, nav_region, noise, hs)
	_build_plaza_inn(ctx, nav_region, noise, hs)


static func _build_fountain(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var pos := Vector3(0, BuildingHelper.snap_y(noise, 0, 0, hs), 0)
	BuildingHelper.create_fountain(ctx, nav_region, pos, 1.5, 0.4, 1.2, 0.8)

	var fountain_emitter: Node3D = AmbientEmitterScript.new()
	nav_region.add_child(fountain_emitter)
	fountain_emitter.global_position = pos
	fountain_emitter.setup("res://assets/audio/ambient/fountain_loop.ogg", ["dawn", "day", "dusk", "night"], -6.0, 25.0)


static func _build_crafting_stations(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	# Smithing station — triangle around fountain, east side.
	var forge_y: float = BuildingHelper.snap_y(noise, 4, 3, hs)
	var smithing: StaticBody3D = StaticBody3D.new()
	smithing.set_script(CraftingStation)
	smithing.position = Vector3(4, forge_y, 3)
	nav_region.add_child(smithing)
	smithing.setup("smithing", "Forge")

	var forge_emitter: Node3D = AmbientEmitterScript.new()
	nav_region.add_child(forge_emitter)
	forge_emitter.global_position = Vector3(4, forge_y, 3)
	forge_emitter.setup("res://assets/audio/ambient/forge_hammer_loop.ogg", ["day", "dusk"], -3.0, 20.0)

	# Cooking station — west side.
	var cooking_y: float = BuildingHelper.snap_y(noise, -4, 3, hs)
	var cooking: StaticBody3D = StaticBody3D.new()
	cooking.set_script(CraftingStation)
	cooking.position = Vector3(-4, cooking_y, 3)
	nav_region.add_child(cooking)
	cooking.setup("cooking", "Cooking Fire")

	# Crafting station — north side.
	var workbench_y: float = BuildingHelper.snap_y(noise, 0, -4, hs)
	var crafting_st: StaticBody3D = StaticBody3D.new()
	crafting_st.set_script(CraftingStation)
	crafting_st.position = Vector3(0, workbench_y, -4)
	nav_region.add_child(crafting_st)
	crafting_st.setup("crafting", "Workbench")


static func _build_benches(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var bench_positions: Array = [Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3)]
	for bpos: Vector3 in bench_positions:
		var rot_y: float = PI * 0.5 if bpos.x == 0 else 0.0
		var world_pos := Vector3(bpos.x, BuildingHelper.snap_y(noise, bpos.x, bpos.z, hs) + 0.2, bpos.z)
		BuildingHelper.create_bench(ctx, nav_region, world_pos, rot_y)


static func _build_street_lamps(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var lamp_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.25, 0.25, 0.25))
	var lamp_glow_mat: StandardMaterial3D = AssetSpawner.get_or_create_emissive_mat(ctx,
		Color(1.0, 0.9, 0.6), Color(1.0, 0.85, 0.5), 0.5)

	var lamp_positions: Array = [Vector3(8, 0, 8), Vector3(-8, 0, 8), Vector3(8, 0, -8), Vector3(-8, 0, -8)]
	for lpos: Vector3 in lamp_positions:
		var lamp_post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.08
		post_mesh.bottom_radius = 0.1
		post_mesh.height = 3.0
		lamp_post.mesh = post_mesh
		lamp_post.position = Vector3(lpos.x, BuildingHelper.snap_y(noise, lpos.x, lpos.z, hs) + 1.5, lpos.z)
		lamp_post.set_surface_override_material(0, lamp_mat)
		lamp_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(lamp_post)

		var lamp_light := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		lamp_light.mesh = sphere
		lamp_light.position = Vector3(lpos.x, BuildingHelper.snap_y(noise, lpos.x, lpos.z, hs) + 3.1, lpos.z)
		lamp_light.set_surface_override_material(0, lamp_glow_mat)
		lamp_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(lamp_light)


static func _build_town_hall(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(-12, BuildingHelper.snap_y(noise, -12, -7, hs), -7),
		Vector3(7, 4, 5), Color(0.55, 0.50, 0.45), "peaked", Color(0.35, 0.28, 0.22),
		0.5, false, true, 0.0, "town_hall")
	# 2 torches flanking entrance (+z face)
	_create_torch(ctx, nav_region, noise, hs, Vector3(-14, 0, -4))
	_create_torch(ctx, nav_region, noise, hs, Vector3(-10, 0, -4))


static func _build_chapel(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(15, BuildingHelper.snap_y(noise, 15, 7, hs), 7),
		Vector3(4, 3.5, 3.5), Color(0.60, 0.58, 0.55), "peaked", Color(0.35, 0.30, 0.25),
		0.5, false, true, 0.0, "chapel")
	# 1 torch at entrance (+z face)
	_create_torch(ctx, nav_region, noise, hs, Vector3(15, 0, 9))


static func _build_money_changer(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(-12, BuildingHelper.snap_y(noise, -12, 7, hs), 7),
		Vector3(3.5, 3, 3), Color(0.55, 0.48, 0.38), "peaked", Color(0.38, 0.25, 0.15),
		0.5, false, true, 0.0, "shop")


static func _build_notice_board_shelter(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(15, BuildingHelper.snap_y(noise, 15, -5, hs), -5),
		Vector3(2.5, 2.5, 2), Color(0.48, 0.42, 0.35), "flat", Color(0.35, 0.30, 0.25),
		0.5, false, false, 0.0, "shelter")


static func _build_stalls(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	# Flower Cart
	_create_stall(ctx, nav_region, noise, hs, Vector3(8, 0, -8), Color(0.75, 0.45, 0.60), "stall")
	# Water Cart
	_create_stall(ctx, nav_region, noise, hs, Vector3(-8, 0, 8), Color(0.25, 0.45, 0.70), "stall")


static func _create_stall(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float,
		spos: Vector3, canopy_color: Color, building_type: String) -> void:
	var stall := Node3D.new()
	stall.position = Vector3(spos.x, BuildingHelper.snap_y(noise, spos.x, spos.z, hs), spos.z)
	if building_type != "":
		stall.set_meta("building_type", building_type)

	var post_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.45, 0.35, 0.22))

	# 4 corner posts
	for px: float in [-1.2, 1.2]:
		for pz: float in [-0.8, 0.8]:
			var post := MeshInstance3D.new()
			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.06
			post_mesh.bottom_radius = 0.08
			post_mesh.height = 2.5
			post.mesh = post_mesh
			post.position = Vector3(px, 1.25, pz)
			post.set_surface_override_material(0, post_mat)
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stall.add_child(post)

	# Canopy
	var canopy := MeshInstance3D.new()
	var canopy_mesh := BoxMesh.new()
	canopy_mesh.size = Vector3(3.0, 0.1, 2.0)
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0, 2.55, 0)
	var canopy_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, canopy_color)
	canopy.set_surface_override_material(0, canopy_mat)
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stall.add_child(canopy)

	# Counter
	var counter := MeshInstance3D.new()
	var counter_mesh := BoxMesh.new()
	counter_mesh.size = Vector3(2.4, 0.8, 0.4)
	counter.mesh = counter_mesh
	counter.position = Vector3(0, 0.4, 0.6)
	counter.set_surface_override_material(0, post_mat)
	counter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stall.add_child(counter)

	nav_region.add_child(stall)


static func _build_plaza_inn(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(15, BuildingHelper.snap_y(noise, 15, -9, hs), -9),
		Vector3(4.5, 3, 4), Color(0.52, 0.44, 0.35), "peaked", Color(0.38, 0.25, 0.16),
		0.5, false, true, 0.0, "inn")


static func _create_torch(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float, tpos: Vector3) -> void:
	var wood_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.40, 0.30, 0.18))
	var flame_mat: StandardMaterial3D = AssetSpawner.get_or_create_emissive_mat(ctx,
		Color(1.0, 0.6, 0.1), Color(1.0, 0.5, 0.05), 0.8)

	var ground_y: float = BuildingHelper.snap_y(noise, tpos.x, tpos.z, hs)

	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.04
	post_mesh.bottom_radius = 0.05
	post_mesh.height = 1.2
	post.mesh = post_mesh
	post.position = Vector3(tpos.x, ground_y + 0.6, tpos.z)
	post.set_surface_override_material(0, wood_mat)
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nav_region.add_child(post)

	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.08
	flame_mesh.height = 0.16
	flame.mesh = flame_mesh
	flame.position = Vector3(tpos.x, ground_y + 1.3, tpos.z)
	flame.set_surface_override_material(0, flame_mat)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nav_region.add_child(flame)
