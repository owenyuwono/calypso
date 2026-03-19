extends Node3D
## West field zone — tougher than east field (wolves, skeletons, dark mages).
## Terrain center: (-110, 0, 0), extents x:-150..-70, z:-40..40.

const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")

var zone_id: String = "west_field"

signal zone_ready

func _ready() -> void:
	# Register west field location markers
	for marker in $LocationMarkers.get_children():
		WorldState.register_location(marker.name, marker.global_position)

	# Create shared context for builder utilities
	var ctx: WorldBuilderContext = WorldBuilderContext.new()
	ctx.nav_region = $NavigationRegion3D
	ctx.world_root = self

	# Build west field terrain
	_build_terrain(ctx)

	# Scatter west field vegetation, trees, and mineable rocks
	FieldBuilder.decorate_west_biomes(ctx)

	# Create zone portals
	_create_portals()

	# Bake navmesh after environment is ready
	var nav_region: NavigationRegion3D = $NavigationRegion3D
	nav_region.bake_finished.connect(_on_navmesh_baked)
	await get_tree().create_timer(0.5).timeout
	nav_region.bake_navigation_mesh()


func _on_navmesh_baked() -> void:
	var nav_mesh: NavigationMesh = $NavigationRegion3D.navigation_mesh
	var poly_count: int = nav_mesh.get_polygon_count()
	if poly_count == 0:
		push_warning("[NavMesh] WARNING: West field navmesh is EMPTY!")
	emit_signal("zone_ready")


func _build_terrain(ctx: WorldBuilderContext) -> void:
	# Shared noise matching game_world defaults
	var terrain_noise: FastNoiseLite = FastNoiseLite.new()
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.05
	terrain_noise.fractal_octaves = 2
	terrain_noise.seed = 42
	ctx.terrain_noise = terrain_noise

	# Load terrain shader + textures
	var terrain_shader: Shader = load("res://assets/shaders/terrain_blend.gdshader") as Shader
	var tex_grass: Texture2D = load("res://assets/textures/terrain/grass_town.png") as Texture2D
	var tex_dirt: Texture2D = load("res://assets/textures/terrain/dirt_albedo.png") as Texture2D
	var tex_stone: Texture2D = load("res://assets/textures/terrain/stone_albedo.png") as Texture2D

	var terrain_data: Dictionary = TerrainGenerator.generate_terrain(
		Vector3(-110, 0, 0), Vector2(80, 80), Vector2i(40, 40),
		terrain_noise, ctx.terrain_height_scale_field, _west_field_terrain_rules()
	)

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = terrain_shader
	mat.set_shader_parameter("texture_grass", tex_grass)
	mat.set_shader_parameter("texture_dirt", tex_dirt)
	mat.set_shader_parameter("texture_stone", tex_stone)
	mat.set_shader_parameter("uv_scale_pavement", 0.5)
	mat.set_shader_parameter("uv_scale_dirt", 0.25)
	mat.set_shader_parameter("uv_scale_stone", 0.2)
	mat.set_shader_parameter("uv_scale_cobble", 0.5)
	mat.set_shader_parameter("uv_scale_earth", 0.5)
	mat.set_shader_parameter("blend_sharpness", 1.5)

	var mi: MeshInstance3D = terrain_data["mesh_instance"]
	mi.mesh.surface_set_material(0, mat)
	$NavigationRegion3D.add_child(mi)
	$NavigationRegion3D.add_child(terrain_data["static_body"])


func _west_field_terrain_rules() -> Array:
	return [
		# Flatten west field terrain at gate boundary so heights match city terrain
		{"type": "flatten", "center": Vector2(-75, 0), "radius": 8.0},
		{"type": "line", "start": Vector2(-70, 0), "end": Vector2(-100, 0), "width": 1.5, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(-100, 0), "end": Vector2(-145, 0), "width": 1.5, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(-100, 0), "end": Vector2(-110, 25), "width": 1.0, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(-100, 0), "end": Vector2(-120, -20), "width": 1.0, "channel": 0, "falloff": 0.5},
		# Rocky clearing — exposed stone
		{"type": "circle", "center": Vector2(-130, -20), "radius": 8.0, "channel": 1, "falloff": 2.0, "noise_perturb": 0.25},
		{"type": "circle", "center": Vector2(-140, -25), "radius": 5.0, "channel": 1, "falloff": 1.5, "noise_perturb": 0.25},
	]


func _create_portals() -> void:
	var portals: Array = ZoneDatabase.get_portals("west_field")
	for portal_def in portals:
		var portal: Area3D = Area3D.new()
		portal.set_script(preload("res://scripts/world/zone_portal.gd"))
		add_child(portal)
		portal.setup(portal_def)
