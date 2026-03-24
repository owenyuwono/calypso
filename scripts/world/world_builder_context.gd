class_name WorldBuilderContext
## Shared mutable context passed to all world builder utilities.
## Holds terrain state, caches, and scatter tracking.

var terrain_noise: FastNoiseLite
var terrain_height_scale_city: float = 0.15
var terrain_height_scale_field: float = 0.5
var texture_cache: Dictionary = {}
var color_mat_cache: Dictionary = {}
var deco_noise: FastNoiseLite
var spawned_positions: Array = []
var path_lines: Array = []    # [{start: Vector2, end: Vector2, buffer: float}]
var building_zones: Array = []  # [{center: Vector2, radius: float}]
var nav_region: Node           # NavigationRegion3D
var world_root: Node3D         # Scene root — parent of nav_region
var city_bounds: Rect2 = Rect2(-70, -50, 140, 100)

func is_in_city(pos: Vector3) -> bool:
	return city_bounds.has_point(Vector2(pos.x, pos.z))


## Release cached material/texture references to prevent leak warnings at exit.
func cleanup() -> void:
	color_mat_cache.clear()
	texture_cache.clear()
