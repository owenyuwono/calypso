extends Node3D
## West field zone — tougher than east field (wolves, skeletons, dark mages).
## Terrain center: (-110, 0, 0), extents x:-150..-70, z:-40..40.

const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")
const AssetSpawner = preload("res://scripts/world/asset_spawner.gd")

var zone_id: String = "west_field"

# Rocky Clearing biome: bounds [-147, -32, 30, 22] → x: -162..-132, z: -43..-21
const _ROCK_BIOME_BOUNDS: Rect2 = Rect2(-162.0, -43.0, 30.0, 22.0)
const _ROCK_TIER_SCALES: Dictionary = {"copper": 1.0, "iron": 1.1, "gold": 1.2}

var _ctx: WorldBuilderContext = null

signal zone_ready

func _ready() -> void:
	# Register west field location markers
	for marker in $LocationMarkers.get_children():
		WorldState.register_location(marker.name, marker.global_position)

	# Create shared context for builder utilities
	_ctx = WorldBuilderContext.new()
	_ctx.nav_region = $NavigationRegion3D
	_ctx.world_root = self

	# Build west field terrain
	_build_terrain(_ctx)

	# Setup exclusion zones and scatter west field vegetation, trees, and mineable rocks
	BiomeScatter.setup_exclusion_zones(_ctx)
	FieldBuilder.decorate_west_biomes(_ctx)
	_connect_rock_signals($NavigationRegion3D)

	# Create zone portals
	_create_portals()

	# Bake navmesh after environment is ready
	await get_tree().create_timer(0.5).timeout
	TerrainHelpers.begin_navmesh_bake($NavigationRegion3D, _on_navmesh_baked)


func _on_navmesh_baked() -> void:
	var nav_mesh: NavigationMesh = $NavigationRegion3D.navigation_mesh
	var poly_count: int = nav_mesh.get_polygon_count()
	if poly_count == 0:
		push_warning("[NavMesh] WARNING: West field navmesh is EMPTY!")
	zone_ready.emit()


func _build_terrain(ctx: WorldBuilderContext) -> void:
	# Shared noise matching game_world defaults
	ctx.terrain_noise = TerrainHelpers.create_terrain_noise()

	# Load terrain shader + textures
	var terrain_shader: Shader = load("res://assets/shaders/terrain_blend.gdshader") as Shader
	var tex_grass: Texture2D = load("res://assets/textures/terrain/grass_town.png") as Texture2D
	var tex_dirt: Texture2D = load("res://assets/textures/terrain/dirt_albedo.png") as Texture2D
	var tex_stone: Texture2D = load("res://assets/textures/terrain/stone_albedo.png") as Texture2D

	var terrain_data: Dictionary = TerrainGenerator.generate_terrain(
		Vector3(-110, 0, 0), Vector2(80, 80), Vector2i(40, 40),
		ctx.terrain_noise, ctx.terrain_height_scale_field, _west_field_terrain_rules()
	)

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = terrain_shader
	mat.set_shader_parameter("texture_grass", tex_grass)
	mat.set_shader_parameter("texture_dirt", tex_dirt)
	mat.set_shader_parameter("texture_stone", tex_stone)
	TerrainHelpers.apply_standard_shader_params(mat)

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
	TerrainHelpers.create_portals(self, zone_id)


## Walk the nav_region children and connect any MineableRock signals found.
func _connect_rock_signals(parent: Node) -> void:
	for child in parent.get_children():
		if child.has_signal("rock_depleted"):
			child.rock_depleted.connect(_on_rock_depleted)


## Called when a rock is depleted: schedule a replacement spawn after the respawn delay.
func _on_rock_depleted(tier: String, respawn_time: float) -> void:
	get_tree().create_timer(respawn_time).timeout.connect(_spawn_replacement_rock.bind(tier))


## Spawn a new rock at a random position within the Rocky Clearing biome bounds.
func _spawn_replacement_rock(tier: String) -> void:
	if not is_instance_valid(_ctx):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var x: float = rng.randf_range(_ROCK_BIOME_BOUNDS.position.x, _ROCK_BIOME_BOUNDS.position.x + _ROCK_BIOME_BOUNDS.size.x)
	var z: float = rng.randf_range(_ROCK_BIOME_BOUNDS.position.y, _ROCK_BIOME_BOUNDS.position.y + _ROCK_BIOME_BOUNDS.size.y)
	var scale_val: float = _ROCK_TIER_SCALES.get(tier, 1.0)
	var rock: StaticBody3D = AssetSpawner.spawn_mineable_rock(_ctx, Vector3(x, 0.0, z), 0.0, scale_val, tier)
	if is_instance_valid(rock) and rock.has_signal("rock_depleted"):
		rock.rock_depleted.connect(_on_rock_depleted)
