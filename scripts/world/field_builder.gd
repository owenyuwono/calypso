class_name FieldBuilder
## Static utility class for field biome decoration.

## Returns a dict of shared asset arrays and colors used by both field biome sets.
static func _get_assets() -> Dictionary:
	var leaf_green := Color(0.18, 0.55, 0.12)
	var dark_leaf := Color(0.12, 0.42, 0.08)
	var green := Color(0.22, 0.48, 0.16)
	var dark_green := Color(0.15, 0.38, 0.1)
	var grass_color := Color(0.28, 0.52, 0.2)
	var fern_color := Color(0.18, 0.42, 0.12)
	var flower_yellow := Color(0.9, 0.85, 0.3)
	var flower_orange := Color(0.9, 0.6, 0.2)
	var flower_pink := Color(0.85, 0.4, 0.55)
	var flower_white := Color(0.9, 0.9, 0.85)
	var mature_leaf := Color(0.10, 0.38, 0.07)
	var ancient_leaf := Color(0.07, 0.28, 0.05)

	var tree_files: Array = ["tree_stylized.fbx"]
	var bush_files: Array = ["SM_Bush1.FBX", "SM_Bush2.FBX", "SM_Bush3.FBX", "SM_BushLeafy01.FBX", "SM_BushLeafy02.FBX"]
	var fern_files: Array = ["SM_Fern1.FBX", "SM_Fern2.FBX", "SM_Fern3.FBX"]
	var grass_files: Array = ["SM_Grass1.FBX", "SM_Grass2.FBX"]
	var flower_files: Array = ["SM_Flower_DaffodilsYellow.FBX", "SM_Flower_Sunflower1.FBX", "SM_Flower_Sunflower2.FBX", "SM_Flower_Sunflower3.FBX", "SM_Flower_TulipsRed.FBX", "SM_FlowerCrocus01.FBX", "SM_Flower_Allium.FBX", "SM_Flower_Foxtails1.FBX"]
	var sapling_files: Array = ["tree_stylized.fbx"]
	var ancient_files: Array = ["tree_stylized.fbx"]

	return {
		"leaf_green": leaf_green, "dark_leaf": dark_leaf,
		"green": green, "dark_green": dark_green,
		"grass_color": grass_color, "fern_color": fern_color,
		"flower_yellow": flower_yellow, "flower_orange": flower_orange,
		"flower_pink": flower_pink, "flower_white": flower_white,
		"mature_leaf": mature_leaf, "ancient_leaf": ancient_leaf,
		"tree_files": tree_files, "bush_files": bush_files,
		"fern_files": fern_files, "grass_files": grass_files,
		"flower_files": flower_files, "sapling_files": sapling_files,
		"ancient_files": ancient_files,
	}


