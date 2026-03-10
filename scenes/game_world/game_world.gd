extends Node3D
## Game world — town, field, and dungeon zones with shops, monsters, and adventurer NPCs.
## Spawns environment decoration (trees, rocks, dungeon props) programmatically.

# Asset directories
const FOLIAGE_DIR := "res://assets/models/environment/nature/foliage/"
const TREE_DIR := "res://assets/models/environment/nature/trees/fir/"
const DUNGEON_DIR := "res://assets/models/environment/dungeon/"
const TREE_TEX_DIR := "res://assets/models/environment/nature/trees/textures/"
const ModelHelper = preload("res://scripts/utils/model_helper.gd")


# Model cache to avoid reloading
var _model_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _color_mat_cache: Dictionary = {}
var _tree_mat_names_printed := false

func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex := load(path) as Texture2D
	if tex:
		_texture_cache[path] = tex
	else:
		push_warning("Failed to load texture: " + path)
	return tex

func _ready() -> void:
	# Register location markers with WorldState
	for marker in $LocationMarkers.get_children():
		WorldState.register_location(marker.name, marker.global_position)

	# Spawn environment decorations
	_build_dungeon_walls()
	_tile_dungeon_floor()
	_spawn_dungeon_decorations()
	_spawn_town_trees()
	_decorate_town()
	_spawn_field_decorations()
	_decorate_field()
	_add_zone_lighting()

	# Apply toon shading to all environment meshes
	_apply_toon_to_environment()

	# Bake navmesh after environment is ready
	var nav_region := $NavigationRegion3D
	nav_region.bake_finished.connect(_on_navmesh_baked)
	await get_tree().create_timer(0.5).timeout
	nav_region.bake_navigation_mesh()

func _on_navmesh_baked() -> void:
	var nav_mesh: NavigationMesh = $NavigationRegion3D.navigation_mesh
	var poly_count: int = nav_mesh.get_polygon_count()
	print("[NavMesh] Bake finished — %d polygons" % poly_count)
	if poly_count == 0:
		push_warning("[NavMesh] WARNING: Navmesh is EMPTY!")
	_setup_adventurer_npcs()

func _setup_adventurer_npcs() -> void:
	# Kael (Warrior) — bold, charges into combat
	var kael: Node3D = $NPCs/Kael
	if kael:
		WorldState.add_to_inventory("kael", "basic_sword")
		WorldState.add_to_inventory("kael", "healing_potion", 3)
		WorldState.equip_item("kael", "basic_sword")

		kael.get_node("NPCBrain").set_test_actions([
			{"action": "move_to", "target": "FieldEntrance", "thinking": "Time to go hunting!"},
			{"action": "move_to", "target": "FieldCenter", "thinking": "Let me find some monsters"},
			{"action": "wait", "target": "", "thinking": "Looking around for targets"},
			{"action": "move_to", "target": "FieldFar", "thinking": "Pushing deeper into the field"},
			{"action": "move_to", "target": "TownSquare", "thinking": "Need to resupply"},
			{"action": "talk_to", "target": "lyra", "dialogue": "Hey Lyra, the field has some tough wolves!", "thinking": "Should warn Lyra about the wolves"},
		])
		kael.get_node("NPCBrain").set_use_llm(false)

	# Lyra (Mage) — cautious, strategic
	var lyra: Node3D = $NPCs/Lyra
	if lyra:
		WorldState.add_to_inventory("lyra", "healing_potion", 5)
		WorldState.set_entity_data("lyra", "gold", 60)

		lyra.get_node("NPCBrain").set_test_actions([
			{"action": "move_to", "target": "ItemShopArea", "thinking": "Let me check the item shop first"},
			{"action": "move_to", "target": "FieldEntrance", "thinking": "Scouting the field carefully"},
			{"action": "move_to", "target": "FieldCenter", "thinking": "Moving deeper, staying alert"},
			{"action": "wait", "target": "", "thinking": "Observing the monsters here"},
			{"action": "move_to", "target": "TownSquare", "thinking": "Time to head back and sell loot"},
			{"action": "talk_to", "target": "kael", "dialogue": "Kael, you should buy potions before going out.", "thinking": "Kael never prepares properly"},
		])
		lyra.get_node("NPCBrain").set_use_llm(false)

# =============================================================================
# Asset Loading Infrastructure
# =============================================================================

