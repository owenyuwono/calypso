extends Node3D
## East Field zone scene — terrain, biome decorations, monster spawners, and city portal.
## Loaded by ZoneManager when the player passes through the east gate.

const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")

var zone_id: String = "east_field"

signal zone_ready

func _ready() -> void:
	# Register field location markers with WorldState
	var markers: Node3D = $LocationMarkers
	for marker in markers.get_children():
		WorldState.register_location(marker.name, marker.global_position)

	# Shared context for builder utilities
	var ctx: WorldBuilderContext = WorldBuilderContext.new()
	ctx.nav_region = $NavigationRegion3D
	ctx.world_root = self

	# Build terrain, decorate biomes, then create portals
	_build_terrain(ctx)
	BiomeScatter.setup_exclusion_zones(ctx)
	FieldBuilder.decorate_east_biomes(ctx)
	_create_portals()

	# Bake navmesh — emit zone_ready after bake so ZoneManager can await it
	await get_tree().create_timer(0.5).timeout
	TerrainHelpers.begin_navmesh_bake($NavigationRegion3D, _on_navmesh_baked)


func _on_navmesh_baked() -> void:
	var nav_mesh: NavigationMesh = $NavigationRegion3D.navigation_mesh
	var poly_count: int = nav_mesh.get_polygon_count()
	if poly_count == 0:
		push_warning("[NavMesh][EastField] WARNING: Navmesh is EMPTY!")
	zone_ready.emit()


func _build_terrain(ctx: WorldBuilderContext) -> void:
	# Shared noise — same seed as game_world so height continuity holds at the gate boundary
	ctx.terrain_noise = TerrainHelpers.create_terrain_noise()

	# Textures — east field uses grass base with dirt and stone channels only
	var terrain_shader: Shader = load("res://assets/shaders/terrain_blend.gdshader") as Shader
	var tex_grass: Texture2D = load("res://assets/textures/terrain/grass_town.png") as Texture2D
	var tex_dirt: Texture2D = load("res://assets/textures/terrain/dirt_albedo.png") as Texture2D
	var tex_stone: Texture2D = load("res://assets/textures/terrain/stone_albedo.png") as Texture2D

	var field: Dictionary = TerrainGenerator.generate_terrain(
		Vector3(110, 0, 0), Vector2(80, 80), Vector2i(40, 40),
		ctx.terrain_noise, ctx.terrain_height_scale_field, _field_terrain_rules()
	)

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = terrain_shader
	mat.set_shader_parameter("texture_grass", tex_grass)
	mat.set_shader_parameter("texture_dirt", tex_dirt)
	mat.set_shader_parameter("texture_stone", tex_stone)
	TerrainHelpers.apply_standard_shader_params(mat)

	var mi: MeshInstance3D = field["mesh_instance"]
	mi.mesh.surface_set_material(0, mat)
	$NavigationRegion3D.add_child(mi)
	$NavigationRegion3D.add_child(field["static_body"])


func _field_terrain_rules() -> Array:
	return [
		# Flatten at gate boundary so heights match city terrain
		{"type": "flatten", "center": Vector2(75, 0), "radius": 8.0},
		# Main E-W dirt path
		{"type": "line", "start": Vector2(70, 0), "end": Vector2(100, 0), "width": 1.5, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(100, 0), "end": Vector2(145, 0), "width": 1.5, "channel": 0, "falloff": 0.5},
		# Branching dirt paths off the main route
		{"type": "line", "start": Vector2(100, 0), "end": Vector2(110, 25), "width": 1.0, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(100, 0), "end": Vector2(120, -20), "width": 1.0, "channel": 0, "falloff": 0.5},
		# Rocky clearing — exposed stone (channel 1)
		{"type": "circle", "center": Vector2(130, -20), "radius": 8.0, "channel": 1, "falloff": 2.0, "noise_perturb": 0.25},
		{"type": "circle", "center": Vector2(140, -25), "radius": 5.0, "channel": 1, "falloff": 1.5, "noise_perturb": 0.25},
	]


func _create_portals() -> void:
	TerrainHelpers.create_portals(self, zone_id)
