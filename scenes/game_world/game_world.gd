extends Node3D
## Game world — walled city and field zones with shops, monsters, and adventurer NPCs.
## Environment decoration is handled by static builder utilities in scripts/world/.

const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")

func _ready() -> void:
	# Register location markers with WorldState
	for marker in $LocationMarkers.get_children():
		WorldState.register_location(marker.name, marker.global_position)

	# Create shared context for all builder utilities
	var ctx := WorldBuilderContext.new()
	ctx.nav_region = $NavigationRegion3D

	# Build procedural terrain
	_build_terrain(ctx)

	# City walls
	TownBuilder.build_walls(ctx)

	# Setup biome scatter infrastructure
	BiomeScatter.setup_exclusion_zones(ctx)

	# Decorate zones
	TownBuilder.decorate_biomes(ctx)
	TownBuilder.place_props(ctx)
	FieldBuilder.decorate_biomes(ctx)

	# Build district buildings via CityBuilder
	const CityBuilder = preload("res://scripts/world/city_builder.gd")
	CityBuilder.build_all_districts($NavigationRegion3D, ctx.terrain_noise, ctx.terrain_height_scale_city)

	# Bake navmesh after environment is ready
	var nav_region := $NavigationRegion3D
	nav_region.bake_finished.connect(_on_navmesh_baked)
	await get_tree().create_timer(0.5).timeout
	nav_region.bake_navigation_mesh()

func _on_navmesh_baked() -> void:
	var nav_mesh: NavigationMesh = $NavigationRegion3D.navigation_mesh
	var poly_count: int = nav_mesh.get_polygon_count()
	if poly_count == 0:
		push_warning("[NavMesh] WARNING: Navmesh is EMPTY!")
	_setup_adventurer_npcs()

