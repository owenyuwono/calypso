## Garrison/Training district builder (x:25..70, z:10..50).
class_name DistrictGarrison

const BuildingHelper = preload("res://scripts/world/building_helper.gd")


static func build(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	_build_barracks(nav_region, noise, hs)
	_build_training_dummies(nav_region, noise, hs)
	_build_weapon_racks(nav_region, noise, hs)
	_build_archery_targets(nav_region, noise, hs)
	_build_cluster_e(nav_region, noise, hs)
	_build_new_buildings(nav_region, noise, hs)
	_build_new_props(nav_region, noise, hs)


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


static func _build_new_buildings(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Officers Quarters
	BuildingHelper.create_building(nav_region,
		Vector3(35, BuildingHelper.snap_y(noise, 35, 35, hs), 35),
		Vector3(4, 3.5, 4), Color(0.44, 0.42, 0.40), "peaked", Color(0.32, 0.28, 0.24), 0.3, false, true, 0.0, "quarters")

	# Infirmary
	BuildingHelper.create_building(nav_region,
		Vector3(60, BuildingHelper.snap_y(noise, 60, 35, hs), 35),
		Vector3(4, 3, 4), Color(0.58, 0.55, 0.52), "peaked", Color(0.40, 0.38, 0.35), 0.3, false, true, 0.0, "infirmary")

	# Military Stable
	BuildingHelper.create_building(nav_region,
		Vector3(60, BuildingHelper.snap_y(noise, 60, 42, hs), 42),
		Vector3(5, 3, 4), Color(0.50, 0.42, 0.32), "flat", Color(0.38, 0.32, 0.25), 0.3, false, true, 0.0, "stable")

	# War Room
	BuildingHelper.create_building(nav_region,
		Vector3(42, BuildingHelper.snap_y(noise, 42, 42, hs), 42),
		Vector3(4, 3.5, 3.5), Color(0.42, 0.40, 0.38), "flat", Color(0.30, 0.28, 0.25), 0.3, false, true, 0.0, "war_room")

	# Watchtower
	BuildingHelper.create_building(nav_region,
		Vector3(65, BuildingHelper.snap_y(noise, 65, 42, hs), 42),
		Vector3(2.5, 6, 2.5), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28), 0.3, false, false, 0.0, "watchtower")


static func _build_new_props(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = Color(0.6, 0.15, 0.15)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.5, 0.42, 0.32)

	# Banner flags at Officers Quarters and War Room
	for fx: float in [35.0, 42.0]:
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.04
		pole_mesh.bottom_radius = 0.05
		pole_mesh.height = 3.5
		pole.mesh = pole_mesh
		pole.position = Vector3(fx + 2.3, BuildingHelper.snap_y(noise, fx + 2.3, 33, hs) + 1.75, 33)
		pole.set_surface_override_material(0, pole_mat)
		nav_region.add_child(pole)

		var flag := MeshInstance3D.new()
		var flag_mesh := BoxMesh.new()
		flag_mesh.size = Vector3(0.8, 0.5, 0.04)
		flag.mesh = flag_mesh
		flag.position = Vector3(fx + 2.7, BuildingHelper.snap_y(noise, fx + 2.3, 33, hs) + 3.25, 33)
		flag.set_surface_override_material(0, flag_mat)
		nav_region.add_child(flag)

	# Torch material
	var torch_body_mat := StandardMaterial3D.new()
	torch_body_mat.albedo_color = Color(0.35, 0.25, 0.15)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.6, 0.1)

	# Torches at Infirmary
	for tx: float in [58.5, 61.5]:
		var torch := Node3D.new()
		torch.position = Vector3(tx, BuildingHelper.snap_y(noise, tx, 33, hs), 33)
		var t_body := MeshInstance3D.new()
		var tb_mesh := CylinderMesh.new()
		tb_mesh.top_radius = 0.05
		tb_mesh.bottom_radius = 0.05
		tb_mesh.height = 1.2
		t_body.mesh = tb_mesh
		t_body.position = Vector3(0, 0.6, 0)
		t_body.set_surface_override_material(0, torch_body_mat)
		torch.add_child(t_body)
		var flame := MeshInstance3D.new()
		var fl_mesh := SphereMesh.new()
		fl_mesh.radius = 0.1
		fl_mesh.height = 0.2
		flame.mesh = fl_mesh
		flame.position = Vector3(0, 1.3, 0)
		flame.set_surface_override_material(0, flame_mat)
		torch.add_child(flame)
		nav_region.add_child(torch)

	# Torches along barracks perimeter
	for bx: float in [40.0, 45.0, 50.0]:
		var torch := Node3D.new()
		torch.position = Vector3(bx, BuildingHelper.snap_y(noise, bx, 37, hs), 37)
		var t_body := MeshInstance3D.new()
		var tb_mesh := CylinderMesh.new()
		tb_mesh.top_radius = 0.05
		tb_mesh.bottom_radius = 0.05
		tb_mesh.height = 1.2
		t_body.mesh = tb_mesh
		t_body.position = Vector3(0, 0.6, 0)
		t_body.set_surface_override_material(0, torch_body_mat)
		torch.add_child(t_body)
		var flame := MeshInstance3D.new()
		var fl_mesh := SphereMesh.new()
		fl_mesh.radius = 0.1
		fl_mesh.height = 0.2
		flame.mesh = fl_mesh
		flame.position = Vector3(0, 1.3, 0)
		flame.set_surface_override_material(0, flame_mat)
		torch.add_child(flame)
		nav_region.add_child(torch)
