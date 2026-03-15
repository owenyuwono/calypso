## Park/Gardens district builder (x:25..70, z:-50..-10).
class_name DistrictPark

const BuildingHelper = preload("res://scripts/world/building_helper.gd")


static func build(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	_build_fountain(nav_region, noise, hs)
	_build_benches(nav_region, noise, hs)
	_build_gardener_cottage(nav_region, noise, hs)
	_build_gazebo(nav_region, noise, hs)


static func _build_fountain(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var pos := Vector3(45, BuildingHelper.snap_y(noise, 45, -30, hs), -30)
	BuildingHelper.create_fountain(nav_region, pos, 2.0, 0.5, 1.5, 1.0)


static func _build_benches(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var bench_spots: Array = [
		Vector3(40, 0, -25), Vector3(50, 0, -25),
		Vector3(40, 0, -35), Vector3(50, 0, -35),
		Vector3(35, 0, -30), Vector3(55, 0, -30),
	]
	for bp: Vector3 in bench_spots:
		var world_pos := Vector3(bp.x, BuildingHelper.snap_y(noise, bp.x, bp.z, hs) + 0.2, bp.z)
		BuildingHelper.create_bench(nav_region, world_pos)


static func _build_gardener_cottage(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(nav_region,
		Vector3(40, BuildingHelper.snap_y(noise, 40, -38, hs), -38),
		Vector3(3.5, 3, 3.5), Color(0.52, 0.48, 0.40), "peaked", Color(0.38, 0.24, 0.16), 0.5, true, false)


static func _build_gazebo(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var gazebo := Node3D.new()
	var gz_y: float = BuildingHelper.snap_y(noise, 35, -20, hs)
	gazebo.position = Vector3(35, gz_y, -20)

	var gz_post_mat := StandardMaterial3D.new()
	gz_post_mat.albedo_color = Color(0.55, 0.45, 0.3)
	var gz_roof_mat := StandardMaterial3D.new()
	gz_roof_mat.albedo_color = Color(0.38, 0.3, 0.22)

	# 6 posts arranged in a circle (radius 1.5)
	for i: int in 6:
		var angle: float = i * PI / 3.0
		var gz_post := MeshInstance3D.new()
		var gz_post_mesh := CylinderMesh.new()
		gz_post_mesh.top_radius = 0.07
		gz_post_mesh.bottom_radius = 0.09
		gz_post_mesh.height = 2.5
		gz_post.mesh = gz_post_mesh
		gz_post.position = Vector3(cos(angle) * 1.5, 1.25, sin(angle) * 1.5)
		gz_post.set_surface_override_material(0, gz_post_mat)
		gazebo.add_child(gz_post)

	# Flat roof
	var gz_roof := MeshInstance3D.new()
	var gz_roof_mesh := BoxMesh.new()
	gz_roof_mesh.size = Vector3(3.6, 0.15, 3.6)
	gz_roof.mesh = gz_roof_mesh
	gz_roof.position = Vector3(0, 2.575, 0)
	gz_roof.set_surface_override_material(0, gz_roof_mat)
	gazebo.add_child(gz_roof)

	nav_region.add_child(gazebo)
