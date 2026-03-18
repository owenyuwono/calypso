## Market District builder (x:-70..-20, z:-10..50).
class_name DistrictMarket

const BuildingHelper = preload("res://scripts/world/building_helper.gd")


static func build(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	_build_shops(nav_region, noise, hs)
	_build_stalls(nav_region, noise, hs)
	_build_cluster_a(nav_region, noise, hs)
	_build_new_shops(nav_region, noise, hs)
	_build_new_stalls(nav_region, noise, hs)
	_build_props(nav_region, noise, hs)


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


static func _build_new_shops(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Spice Shop
	BuildingHelper.create_building(nav_region,
		Vector3(-50, BuildingHelper.snap_y(noise, -50, 20, hs), 20),
		Vector3(4, 3, 3.5), Color(0.60, 0.45, 0.28), "peaked", Color(0.45, 0.22, 0.12), 0.5, false, true, 0.0, "shop")

	# Cloth Merchant
	BuildingHelper.create_building(nav_region,
		Vector3(-38, BuildingHelper.snap_y(noise, -38, 25, hs), 25),
		Vector3(4, 3, 4), Color(0.52, 0.46, 0.40), "peaked", Color(0.30, 0.35, 0.45), 0.5, false, true, 0.0, "shop")

	# Apothecary
	BuildingHelper.create_building(nav_region,
		Vector3(-62, BuildingHelper.snap_y(noise, -62, 25, hs), 25),
		Vector3(4, 3, 3.5), Color(0.48, 0.52, 0.42), "peaked", Color(0.22, 0.38, 0.18), 0.5, false, true, 0.0, "shop")

	# Pawn Shop
	BuildingHelper.create_building(nav_region,
		Vector3(-28, BuildingHelper.snap_y(noise, -28, 20, hs), 20),
		Vector3(3.5, 3, 3), Color(0.50, 0.42, 0.32), "peaked", Color(0.38, 0.28, 0.18), 0.5, false, true, 0.0, "shop")

	# Tavern
	BuildingHelper.create_building(nav_region,
		Vector3(-50, BuildingHelper.snap_y(noise, -50, 40, hs), 40),
		Vector3(6, 3.5, 5), Color(0.50, 0.38, 0.25), "peaked", Color(0.40, 0.18, 0.10), 0.5, false, true, 0.0, "tavern")

	# Fish Monger
	BuildingHelper.create_building(nav_region,
		Vector3(-35, BuildingHelper.snap_y(noise, -35, 45, hs), 45),
		Vector3(3.5, 3, 3), Color(0.48, 0.48, 0.52), "flat", Color(0.35, 0.35, 0.38), 0.5, false, true, 0.0, "shop")

	# Butcher
	BuildingHelper.create_building(nav_region,
		Vector3(-28, BuildingHelper.snap_y(noise, -28, 45, hs), 45),
		Vector3(3.5, 3, 3), Color(0.55, 0.38, 0.35), "peaked", Color(0.45, 0.20, 0.15), 0.5, false, true, 0.0, "shop")

	# Grain Store
	BuildingHelper.create_building(nav_region,
		Vector3(-65, BuildingHelper.snap_y(noise, -65, 35, hs), 35),
		Vector3(4, 3, 4), Color(0.52, 0.45, 0.32), "flat", Color(0.38, 0.32, 0.25), 0.5, false, true, 0.0, "warehouse")

	# Cartographer
	BuildingHelper.create_building(nav_region,
		Vector3(-24, BuildingHelper.snap_y(noise, -24, 15, hs), 15),
		Vector3(3.5, 3, 3), Color(0.55, 0.50, 0.42), "peaked", Color(0.35, 0.28, 0.20), 0.5, false, true, 0.0, "shop")

	# Chandler
	BuildingHelper.create_building(nav_region,
		Vector3(-65, BuildingHelper.snap_y(noise, -65, 45, hs), 45),
		Vector3(3.5, 3, 3), Color(0.58, 0.52, 0.38), "peaked", Color(0.42, 0.32, 0.18), 0.5, false, true, 0.0, "shop")


static func _build_new_stalls(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Fruit Stall — orange canopy
	_create_stall(nav_region, noise, hs, Vector3(-42, 0, 30), 0.0, Color(0.85, 0.45, 0.10))

	# Trinket Stall — purple canopy
	_create_stall(nav_region, noise, hs, Vector3(-60, 0, 22), 0.15, Color(0.45, 0.20, 0.65))

	# Herb Stall — green canopy
	_create_stall(nav_region, noise, hs, Vector3(-32, 0, 35), -0.1, Color(0.20, 0.55, 0.20))


static func _build_props(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.35, 0.25, 0.15)

	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.45, 0.32, 0.18)

	var torch_pole_mat := StandardMaterial3D.new()
	torch_pole_mat.albedo_color = Color(0.30, 0.22, 0.12)

	var torch_flame_mat := StandardMaterial3D.new()
	torch_flame_mat.albedo_color = Color(1.0, 0.65, 0.1)
	torch_flame_mat.emission_enabled = true
	torch_flame_mat.emission = Color(1.0, 0.55, 0.05)
	torch_flame_mat.emission_energy_multiplier = 1.2

	# Barrel cluster at (-38, y, 20)
	for i: int in 3:
		var barrel := MeshInstance3D.new()
		var barrel_mesh := CylinderMesh.new()
		barrel_mesh.top_radius = 0.25
		barrel_mesh.bottom_radius = 0.28
		barrel_mesh.height = 0.7
		barrel.mesh = barrel_mesh
		barrel.position = Vector3(-38.0 + i * 0.6, BuildingHelper.snap_y(noise, -38.0 + i * 0.6, 20.0, hs) + 0.35, 20.0 + i * 0.3)
		barrel.set_surface_override_material(0, barrel_mat)
		nav_region.add_child(barrel)

	# Barrel cluster at (-50, y, 45)
	for i: int in 2:
		var barrel := MeshInstance3D.new()
		var barrel_mesh := CylinderMesh.new()
		barrel_mesh.top_radius = 0.25
		barrel_mesh.bottom_radius = 0.28
		barrel_mesh.height = 0.7
		barrel.mesh = barrel_mesh
		barrel.position = Vector3(-50.0 + i * 0.6, BuildingHelper.snap_y(noise, -50.0 + i * 0.6, 45.0, hs) + 0.35, 45.0)
		barrel.set_surface_override_material(0, barrel_mat)
		nav_region.add_child(barrel)

	# Crate stack near Grain Store (-65, y, 33)
	for i: int in 2:
		var crate := MeshInstance3D.new()
		var crate_mesh := BoxMesh.new()
		crate_mesh.size = Vector3(0.7, 0.7, 0.7)
		crate.mesh = crate_mesh
		crate.position = Vector3(-65.0, BuildingHelper.snap_y(noise, -65.0, 33.0, hs) + 0.35 + i * 0.7, 33.0)
		crate.set_surface_override_material(0, crate_mat)
		nav_region.add_child(crate)

	# Crate stack near Tavern (-48, y, 40)
	for i: int in 2:
		var crate := MeshInstance3D.new()
		var crate_mesh := BoxMesh.new()
		crate_mesh.size = Vector3(0.7, 0.7, 0.7)
		crate.mesh = crate_mesh
		crate.position = Vector3(-48.0, BuildingHelper.snap_y(noise, -48.0, 40.0, hs) + 0.35 + i * 0.7, 40.0)
		crate.set_surface_override_material(0, crate_mat)
		nav_region.add_child(crate)

	# Torches: Tavern entrance (-50, y, 42), Apothecary entrance (-62, y, 27),
	#          Pawn Shop entrance (-28, y, 22)
	var torch_positions: Array = [Vector3(-50, 0, 42), Vector3(-62, 0, 27), Vector3(-28, 0, 22)]
	for tpos: Vector3 in torch_positions:
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.04
		pole_mesh.bottom_radius = 0.05
		pole_mesh.height = 1.8
		pole.mesh = pole_mesh
		pole.position = Vector3(tpos.x, BuildingHelper.snap_y(noise, tpos.x, tpos.z, hs) + 0.9, tpos.z)
		pole.set_surface_override_material(0, torch_pole_mat)
		nav_region.add_child(pole)

		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.12
		flame_mesh.height = 0.24
		flame.mesh = flame_mesh
		flame.position = Vector3(tpos.x, BuildingHelper.snap_y(noise, tpos.x, tpos.z, hs) + 1.85, tpos.z)
		flame.set_surface_override_material(0, torch_flame_mat)
		nav_region.add_child(flame)
