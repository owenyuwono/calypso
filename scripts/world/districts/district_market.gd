## Market District builder (x:-70..-20, z:-10..50).
class_name DistrictMarket

const BuildingHelper = preload("res://scripts/world/building_helper.gd")


static func build(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	_build_shops(nav_region, noise, hs)
	_build_stalls(nav_region, noise, hs)
	_build_cluster_a(nav_region, noise, hs)


static func _build_shops(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Weapon Shop
	BuildingHelper.create_building(nav_region,
		Vector3(-45, BuildingHelper.snap_y(noise, -45, 20, hs), 20),
		Vector3(6, 3.5, 5), Color(0.55, 0.38, 0.22), "peaked", Color(0.5, 0.18, 0.1), 0.6, false, true, PI / 2)

	# Item Shop
	BuildingHelper.create_building(nav_region,
		Vector3(-55, BuildingHelper.snap_y(noise, -55, 30, hs), 30),
		Vector3(5, 3, 4), Color(0.55, 0.48, 0.35), "peaked", Color(0.2, 0.4, 0.15), 0.5)

	# Bakery — peaked roof, chimney + door
	BuildingHelper.create_building(nav_region,
		Vector3(-30, BuildingHelper.snap_y(noise, -30, 30, hs), 30),
		Vector3(4, 3, 4), Color(0.62, 0.52, 0.38), "peaked", Color(0.45, 0.25, 0.15), 0.5, true, true)

	# Storage Shed — flat roof, no door
	BuildingHelper.create_building(nav_region,
		Vector3(-65, BuildingHelper.snap_y(noise, -65, 15, hs), 15),
		Vector3(3.5, 2.5, 3), Color(0.42, 0.35, 0.28), "flat", Color(0.35, 0.3, 0.25), 0.3, false, false)


static func _build_stalls(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var stall_positions: Array = [Vector3(-35, 0, 15), Vector3(-40, 0, 35), Vector3(-55, 0, 15), Vector3(-30, 0, 40)]
	var stall_mat := StandardMaterial3D.new()
	stall_mat.albedo_color = Color(0.45, 0.35, 0.22)
	var canopy_colors: Array = [Color(0.7, 0.2, 0.15), Color(0.2, 0.5, 0.2), Color(0.6, 0.5, 0.15), Color(0.3, 0.3, 0.6)]
	var rotations: Array = [0.0, 0.2, -0.15, 0.3]

	for i: int in stall_positions.size():
		var spos: Vector3 = stall_positions[i]
		_create_stall(nav_region, noise, hs, spos, rotations[i], canopy_colors[i])

	# Stall 5
	_create_stall(nav_region, noise, hs, Vector3(-48, 0, 42), 0.1, Color(0.55, 0.35, 0.15))


static func _create_stall(nav_region: Node3D, noise: FastNoiseLite, hs: float,
		spos: Vector3, rot_y: float, canopy_color: Color) -> void:
	var stall := Node3D.new()
	stall.position = Vector3(spos.x, BuildingHelper.snap_y(noise, spos.x, spos.z, hs), spos.z)
	stall.rotation.y = rot_y

	var stall_mat := StandardMaterial3D.new()
	stall_mat.albedo_color = Color(0.45, 0.35, 0.22)

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
			post.set_surface_override_material(0, stall_mat)
			stall.add_child(post)

	# Canopy
	var canopy := MeshInstance3D.new()
	var canopy_mesh := BoxMesh.new()
	canopy_mesh.size = Vector3(3.0, 0.1, 2.0)
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0, 2.55, 0)
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = canopy_color
	canopy.set_surface_override_material(0, canopy_mat)
	stall.add_child(canopy)

	# Counter
	var counter := MeshInstance3D.new()
	var counter_mesh := BoxMesh.new()
	counter_mesh.size = Vector3(2.4, 0.8, 0.4)
	counter.mesh = counter_mesh
	counter.position = Vector3(0, 0.4, 0.6)
	counter.set_surface_override_material(0, stall_mat)
	stall.add_child(counter)

	nav_region.add_child(stall)


static func _build_cluster_a(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# A1 Merchant Office
	BuildingHelper.create_building(nav_region,
		Vector3(-36, BuildingHelper.snap_y(noise, -36, 5, hs), 5),
		Vector3(4, 3, 3.5), Color(0.58, 0.50, 0.40), "peaked", Color(0.40, 0.25, 0.15), 0.5, false, true)

	# A2 Tax Office
	BuildingHelper.create_building(nav_region,
		Vector3(-30, BuildingHelper.snap_y(noise, -30, 5, hs), 5),
		Vector3(3.5, 3, 3), Color(0.55, 0.48, 0.38), "peaked", Color(0.38, 0.22, 0.14), 0.5, false, true)

	# A3 Courier Post
	BuildingHelper.create_building(nav_region,
		Vector3(-24, BuildingHelper.snap_y(noise, -24, 5, hs), 5),
		Vector3(3.5, 3, 3), Color(0.52, 0.46, 0.36), "flat", Color(0.35, 0.30, 0.25), 0.5, false, true)