func _load_model(path: String) -> PackedScene:
	if _model_cache.has(path):
		return _model_cache[path]
	var scene := load(path) as PackedScene
	if scene:
		_model_cache[path] = scene
	else:
		push_warning("Failed to load model: " + path)
	return scene

func _spawn_model(path: String, pos: Vector3, rot_y: float = 0.0, scale_val: float = 1.0, parent: Node = null) -> Node3D:
	var scene := _load_model(path)
	if not scene:
		return null
	var instance: Node3D = scene.instantiate()
	instance.position = pos
	if rot_y != 0.0:
		instance.rotation.y = rot_y
	if scale_val != 1.0:
		instance.scale = Vector3.ONE * scale_val
	var target_parent := parent if parent else $NavigationRegion3D
	target_parent.add_child(instance)
	return instance

func _get_or_create_color_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _color_mat_cache.has(key):
		return _color_mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_color_mat_cache[key] = mat
	return mat

func _apply_color_to_model(instance: Node3D, color: Color) -> void:
	var mat := _get_or_create_color_mat(color)
	_apply_material_recursive(instance, mat)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		for i in mesh_inst.get_surface_override_material_count():
			mesh_inst.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _create_bark_material(misc: bool = false) -> StandardMaterial3D:
	var prefix := "T_FirBarkMisc" if misc else "T_FirBark"
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _load_texture(TREE_TEX_DIR + prefix + "_BC.PNG")
	return mat

