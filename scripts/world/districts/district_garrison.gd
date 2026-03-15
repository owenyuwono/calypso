## Garrison/Training district builder (x:25..70, z:10..50).
class_name DistrictGarrison

const BuildingHelper = preload("res://scripts/world/building_helper.gd")


static func build(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	_build_barracks(nav_region, noise, hs)
	_build_training_dummies(nav_region, noise, hs)
	_build_weapon_racks(nav_region, noise, hs)
	_build_archery_targets(nav_region, noise, hs)
	_build_cluster_e(nav_region, noise, hs)


static func _build_barracks(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(nav_region,
		Vector3(45, BuildingHelper.snap_y(noise, 45, 35, hs), 35),
		Vector3(12, 3.5, 5), Color(0.42, 0.4, 0.38), "flat", Color(0.3, 0.28, 0.25), 0.3, false, true, PI / 2)


static func _build_training_dummies(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var dummy_mat := StandardMaterial3D.new()
	dummy_mat.albedo_color = Color(0.45, 0.35, 0.22)
	var dummy_positions: Array = [
		Vector3(35, 0, 18), Vector3(38, 0, 22), Vector3(42, 0, 18),
		Vector3(45, 0, 22), Vector3(48, 0, 18), Vector3(40, 0, 15),
	]
	for dpos: Vector3 in dummy_positions:
		var dummy := Node3D.new()
		dummy.position = Vector3(dpos.x, BuildingHelper.snap_y(noise, dpos.x, dpos.z, hs), dpos.z)
		dummy.rotation.y = dpos.x * 0.3

		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.06
		post_mesh.bottom_radius = 0.08
		post_mesh.height = 1.8
		post.mesh = post_mesh
		post.position = Vector3(0, 0.9, 0)
		post.set_surface_override_material(0, dummy_mat)
		dummy.add_child(post)

		var crossbar := MeshInstance3D.new()
		var cb_mesh := BoxMesh.new()
		cb_mesh.size = Vector3(1.0, 0.12, 0.12)
		crossbar.mesh = cb_mesh
		crossbar.position = Vector3(0, 1.4, 0)
		crossbar.set_surface_override_material(0, dummy_mat)
		dummy.add_child(crossbar)

		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.15
		head_mesh.height = 0.3
		head.mesh = head_mesh
		head.position = Vector3(0, 1.9, 0)
		var head_mat := StandardMaterial3D.new()
		head_mat.albedo_color = Color(0.6, 0.5, 0.35)
		head.set_surface_override_material(0, head_mat)
		dummy.add_child(head)

		nav_region.add_child(dummy)


static func _build_weapon_racks(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var rack_mat := StandardMaterial3D.new()
	rack_mat.albedo_color = Color(0.4, 0.3, 0.2)
	for rx: float in [40.0, 44.0, 48.0]:
		var rack := Node3D.new()
		rack.position = Vector3(rx, BuildingHelper.snap_y(noise, rx, 32, hs), 32)
		rack.rotation.y = 0.15

		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(1.5, 0.08, 0.08)
		bar.mesh = bar_mesh
		bar.position = Vector3(0, 1.2, 0)
		bar.set_surface_override_material(0, rack_mat)
		rack.add_child(bar)

		for side: float in [-0.6, 0.6]:
			var leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.08, 1.4, 0.08)
			leg.mesh = leg_mesh
			leg.position = Vector3(side, 0.7, 0)
			leg.set_surface_override_material(0, rack_mat)
			rack.add_child(leg)

		nav_region.add_child(rack)


static func _build_archery_targets(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var rack_mat := StandardMaterial3D.new()
	rack_mat.albedo_color = Color(0.4, 0.3, 0.2)
	var target_mat := StandardMaterial3D.new()
	target_mat.albedo_color = Color(0.8, 0.3, 0.2)
	var target_positions: Array = [Vector3(55, 0, 15), Vector3(58, 0, 20)]
	for tpos: Vector3 in target_positions:
		var target_post := MeshInstance3D.new()
		var tp_mesh := CylinderMesh.new()
		tp_mesh.top_radius = 0.06
		tp_mesh.bottom_radius = 0.08
		tp_mesh.height = 1.5
		target_post.mesh = tp_mesh
		target_post.position = Vector3(tpos.x, BuildingHelper.snap_y(noise, tpos.x, tpos.z, hs) + 0.75, tpos.z)
		target_post.set_surface_override_material(0, rack_mat)
		nav_region.add_child(target_post)

		var target_face := MeshInstance3D.new()
		var tf_mesh := CylinderMesh.new()
		tf_mesh.top_radius = 0.5
		tf_mesh.bottom_radius = 0.5
		tf_mesh.height = 0.1
		target_face.mesh = tf_mesh
		target_face.position = Vector3(tpos.x, BuildingHelper.snap_y(noise, tpos.x, tpos.z, hs) + 1.3, tpos.z)
		target_face.rotation.x = PI * 0.5
		target_face.set_surface_override_material(0, target_mat)
		nav_region.add_child(target_face)


static func _build_cluster_e(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Guard Tower
	BuildingHelper.create_building(nav_region,
		Vector3(30, BuildingHelper.snap_y(noise, 30, 40, hs), 40),
		Vector3(3, 5, 3), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28), 0.3, false, false)

	# E1 Quartermaster
	BuildingHelper.create_building(nav_region,
		Vector3(38, BuildingHelper.snap_y(noise, 38, 30, hs), 30),
		Vector3(4, 3, 3.5), Color(0.46, 0.42, 0.36), "flat", Color(0.34, 0.30, 0.26), 0.5, false, true)

	# E2 Mess Hall
	BuildingHelper.create_building(nav_region,
		Vector3(52, BuildingHelper.snap_y(noise, 52, 32, hs), 32),
		Vector3(3.5, 3, 3), Color(0.48, 0.44, 0.38), "flat", Color(0.36, 0.32, 0.28), 0.5, false, true)

	# Armory
	BuildingHelper.create_building(nav_region,
		Vector3(55, BuildingHelper.snap_y(noise, 55, 25, hs), 25),
		Vector3(5, 3.5, 4), Color(0.48, 0.44, 0.38), "flat", Color(0.32, 0.28, 0.24), 0.3, false, true)
