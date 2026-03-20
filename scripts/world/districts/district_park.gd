## Park/Gardens district builder (x:25..70, z:-50..-10).
class_name DistrictPark

const BuildingHelper = preload("res://scripts/world/building_helper.gd")
const AmbientEmitterScript = preload("res://scripts/audio/ambient_emitter.gd")


static func build(ctx: WorldBuilderContext) -> void:
	var nav_region: Node = ctx.nav_region
	var noise: FastNoiseLite = ctx.terrain_noise
	var hs: float = ctx.terrain_height_scale_city
	_build_fountain(ctx, nav_region, noise, hs)
	_build_benches(ctx, nav_region, noise, hs)
	_build_gardener_cottage(ctx, nav_region, noise, hs)
	_build_gazebo(ctx, nav_region, noise, hs)
	_build_herbalist_shop(ctx, nav_region, noise, hs)
	_build_greenhouse(ctx, nav_region, noise, hs)
	_build_groundskeeper_lodge(ctx, nav_region, noise, hs)
	_build_pond_pavilion(ctx, nav_region, noise, hs)
	_build_garden_storage(ctx, nav_region, noise, hs)
	_build_ambient_emitters(nav_region, noise, hs)


static func _build_ambient_emitters(nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	# Birds near the gazebo and open green space
	var birds_pos: Vector3 = Vector3(45, BuildingHelper.snap_y(noise, 45, -30, hs), -30)
	var birds_emitter: Node3D = AmbientEmitterScript.new()
	nav_region.add_child(birds_emitter)
	birds_emitter.global_position = birds_pos
	birds_emitter.setup("res://assets/audio/ambient/birds_day.ogg", ["dawn", "day", "dusk"], -6.0, 30.0)

	# Crickets at night — same general area
	var crickets_pos: Vector3 = Vector3(45, BuildingHelper.snap_y(noise, 45, -30, hs), -30)
	var crickets_emitter: Node3D = AmbientEmitterScript.new()
	nav_region.add_child(crickets_emitter)
	crickets_emitter.global_position = crickets_pos
	crickets_emitter.setup("res://assets/audio/ambient/crickets_night.ogg", ["night", "dusk"], -6.0, 30.0)


static func _build_fountain(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var pos := Vector3(45, BuildingHelper.snap_y(noise, 45, -30, hs), -30)
	BuildingHelper.create_fountain(ctx, nav_region, pos, 2.0, 0.5, 1.5, 1.0)


static func _build_benches(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var bench_spots: Array = [
		Vector3(40, 0, -25), Vector3(50, 0, -25),
		Vector3(40, 0, -35), Vector3(50, 0, -35),
		Vector3(35, 0, -30), Vector3(55, 0, -30),
	]
	for bp: Vector3 in bench_spots:
		var world_pos := Vector3(bp.x, BuildingHelper.snap_y(noise, bp.x, bp.z, hs) + 0.2, bp.z)
		BuildingHelper.create_bench(ctx, nav_region, world_pos)


static func _build_gardener_cottage(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(40, BuildingHelper.snap_y(noise, 40, -38, hs), -38),
		Vector3(3.5, 3, 3.5), Color(0.52, 0.48, 0.40), "peaked", Color(0.38, 0.24, 0.16), 0.5, true, false)


static func _build_gazebo(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var gazebo := Node3D.new()
	var gz_y: float = BuildingHelper.snap_y(noise, 35, -20, hs)
	gazebo.position = Vector3(35, gz_y, -20)

	var gz_post_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.55, 0.45, 0.3))
	var gz_roof_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.38, 0.3, 0.22))

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
		gz_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gazebo.add_child(gz_post)

	# Flat roof
	var gz_roof := MeshInstance3D.new()
	var gz_roof_mesh := BoxMesh.new()
	gz_roof_mesh.size = Vector3(3.6, 0.15, 3.6)
	gz_roof.mesh = gz_roof_mesh
	gz_roof.position = Vector3(0, 2.575, 0)
	gz_roof.set_surface_override_material(0, gz_roof_mat)
	gz_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gazebo.add_child(gz_roof)

	nav_region.add_child(gazebo)


