class_name FieldBuilder
## Static utility class for field biome decoration.

static func decorate_biomes(ctx: WorldBuilderContext) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 300

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

	var tree_files := ["SM_FirTree1.FBX", "SM_FirTree2.FBX", "SM_FirTree3.FBX", "SM_FirTree4.FBX", "SM_FirTree5.FBX"]
	var bush_files := ["SM_Bush1.FBX", "SM_Bush2.FBX", "SM_Bush3.FBX", "SM_BushLeafy01.FBX", "SM_BushLeafy02.FBX"]
	var fern_files := ["SM_Fern1.FBX", "SM_Fern2.FBX", "SM_Fern3.FBX"]
	var grass_files := ["SM_Grass1.FBX", "SM_Grass2.FBX"]
	var flower_files := ["SM_Flower_DaffodilsYellow.FBX", "SM_Flower_Sunflower1.FBX", "SM_Flower_Sunflower2.FBX", "SM_Flower_Sunflower3.FBX", "SM_Flower_TulipsRed.FBX", "SM_FlowerCrocus01.FBX", "SM_Flower_Allium.FBX", "SM_Flower_Foxtails1.FBX"]
	var sapling_files := ["SM_FirSapling1.FBX", "SM_FirSapling2.FBX"]

	var biomes := [
		# Dense Forest — NW field, thick trees
		{
			"bounds": [73, 22, 22, 20], "noise_threshold": -0.1,
			"recipes": [
				{"type": "tree", "count": 14, "min_spacing": 2.5, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 8, "min_spacing": 1.5, "files": fern_files, "colors": [fern_color], "scale": 0.25},
				{"type": "foliage", "count": 4, "min_spacing": 2.0, "files": bush_files, "colors": [green, dark_green], "scale": 0.25},
			]
		},
		# Open Meadow — center-south, wildflowers and grass only
		{
			"center": Vector2(103, -15), "radius": 18.0, "noise_threshold": -0.2,
			"recipes": [
				{"type": "foliage", "count": 15, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 8, "min_spacing": 2.5, "files": flower_files, "colors": [flower_yellow, flower_orange, flower_pink, flower_white], "scale": 0.25},
			]
		},
		# Rocky Clearing — east field, rocks and stumps
		{
			"bounds": [117, -32, 30, 22], "noise_threshold": -0.2,
			"recipes": [
				{"type": "rock_cluster", "count": 8, "min_spacing": 4.0, "files": [], "colors": []},
				{"type": "stump", "count": 3, "min_spacing": 3.0, "files": ["SM_FirStump1.FBX"], "colors": [], "scale": 0.25},
				{"type": "fallen", "count": 2, "min_spacing": 4.0, "files": ["SM_FirFallen1.FBX", "SM_FirFallen2.FBX"], "colors": [], "scale": 0.25},
				{"type": "foliage", "count": 4, "min_spacing": 1.5, "files": fern_files, "colors": [fern_color], "scale": 0.25},
			]
		},
		# Transitional NE — sparse mix
		{
			"bounds": [110, 22, 30, 20], "noise_threshold": 0.0,
			"recipes": [
				{"type": "tree", "count": 6, "min_spacing": 3.0, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 1.5, "files": fern_files, "colors": [fern_color], "scale": 0.25},
			]
		},
		# Transitional SW — sparse mix near entrance
		{
			"bounds": [73, -10, 17, 20], "noise_threshold": 0.0,
			"recipes": [
				{"type": "tree", "count": 5, "min_spacing": 3.0, "files": tree_files, "colors": [leaf_green, dark_leaf], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 2, "min_spacing": 2.0, "files": bush_files, "colors": [green, dark_green], "scale": 0.25},
				{"type": "stump", "count": 1, "min_spacing": 3.0, "files": ["SM_FirStump1.FBX"], "colors": [], "scale": 0.25},
			]
		},
		# Path-edge scatter — sparse along main path
		{
			"bounds": [73, 0, 77, 10], "noise_threshold": 0.2,
			"recipes": [
				{"type": "tree", "count": 2, "min_spacing": 4.0, "files": sapling_files, "colors": [leaf_green], "scale": 0.25},
				{"type": "foliage", "count": 5, "min_spacing": 2.0, "files": grass_files, "colors": [grass_color], "scale": 0.25},
				{"type": "foliage", "count": 3, "min_spacing": 2.0, "files": fern_files, "colors": [fern_color], "scale": 0.25},
			]
		},
	]

	var total := 0
	for biome in biomes:
		total += BiomeScatter.scatter_biome(ctx, biome, rng)
	print("[Field] Biome scatter placed %d objects" % total)
