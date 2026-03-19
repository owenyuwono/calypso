## Noble/Temple Quarter district builder (x:-20..25, z:-50..-10).
class_name DistrictNoble

const BuildingHelper = preload("res://scripts/world/building_helper.gd")


static func build(ctx: WorldBuilderContext) -> void:
	var nav_region: Node = ctx.nav_region
	var noise: FastNoiseLite = ctx.terrain_noise
	var hs: float = ctx.terrain_height_scale_city
	_build_temple(ctx, nav_region, noise, hs)
	_build_guild_hall(ctx, nav_region, noise, hs)
	_build_manor(ctx, nav_region, noise, hs)
	_build_statue(ctx, nav_region, noise, hs)
	_build_cluster_c(ctx, nav_region, noise, hs)
	_build_magistrate_court(ctx, nav_region, noise, hs)
	_build_noble_house_1(ctx, nav_region, noise, hs)
	_build_noble_house_2(ctx, nav_region, noise, hs)
	_build_shrine(ctx, nav_region, noise, hs)
	_build_clerk_office(ctx, nav_region, noise, hs)
	_build_archive_tower(ctx, nav_region, noise, hs)


static func _build_temple(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var temple_pos := Vector3(10, BuildingHelper.snap_y(noise, 10, -35, hs), -35)
	BuildingHelper.create_building(ctx, nav_region, temple_pos,
		Vector3(8, 5, 10), Color(0.6, 0.58, 0.55), "peaked", Color(0.35, 0.3, 0.28), 0.8, false, true)

	# Spire
	var spire := MeshInstance3D.new()
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.1
	spire_mesh.bottom_radius = 0.5
	spire_mesh.height = 3.0
	spire.mesh = spire_mesh
	spire.position = Vector3(temple_pos.x, temple_pos.y + 7.5, temple_pos.z)
	var spire_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.4, 0.35, 0.3))
	spire.set_surface_override_material(0, spire_mat)
	spire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nav_region.add_child(spire)

	# Front steps
	var steps := MeshInstance3D.new()
	var steps_mesh := BoxMesh.new()
	steps_mesh.size = Vector3(4, 0.3, 1.5)
	steps.mesh = steps_mesh
	steps.position = Vector3(temple_pos.x, temple_pos.y + 0.15, temple_pos.z + 5.75)
	var step_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.55, 0.52, 0.48))
	steps.set_surface_override_material(0, step_mat)
	steps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nav_region.add_child(steps)


static func _build_guild_hall(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(15, BuildingHelper.snap_y(noise, 15, -25, hs), -25),
		Vector3(10, 4, 7), Color(0.5, 0.45, 0.4), "flat", Color(0.3, 0.28, 0.25), 0.4, false, true, PI / 2)


static func _build_manor(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var manor_pos := Vector3(-10, BuildingHelper.snap_y(noise, -10, -40, hs), -40)
	BuildingHelper.create_building(ctx, nav_region, manor_pos,
		Vector3(6, 3.5, 5), Color(0.62, 0.58, 0.52), "peaked", Color(0.38, 0.3, 0.25), 0.5, true, true, 0.12)
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(manor_pos.x + 4, manor_pos.y, manor_pos.z - 1),
		Vector3(4, 3, 3), Color(0.62, 0.58, 0.52), "peaked", Color(0.38, 0.3, 0.25), 0.5, false, false)


static func _build_statue(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var statue := Node3D.new()
	statue.position = Vector3(5, BuildingHelper.snap_y(noise, 5, -30, hs), -30)

	var pedestal := MeshInstance3D.new()
	var ped_mesh := BoxMesh.new()
	ped_mesh.size = Vector3(1.0, 1.0, 1.0)
	pedestal.mesh = ped_mesh
	pedestal.position = Vector3(0, 0.5, 0)
	var ped_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.5, 0.48, 0.45))
	pedestal.set_surface_override_material(0, ped_mat)
	pedestal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	statue.add_child(pedestal)

	var figure := MeshInstance3D.new()
	var fig_mesh := CylinderMesh.new()
	fig_mesh.top_radius = 0.2
	fig_mesh.bottom_radius = 0.25
	fig_mesh.height = 1.5
	figure.mesh = fig_mesh
	figure.position = Vector3(0, 1.75, 0)
	var fig_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.55, 0.52, 0.48))
	figure.set_surface_override_material(0, fig_mat)
	figure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	statue.add_child(figure)

	nav_region.add_child(statue)


static func _build_cluster_c(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	# C1 Scriptorium
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(6, BuildingHelper.snap_y(noise, 6, -26, hs), -26),
		Vector3(4, 3, 3.5), Color(0.56, 0.53, 0.48), "peaked", Color(0.32, 0.26, 0.20), 0.5, false, true)

	# C2 Records Hall
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(18, BuildingHelper.snap_y(noise, 18, -35, hs), -35),
		Vector3(3.5, 3, 3.5), Color(0.58, 0.55, 0.50), "peaked", Color(0.30, 0.25, 0.20), 0.5, false, true)

	# Library
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(0, BuildingHelper.snap_y(noise, 0, -20, hs), -20),
		Vector3(6, 4, 5), Color(0.55, 0.52, 0.48), "peaked", Color(0.3, 0.25, 0.2), 0.5, false, true)

	# Chapel Annex
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(18, BuildingHelper.snap_y(noise, 18, -40, hs), -40),
		Vector3(3.5, 3, 3), Color(0.6, 0.58, 0.55), "peaked", Color(0.35, 0.28, 0.22), 0.5, false, true)


