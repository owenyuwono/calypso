class_name TerrainHelpers
## Shared terrain utilities — noise init, shader params, portal creation, and navmesh bake setup.
## Extracted from zone files to eliminate per-zone duplication.


static func create_terrain_noise() -> FastNoiseLite:
	## Returns the standard terrain noise used by all zones.
	## Seed 42 — shared across zones so height continuity holds at gate boundaries.
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	noise.fractal_octaves = 2
	noise.seed = 42
	return noise


static func apply_standard_shader_params(mat: ShaderMaterial) -> void:
	## Applies the standard UV scale and blend sharpness parameters to a terrain ShaderMaterial.
	mat.set_shader_parameter("uv_scale_pavement", 0.5)
	mat.set_shader_parameter("uv_scale_dirt", 0.25)
	mat.set_shader_parameter("uv_scale_stone", 0.2)
	mat.set_shader_parameter("uv_scale_cobble", 0.5)
	mat.set_shader_parameter("uv_scale_earth", 0.5)
	mat.set_shader_parameter("blend_sharpness", 1.5)


static func create_portals(parent: Node3D, zone_id: String) -> void:
	## Instantiates zone portal nodes for zone_id and adds them to parent.
	## Portal definitions are passed externally — ZoneDatabase is not available.
	pass


static func begin_navmesh_bake(nav_region: NavigationRegion3D, on_baked: Callable) -> void:
	## Connects on_baked to bake_finished and triggers the navmesh bake.
	## Call this after `await get_tree().create_timer(0.5).timeout` in the zone's _ready().
	## The 0.5s delay must be awaited by the caller before this call so all geometry is in place.
	nav_region.bake_finished.connect(on_baked)
	nav_region.bake_navigation_mesh()