static func _build_herbalist_shop(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var pos := Vector3(30, BuildingHelper.snap_y(noise, 30, -15, hs), -15)
	BuildingHelper.create_building(ctx, nav_region, pos,
		Vector3(4, 3, 3.5), Color(0.48, 0.55, 0.42), "peaked", Color(0.25, 0.38, 0.18),
		0.5, false, true, 0.0, "shop")

	# Torches flanking the door
	var torch_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.35, 0.28, 0.20))
	var flame_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(1.0, 0.55, 0.1))
	for side: int in [-1, 1]:
		var torch := MeshInstance3D.new()
		var torch_mesh := CylinderMesh.new()
		torch_mesh.top_radius = 0.06
		torch_mesh.bottom_radius = 0.08
		torch_mesh.height = 0.7
		torch.mesh = torch_mesh
		torch.position = Vector3(pos.x + side * 0.65, pos.y + 1.0, pos.z + 1.85)
		torch.set_surface_override_material(0, torch_mat)
		torch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(torch)

		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.1
		flame_mesh.height = 0.2
		flame.mesh = flame_mesh
		flame.position = Vector3(pos.x + side * 0.65, pos.y + 1.42, pos.z + 1.85)
		flame.set_surface_override_material(0, flame_mat)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(flame)


static func _build_greenhouse(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	var pos := Vector3(55, BuildingHelper.snap_y(noise, 55, -25, hs), -25)
	BuildingHelper.create_building(ctx, nav_region, pos,
		Vector3(5, 3, 4), Color(0.50, 0.58, 0.48), "flat", Color(0.35, 0.42, 0.32),
		0.5, false, true, 0.0, "greenhouse")

	# Torches flanking the door
	var torch_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.35, 0.28, 0.20))
	var flame_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(1.0, 0.55, 0.1))
	for side: int in [-1, 1]:
		var torch := MeshInstance3D.new()
		var torch_mesh := CylinderMesh.new()
		torch_mesh.top_radius = 0.06
		torch_mesh.bottom_radius = 0.08
		torch_mesh.height = 0.7
		torch.mesh = torch_mesh
		torch.position = Vector3(pos.x + side * 0.7, pos.y + 1.0, pos.z + 2.1)
		torch.set_surface_override_material(0, torch_mat)
		torch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(torch)

		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.1
		flame_mesh.height = 0.2
		flame.mesh = flame_mesh
		flame.position = Vector3(pos.x + side * 0.7, pos.y + 1.42, pos.z + 2.1)
		flame.set_surface_override_material(0, flame_mat)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nav_region.add_child(flame)


static func _build_groundskeeper_lodge(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(60, BuildingHelper.snap_y(noise, 60, -40, hs), -40),
		Vector3(4, 3, 4), Color(0.52, 0.46, 0.38), "peaked", Color(0.38, 0.25, 0.16),
		0.5, false, true, 0.0, "lodge")


static func _build_pond_pavilion(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(50, BuildingHelper.snap_y(noise, 50, -40, hs), -40),
		Vector3(3, 2.5, 3), Color(0.50, 0.45, 0.38), "flat", Color(0.35, 0.30, 0.25),
		0.5, false, true, 0.0, "pavilion")

	# Bench near the pavilion
	var bench_pos := Vector3(50, BuildingHelper.snap_y(noise, 50, -43, hs) + 0.2, -43)
	BuildingHelper.create_bench(ctx, nav_region, bench_pos)


static func _build_garden_storage(ctx: WorldBuilderContext, nav_region: Node, noise: FastNoiseLite, hs: float) -> void:
	BuildingHelper.create_building(ctx, nav_region,
		Vector3(30, BuildingHelper.snap_y(noise, 30, -42, hs), -42),
		Vector3(3, 2.5, 3), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28),
		0.5, false, false, 0.0, "shed")