func _build_terrain(ctx: WorldBuilderContext) -> void:
	# Shared noise for all terrain patches and height queries
	var terrain_noise := FastNoiseLite.new()
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.05
	terrain_noise.fractal_octaves = 2
	terrain_noise.seed = 42
	ctx.terrain_noise = terrain_noise

	# Load terrain shader + textures
	var terrain_shader := load("res://assets/shaders/terrain_blend.gdshader") as Shader
	var tex_dirt := load("res://assets/textures/terrain/dirt_albedo.png") as Texture2D
	var tex_stone := load("res://assets/textures/terrain/stone_albedo.png") as Texture2D

	# Zone-specific textures
	var tex_grass_city := load("res://assets/textures/terrain/grass_town.png") as Texture2D
	var tex_bricks_city := load("res://assets/textures/terrain/Bricks/Bricks_23-512x512.png") as Texture2D

	# --- City Terrain (140x100, center at origin) ---
	var city_rules: Array = [
		# Roads — tile_town paving (channel 2)
		# Main E-W road (gate road through center)
		{"type": "line", "start": Vector2(-65, 0), "end": Vector2(65, 0), "width": 2.0, "channel": 2, "falloff": 0.0},
		# Main N-S road
		{"type": "line", "start": Vector2(0, -45), "end": Vector2(0, 45), "width": 2.0, "channel": 2, "falloff": 0.0},
		# Secondary roads along district boundaries
		{"type": "line", "start": Vector2(-65, -10), "end": Vector2(65, -10), "width": 1.2, "channel": 2, "falloff": 0.0},
		{"type": "line", "start": Vector2(-65, 10), "end": Vector2(65, 10), "width": 1.2, "channel": 2, "falloff": 0.0},
		{"type": "line", "start": Vector2(-20, -45), "end": Vector2(-20, 45), "width": 1.2, "channel": 2, "falloff": 0.0},
		{"type": "line", "start": Vector2(25, -45), "end": Vector2(25, 45), "width": 1.2, "channel": 2, "falloff": 0.0},
		# Gate road (wider near gate)
		{"type": "line", "start": Vector2(55, 0), "end": Vector2(75, 0), "width": 3.0, "channel": 2, "falloff": 0.0},
		# Diagonal secondary paths
		{"type": "line", "start": Vector2(0, 0), "end": Vector2(-35, 20), "width": 1.0, "channel": 2, "falloff": 0.0},
		{"type": "line", "start": Vector2(0, 0), "end": Vector2(35, -25), "width": 1.0, "channel": 2, "falloff": 0.0},
		{"type": "line", "start": Vector2(55, 0), "end": Vector2(45, 25), "width": 1.0, "channel": 2, "falloff": 0.0},
		{"type": "line", "start": Vector2(-40, -15), "end": Vector2(-55, -30), "width": 0.8, "channel": 2, "falloff": 0.0},

		# District ground — brick ground rectangles (channel 3)
		{"type": "rect", "center": Vector2(-48, -25), "size": Vector2(44, 44), "channel": 3, "strength": 0.85},  # Residential
		{"type": "rect", "center": Vector2(8, -30), "size": Vector2(40, 40), "channel": 3, "strength": 0.85},    # Noble/Temple
		{"type": "rect", "center": Vector2(2, 32), "size": Vector2(36, 36), "channel": 3, "strength": 0.85},     # Craft/Workshop
		{"type": "rect", "center": Vector2(45, 32), "size": Vector2(36, 36), "channel": 3, "strength": 0.85},    # Garrison
		{"type": "rect", "center": Vector2(0, 0), "size": Vector2(20, 20), "channel": 3, "strength": 0.85},      # Central plaza
		{"type": "rect", "center": Vector2(60, 0), "size": Vector2(24, 24), "channel": 3, "strength": 0.85},     # Gate area

		# Market area — dirt rectangle (channel 0)
		{"type": "rect", "center": Vector2(-45, 25), "size": Vector2(36, 36), "channel": 0},
		# City Gate area — stone rectangle (channel 1)
		{"type": "rect", "center": Vector2(60, 0), "size": Vector2(20, 20), "channel": 1},

		# Central plaza — road paving square (channel 2)
		{"type": "rect", "center": Vector2(0, 0), "size": Vector2(16, 16), "channel": 2},

		# Alley dirt lines (channel 0)
		{"type": "line", "start": Vector2(-48, -14), "end": Vector2(-36, -14), "width": 0.6, "channel": 0, "falloff": 0.0},  # Residential alleys
		{"type": "line", "start": Vector2(-36, 5), "end": Vector2(-24, 5), "width": 0.6, "channel": 0, "falloff": 0.0},      # Market alleys
		{"type": "line", "start": Vector2(-4, 26), "end": Vector2(-4, 38), "width": 0.6, "channel": 0, "falloff": 0.0},      # Craft alleys
		{"type": "line", "start": Vector2(6, -22), "end": Vector2(6, -30), "width": 0.6, "channel": 0, "falloff": 0.0},      # Noble passage

		# Flatten building sites (original)
		{"type": "flatten", "center": Vector2(-45, 20), "radius": 6.0},
		{"type": "flatten", "center": Vector2(-55, 30), "radius": 5.0},
		{"type": "flatten", "center": Vector2(0, 0), "radius": 8.0},
		{"type": "flatten", "center": Vector2(10, -35), "radius": 8.0},
		{"type": "flatten", "center": Vector2(15, -25), "radius": 6.0},
		{"type": "flatten", "center": Vector2(-10, -40), "radius": 6.0},
		{"type": "flatten", "center": Vector2(8, 30), "radius": 6.0},
		{"type": "flatten", "center": Vector2(45, 35), "radius": 8.0},
		# Flatten building sites (new buildings — batch from city_builder)
		{"type": "flatten", "center": Vector2(-62, -20), "radius": 5.0},   # House 6
		{"type": "flatten", "center": Vector2(-38, -40), "radius": 5.5},   # House 7
		{"type": "flatten", "center": Vector2(-42, -35), "radius": 3.0},   # Well
		{"type": "flatten", "center": Vector2(-30, 30), "radius": 5.0},    # Bakery
		{"type": "flatten", "center": Vector2(-65, 15), "radius": 4.5},    # Storage Shed
		{"type": "flatten", "center": Vector2(-48, 42), "radius": 4.0},    # Market Stall 5
		{"type": "flatten", "center": Vector2(0, -20), "radius": 7.0},     # Library
		{"type": "flatten", "center": Vector2(18, -40), "radius": 4.5},    # Chapel Annex
		{"type": "flatten", "center": Vector2(-15, 20), "radius": 7.0},    # Stables
		{"type": "flatten", "center": Vector2(20, 38), "radius": 4.0},     # Storage Hut
		{"type": "flatten", "center": Vector2(30, 40), "radius": 4.0},     # Guard Tower
		{"type": "flatten", "center": Vector2(55, 25), "radius": 6.0},     # Armory
		{"type": "flatten", "center": Vector2(35, -20), "radius": 5.0},    # Gazebo
		{"type": "flatten", "center": Vector2(60, -7), "radius": 4.0},     # Gatehouse Storage
		# Flatten building sites (16 new buildings)
		{"type": "flatten", "center": Vector2(-36, 5), "radius": 3.5},
		{"type": "flatten", "center": Vector2(-30, 5), "radius": 3.0},
		{"type": "flatten", "center": Vector2(-24, 5), "radius": 3.0},
		{"type": "flatten", "center": Vector2(-47, -14), "radius": 3.0},
		{"type": "flatten", "center": Vector2(-41, -14), "radius": 3.0},
		{"type": "flatten", "center": Vector2(-36, -14), "radius": 2.5},
		{"type": "flatten", "center": Vector2(6, -26), "radius": 3.5},
		{"type": "flatten", "center": Vector2(18, -35), "radius": 3.0},
		{"type": "flatten", "center": Vector2(-4, 26), "radius": 3.5},
		{"type": "flatten", "center": Vector2(-4, 33), "radius": 3.0},
		{"type": "flatten", "center": Vector2(-4, 38), "radius": 2.5},
		{"type": "flatten", "center": Vector2(38, 30), "radius": 3.5},
		{"type": "flatten", "center": Vector2(52, 32), "radius": 3.0},
		{"type": "flatten", "center": Vector2(49, -4), "radius": 3.0},
		{"type": "flatten", "center": Vector2(55, -4), "radius": 3.0},
		{"type": "flatten", "center": Vector2(40, -38), "radius": 3.0},
	]
	var city := TerrainGenerator.generate_terrain(
		Vector3(0, 0, 0), Vector2(140, 100), Vector2i(70, 50),
		terrain_noise, ctx.terrain_height_scale_city, city_rules
	)

	# --- Field Terrain (80x80, center at 110,0,0) ---
	var field_rules: Array = [
		# Flatten field terrain at gate boundary so heights match city terrain
		{"type": "flatten", "center": Vector2(75, 0), "radius": 8.0},
		{"type": "line", "start": Vector2(70, 0), "end": Vector2(100, 0), "width": 1.5, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(100, 0), "end": Vector2(145, 0), "width": 1.5, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(100, 0), "end": Vector2(110, 25), "width": 1.0, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(100, 0), "end": Vector2(120, -20), "width": 1.0, "channel": 0, "falloff": 0.5},
		# Rocky clearing — exposed stone
		{"type": "circle", "center": Vector2(130, -20), "radius": 8.0, "channel": 1, "falloff": 2.0, "noise_perturb": 0.25},
		{"type": "circle", "center": Vector2(140, -25), "radius": 5.0, "channel": 1, "falloff": 1.5, "noise_perturb": 0.25},
	]
	var field := TerrainGenerator.generate_terrain(
		Vector3(110, 0, 0), Vector2(80, 80), Vector2i(40, 40),
		terrain_noise, ctx.terrain_height_scale_field, field_rules
	)

	# Per-zone texture sets: [grass, dirt/ch0, stone/ch1, tile_town/ch2, bricks/ch3]
	var tex_tile_city := load("res://assets/textures/terrain/Bricks/Bricks_17-512x512.png") as Texture2D
	var zone_textures := [
		[tex_bricks_city, tex_dirt, tex_stone, tex_tile_city, tex_bricks_city],  # city
		[tex_grass_city, tex_dirt, tex_stone, null, null],                       # field
	]
	var tex_keys := ["texture_grass", "texture_dirt", "texture_stone", "texture_cobble", "texture_packed_earth"]

	# Apply shader material to each terrain mesh
	for i in 2:
		var terrain_data = [city, field][i]
		var textures = zone_textures[i]
		var mat := ShaderMaterial.new()
		mat.shader = terrain_shader
		for j in textures.size():
			if textures[j]:
				mat.set_shader_parameter(tex_keys[j], textures[j])
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

func _setup_adventurer_npcs() -> void:
	for npc_id in NpcLoadouts.LOADOUTS:
		var loadout: Dictionary = NpcLoadouts.LOADOUTS[npc_id]
		var npc_name: String = npc_id.capitalize()
		var npc: Node3D = $NPCs.get_node_or_null(npc_name)
		if not npc:
			continue

		npc.trait_profile = loadout["trait_profile"]

		var inventory: Node = npc.get_node("InventoryComponent")
		for item_id in loadout["items"]:
			inventory.add_item(item_id, loadout["items"][item_id])

		var equipment: Node = npc.get_node("EquipmentComponent")
		for item_id in loadout["equip"]:
			equipment.equip(item_id)

		var gold: int = loadout["gold"]
		if gold != -1:
			inventory.set_gold_amount(gold)

		var brain: Node = npc.get_node_or_null("NPCBrain")
		if brain:
			brain.set_use_llm(false)
			brain.set_use_llm_chat(true)

		var goal: String = loadout["default_goal"]
		var behavior: Node = npc.get_node_or_null("NPCBehavior")
		if behavior:
			behavior.default_goal = goal
		npc.set_goal(goal)