func _create_leaf_material(color: Color = Color(0.18, 0.55, 0.12)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.albedo_texture = _load_texture(TREE_TEX_DIR + "T_Leaf_Fir_Filled.PNG")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _apply_tree_materials(instance: Node3D, leaf_color: Color, use_misc_bark: bool = false) -> void:
	var bark_mat := _create_bark_material(use_misc_bark)
	var leaf_mat := _create_leaf_material(leaf_color)
	_apply_tree_materials_recursive(instance, bark_mat, leaf_mat)
	_tree_mat_names_printed = true

func _apply_tree_materials_recursive(node: Node, bark_mat: Material, leaf_mat: Material) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var surface_count := mesh_inst.get_surface_override_material_count()
		var has_leaf_match := false

		# First pass: check if any material name contains "leaf"
		for i in surface_count:
			var orig_mat := mesh_inst.mesh.surface_get_material(i)
			var mat_name := orig_mat.resource_name.to_lower() if orig_mat else ""
			if not _tree_mat_names_printed:
				print("[Tree] Surface %d material name: '%s'" % [i, mat_name])
			if "leaf" in mat_name or "leaves" in mat_name:
				has_leaf_match = true
				break

		# Second pass: apply materials
		for i in surface_count:
			var orig_mat := mesh_inst.mesh.surface_get_material(i)
			var mat_name := orig_mat.resource_name.to_lower() if orig_mat else ""
			if has_leaf_match:
				if "leaf" in mat_name or "leaves" in mat_name:
					mesh_inst.set_surface_override_material(i, leaf_mat)
				else:
					mesh_inst.set_surface_override_material(i, bark_mat)
			else:
				# Fallback: if 2+ surfaces, last surface is leaves
				if surface_count >= 2 and i == surface_count - 1:
					mesh_inst.set_surface_override_material(i, leaf_mat)
				else:
					mesh_inst.set_surface_override_material(i, bark_mat)
	for child in node.get_children():
		_apply_tree_materials_recursive(child, bark_mat, leaf_mat)

func _spawn_foliage(filename: String, pos: Vector3, color: Color, rot_y: float = 0.0, scale_val: float = 0.25) -> Node3D:
	var instance := _spawn_model(FOLIAGE_DIR + filename, pos, rot_y, scale_val)
	if instance:
		_apply_color_to_model(instance, color)
	return instance

func _spawn_tree(filename: String, pos: Vector3, rot_y: float = 0.0, scale_val: float = 0.25, leaf_color: Color = Color(0.18, 0.55, 0.12)) -> Node3D:
	var instance := _spawn_model(TREE_DIR + filename, pos, rot_y, scale_val)
	if instance:
		_apply_tree_materials(instance, leaf_color)
		# Add trunk collision for navmesh
		var body := StaticBody3D.new()
		body.position = Vector3(0, 1.5, 0)
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.3
		shape.height = 3.0
		col.shape = shape
		body.add_child(col)
		instance.add_child(body)
	return instance

func _spawn_dungeon_model(filename: String, pos: Vector3, rot_y: float = 0.0, scale_val: float = 1.0) -> Node3D:
	return _spawn_model(DUNGEON_DIR + filename, pos, rot_y, scale_val)

func _add_torch_light(_parent: Node3D, _offset: Vector3 = Vector3(0, 1.5, 0)) -> void:
	# OmniLights removed for performance — ambient light provides adequate illumination.
	pass

# =============================================================================
# Dungeon Zone
# =============================================================================

func _build_dungeon_walls() -> void:
	var walls_parent := $NavigationRegion3D/DungeonWalls

	# Measure wall tile width from model AABB
	var wall_scene := _load_model(DUNGEON_DIR + "wall.gltf.glb")
	var wall_width := 2.0  # default fallback
	if wall_scene:
		var temp := wall_scene.instantiate() as Node3D
		var aabb := _get_node_aabb(temp)
		if aabb.size.x > 0.1:
			wall_width = aabb.size.x
		elif aabb.size.z > 0.1:
			wall_width = aabb.size.z
		temp.queue_free()
	print("[Dungeon] Wall tile width: %.2f" % wall_width)

	# North wall: z=20, x from 40 to 70
	_place_wall_line(Vector3(40, 0, 20), Vector3(70, 0, 20), wall_width, 0.0, walls_parent)
	# South wall: z=50, x from 40 to 70
	_place_wall_line(Vector3(40, 0, 50), Vector3(70, 0, 50), wall_width, PI, walls_parent)
	# East wall: x=70, z from 20 to 50
	_place_wall_line(Vector3(70, 0, 20), Vector3(70, 0, 50), wall_width, -PI / 2.0, walls_parent)
	# West wall with entrance gap: x=40, z=20 to 28, then z=36 to 50
	_place_wall_line(Vector3(40, 0, 20), Vector3(40, 0, 28), wall_width, PI / 2.0, walls_parent)
	_place_wall_line(Vector3(40, 0, 36), Vector3(40, 0, 50), wall_width, PI / 2.0, walls_parent)

	# Doorway at entrance
	var doorway := _spawn_dungeon_model("wall_doorway.glb", Vector3(40, 0, 32), PI / 2.0)
	if doorway:
		doorway.reparent(walls_parent)
		_add_wall_collision(doorway, Vector3(1, 3, 4))

	# Corners
	_spawn_dungeon_model("wall_corner.gltf.glb", Vector3(40, 0, 20), 0.0)
	_spawn_dungeon_model("wall_corner.gltf.glb", Vector3(70, 0, 20), -PI / 2.0)
	_spawn_dungeon_model("wall_corner.gltf.glb", Vector3(70, 0, 50), PI)
	_spawn_dungeon_model("wall_corner.gltf.glb", Vector3(40, 0, 50), PI / 2.0)

	# Inner walls using wall_arched for variety
	_place_wall_line(Vector3(46, 0, 30), Vector3(54, 0, 30), wall_width, 0.0, walls_parent, true)
	_place_wall_line(Vector3(56, 0, 40), Vector3(64, 0, 40), wall_width, 0.0, walls_parent, true)

func _place_wall_line(start: Vector3, end: Vector3, tile_w: float, rot_y: float, parent: Node, is_inner: bool = false) -> void:
	var direction := (end - start).normalized()
	var total_dist := start.distance_to(end)
	var count := int(total_dist / tile_w)
	if count < 1:
		count = 1

	for i in count:
		var pos := start + direction * (tile_w * i + tile_w * 0.5)
		# Every 4th-5th wall segment use broken variant for variety
		var wall_file := "wall.gltf.glb"
		if is_inner:
			wall_file = "wall_arched.gltf.glb"
		elif i % 5 == 3:
			wall_file = "wall_broken.gltf.glb"

		var wall := _spawn_dungeon_model(wall_file, pos, rot_y)
		if wall:
			wall.reparent(parent)
			_add_wall_collision(wall, Vector3(tile_w, 3, 1))

func _add_wall_collision(wall_node: Node3D, box_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0, box_size.y * 0.5, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	body.add_child(col)
	wall_node.add_child(body)

func _get_node_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_aabb: AABB = child.get_aabb()
			if not found:
				result = mesh_aabb
				found = true
			else:
				result = result.merge(mesh_aabb)
	if not found:
		for child in node.get_children():
			if child is Node3D:
				var child_aabb := _get_node_aabb(child)
				if child_aabb.size.length() > 0.01:
					if not found:
						result = child_aabb
						found = true
					else:
						result = result.merge(child_aabb)
	return result

func _tile_dungeon_floor() -> void:
	# Single plane replaces ~150 individual floor tile models for draw call reduction
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)  # covers dungeon area 40→70 x 20→50
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(55, 0.02, 35)  # center of dungeon area
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.18, 0.15)
	mat.roughness = 1.0
	floor_mesh.set_surface_override_material(0, mat)
	$NavigationRegion3D.add_child(floor_mesh)

