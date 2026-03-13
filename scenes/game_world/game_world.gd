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
	var tex_grass := load("res://assets/textures/terrain/grass_albedo.png") as Texture2D
	var tex_dirt := load("res://assets/textures/terrain/dirt_albedo.png") as Texture2D
	var tex_stone := load("res://assets/textures/terrain/stone_albedo.png") as Texture2D
	var tex_cobble: Texture2D = null
	var tex_packed_earth: Texture2D = null
	if ResourceLoader.exists("res://assets/textures/terrain/cobble_albedo.png"):
		tex_cobble = load("res://assets/textures/terrain/cobble_albedo.png") as Texture2D
	if ResourceLoader.exists("res://assets/textures/terrain/packed_earth_albedo.png"):
		tex_packed_earth = load("res://assets/textures/terrain/packed_earth_albedo.png") as Texture2D

	# --- City Terrain (140x100, center at origin) ---
	var city_rules: Array = [
		# Main E-W road (gate road through center)
		{"type": "line", "start": Vector2(-65, 0), "end": Vector2(65, 0), "width": 2.0, "channel": 0, "falloff": 0.5},
		# Main N-S road
		{"type": "line", "start": Vector2(0, -45), "end": Vector2(0, 45), "width": 2.0, "channel": 0, "falloff": 0.5},
		# Secondary roads along district boundaries
		{"type": "line", "start": Vector2(-65, -10), "end": Vector2(65, -10), "width": 1.2, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(-65, 10), "end": Vector2(65, 10), "width": 1.2, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(-20, -45), "end": Vector2(-20, 45), "width": 1.2, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(25, -45), "end": Vector2(25, 45), "width": 1.2, "channel": 0, "falloff": 0.5},
		# Gate road (wider near gate)
		{"type": "line", "start": Vector2(55, 0), "end": Vector2(75, 0), "width": 3.0, "channel": 0, "falloff": 0.3},
		# Diagonal secondary paths
		{"type": "line", "start": Vector2(0, 0), "end": Vector2(-35, 20), "width": 1.0, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(0, 0), "end": Vector2(35, -25), "width": 1.0, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(55, 0), "end": Vector2(45, 25), "width": 1.0, "channel": 0, "falloff": 0.5},
		{"type": "line", "start": Vector2(-40, -15), "end": Vector2(-55, -30), "width": 0.8, "channel": 0, "falloff": 0.5},

		# District ground textures (cobblestone via channel 2)
		{"type": "circle", "center": Vector2(0, 0), "radius": 12.0, "channel": 2, "falloff": 0.3},
		{"type": "circle", "center": Vector2(-45, 25), "radius": 18.0, "channel": 2, "falloff": 0.4},
		{"type": "circle", "center": Vector2(0, -30), "radius": 16.0, "channel": 2, "falloff": 0.4},
		# City Gate area — stone (channel 1)
		{"type": "circle", "center": Vector2(60, 0), "radius": 10.0, "channel": 1, "falloff": 0.3},
		# Craft/Workshop — packed earth (channel 3)
		{"type": "circle", "center": Vector2(0, 30), "radius": 14.0, "channel": 3, "falloff": 0.4},
		# Garrison — packed earth
		{"type": "circle", "center": Vector2(45, 30), "radius": 16.0, "channel": 3, "falloff": 0.4},

		# Flatten building sites
		{"type": "flatten", "center": Vector2(-45, 20), "radius": 6.0},
		{"type": "flatten", "center": Vector2(-55, 30), "radius": 5.0},
		{"type": "flatten", "center": Vector2(0, 0), "radius": 8.0},
		{"type": "flatten", "center": Vector2(0, -35), "radius": 8.0},
		{"type": "flatten", "center": Vector2(15, -25), "radius": 6.0},
		{"type": "flatten", "center": Vector2(-10, -40), "radius": 6.0},
		{"type": "flatten", "center": Vector2(0, 30), "radius": 6.0},
		{"type": "flatten", "center": Vector2(45, 35), "radius": 8.0},
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
	]
	var field := TerrainGenerator.generate_terrain(
		Vector3(110, 0, 0), Vector2(80, 80), Vector2i(40, 40),
		terrain_noise, ctx.terrain_height_scale_field, field_rules
	)

	# Apply shader material to each terrain mesh
	for terrain_data in [city, field]:
		var mat := ShaderMaterial.new()
		mat.shader = terrain_shader
		if tex_grass:
			mat.set_shader_parameter("texture_grass", tex_grass)
		if tex_dirt:
			mat.set_shader_parameter("texture_dirt", tex_dirt)
		if tex_stone:
			mat.set_shader_parameter("texture_stone", tex_stone)
		if tex_cobble:
			mat.set_shader_parameter("texture_cobble", tex_cobble)
		if tex_packed_earth:
			mat.set_shader_parameter("texture_packed_earth", tex_packed_earth)
		mat.set_shader_parameter("uv_scale", 0.5)
		mat.set_shader_parameter("blend_sharpness", 3.0)
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
