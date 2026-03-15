## Noble/Temple Quarter district builder (x:-20..25, z:-50..-10).
class_name DistrictNoble

const BuildingHelper = preload("res://scripts/world/building_helper.gd")


static func build(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	_build_temple(nav_region, noise, hs)
	_build_guild_hall(nav_region, noise, hs)
	_build_manor(nav_region, noise, hs)
	_build_statue(nav_region, noise, hs)
	_build_cluster_c(nav_region, noise, hs)


static func _build_temple(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var temple_pos := Vector3(10, BuildingHelper.snap_y(noise, 10, -35, hs), -35)
	BuildingHelper.create_building(nav_region, temple_pos,
		Vector3(8, 5, 10), Color(0.6, 0.58, 0.55), "peaked", Color(0.35, 0.3, 0.28), 0.8, false, true)

	# Spire
	var spire := MeshInstance3D.new()
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.1
	spire_mesh.bottom_radius = 0.5
	spire_mesh.height = 3.0
	spire.mesh = spire_mesh
	spire.position = Vector3(temple_pos.x, temple_pos.y + 7.5, temple_pos.z)
	var spire_mat := StandardMaterial3D.new()
	spire_mat.albedo_color = Color(0.4, 0.35, 0.3)
	spire.set_surface_override_material(0, spire_mat)
	nav_region.add_child(spire)

	# Front steps
	var steps := MeshInstance3D.new()
	var steps_mesh := BoxMesh.new()
	steps_mesh.size = Vector3(4, 0.3, 1.5)
	steps.mesh = steps_mesh
	steps.position = Vector3(temple_pos.x, temple_pos.y + 0.15, temple_pos.z + 5.75)
	var step_mat := StandardMaterial3D.new()
	step_mat.albedo_color = Color(0.55, 0.52, 0.48)
	steps.set_surface_override_material(0, step_mat)
	nav_region.add_child(steps)


static func _build_guild_hall(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(nav_region,
		Vector3(15, BuildingHelper.snap_y(noise, 15, -25, hs), -25),
		Vector3(10, 4, 7), Color(0.5, 0.45, 0.4), "flat", Color(0.3, 0.28, 0.25), 0.4, false, true, PI / 2)


static func _build_manor(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var manor_pos := Vector3(-10, BuildingHelper.snap_y(noise, -10, -40, hs), -40)
	BuildingHelper.create_building(nav_region, manor_pos,
		Vector3(6, 3.5, 5), Color(0.62, 0.58, 0.52), "peaked", Color(0.38, 0.3, 0.25), 0.5, true, true, 0.12)
	BuildingHelper.create_building(nav_region,
		Vector3(manor_pos.x + 4, manor_pos.y, manor_pos.z - 1),
		Vector3(4, 3, 3), Color(0.62, 0.58, 0.52), "peaked", Color(0.38, 0.3, 0.25), 0.5, false, false)


static func _build_statue(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var statue := Node3D.new()
	statue.position = Vector3(5, BuildingHelper.snap_y(noise, 5, -30, hs), -30)

	var pedestal := MeshInstance3D.new()
	var ped_mesh := BoxMesh.new()
	ped_mesh.size = Vector3(1.0, 1.0, 1.0)
	pedestal.mesh = ped_mesh
	pedestal.position = Vector3(0, 0.5, 0)
	var ped_mat := StandardMaterial3D.new()
	ped_mat.albedo_color = Color(0.5, 0.48, 0.45)
	pedestal.set_surface_override_material(0, ped_mat)
	statue.add_child(pedestal)

	var figure := MeshInstance3D.new()
	var fig_mesh := CylinderMesh.new()
	fig_mesh.top_radius = 0.2
	fig_mesh.bottom_radius = 0.25
	fig_mesh.height = 1.5
	figure.mesh = fig_mesh
	figure.position = Vector3(0, 1.75, 0)
	var fig_mat := StandardMaterial3D.new()
	fig_mat.albedo_color = Color(0.55, 0.52, 0.48)
	figure.set_surface_override_material(0, fig_mat)
	statue.add_child(figure)

	nav_region.add_child(statue)


static func _build_cluster_c(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# C1 Scriptorium
	BuildingHelper.create_building(nav_region,
		Vector3(6, BuildingHelper.snap_y(noise, 6, -26, hs), -26),
		Vector3(4, 3, 3.5), Color(0.56, 0.53, 0.48), "peaked", Color(0.32, 0.26, 0.20), 0.5, false, true)

	# C2 Records Hall
	BuildingHelper.create_building(nav_region,
		Vector3(18, BuildingHelper.snap_y(noise, 18, -35, hs), -35),
		Vector3(3.5, 3, 3.5), Color(0.58, 0.55, 0.50), "peaked", Color(0.30, 0.25, 0.20), 0.5, false, true)

	# Library
	BuildingHelper.create_building(nav_region,
		Vector3(0, BuildingHelper.snap_y(noise, 0, -20, hs), -20),
		Vector3(6, 4, 5), Color(0.55, 0.52, 0.48), "peaked", Color(0.3, 0.25, 0.2), 0.5, false, true)

	# Chapel Annex
	BuildingHelper.create_building(nav_region,
		Vector3(18, BuildingHelper.snap_y(noise, 18, -40, hs), -40),
		Vector3(3.5, 3, 3), Color(0.6, 0.58, 0.55), "peaked", Color(0.35, 0.28, 0.22), 0.5, false, true)
