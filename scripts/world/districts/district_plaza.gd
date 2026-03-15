## Central Plaza district builder (x:-15..20, z:-10..10).
class_name DistrictPlaza

const BuildingHelper = preload("res://scripts/world/building_helper.gd")


static func build(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	_build_fountain(nav_region, noise, hs)
	_build_benches(nav_region, noise, hs)
	_build_street_lamps(nav_region, noise, hs)


static func _build_fountain(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var pos := Vector3(0, BuildingHelper.snap_y(noise, 0, 0, hs), 0)
	BuildingHelper.create_fountain(nav_region, pos, 1.5, 0.4, 1.2, 0.8)


static func _build_benches(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var bench_positions: Array = [Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3)]
	for bpos: Vector3 in bench_positions:
		var rot_y: float = PI * 0.5 if bpos.x == 0 else 0.0
		var world_pos := Vector3(bpos.x, BuildingHelper.snap_y(noise, bpos.x, bpos.z, hs) + 0.2, bpos.z)
		BuildingHelper.create_bench(nav_region, world_pos, rot_y)


static func _build_street_lamps(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.25, 0.25, 0.25)
	var lamp_glow_mat := StandardMaterial3D.new()
	lamp_glow_mat.albedo_color = Color(1.0, 0.9, 0.6)
	lamp_glow_mat.emission_enabled = true
	lamp_glow_mat.emission = Color(1.0, 0.85, 0.5)
	lamp_glow_mat.emission_energy_multiplier = 0.5

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
		nav_region.add_child(lamp_post)

		var lamp_light := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		lamp_light.mesh = sphere
		lamp_light.position = Vector3(lpos.x, BuildingHelper.snap_y(noise, lpos.x, lpos.z, hs) + 3.1, lpos.z)
		lamp_light.set_surface_override_material(0, lamp_glow_mat)
		nav_region.add_child(lamp_light)
