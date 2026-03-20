## Craft/Workshop district builder (x:-20..25, z:10..50).
class_name DistrictCraft

const BuildingHelper = preload("res://scripts/world/building_helper.gd")
const AmbientEmitterScript = preload("res://scripts/audio/ambient_emitter.gd")


static func build(ctx: WorldBuilderContext) -> void:
	var nav_region: Node = ctx.nav_region
	var noise: FastNoiseLite = ctx.terrain_noise
	var hs: float = ctx.terrain_height_scale_city
	_build_forge(ctx, nav_region, noise, hs)
	_build_workshop_1(ctx, nav_region, noise, hs)
	_build_workshop_2(ctx, nav_region, noise, hs)
	_build_forge_props(ctx, nav_region, noise, hs)
	_build_stables(ctx, nav_region, noise, hs)
	_build_cluster_d(ctx, nav_region, noise, hs)
	_build_new_buildings(ctx, nav_region, noise, hs)
	_build_new_props(ctx, nav_region, noise, hs)
	_build_ambient_emitters(nav_region, noise, hs)


static func _build_ambient_emitters(nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	# Forge ambience near the main forge building
	var forge_pos: Vector3 = Vector3(8, BuildingHelper.snap_y(noise, 8, 30, hs), 30)
	var forge_emitter: Node3D = AmbientEmitterScript.new()
	nav_region.add_child(forge_emitter)
	forge_emitter.global_position = forge_pos
	forge_emitter.setup("res://assets/audio/ambient/forge_hammer_loop.ogg", ["day"], -6.0, 20.0)


static func _build_forge(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(8, BuildingHelper.snap_y(noise, 8, 30, hs), 30),
		Vector3(6, 3.5, 5), Color(0.4, 0.38, 0.35), "flat", Color(0.3, 0.28, 0.25), 0.3, true, true, PI / 4)


static func _build_workshop_1(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var ws1 := Node3D.new()
	ws1.position = Vector3(-10, BuildingHelper.snap_y(noise, -10, 35, hs), 35)
	ws1.rotation.y = -0.2
	var ws_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.45, 0.35, 0.22))

	# Back wall only
	var back_wall := MeshInstance3D.new()
	var bw_mesh := BoxMesh.new()
	bw_mesh.size = Vector3(4, 2.5, 0.2)
	back_wall.mesh = bw_mesh
	back_wall.position = Vector3(0, 1.25, -1.5)
	back_wall.set_surface_override_material(0, ws_mat)
	back_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ws1.add_child(back_wall)

	# Front posts
	for px: float in [-1.8, 1.8]:
		var post := MeshInstance3D.new()
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 0.08
		p_mesh.bottom_radius = 0.1
		p_mesh.height = 2.5
		post.mesh = p_mesh
		post.position = Vector3(px, 1.25, 1.5)
		post.set_surface_override_material(0, ws_mat)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ws1.add_child(post)

	# Lean-to roof
	var ws_roof := MeshInstance3D.new()
	var wsr_mesh := BoxMesh.new()
	wsr_mesh.size = Vector3(4.5, 0.15, 3.5)
	ws_roof.mesh = wsr_mesh
	ws_roof.position = Vector3(0, 2.6, 0)
	var roof_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.35, 0.28, 0.2))
	ws_roof.set_surface_override_material(0, roof_mat)
	ws_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ws1.add_child(ws_roof)

	nav_region.add_child(ws1)


static func _build_workshop_2(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(12, BuildingHelper.snap_y(noise, 12, 42, hs), 42),
		Vector3(4, 3, 4), Color(0.48, 0.42, 0.35), "peaked", Color(0.35, 0.25, 0.18), 0.4, false, true, PI / 2)


static func _build_forge_props(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	# Anvil outside forge
	var anvil := MeshInstance3D.new()
	var anvil_mesh := BoxMesh.new()
	anvil_mesh.size = Vector3(0.6, 0.5, 0.4)
	anvil.mesh = anvil_mesh
	anvil.position = Vector3(11, BuildingHelper.snap_y(noise, 11, 28, hs) + 0.25, 28)
	var anvil_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.2, 0.2, 0.22))
	anvil.set_surface_override_material(0, anvil_mat)
	anvil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nav_region.add_child(anvil)

	# Lumber pile near workshop
	var lumber_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.5, 0.35, 0.2))
	for i: int in 3:
		var log := MeshInstance3D.new()
		var log_mesh := BoxMesh.new()
		log_mesh.size = Vector3(2.0, 0.3, 0.3)
		log.mesh = log_mesh
		log.position = Vector3(20, BuildingHelper.snap_y(noise, 20, 25, hs) + 0.15 + i * 0.3, 25 + i * 0.15)
		log.rotation.y = 0.1 * i
		log.set_surface_override_material(0, lumber_mat)
		log.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(log)


