extends Node3D
## City zone — walled city terrain, districts, props, and navmesh.
## Does NOT contain NPCs — those persist under Main/NPCs.

const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")
const CityBuilderClass = preload("res://scripts/world/city_builder.gd")

var zone_id: String = "city"
var _ctx: WorldBuilderContext = null

signal zone_ready


func _ready() -> void:
	# Register city location markers with WorldState
	for marker in $LocationMarkers.get_children():
		WorldState.register_location(marker.name, marker.global_position)

	# Shared context for all builder utilities
	_ctx = WorldBuilderContext.new()
	_ctx.nav_region = $NavigationRegion3D
	_ctx.world_root = self

	# Build terrain, walls, scatter, decorations, districts
	_build_city_terrain(_ctx)
	TownBuilder.build_walls(_ctx)
	BiomeScatter.setup_exclusion_zones(_ctx)
	TownBuilder.decorate_biomes(_ctx)
	TownBuilder.place_props(_ctx)
	CityBuilderClass.build_all_districts(_ctx)

	# Portals — requires ZoneDatabase autoload (may not be present yet)
	TerrainHelpers.create_portals(self, zone_id)

	# Bake navmesh; emit zone_ready after bake
	await get_tree().create_timer(0.5).timeout
	TerrainHelpers.begin_navmesh_bake($NavigationRegion3D, _on_navmesh_baked)


func _on_navmesh_baked() -> void:
	var nav_mesh: NavigationMesh = $NavigationRegion3D.navigation_mesh
	if nav_mesh.get_polygon_count() == 0:
		push_warning("[ZoneCity] Navmesh is EMPTY after bake!")
	zone_ready.emit()


func _exit_tree() -> void:
	if _ctx:
		_ctx.cleanup()


# --- Terrain -----------------------------------------------------------------

func _build_city_terrain(ctx: WorldBuilderContext) -> void:
	# Shared noise used by terrain generator and biome scatter
	ctx.terrain_noise = TerrainHelpers.create_terrain_noise()

	# Load shader and city-specific textures
	var terrain_shader: Shader = load("res://assets/shaders/terrain_blend.gdshader") as Shader
	var tex_dirt: Texture2D = load("res://assets/textures/terrain/dirt_albedo.png") as Texture2D
	var tex_stone: Texture2D = load("res://assets/textures/terrain/stone_albedo.png") as Texture2D
	var tex_grass_city: Texture2D = load("res://assets/textures/terrain/grass_town.png") as Texture2D
	var tex_bricks_city: Texture2D = load("res://assets/textures/terrain/Bricks/Bricks_23-512x512.png") as Texture2D
	var tex_tile_city: Texture2D = load("res://assets/textures/terrain/Bricks/Bricks_17-512x512.png") as Texture2D

	var city_data: Dictionary = TerrainGenerator.generate_terrain(
		Vector3(0, 0, 0), Vector2(140, 100), Vector2i(70, 50),
		ctx.terrain_noise, ctx.terrain_height_scale_city, _city_terrain_rules()
	)

	# Texture slots: [grass/base, dirt/ch0, stone/ch1, cobble/ch2, packed_earth/ch3]
	var textures: Array = [tex_bricks_city, tex_dirt, tex_stone, tex_tile_city, tex_bricks_city]
	var tex_keys: Array = ["texture_grass", "texture_dirt", "texture_stone", "texture_cobble", "texture_packed_earth"]

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = terrain_shader
	for i in textures.size():
		if textures[i]:
			mat.set_shader_parameter(tex_keys[i], textures[i])
	TerrainHelpers.apply_standard_shader_params(mat)

	var mi: MeshInstance3D = city_data["mesh_instance"]
	mi.mesh.surface_set_material(0, mat)
	$NavigationRegion3D.add_child(mi)
	$NavigationRegion3D.add_child(city_data["static_body"])


