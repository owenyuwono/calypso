extends Node3D
## Minimal placeholder suburb zone. Flat grassy area for game boot testing.

signal zone_ready

const ZombieSpawner = preload("res://scenes/enemies/zombie_spawner.gd")
const BuildingHelper = preload("res://scripts/world/building_helper.gd")
const AssetSpawner = preload("res://scripts/world/asset_spawner.gd")

const ZONE_SIZE: float = 100.0

var zone_id: String = "suburb"

var _nav_region: NavigationRegion3D
var _ctx: WorldBuilderContext

func _ready() -> void:
	_build_lighting()
	_build_nav_region()    # creates region only, NO bake
	_build_terrain()       # terrain under _nav_region
	_build_suburb_lot()    # house + fences under _nav_region
	_add_location_markers()
	_bake_navmesh_async(_nav_region)  # bake LAST

func _build_lighting() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.rotation_degrees = Vector3(-55.0, -45.0, 0.0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.shadow_enabled = true
	add_child(sun)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.529, 0.706, 0.878)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.ambient_light_energy = 0.25
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.72, 0.65)
	env.fog_density = 0.002
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

func _build_terrain() -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Terrain"

	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(ZONE_SIZE, ZONE_SIZE)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	mesh_instance.mesh = plane

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.55, 0.25)
	mesh_instance.material_override = mat

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "TerrainCollider"
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(ZONE_SIZE, 0.1, ZONE_SIZE)
	col.shape = shape
	body.add_child(col)

	_nav_region.add_child(mesh_instance)
	_nav_region.add_child(body)

func _build_nav_region() -> void:
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "NavigationRegion3D"

	var nav_mesh: NavigationMesh = NavigationMesh.new()
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_radius = 0.5
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.2
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	_nav_region.navigation_mesh = nav_mesh

	add_child(_nav_region)

func _bake_navmesh_async(nav_region: NavigationRegion3D) -> void:
	await get_tree().physics_frame
	nav_region.bake_finished.connect(_on_navmesh_baked, CONNECT_ONE_SHOT)
	nav_region.bake_navigation_mesh(true)

func _on_navmesh_baked() -> void:
	zone_ready.emit()
	_spawn_zombies()


func _spawn_zombies() -> void:
	var spawner: Node = ZombieSpawner.new()
	add_child(spawner)
	spawner.add_exclusion_zone(Vector3.ZERO, 18.0)  # keep zombies out of the 20x30 lot
	spawner.setup(self, Vector3.ZERO, 6, 45.0)

func _build_suburb_lot() -> void:
	_ctx = WorldBuilderContext.new()
	_ctx.nav_region = _nav_region
	_ctx.world_root = self

	# House: 12x10m, centered at front of lot
	BuildingHelper.create_building(
		_ctx, _nav_region, Vector3(0, 0, 6),
		Vector3(12, 3.5, 10),
		Color(0.82, 0.75, 0.65),  # beige walls
		"peaked",
		Color(0.45, 0.3, 0.18),  # brown roof
		1.0, true, true, 0.0, ""
	)

	# Fence around 20x30m lot perimeter (x: ±10, z: -15 to +15)
	var fence_h: float = 1.5
	var fence_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(_ctx, Color(0.55, 0.4, 0.25))

	# Front (with 4m gate gap centered)
	_build_fence_segment(_nav_region, Vector3(-10, 0, 15), Vector3(-2, 0, 15), fence_h, fence_mat)
	_build_fence_segment(_nav_region, Vector3(2, 0, 15), Vector3(10, 0, 15), fence_h, fence_mat)
	# Back
	_build_fence_segment(_nav_region, Vector3(-10, 0, -15), Vector3(10, 0, -15), fence_h, fence_mat)
	# Left side
	_build_fence_segment(_nav_region, Vector3(-10, 0, -15), Vector3(-10, 0, 15), fence_h, fence_mat)
	# Right side
	_build_fence_segment(_nav_region, Vector3(10, 0, -15), Vector3(10, 0, 15), fence_h, fence_mat)

func _build_fence_segment(parent: Node3D, start: Vector3, end: Vector3, height: float, mat: StandardMaterial3D) -> void:
	var diff: Vector3 = end - start
	var length: float = Vector2(diff.x, diff.z).length()
	var center: Vector3 = (start + end) / 2.0
	center.y = height / 2.0

	var body := StaticBody3D.new()
	body.position = center
	body.rotation.y = -atan2(diff.z, diff.x)

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, height, 0.15)
	mesh_inst.mesh = box
	mesh_inst.set_surface_override_material(0, mat)
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, height, 0.15)
	col.shape = shape
	body.add_child(col)

	parent.add_child(body)

func _add_location_markers() -> void:
	var markers: Node3D = Node3D.new()
	markers.name = "LocationMarkers"

	var spawn: Node3D = Node3D.new()
	spawn.name = "spawn"
	spawn.position = Vector3(0, 0, 19)
	markers.add_child(spawn)

	add_child(markers)
