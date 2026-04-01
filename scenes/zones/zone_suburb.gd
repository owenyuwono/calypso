extends Node3D
## Minimal placeholder suburb zone. Flat grassy area for game boot testing.

signal zone_ready

const ZONE_SIZE: float = 100.0

var zone_id: String = "suburb"

func _ready() -> void:
	_build_lighting()
	_build_terrain()
	_build_nav_region()
	_add_location_markers()

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

	add_child(mesh_instance)
	add_child(body)

func _build_nav_region() -> void:
	var nav_region: NavigationRegion3D = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"

	var nav_mesh: NavigationMesh = NavigationMesh.new()
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_radius = 0.5
	nav_mesh.cell_size = 0.25
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_region.navigation_mesh = nav_mesh

	add_child(nav_region)

	# Bake after one physics frame so geometry is registered with the physics server
	_bake_navmesh_async(nav_region)

func _bake_navmesh_async(nav_region: NavigationRegion3D) -> void:
	await get_tree().physics_frame
	nav_region.bake_finished.connect(_on_navmesh_baked, CONNECT_ONE_SHOT)
	nav_region.bake_navigation_mesh(true)

func _on_navmesh_baked() -> void:
	zone_ready.emit()

func _add_location_markers() -> void:
	var markers: Node3D = Node3D.new()
	markers.name = "LocationMarkers"

	var spawn: Node3D = Node3D.new()
	spawn.name = "spawn"
	spawn.position = Vector3.ZERO
	markers.add_child(spawn)

	add_child(markers)
