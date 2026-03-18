## Residential Quarter district builder (x:-70..-20, z:-50..-10).
class_name DistrictResidential

const BuildingHelper = preload("res://scripts/world/building_helper.gd")


static func build(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	_build_houses(nav_region, noise, hs)
	_build_cluster_b(nav_region, noise, hs)
	_build_inn(nav_region, noise, hs)
	_build_well(nav_region, noise, hs)
	_build_new_houses(nav_region, noise, hs)


static func _build_houses(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var house_configs: Array = [
		{"pos": Vector3(-62, 0, -20), "size": Vector3(4, 3, 4),   "color": Color(0.6, 0.53, 0.42),  "roof": Color(0.38, 0.22, 0.14), "chimney": true,  "rot_y": 0.0},
		{"pos": Vector3(-38, 0, -40), "size": Vector3(4.5, 3, 4), "color": Color(0.57, 0.5, 0.38),  "roof": Color(0.42, 0.24, 0.16), "chimney": false, "rot_y": 0.0},
		{"pos": Vector3(-53, 0, -21), "size": Vector3(4, 3, 4),   "color": Color(0.65, 0.58, 0.45), "roof": Color(0.45, 0.25, 0.15), "chimney": false, "rot_y": 0.15},
		{"pos": Vector3(-62, 0, -33), "size": Vector3(5, 3.5, 5), "color": Color(0.6, 0.55, 0.42),  "roof": Color(0.35, 0.2, 0.15),  "chimney": true, "rot_y": PI / 2},
		{"pos": Vector3(-46, 0, -42), "size": Vector3(4.5, 3, 4), "color": Color(0.62, 0.56, 0.48), "roof": Color(0.4, 0.22, 0.12),  "chimney": false, "rot_y": -0.1},
		{"pos": Vector3(-34, 0, -21), "size": Vector3(4, 3, 4.5), "color": Color(0.58, 0.52, 0.4),  "roof": Color(0.3, 0.3, 0.3),   "chimney": true, "rot_y": 0.0},
		{"pos": Vector3(-51, 0, -43), "size": Vector3(5, 3, 4),   "color": Color(0.55, 0.5, 0.4),   "roof": Color(0.42, 0.2, 0.12),  "chimney": false, "rot_y": PI / 2},
	]
	for cfg: Dictionary in house_configs:
		var p: Vector3 = cfg["pos"]
		BuildingHelper.create_building(nav_region,
			Vector3(p.x, BuildingHelper.snap_y(noise, p.x, p.z, hs), p.z),
			cfg["size"], cfg["color"], "peaked", cfg["roof"], 0.5, cfg["chimney"], true, cfg.get("rot_y", 0.0))


static func _build_cluster_b(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# B1 Boarding House
	BuildingHelper.create_building(nav_region,
		Vector3(-47, BuildingHelper.snap_y(noise, -47, -14, hs), -14),
		Vector3(3.5, 3, 3), Color(0.60, 0.52, 0.40), "peaked", Color(0.40, 0.24, 0.16), 0.5, true, false)

	# B2 Tailor Shop
	BuildingHelper.create_building(nav_region,
		Vector3(-41, BuildingHelper.snap_y(noise, -41, -14, hs), -14),
		Vector3(3.5, 3, 3), Color(0.56, 0.48, 0.36), "peaked", Color(0.36, 0.22, 0.14), 0.5, false, true)

	# B3 Cobbler
	BuildingHelper.create_building(nav_region,
		Vector3(-36, BuildingHelper.snap_y(noise, -36, -14, hs), -14),
		Vector3(3, 3, 3), Color(0.54, 0.46, 0.34), "peaked", Color(0.38, 0.24, 0.16), 0.5, false, true)


static func _build_inn(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var inn_pos := Vector3(-45, 0, -30)
	var inn_y: float = BuildingHelper.snap_y(noise, inn_pos.x, inn_pos.z, hs)

	# Ground floor
	BuildingHelper.create_building(nav_region,
		Vector3(inn_pos.x, inn_y, inn_pos.z),
		Vector3(7, 3, 6), Color(0.5, 0.38, 0.25), "flat", Color(0.35, 0.28, 0.2), 0.3)

	# Upper floor (slightly smaller)
	var upper := MeshInstance3D.new()
	var upper_mesh := BoxMesh.new()
	upper_mesh.size = Vector3(6.5, 2.5, 5.5)
	upper.mesh = upper_mesh
	upper.position = Vector3(inn_pos.x, inn_y + 4.25, inn_pos.z)
	var inn_mat := StandardMaterial3D.new()
	inn_mat.albedo_color = Color(0.52, 0.4, 0.28)
	upper.set_surface_override_material(0, inn_mat)
	nav_region.add_child(upper)

	# Peaked roof
	var inn_roof := MeshInstance3D.new()
	var inn_roof_mesh := BoxMesh.new()
	inn_roof_mesh.size = Vector3(7.0, 0.3, 6.0)
	inn_roof.mesh = inn_roof_mesh
	inn_roof.position = Vector3(inn_pos.x, inn_y + 5.65, inn_pos.z)
	var inn_roof_mat := StandardMaterial3D.new()
	inn_roof_mat.albedo_color = Color(0.4, 0.18, 0.1)
	inn_roof.set_surface_override_material(0, inn_roof_mat)
	nav_region.add_child(inn_roof)


static func _build_new_houses(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Houses 8-12: southern residential expansion
	var house_configs: Array = [
		{"pos": Vector3(-28, 0, -30), "size": Vector3(4, 3, 4),     "color": Color(0.58, 0.50, 0.40), "roof": Color(0.40, 0.24, 0.16), "type": "house"},
		{"pos": Vector3(-58, 0, -42), "size": Vector3(4, 3, 3.5),   "color": Color(0.55, 0.48, 0.38), "roof": Color(0.38, 0.22, 0.14), "type": "house"},
		{"pos": Vector3(-32, 0, -35), "size": Vector3(3.5, 3, 3.5), "color": Color(0.60, 0.52, 0.42), "roof": Color(0.42, 0.25, 0.15), "type": "house"},
		{"pos": Vector3(-40, 0, -28), "size": Vector3(4, 3, 4),     "color": Color(0.56, 0.50, 0.38), "roof": Color(0.36, 0.20, 0.12), "type": "house"},
		{"pos": Vector3(-55, 0, -30), "size": Vector3(4, 3, 3.5),   "color": Color(0.62, 0.55, 0.45), "roof": Color(0.44, 0.26, 0.16), "type": "house"},
	]
	for cfg: Dictionary in house_configs:
		var p: Vector3 = cfg["pos"]
		BuildingHelper.create_building(nav_region,
			Vector3(p.x, BuildingHelper.snap_y(noise, p.x, p.z, hs), p.z),
			cfg["size"], cfg["color"], "peaked", cfg["roof"], 0.5, false, true, 0.0, cfg["type"])

	# Midwife Hut
	var mh: Vector3 = Vector3(-28, 0, -45)
	BuildingHelper.create_building(nav_region,
		Vector3(mh.x, BuildingHelper.snap_y(noise, mh.x, mh.z, hs), mh.z),
		Vector3(3, 2.5, 3), Color(0.52, 0.55, 0.48), "peaked", Color(0.25, 0.35, 0.20), 0.5, false, true, 0.0, "artisan_hut")

	# Woodcarver
	var wc: Vector3 = Vector3(-65, 0, -42)
	BuildingHelper.create_building(nav_region,
		Vector3(wc.x, BuildingHelper.snap_y(noise, wc.x, wc.z, hs), wc.z),
		Vector3(3.5, 3, 3), Color(0.50, 0.42, 0.32), "peaked", Color(0.38, 0.28, 0.18), 0.5, false, true, 0.0, "artisan_hut")

	# Wash House
	var wh: Vector3 = Vector3(-48, 0, -35)
	BuildingHelper.create_building(nav_region,
		Vector3(wh.x, BuildingHelper.snap_y(noise, wh.x, wh.z, hs), wh.z),
		Vector3(4, 2.5, 3.5), Color(0.55, 0.52, 0.48), "flat", Color(0.38, 0.35, 0.30), 0.5, false, true, 0.0, "utility")


static func _build_well(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	var well := Node3D.new()
	well.position = Vector3(-42, BuildingHelper.snap_y(noise, -42, -35, hs), -35)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.5, 0.47, 0.42)
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.4, 0.3, 0.2)

	# Basin ring
	var basin := MeshInstance3D.new()
	var basin_mesh := CylinderMesh.new()
	basin_mesh.top_radius = 0.8
	basin_mesh.bottom_radius = 0.8
	basin_mesh.height = 0.6
	basin_mesh.rings = 1
	basin.mesh = basin_mesh
	basin.position = Vector3(0, 0.3, 0)
	basin.set_surface_override_material(0, stone_mat)
	well.add_child(basin)

	# Two vertical posts
	for px: float in [-0.6, 0.6]:
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.06
		post_mesh.bottom_radius = 0.08
		post_mesh.height = 1.6
		post.mesh = post_mesh
		post.position = Vector3(px, 1.4, 0)
		post.set_surface_override_material(0, wood_mat)
		well.add_child(post)

	# Crossbar
	var crossbar := MeshInstance3D.new()
	var cb_mesh := BoxMesh.new()
	cb_mesh.size = Vector3(1.4, 0.1, 0.1)
	crossbar.mesh = cb_mesh
	crossbar.position = Vector3(0, 2.25, 0)
	crossbar.set_surface_override_material(0, wood_mat)
	well.add_child(crossbar)

	# Collision
	var well_body := StaticBody3D.new()
	var well_col := CollisionShape3D.new()
	var well_shape := CylinderShape3D.new()
	well_shape.radius = 0.8
	well_shape.height = 0.6
	well_col.shape = well_shape
	well_body.position = Vector3(0, 0.3, 0)
	well_body.add_child(well_col)
	well.add_child(well_body)

	nav_region.add_child(well)