func _spawn_dungeon_decorations() -> void:
	# Torches along walls with lights
	var torch_positions := [
		# North wall torches
		Vector3(45, 0, 20.5), Vector3(51, 0, 20.5), Vector3(57, 0, 20.5), Vector3(63, 0, 20.5),
		# South wall torches
		Vector3(45, 0, 49.5), Vector3(51, 0, 49.5), Vector3(57, 0, 49.5), Vector3(63, 0, 49.5),
		# East wall torches
		Vector3(69.5, 0, 25), Vector3(69.5, 0, 32), Vector3(69.5, 0, 39), Vector3(69.5, 0, 46),
		# West wall torches
		Vector3(40.5, 0, 24), Vector3(40.5, 0, 42), Vector3(40.5, 0, 48),
		# Inner area torches
		Vector3(50, 0, 35), Vector3(60, 0, 35),
	]
	for torch_rot_data in [
		[Vector3(45, 0, 20.5), PI],
		[Vector3(51, 0, 20.5), PI],
		[Vector3(57, 0, 20.5), PI],
		[Vector3(63, 0, 20.5), PI],
	]:
		pass  # rotation handled below

	for pos in torch_positions:
		# Determine rotation based on which wall the torch is near
		var rot := 0.0
		if pos.z < 21:  # North wall
			rot = PI
		elif pos.z > 49:  # South wall
			rot = 0.0
		elif pos.x > 69:  # East wall
			rot = PI / 2.0
		elif pos.x < 41:  # West wall
			rot = -PI / 2.0

		var torch := _spawn_dungeon_model("torch_mounted.gltf.glb", pos, rot)
		if torch:
			_add_torch_light(torch)

	# Pillars at room corners
	_spawn_dungeon_model("pillar_decorated.gltf.glb", Vector3(43, 0, 23))
	_spawn_dungeon_model("pillar_decorated.gltf.glb", Vector3(67, 0, 23))
	_spawn_dungeon_model("pillar_decorated.gltf.glb", Vector3(67, 0, 47))
	_spawn_dungeon_model("pillar_decorated.gltf.glb", Vector3(43, 0, 47))

	# Pillars flanking inner walls
	_spawn_dungeon_model("pillar.gltf.glb", Vector3(46, 0, 30))
	_spawn_dungeon_model("pillar.gltf.glb", Vector3(54, 0, 30))
	_spawn_dungeon_model("pillar.gltf.glb", Vector3(56, 0, 40))
	_spawn_dungeon_model("pillar.gltf.glb", Vector3(64, 0, 40))

	# Banners at entrance and near chest
	_spawn_dungeon_model("banner_red.gltf.glb", Vector3(40.5, 0, 30), -PI / 2.0)
	_spawn_dungeon_model("banner_red.gltf.glb", Vector3(40.5, 0, 34), -PI / 2.0)
	_spawn_dungeon_model("banner_red.gltf.glb", Vector3(65, 0, 46))

	# Storage clusters near walls
	_spawn_dungeon_model("barrel_large.gltf.glb", Vector3(42, 0, 46))
	_spawn_dungeon_model("barrel_small.gltf.glb", Vector3(43.5, 0, 46.5))
	_spawn_dungeon_model("crates_stacked.gltf.glb", Vector3(44, 0, 47), 0.3)
	_spawn_dungeon_model("barrel_large.gltf.glb", Vector3(68, 0, 22))
	_spawn_dungeon_model("crates_stacked.gltf.glb", Vector3(67, 0, 23), -0.5)

	# Chest
	_spawn_dungeon_model("chest.glb", Vector3(65, 0, 45), PI)

	# Stairs at entrance
	_spawn_dungeon_model("stairs.gltf.glb", Vector3(40, 0, 32), PI / 2.0)

	# Red ferns near entrance for transition feel
	var dark_green := Color(0.08, 0.18, 0.06)
	_spawn_foliage("SM_RedFern01.FBX", Vector3(39, 0, 30), dark_green, 0.0, 0.25)
	_spawn_foliage("SM_RedFern02.FBX", Vector3(39, 0, 34), dark_green, 1.2, 0.25)
	_spawn_foliage("SM_Fern1.FBX", Vector3(38, 0, 32), dark_green, 0.5, 0.25)

	# Dungeon atmosphere — dark ceiling
	_create_dungeon_ceiling()

