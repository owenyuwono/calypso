## City Gate Area district builder (x:55..70, z:-10..10).
class_name DistrictGate

const BuildingHelper = preload("res://scripts/world/building_helper.gd")


static func build(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	_build_cluster_f(nav_region, noise, hs)
	_build_guard_posts(nav_region, noise, hs)
	_build_gatehouse_storage(nav_region, noise, hs)


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
