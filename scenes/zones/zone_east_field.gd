extends Node3D
## East Field zone scene — terrain, biome decorations, monster spawners, and city portal.
## Loaded by ZoneManager when the player passes through the east gate.

const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")
const AssetSpawner = preload("res://scripts/world/asset_spawner.gd")
const AmbientEmitterScript = preload("res://scripts/audio/ambient_emitter.gd")

var zone_id: String = "east_field"

# Rocky Clearing biome: bounds [117, -32, 30, 22] → x: 102..132, z: -43..-21
const _ROCK_BIOME_BOUNDS: Rect2 = Rect2(102.0, -43.0, 30.0, 22.0)
const _ROCK_TIER_SCALES: Dictionary = {"copper": 1.0, "iron": 1.1, "gold": 1.2}

var _ctx: WorldBuilderContext = null

signal zone_ready

func _ready() -> void:
	# Register field location markers with WorldState
	var markers: Node3D = $LocationMarkers
	for marker in markers.get_children():
		WorldState.register_location(marker.name, marker.global_position)

	# Shared context for builder utilities
	_ctx = WorldBuilderContext.new()
	_ctx.nav_region = $NavigationRegion3D
	_ctx.world_root = self

	# Build terrain, decorate biomes, then create portals
	_build_terrain(_ctx)
	BiomeScatter.setup_exclusion_zones(_ctx)
	FieldBuilder.decorate_east_biomes(_ctx)
	_connect_rock_signals($NavigationRegion3D)
	_spawn_fishing_spots(_ctx)
	TerrainHelpers.create_portals(self, zone_id)
	_spawn_ambient_emitters()

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


func _spawn_fishing_spots(ctx: WorldBuilderContext) -> void:
	# Shallow spot near the zone entrance (accessible at fishing level 1)
	AssetSpawner.spawn_fishing_spot(ctx, Vector3(82.0, 0.0, 18.0), "shallow")
	# Medium spot mid-field beside the northern path branch
	AssetSpawner.spawn_fishing_spot(ctx, Vector3(108.0, 0.0, 28.0), "medium")
	# Deep spot at the far east end (high-level content)
	AssetSpawner.spawn_fishing_spot(ctx, Vector3(138.0, 0.0, -5.0), "deep")


func _spawn_ambient_emitters() -> void:
	var nav: Node = $NavigationRegion3D

	# Wind across the whole field — centered at zone center
	var wind_emitter: Node3D = AmbientEmitterScript.new()
	nav.add_child(wind_emitter)
	wind_emitter.global_position = Vector3(110.0, 0.0, 0.0)
	wind_emitter.setup("res://assets/audio/ambient/wind_field.ogg", ["dawn", "day", "dusk", "night"], -6.0, 40.0)

	# Birds during daytime — slightly north of center
	var birds_emitter: Node3D = AmbientEmitterScript.new()
	nav.add_child(birds_emitter)
	birds_emitter.global_position = Vector3(110.0, 0.0, -15.0)
	birds_emitter.setup("res://assets/audio/ambient/birds_day.ogg", ["dawn", "day"], -8.0, 35.0)

	# Crickets at night — slightly south of center
	var crickets_emitter: Node3D = AmbientEmitterScript.new()
	nav.add_child(crickets_emitter)
	crickets_emitter.global_position = Vector3(110.0, 0.0, 15.0)
	crickets_emitter.setup("res://assets/audio/ambient/crickets_night.ogg", ["night"], -6.0, 35.0)


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