func _create_dungeon_ceiling() -> void:
	var ceiling := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(30, 30)
	ceiling.mesh = mesh
	ceiling.position = Vector3(55, 3.5, 35)
	ceiling.rotation.x = PI  # Flip to face downward
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.08, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ceiling.material_override = mat
	$NavigationRegion3D.add_child(ceiling)

# =============================================================================
# Town Zone
# =============================================================================

func _spawn_town_trees() -> void:
	var leaf_green := Color(0.18, 0.55, 0.12)
	var dark_leaf := Color(0.12, 0.42, 0.08)
	var light_leaf := Color(0.25, 0.6, 0.18)

	# Replace procedural trees with fir tree models
	var tree_positions := [
		["SM_FirTree1.FBX", Vector3(-12, 0, 5), 0.0, leaf_green],
		["SM_FirTree3.FBX", Vector3(-14, 0, 8), 0.5, dark_leaf],
		["SM_FirTree2.FBX", Vector3(-10, 0, -8), 1.2, leaf_green],
		["SM_FirTree4.FBX", Vector3(10, 0, 8), 0.8, dark_leaf],
		["SM_FirTree5.FBX", Vector3(12, 0, -12), 2.0, leaf_green],
		["SM_FirTree1.FBX", Vector3(-16, 0, -2), 1.5, dark_leaf],
	]
	for data in tree_positions:
		_spawn_tree(data[0], data[1], data[2], 0.25, data[3])

	# Saplings near paths
	_spawn_tree("SM_FirSapling1.FBX", Vector3(-5, 0, 9), 0.3, 0.25, light_leaf)
	_spawn_tree("SM_FirSapling2.FBX", Vector3(7, 0, 7), 1.8, 0.25, light_leaf)