static func _build_stables(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(-15, BuildingHelper.snap_y(noise, -15, 20, hs), 20),
		Vector3(6, 3, 5), Color(0.5, 0.42, 0.32), "flat", Color(0.38, 0.32, 0.25), 0.3, false, true)

	# Fence posts along stable front
	var fence_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.45, 0.35, 0.22))
	for fx: float in [-13.5, -12.5, -11.5, -10.5]:
		var fpost := MeshInstance3D.new()
		var fp_mesh := CylinderMesh.new()
		fp_mesh.top_radius = 0.05
		fp_mesh.bottom_radius = 0.06
		fp_mesh.height = 1.2
		fpost.mesh = fp_mesh
		fpost.position = Vector3(fx, BuildingHelper.snap_y(noise, fx, 23, hs) + 0.6, 23)
		fpost.set_surface_override_material(0, fence_mat)
		fpost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(fpost)


static func _build_cluster_d(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	# D1 Tannery
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(-4, BuildingHelper.snap_y(noise, -4, 26, hs), 26),
		Vector3(4, 3, 3.5), Color(0.48, 0.40, 0.30), "flat", Color(0.36, 0.30, 0.24), 0.5, true, false)

	# D2 Potter Shop
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(-4, BuildingHelper.snap_y(noise, -4, 33, hs), 33),
		Vector3(3.5, 3, 3), Color(0.50, 0.42, 0.32), "flat", Color(0.38, 0.32, 0.26), 0.5, false, true)

	# D3 Weaver Hut
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(-4, BuildingHelper.snap_y(noise, -4, 38, hs), 38),
		Vector3(3, 3, 3), Color(0.46, 0.38, 0.28), "flat", Color(0.34, 0.28, 0.22), 0.5, false, true)

	# Storage Hut — flat roof, no door
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(20, BuildingHelper.snap_y(noise, 20, 38, hs), 38),
		Vector3(3, 2.5, 3), Color(0.45, 0.38, 0.3), "flat", Color(0.35, 0.3, 0.25), 0.3, false, false)


static func _build_new_buildings(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	# Lumberyard
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(15, BuildingHelper.snap_y(noise, 15, 20, hs), 20),
		Vector3(5, 3, 4), Color(0.50, 0.42, 0.30), "flat", Color(0.38, 0.32, 0.24), 0.3, false, true, 0.0, "workshop")

	# Kiln House
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(8, BuildingHelper.snap_y(noise, 8, 38, hs), 38),
		Vector3(3.5, 3, 3.5), Color(0.52, 0.40, 0.32), "flat", Color(0.40, 0.30, 0.22), 0.3, false, true, 0.0, "kiln")

	# Carpenter Shop
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(5, BuildingHelper.snap_y(noise, 5, 18, hs), 18),
		Vector3(4, 3, 3.5), Color(0.48, 0.42, 0.32), "peaked", Color(0.36, 0.28, 0.20), 0.3, false, true, 0.0, "workshop")

	# Rope Maker
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(-10, BuildingHelper.snap_y(noise, -10, 42, hs), 42),
		Vector3(3, 2.5, 3), Color(0.46, 0.40, 0.30), "flat", Color(0.34, 0.28, 0.22), 0.3, false, true, 0.0, "workshop")

	# Dye Works
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(-15, BuildingHelper.snap_y(noise, -15, 40, hs), 40),
		Vector3(4, 3, 3.5), Color(0.44, 0.42, 0.50), "flat", Color(0.32, 0.30, 0.38), 0.3, false, true, 0.0, "workshop")

	# Tool Shed
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(20, BuildingHelper.snap_y(noise, 20, 30, hs), 30),
		Vector3(3, 2.5, 3), Color(0.45, 0.38, 0.30), "flat", Color(0.35, 0.30, 0.25), 0.3, false, true, 0.0, "shed")


static func _build_new_props(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	# Lumber log piles near Lumberyard
	var lumber_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.5, 0.35, 0.2))
	for i: int in 3:
		var log := MeshInstance3D.new()
		var log_mesh := BoxMesh.new()
		log_mesh.size = Vector3(2.0, 0.3, 0.3)
		log.mesh = log_mesh
		log.position = Vector3(17, BuildingHelper.snap_y(noise, 17, 22, hs) + 0.15 + i * 0.3, 22 + i * 0.15)
		log.rotation.y = 0.1 * i
		log.set_surface_override_material(0, lumber_mat)
		log.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(log)

	# Barrel near Kiln House
	var barrel_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.35, 0.25, 0.15))
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.25
	barrel_mesh.bottom_radius = 0.25
	barrel_mesh.height = 0.6
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(10, BuildingHelper.snap_y(noise, 10, 37, hs) + 0.3, 37)
	barrel.set_surface_override_material(0, barrel_mat)
	barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nav_region.add_child(barrel)

	# Crate near Carpenter Shop
	var crate_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.45, 0.32, 0.18))
	var crate := MeshInstance3D.new()
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(0.6, 0.6, 0.6)
	crate.mesh = crate_mesh
	crate.position = Vector3(7, BuildingHelper.snap_y(noise, 7, 17, hs) + 0.3, 17)
	crate.set_surface_override_material(0, crate_mat)
	crate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nav_region.add_child(crate)