## Returns biome definitions for the east field zone.
static func get_east_biome_defs() -> Array:
	var a: Dictionary = _get_assets()
	return [
		# Dense Forest — NW field, thick trees
		{
			"bounds": [73, 22, 22, 20], "noise_threshold": -0.1,
			"recipes": [
				{"type": "choppable_tree", "tier": "normal", "count": 5, "min_spacing": 3.5, "files": a.tree_files, "leaf_colors": [a.leaf_green, a.dark_leaf], "scale": 0.5},
				{"type": "choppable_tree", "tier": "mature", "count": 3, "min_spacing": 4.0, "files": a.tree_files, "leaf_colors": [a.mature_leaf], "scale": 0.7},
				{"type": "choppable_tree", "tier": "ancient", "count": 1, "min_spacing": 5.0, "files": a.ancient_files, "leaf_colors": [a.ancient_leaf], "scale": 0.9},
				{"type": "foliage", "count": 8, "min_spacing": 1.5, "files": a.fern_files, "colors": [a.fern_color], "scale": 0.25},
				{"type": "foliage", "count": 4, "min_spacing": 2.0, "files": a.bush_files, "colors": [a.green, a.dark_green], "scale": 0.25},
			]
		},
		# Open Meadow — center-south, wildflowers and grass only
		{
			"center": Vector2(103, -15), "radius": 18.0, "noise_threshold": -0.2,
			"recipes": [
				{"type": "foliage", "count": 15, "min_spacing": 2.0, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
				{"type": "foliage", "count": 8, "min_spacing": 2.5, "files": a.flower_files, "colors": [a.flower_yellow, a.flower_orange, a.flower_pink, a.flower_white], "scale": 0.25},
			]
		},
		# Rocky Clearing — east field, rocks and stumps
		{
			"bounds": [117, -32, 30, 22], "noise_threshold": -0.2,
			"recipes": [
				{"type": "rock_cluster", "count": 6, "min_spacing": 4.0, "files": [], "colors": []},
				{"type": "mineable_rock", "tier": "copper", "count": 4, "min_spacing": 4.0, "files": [], "colors": [], "scale": 1.0},
				{"type": "mineable_rock", "tier": "iron", "count": 2, "min_spacing": 5.0, "files": [], "colors": [], "scale": 1.1},
				{"type": "mineable_rock", "tier": "gold", "count": 1, "min_spacing": 6.0, "files": [], "colors": [], "scale": 1.2},
				{"type": "foliage", "count": 4, "min_spacing": 1.5, "files": a.fern_files, "colors": [a.fern_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
			]
		},
		# Transitional NE — sparse mix
		{
			"bounds": [110, 22, 30, 20], "noise_threshold": 0.0,
			"recipes": [
				{"type": "choppable_tree", "tier": "normal", "count": 3, "min_spacing": 4.0, "files": a.tree_files, "leaf_colors": [a.leaf_green, a.dark_leaf], "scale": 0.5},
				{"type": "choppable_tree", "tier": "mature", "count": 1, "min_spacing": 5.0, "files": a.tree_files, "leaf_colors": [a.mature_leaf], "scale": 0.7},
				{"type": "foliage", "count": 4, "min_spacing": 2.0, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 1.5, "files": a.fern_files, "colors": [a.fern_color], "scale": 0.25},
			]
		},
		# Transitional SW — sparse mix near entrance
		{
			"bounds": [73, -10, 17, 20], "noise_threshold": 0.0,
			"recipes": [
				{"type": "choppable_tree", "tier": "normal", "count": 2, "min_spacing": 4.0, "files": a.tree_files, "leaf_colors": [a.leaf_green, a.dark_leaf], "scale": 0.5},
				{"type": "choppable_tree", "tier": "mature", "count": 1, "min_spacing": 5.0, "files": a.tree_files, "leaf_colors": [a.mature_leaf], "scale": 0.7},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
				{"type": "foliage", "count": 2, "min_spacing": 2.0, "files": a.bush_files, "colors": [a.green, a.dark_green], "scale": 0.25},
			]
		},
		# Path-edge scatter — sparse along main path
		{
			"bounds": [73, 0, 77, 10], "noise_threshold": 0.2,
			"recipes": [
				{"type": "foliage", "count": 5, "min_spacing": 2.0, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": a.fern_files, "colors": [a.fern_color], "scale": 0.25},
			]
		},
		# City-Field border transition (x:70..80) — bushes only
		{
			"bounds": [70, -40, 10, 80], "noise_threshold": -0.3,
			"recipes": [
				{"type": "foliage", "count": 8, "min_spacing": 1.5, "files": a.bush_files, "colors": [a.green, a.dark_green], "scale": 0.25},
				{"type": "foliage", "count": 6, "min_spacing": 1.5, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
			]
		},
	]


## Returns biome definitions for the west field zone.
static func get_west_biome_defs() -> Array:
	var a: Dictionary = _get_assets()
	return [
		# Dense Forest — NW of west field
		{
			"bounds": [-152, 12, 22, 20], "noise_threshold": -0.1,
			"recipes": [
				{"type": "choppable_tree", "tier": "normal", "count": 5, "min_spacing": 3.5, "files": a.tree_files, "leaf_colors": [a.leaf_green, a.dark_leaf], "scale": 0.5},
				{"type": "choppable_tree", "tier": "mature", "count": 3, "min_spacing": 4.0, "files": a.tree_files, "leaf_colors": [a.mature_leaf], "scale": 0.7},
				{"type": "choppable_tree", "tier": "ancient", "count": 1, "min_spacing": 5.0, "files": a.ancient_files, "leaf_colors": [a.ancient_leaf], "scale": 0.9},
				{"type": "foliage", "count": 8, "min_spacing": 1.5, "files": a.fern_files, "colors": [a.fern_color], "scale": 0.25},
				{"type": "foliage", "count": 4, "min_spacing": 2.0, "files": a.bush_files, "colors": [a.green, a.dark_green], "scale": 0.25},
			]
		},
		# Open Meadow — center-south of west field
		{
			"center": Vector2(-103, -15), "radius": 18.0, "noise_threshold": -0.2,
			"recipes": [
				{"type": "foliage", "count": 15, "min_spacing": 2.0, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
				{"type": "foliage", "count": 8, "min_spacing": 2.5, "files": a.flower_files, "colors": [a.flower_yellow, a.flower_orange, a.flower_pink, a.flower_white], "scale": 0.25},
			]
		},
		# Rocky Clearing — SW of west field
		{
			"bounds": [-147, -32, 30, 22], "noise_threshold": -0.2,
			"recipes": [
				{"type": "rock_cluster", "count": 6, "min_spacing": 4.0, "files": [], "colors": []},
				{"type": "mineable_rock", "tier": "copper", "count": 4, "min_spacing": 4.0, "files": [], "colors": [], "scale": 1.0},
				{"type": "mineable_rock", "tier": "iron", "count": 2, "min_spacing": 5.0, "files": [], "colors": [], "scale": 1.1},
				{"type": "foliage", "count": 4, "min_spacing": 1.5, "files": a.fern_files, "colors": [a.fern_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
			]
		},
		# Transitional NE — sparse mix
		{
			"bounds": [-140, 22, 30, 18], "noise_threshold": 0.0,
			"recipes": [
				{"type": "choppable_tree", "tier": "normal", "count": 3, "min_spacing": 4.0, "files": a.tree_files, "leaf_colors": [a.leaf_green, a.dark_leaf], "scale": 0.5},
				{"type": "choppable_tree", "tier": "mature", "count": 1, "min_spacing": 5.0, "files": a.tree_files, "leaf_colors": [a.mature_leaf], "scale": 0.7},
				{"type": "foliage", "count": 4, "min_spacing": 2.0, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 1.5, "files": a.fern_files, "colors": [a.fern_color], "scale": 0.25},
			]
		},
		# Transitional SW — sparse mix near west gate
		{
			"bounds": [-90, -20, 17, 20], "noise_threshold": 0.0,
			"recipes": [
				{"type": "choppable_tree", "tier": "normal", "count": 2, "min_spacing": 4.0, "files": a.tree_files, "leaf_colors": [a.leaf_green, a.dark_leaf], "scale": 0.5},
				{"type": "choppable_tree", "tier": "mature", "count": 1, "min_spacing": 5.0, "files": a.tree_files, "leaf_colors": [a.mature_leaf], "scale": 0.7},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
				{"type": "foliage", "count": 2, "min_spacing": 2.0, "files": a.bush_files, "colors": [a.green, a.dark_green], "scale": 0.25},
			]
		},
		# Path-edge scatter — sparse along main west path
		{
			"bounds": [-150, -5, 77, 10], "noise_threshold": 0.2,
			"recipes": [
				{"type": "foliage", "count": 5, "min_spacing": 2.0, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": a.fern_files, "colors": [a.fern_color], "scale": 0.25},
			]
		},
		# City-Field border transition (x:-80..-70) — bushes only
		{
			"bounds": [-80, -40, 10, 80], "noise_threshold": -0.3,
			"recipes": [
				{"type": "foliage", "count": 8, "min_spacing": 1.5, "files": a.bush_files, "colors": [a.green, a.dark_green], "scale": 0.25},
				{"type": "foliage", "count": 6, "min_spacing": 1.5, "files": a.grass_files, "colors": [a.grass_color], "scale": 0.25},
			]
		},
	]


## Scatter the given biome definitions into the world.
## Zone scripts call this with their own biome_defs array.
static func decorate_biomes(ctx: WorldBuilderContext, biome_defs: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 300
	var total: int = 0
	for biome in biome_defs:
		total += BiomeScatter.scatter_biome(ctx, biome, rng)
	print("[Field] Biome scatter placed %d objects" % total)


## Convenience: scatter all east field biomes.
static func decorate_east_biomes(ctx: WorldBuilderContext) -> void:
	decorate_biomes(ctx, get_east_biome_defs())


## Convenience: scatter all west field biomes.
static func decorate_west_biomes(ctx: WorldBuilderContext) -> void:
	decorate_biomes(ctx, get_west_biome_defs())
