## City Gate Area district builder — east, north, and south gate areas.
class_name DistrictGate

const BuildingHelper = preload("res://scripts/world/building_helper.gd")


static func build(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	_build_cluster_f(nav_region, noise, hs)
	_build_guard_posts(nav_region, noise, hs)
	_build_gatehouse_storage(nav_region, noise, hs)
	_build_east_gate_expansion(nav_region, noise, hs)
	_build_north_gate(nav_region, noise, hs)
	_build_south_gate(nav_region, noise, hs)


static func _build_cluster_f(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# F1 Waystation
	BuildingHelper.create_building(nav_region,
		Vector3(49, BuildingHelper.snap_y(noise, 49, -4, hs), -4),
		Vector3(3.5, 3, 3), Color(0.50, 0.46, 0.40), "flat", Color(0.36, 0.32, 0.28), 0.5, false, true)

	# F2 Gatehouse Office
	BuildingHelper.create_building(nav_region,
		Vector3(55, BuildingHelper.snap_y(noise, 55, -4, hs), -4),
		Vector3(3.5, 3, 3), Color(0.48, 0.44, 0.38), "flat", Color(0.34, 0.30, 0.26), 0.5, false, true)


static func _build_guard_posts(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(nav_region,
		Vector3(65, BuildingHelper.snap_y(noise, 65, -7, hs), -7),
		Vector3(2, 2.5, 2), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28), 0.2)
	BuildingHelper.create_building(nav_region,
		Vector3(65, BuildingHelper.snap_y(noise, 65, 7, hs), 7),
		Vector3(2, 2.5, 2), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28), 0.2)


static func _build_gatehouse_storage(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(nav_region,
		Vector3(60, BuildingHelper.snap_y(noise, 60, -7, hs), -7),
		Vector3(3, 2.5, 3), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28), 0.3, false, false)


static func _build_east_gate_expansion(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Customs House
	BuildingHelper.create_building(nav_region,
		Vector3(56, BuildingHelper.snap_y(noise, 56, 4, hs), 4),
		Vector3(4, 3, 3.5), Color(0.50, 0.46, 0.40), "flat", Color(0.36, 0.32, 0.28),
		0.5, false, true, 0.0, "customs")

	# Gate Inn
	BuildingHelper.create_building(nav_region,
		Vector3(49, BuildingHelper.snap_y(noise, 49, 4, hs), 4),
		Vector3(4, 3, 4), Color(0.52, 0.44, 0.35), "peaked", Color(0.38, 0.25, 0.16),
		0.5, false, true, 0.0, "inn")

	# Toll Booth
	BuildingHelper.create_building(nav_region,
		Vector3(62, BuildingHelper.snap_y(noise, 62, 4, hs), 4),
		Vector3(2.5, 2.5, 2), Color(0.48, 0.44, 0.40), "flat", Color(0.35, 0.32, 0.28),
		0.5, false, true, 0.0, "toll_booth")


static func _build_north_gate(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# North Guard Post W
	BuildingHelper.create_building(nav_region,
		Vector3(-3, BuildingHelper.snap_y(noise, -3, -47, hs), -47),
		Vector3(2, 2.5, 2), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28),
		0.2, false, true, 0.0, "guard_post")

	# North Guard Post E
	BuildingHelper.create_building(nav_region,
		Vector3(3, BuildingHelper.snap_y(noise, 3, -47, hs), -47),
		Vector3(2, 2.5, 2), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28),
		0.2, false, true, 0.0, "guard_post")

	# North Waystation
	BuildingHelper.create_building(nav_region,
		Vector3(-8, BuildingHelper.snap_y(noise, -8, -46, hs), -46),
		Vector3(3.5, 3, 3), Color(0.50, 0.46, 0.40), "flat", Color(0.36, 0.32, 0.28),
		0.5, false, true, 0.0, "waystation")

	# North Toll Office
	BuildingHelper.create_building(nav_region,
		Vector3(8, BuildingHelper.snap_y(noise, 8, -46, hs), -46),
		Vector3(3, 2.5, 3), Color(0.48, 0.44, 0.40), "flat", Color(0.34, 0.30, 0.26),
		0.5, false, true, 0.0, "toll_booth")


static func _build_south_gate(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# South Guard Post W
	BuildingHelper.create_building(nav_region,
		Vector3(-3, BuildingHelper.snap_y(noise, -3, 47, hs), 47),
		Vector3(2, 2.5, 2), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28),
		0.2, false, true, 0.0, "guard_post")

	# South Guard Post E
	BuildingHelper.create_building(nav_region,
		Vector3(3, BuildingHelper.snap_y(noise, 3, 47, hs), 47),
		Vector3(2, 2.5, 2), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28),
		0.2, false, true, 0.0, "guard_post")

	# South Waystation
	BuildingHelper.create_building(nav_region,
		Vector3(-8, BuildingHelper.snap_y(noise, -8, 46, hs), 46),
		Vector3(3.5, 3, 3), Color(0.50, 0.46, 0.40), "flat", Color(0.36, 0.32, 0.28),
		0.5, false, true, 0.0, "waystation")

	# South Customs
	BuildingHelper.create_building(nav_region,
		Vector3(8, BuildingHelper.snap_y(noise, 8, 46, hs), 46),
		Vector3(3, 2.5, 3), Color(0.48, 0.44, 0.40), "flat", Color(0.34, 0.30, 0.26),
		0.5, false, true, 0.0, "customs")