func _decorate_town() -> void:
	var green := Color(0.2, 0.45, 0.15)
	var dark_green := Color(0.15, 0.35, 0.1)
	var flower_pink := Color(0.85, 0.4, 0.55)
	var flower_yellow := Color(0.9, 0.85, 0.3)
	var flower_white := Color(0.9, 0.9, 0.85)
	var flower_orange := Color(0.9, 0.6, 0.2)

	# Bushes along paths and near buildings
	_spawn_foliage("SM_Bush1.FBX", Vector3(-3, 0, -3), green, 0.0)
	_spawn_foliage("SM_Bush2.FBX", Vector3(3, 0, -3), green, 1.0)
	_spawn_foliage("SM_Bush3.FBX", Vector3(-6, 0, 6), dark_green, 0.5)
	_spawn_foliage("SM_BushLeafy01.FBX", Vector3(-10, 0, -3), green, 0.0)
	_spawn_foliage("SM_BushLeafy02.FBX", Vector3(10, 0, -3), green, 2.0)
	_spawn_foliage("SM_BushChina01.FBX", Vector3(-4, 0, 8), dark_green, 0.8)
	_spawn_foliage("SM_BushChina02.FBX", Vector3(8, 0, 5), dark_green, 1.5)
	_spawn_foliage("SM_Bush1.FBX", Vector3(6, 0, -10), green, 2.5)

	# Flowers near well (reduced from 3 to 2)
	_spawn_foliage("SM_Flower_Daisies1.FBX", Vector3(4.5, 0, -1), flower_white, 0.0)
	_spawn_foliage("SM_FlowerBush01.FBX", Vector3(2, 0, -2.5), flower_pink, 0.5)

	# One flower per shop front (reduced from 4 to 2)
	_spawn_foliage("SM_Flower_TulipsRed.FBX", Vector3(-6, 0, -3), flower_pink, 0.0)
	_spawn_foliage("SM_Flower_TulipsYellow.FBX", Vector3(6, 0, -4), flower_yellow, 0.0)

	# Grass patches removed for draw call reduction

	# Shop props — barrels and crates outside weapon shop
	_spawn_dungeon_model("barrel_large.gltf.glb", Vector3(-5.5, 0, -3))
	_spawn_dungeon_model("crates_stacked.gltf.glb", Vector3(-10.5, 0, -3.5), 0.3)

	# Barrel outside item shop
	_spawn_dungeon_model("barrel_small.gltf.glb", Vector3(10, 0, -4))

	# Leafy bushes flanking shop entrances
	_spawn_foliage("SM_BushLeafy01.FBX", Vector3(-5.5, 0, -5), green, 0.0)
	_spawn_foliage("SM_BushLeafy02.FBX", Vector3(5.5, 0, -6), green, 1.0)

	# Torches at shop fronts
	var torch1 := _spawn_dungeon_model("torch_lit.gltf.glb", Vector3(-6.5, 0, -3))
	if torch1:
		_add_torch_light(torch1)
	var torch2 := _spawn_dungeon_model("torch_lit.gltf.glb", Vector3(-9.5, 0, -3))
	if torch2:
		_add_torch_light(torch2)
	var torch3 := _spawn_dungeon_model("torch_lit.gltf.glb", Vector3(6.5, 0, -4))
	if torch3:
		_add_torch_light(torch3)
	var torch4 := _spawn_dungeon_model("torch_lit.gltf.glb", Vector3(9.5, 0, -4))
	if torch4:
		_add_torch_light(torch4)

	# Bushes along fence lines
	_spawn_foliage("SM_BushChina01.FBX", Vector3(11.5, 0, -8), dark_green, 0.0)
	_spawn_foliage("SM_BushChina02.FBX", Vector3(11.5, 0, 0), dark_green, 1.2)
	_spawn_foliage("SM_BushChina03.FBX", Vector3(11.5, 0, 10), dark_green, 2.0)

	# Torches at field entrance as gateposts
	var gate_torch1 := _spawn_dungeon_model("torch_lit.gltf.glb", Vector3(14, 0, 9))
	if gate_torch1:
		_add_torch_light(gate_torch1)
	var gate_torch2 := _spawn_dungeon_model("torch_lit.gltf.glb", Vector3(14, 0, 11))
	if gate_torch2:
		_add_torch_light(gate_torch2)

# =============================================================================
# Field Zone
# =============================================================================

func _spawn_field_decorations() -> void:
	var leaf_green := Color(0.18, 0.55, 0.12)
	var dark_leaf := Color(0.12, 0.42, 0.08)
	var light_leaf := Color(0.25, 0.6, 0.18)
	var muted_leaf := Color(0.15, 0.35, 0.1)

	# Fir trees scattered across the field — clustered in groups
	# Cluster 1: near entrance
	_spawn_tree("SM_FirTree1.FBX", Vector3(18, 0, 12), 0.0, 0.25, leaf_green)
	_spawn_tree("SM_FirTree3.FBX", Vector3(20, 0, 14), 0.8, 0.25, dark_leaf)

	# Cluster 2: center-west
	_spawn_tree("SM_FirTree2.FBX", Vector3(24, 0, 20), 1.5, 0.25, dark_leaf)
	_spawn_tree("SM_FirTree5.FBX", Vector3(26, 0, 22), 0.3, 0.25, leaf_green)
	_spawn_tree("SM_FirSapling1.FBX", Vector3(25, 0, 19), 2.0, 0.25, light_leaf)

	# Cluster 3: south
	_spawn_tree("SM_FirTree4.FBX", Vector3(28, 0, 38), 0.5, 0.25, leaf_green)
	_spawn_tree("SM_FirTree1.FBX", Vector3(30, 0, 40), 1.2, 0.25, dark_leaf)

	# Cluster 4: east
	_spawn_tree("SM_FirTree3.FBX", Vector3(38, 0, 25), 2.5, 0.25, dark_leaf)
	_spawn_tree("SM_FirSapling2.FBX", Vector3(37, 0, 27), 0.0, 0.25, light_leaf)

	# Scattered singles
	_spawn_tree("SM_FirTree2.FBX", Vector3(35, 0, 35), 1.0, 0.25, leaf_green)

	# Stumps and fallen trees with misc bark textures
	var stump1 := _spawn_model(TREE_DIR + "SM_FirStump1.FBX", Vector3(22, 0, 28), 0.5, 0.25)
	if stump1:
		_apply_tree_materials(stump1, muted_leaf, true)
	var fallen1 := _spawn_model(TREE_DIR + "SM_FirFallen1.FBX", Vector3(32, 0, 18), 0.8, 0.25)
	if fallen1:
		_apply_tree_materials(fallen1, muted_leaf, true)
	var fallen2 := _spawn_model(TREE_DIR + "SM_FirFallen2.FBX", Vector3(36, 0, 40), 2.0, 0.25)
	if fallen2:
		_apply_tree_materials(fallen2, muted_leaf, true)

	# Rock clusters (reduced from 6 to 4)
	_create_rock_cluster(Vector3(20, 0, 20))
	_create_rock_cluster(Vector3(38, 0, 22))
	_create_rock_cluster(Vector3(30, 0, 35))
	_create_rock_cluster(Vector3(34, 0, 28))