static func _build_magistrate_court(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var court_pos := Vector3(-15, BuildingHelper.snap_y(noise, -15, -25, hs), -25)
	BuildingHelper.create_building(ctx, nav_region, court_pos,
		Vector3(5, 4, 5), Color(0.55, 0.52, 0.48), "flat", Color(0.32, 0.28, 0.24),
		0.5, false, true, 0.0, "court")

	# Decorated pillars flanking the entrance
	var pillar_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.58, 0.55, 0.50))
	for side: int in [-1, 1]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := CylinderMesh.new()
		pillar_mesh.top_radius = 0.18
		pillar_mesh.bottom_radius = 0.22
		pillar_mesh.height = 3.5
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(court_pos.x + side * 1.5, court_pos.y + 1.75, court_pos.z + 2.8)
		pillar.set_surface_override_material(0, pillar_mat)
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(pillar)

		# Pillar capital (decorative top cap)
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.45, 0.2, 0.45)
		cap.mesh = cap_mesh
		cap.position = Vector3(court_pos.x + side * 1.5, court_pos.y + 3.6, court_pos.z + 2.8)
		cap.set_surface_override_material(0, pillar_mat)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(cap)


static func _build_noble_house_1(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var pos := Vector3(-15, BuildingHelper.snap_y(noise, -15, -35, hs), -35)
	BuildingHelper.create_building(ctx, nav_region, pos,
		Vector3(5, 3.5, 4.5), Color(0.62, 0.58, 0.52), "peaked", Color(0.38, 0.30, 0.25),
		0.5, false, true, 0.0, "noble_house")

	# Torches flanking the door
	var torch_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.35, 0.28, 0.20))
	var flame_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(1.0, 0.55, 0.1))
	for side: int in [-1, 1]:
		var torch := MeshInstance3D.new()
		var torch_mesh := CylinderMesh.new()
		torch_mesh.top_radius = 0.06
		torch_mesh.bottom_radius = 0.08
		torch_mesh.height = 0.7
		torch.mesh = torch_mesh
		torch.position = Vector3(pos.x + side * 0.7, pos.y + 1.0, pos.z + 2.35)
		torch.set_surface_override_material(0, torch_mat)
		torch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(torch)

		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.1
		flame_mesh.height = 0.2
		flame.mesh = flame_mesh
		flame.position = Vector3(pos.x + side * 0.7, pos.y + 1.42, pos.z + 2.35)
		flame.set_surface_override_material(0, flame_mat)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(flame)


static func _build_noble_house_2(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var pos := Vector3(20, BuildingHelper.snap_y(noise, 20, -20, hs), -20)
	BuildingHelper.create_building(ctx, nav_region, pos,
		Vector3(4.5, 3.5, 4), Color(0.60, 0.56, 0.50), "peaked", Color(0.36, 0.28, 0.22),
		0.5, false, true, 0.0, "noble_house")

	# Torches flanking the door
	var torch_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.35, 0.28, 0.20))
	var flame_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(1.0, 0.55, 0.1))
	for side: int in [-1, 1]:
		var torch := MeshInstance3D.new()
		var torch_mesh := CylinderMesh.new()
		torch_mesh.top_radius = 0.06
		torch_mesh.bottom_radius = 0.08
		torch_mesh.height = 0.7
		torch.mesh = torch_mesh
		torch.position = Vector3(pos.x + side * 0.65, pos.y + 1.0, pos.z + 2.1)
		torch.set_surface_override_material(0, torch_mat)
		torch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(torch)

		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.1
		flame_mesh.height = 0.2
		flame.mesh = flame_mesh
		flame.position = Vector3(pos.x + side * 0.65, pos.y + 1.42, pos.z + 2.1)
		flame.set_surface_override_material(0, flame_mat)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(flame)


static func _build_shrine(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(-5, BuildingHelper.snap_y(noise, -5, -43, hs), -43),
		Vector3(3, 3, 3), Color(0.65, 0.62, 0.58), "peaked", Color(0.40, 0.35, 0.30),
		0.5, false, true, 0.0, "shrine")


static func _build_clerk_office(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(10, BuildingHelper.snap_y(noise, 10, -18, hs), -18),
		Vector3(3.5, 3, 3), Color(0.56, 0.52, 0.46), "peaked", Color(0.34, 0.28, 0.22),
		0.5, false, true, 0.0, "office")


static func _build_archive_tower(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var tower_pos := Vector3(22, BuildingHelper.snap_y(noise, 22, -45, hs), -45)
	BuildingHelper.create_building(ctx, nav_region, tower_pos,
		Vector3(3, 5, 3), Color(0.48, 0.45, 0.42), "flat", Color(0.30, 0.28, 0.25),
		0.5, false, true, 0.0, "tower")

	# Banner hanging from the front face
	var banner := MeshInstance3D.new()
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(0.8, 1.5, 0.05)
	banner.mesh = banner_mesh
	banner.position = Vector3(tower_pos.x, tower_pos.y + 3.5, tower_pos.z + 1.6)
	var banner_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.55, 0.15, 0.15))
	banner.set_surface_override_material(0, banner_mat)
	banner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nav_region.add_child(banner)