func _city_terrain_rules() -> Array:
	return [
		# Roads — cobblestone paving (channel 2)
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

		# Gate approach roads — cobblestone (channel 2)
		{"type": "line", "start": Vector2(0, -45), "end": Vector2(0, -55), "width": 3.0, "channel": 2},
		{"type": "line", "start": Vector2(0, 45), "end": Vector2(0, 55), "width": 3.0, "channel": 2},

		# Flatten building sites — Central Plaza
		{"type": "flatten_rect", "center": Vector2(-12, -7), "size": Vector2(7, 5)},    # Town Hall
		{"type": "flatten_rect", "center": Vector2(15, 7), "size": Vector2(4, 3.5)},    # Chapel
		{"type": "flatten_rect", "center": Vector2(-12, 7), "size": Vector2(3.5, 3)},   # Money Changer
		{"type": "flatten_rect", "center": Vector2(15, -5), "size": Vector2(2.5, 2)},   # Notice Board

		# Flatten building sites — Market
		{"type": "flatten_rect", "center": Vector2(-50, 20), "size": Vector2(4, 3.5)},  # Spice Shop
		{"type": "flatten_rect", "center": Vector2(-38, 25), "size": Vector2(4, 4)},    # Cloth Merchant
		{"type": "flatten_rect", "center": Vector2(-62, 25), "size": Vector2(4, 3.5)},  # Apothecary
		{"type": "flatten_rect", "center": Vector2(-28, 20), "size": Vector2(3.5, 3)},  # Pawn Shop
		{"type": "flatten_rect", "center": Vector2(-50, 40), "size": Vector2(6, 5)},    # Tavern
		{"type": "flatten_rect", "center": Vector2(-35, 45), "size": Vector2(3.5, 3)},  # Fish Monger
		{"type": "flatten_rect", "center": Vector2(-28, 45), "size": Vector2(3.5, 3)},  # Butcher
		{"type": "flatten_rect", "center": Vector2(-65, 35), "size": Vector2(4, 4)},    # Grain Store
		{"type": "flatten_rect", "center": Vector2(-24, 15), "size": Vector2(3.5, 3)},  # Cartographer
		{"type": "flatten_rect", "center": Vector2(-65, 45), "size": Vector2(3.5, 3)},  # Chandler

		# Flatten building sites — Residential
		{"type": "flatten_rect", "center": Vector2(-28, -30), "size": Vector2(4, 4)},     # House 8
		{"type": "flatten_rect", "center": Vector2(-58, -42), "size": Vector2(4, 3.5)},   # House 9
		{"type": "flatten_rect", "center": Vector2(-32, -35), "size": Vector2(3.5, 3.5)}, # House 10
		{"type": "flatten_rect", "center": Vector2(-40, -28), "size": Vector2(4, 4)},     # House 11
		{"type": "flatten_rect", "center": Vector2(-55, -30), "size": Vector2(4, 3.5)},   # House 12
		{"type": "flatten_rect", "center": Vector2(-28, -45), "size": Vector2(3, 3)},     # Midwife Hut
		{"type": "flatten_rect", "center": Vector2(-65, -42), "size": Vector2(3.5, 3)},   # Woodcarver
		{"type": "flatten_rect", "center": Vector2(-48, -35), "size": Vector2(4, 3.5)},   # Wash House

		# Flatten building sites — Noble/Temple
		{"type": "flatten_rect", "center": Vector2(-15, -25), "size": Vector2(5, 5)},    # Magistrate Court
		{"type": "flatten_rect", "center": Vector2(-15, -35), "size": Vector2(5, 4.5)},  # Noble House 1
		{"type": "flatten_rect", "center": Vector2(20, -20), "size": Vector2(4.5, 4)},   # Noble House 2
		{"type": "flatten_rect", "center": Vector2(-5, -43), "size": Vector2(3, 3)},     # Shrine
		{"type": "flatten_rect", "center": Vector2(10, -18), "size": Vector2(3.5, 3)},   # Clerk Office
		{"type": "flatten_rect", "center": Vector2(22, -45), "size": Vector2(3, 3)},     # Archive Tower

		# Flatten building sites — Park/Gardens
		{"type": "flatten_rect", "center": Vector2(30, -15), "size": Vector2(4, 3.5)},  # Herbalist
		{"type": "flatten_rect", "center": Vector2(55, -25), "size": Vector2(5, 4)},    # Greenhouse
		{"type": "flatten_rect", "center": Vector2(60, -40), "size": Vector2(4, 4)},    # Groundskeeper Lodge
		{"type": "flatten_rect", "center": Vector2(50, -40), "size": Vector2(3, 3)},    # Pond Pavilion
		{"type": "flatten_rect", "center": Vector2(30, -42), "size": Vector2(3, 3)},    # Garden Storage

		# Flatten building sites — Craft/Workshop
		{"type": "flatten_rect", "center": Vector2(15, 20), "size": Vector2(5, 4)},    # Lumberyard
		{"type": "flatten_rect", "center": Vector2(8, 38), "size": Vector2(3.5, 3.5)}, # Kiln House
		{"type": "flatten_rect", "center": Vector2(5, 18), "size": Vector2(4, 3.5)},   # Carpenter Shop
		{"type": "flatten_rect", "center": Vector2(-10, 42), "size": Vector2(3, 3)},   # Rope Maker
		{"type": "flatten_rect", "center": Vector2(-15, 40), "size": Vector2(4, 3.5)}, # Dye Works
		{"type": "flatten_rect", "center": Vector2(20, 30), "size": Vector2(3, 3)},    # Tool Shed

		# Flatten building sites — Garrison
		{"type": "flatten_rect", "center": Vector2(35, 35), "size": Vector2(4, 4)},    # Officers Quarters
		{"type": "flatten_rect", "center": Vector2(60, 35), "size": Vector2(4, 4)},    # Infirmary
		{"type": "flatten_rect", "center": Vector2(60, 42), "size": Vector2(5, 4)},    # Military Stable
		{"type": "flatten_rect", "center": Vector2(42, 42), "size": Vector2(4, 3.5)},  # War Room
		{"type": "flatten_rect", "center": Vector2(65, 42), "size": Vector2(2.5, 2.5)},# Watchtower

		# Flatten building sites — Gate Area
		{"type": "flatten_rect", "center": Vector2(56, 4), "size": Vector2(4, 3.5)},   # Customs House
		{"type": "flatten_rect", "center": Vector2(49, 4), "size": Vector2(4, 4)},     # Gate Inn
		{"type": "flatten_rect", "center": Vector2(62, 4), "size": Vector2(2.5, 2)},   # Toll Booth
		{"type": "flatten_rect", "center": Vector2(-3, -47), "size": Vector2(2, 2)},   # North Guard Post W
		{"type": "flatten_rect", "center": Vector2(3, -47), "size": Vector2(2, 2)},    # North Guard Post E
		{"type": "flatten_rect", "center": Vector2(-8, -46), "size": Vector2(3.5, 3)}, # North Waystation
		{"type": "flatten_rect", "center": Vector2(8, -46), "size": Vector2(3, 3)},    # North Toll Office
		{"type": "flatten_rect", "center": Vector2(-3, 47), "size": Vector2(2, 2)},    # South Guard Post W
		{"type": "flatten_rect", "center": Vector2(3, 47), "size": Vector2(2, 2)},     # South Guard Post E
		{"type": "flatten_rect", "center": Vector2(-8, 46), "size": Vector2(3.5, 3)},  # South Waystation
		{"type": "flatten_rect", "center": Vector2(8, 46), "size": Vector2(3, 3)},     # South Customs

		# Park walking paths — dirt (channel 0)
		{"type": "line", "start": Vector2(25, -10), "end": Vector2(55, -40), "width": 0.8, "channel": 0},  # Park diagonal path
		{"type": "line", "start": Vector2(35, -15), "end": Vector2(55, -15), "width": 0.8, "channel": 0},  # Park perimeter path N
		{"type": "line", "start": Vector2(55, -15), "end": Vector2(55, -40), "width": 0.8, "channel": 0},  # Park perimeter path E
		{"type": "line", "start": Vector2(55, -40), "end": Vector2(35, -40), "width": 0.8, "channel": 0},  # Park perimeter path S
		{"type": "line", "start": Vector2(35, -40), "end": Vector2(35, -15), "width": 0.8, "channel": 0},  # Park perimeter path W
	]