func _create_rock_cluster(center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x * 100 + center.z * 10)
	var rock_mat := _get_or_create_color_mat(Color(0.4, 0.38, 0.36))
	for i in 2:
		var offset := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
		var radius := rng.randf_range(0.3, 0.7)
		var pos := center + offset
		pos.y = radius * 0.3

		var rock := StaticBody3D.new()
		rock.position = pos
		$NavigationRegion3D.add_child(rock)

		var mesh_inst := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * rng.randf_range(1.0, 1.6)
		mesh_inst.mesh = sphere
		mesh_inst.rotation.y = rng.randf() * TAU
		mesh_inst.rotation.x = rng.randf_range(-0.2, 0.2)
		mesh_inst.set_surface_override_material(0, rock_mat)
		rock.add_child(mesh_inst)

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = radius
		col.shape = shape
		rock.add_child(col)

func _decorate_field() -> void:
	var green := Color(0.22, 0.48, 0.16)
	var dark_green := Color(0.15, 0.38, 0.1)
	var grass_color := Color(0.28, 0.52, 0.2)
	var fern_color := Color(0.18, 0.42, 0.12)
	var flower_yellow := Color(0.9, 0.85, 0.3)
	var flower_orange := Color(0.9, 0.6, 0.2)

	# Grass scattered across field (reduced from 15 to 5)
	var grass_positions := [
		Vector3(22, 0, 22), Vector3(28, 0, 25), Vector3(33, 0, 20),
		Vector3(35, 0, 32), Vector3(24, 0, 35),
	]
	for i in grass_positions.size():
		var grass_file := "SM_Grass1.FBX" if i % 2 == 0 else "SM_Grass2.FBX"
		_spawn_foliage(grass_file, grass_positions[i], grass_color, float(i) * 1.3)

	# Ferns near trees (reduced from 10 to 4)
	var fern_data := [
		["SM_Fern1.FBX", Vector3(19, 0, 13)],
		["SM_Fern2.FBX", Vector3(25, 0, 21)],
		["SM_Fern3.FBX", Vector3(37, 0, 24)],
		["SM_Fern1.FBX", Vector3(34, 0, 34)],
	]
	for data in fern_data:
		_spawn_foliage(data[0], data[1], fern_color, randf() * TAU)

	# Bushes in clusters (reduced from 6 to 3)
	_spawn_foliage("SM_Bush1.FBX", Vector3(21, 0, 17), green, 0.0)
	_spawn_foliage("SM_Bush2.FBX", Vector3(26, 0, 25), green, 1.2)
	_spawn_foliage("SM_Bush3.FBX", Vector3(33, 0, 33), dark_green, 0.5)

	# Flowers (reduced from 5 to 2)
	_spawn_foliage("SM_Flower_DaffodilsYellow.FBX", Vector3(18, 0, 18), flower_yellow, 0.0)
	_spawn_foliage("SM_Flower_Sunflower1.FBX", Vector3(24, 0, 15), flower_yellow, 0.0)

	# Field-dungeon transition removed for draw call reduction

	# Torches flanking dungeon path entrance
	var dt1 := _spawn_dungeon_model("torch_lit.gltf.glb", Vector3(41, 0, 29))
	if dt1:
		_add_torch_light(dt1)
	var dt2 := _spawn_dungeon_model("torch_lit.gltf.glb", Vector3(41, 0, 31))
	if dt2:
		_add_torch_light(dt2)

# =============================================================================
# Lighting
# =============================================================================

func _add_zone_lighting() -> void:
	# OmniLights removed for performance — ambient light provides adequate illumination.
	pass

