class_name InteriorInn
extends InteriorBase
## Inn interior — 12x10m room with counter, tables, and warm lighting.
## Geometry is built procedurally in _ready(). No roof — isometric camera
## looks down into the room from above.
## Position the root at Y=-50 to isolate from exterior geometry.

const FLOOR_W: float = 12.0
const FLOOR_D: float = 10.0
const WALL_H: float = 3.0
const WALL_T: float = 0.15

const COLOR_FLOOR: Color = Color(0.35, 0.22, 0.12)
const COLOR_WALL: Color = Color(0.45, 0.30, 0.18)
const COLOR_COUNTER: Color = Color(0.30, 0.18, 0.10)
const COLOR_TABLE: Color = Color(0.40, 0.26, 0.14)
const COLOR_VOID: Color = Color(0.08, 0.05, 0.03)
const COLOR_LIGHT: Color = Color(1.0, 0.85, 0.6)
const COLOR_DOOR_FRAME: Color = Color(0.22, 0.13, 0.07)
const COLOR_PILLAR: Color = Color(0.28, 0.17, 0.09)


func _ready() -> void:
	interior_type = "inn"

	var nav_region: NavigationRegion3D = _build_nav_region()
	add_child(nav_region)

	_build_floor(nav_region)
	_build_walls(nav_region)
	_build_counter(nav_region)
	_build_tables(nav_region)
	_build_void_ground()
	_build_lights()
	_build_spawn_point()
	_build_exit_door()
	_build_innkeeper()

	super._ready()


func _build_innkeeper() -> void:
	# Counter center is at Z = -FLOOR_D * 0.5 + 0.8 = -4.2, depth 0.5.
	# Back face of counter is at Z ≈ -4.45. Back wall inner face at Z = -5.0.
	# Split the gap: innkeeper at Z = -4.7.
	var innkeeper: StaticBody3D = StaticBody3D.new()
	innkeeper.set_script(preload("res://scenes/interiors/interior_npc.gd"))
	innkeeper.npc_name = "Innkeeper"
	innkeeper.npc_role = "innkeeper"
	innkeeper.npc_color = Color(0.7, 0.5, 0.3, 1.0)
	innkeeper.model_path = "res://assets/models/characters/Barbarian.glb"
	innkeeper.model_scale = 0.7
	innkeeper.position = Vector3(0.0, 0.0, -4.7)
	add_child(innkeeper)

	# Add stock after _setup_vending() has run (triggered by add_child above).
	var vending: Node = innkeeper.get_node_or_null("VendingComponent")
	if vending:
		vending.add_listing("healing_potion",  10, 25)
		vending.add_listing("bandage",         10, 10)
		vending.add_listing("cooked_sardine",  10, 12)
		vending.add_listing("cooked_trout",     5, 30)
		vending.add_listing("fish_stew",        5, 40)


# --- Geometry builders --------------------------------------------------------

func _build_nav_region() -> NavigationRegion3D:
	var nav_region: NavigationRegion3D = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"

	var nav_mesh: NavigationMesh = NavigationMesh.new()
	nav_mesh.cell_size = 0.25
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.25
	nav_region.navigation_mesh = nav_mesh

	return nav_region


func _build_floor(nav_region: NavigationRegion3D) -> void:
	var mat: StandardMaterial3D = _make_mat(COLOR_FLOOR)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(FLOOR_W, 0.1, FLOOR_D)
	mesh_inst.mesh = box
	mesh_inst.set_surface_override_material(0, mat)

	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(0.0, -0.05, 0.0)
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(FLOOR_W, 0.1, FLOOR_D)
	col.shape = shape
	body.add_child(mesh_inst)
	body.add_child(col)

	nav_region.add_child(body)


func _build_walls(nav_region: NavigationRegion3D) -> void:
	var mat: StandardMaterial3D = _make_mat(COLOR_WALL)

	# Left wall (X-)
	_add_wall(nav_region, mat,
		Vector3(-FLOOR_W * 0.5 - WALL_T * 0.5, WALL_H * 0.5, 0.0),
		Vector3(WALL_T, WALL_H, FLOOR_D + WALL_T * 2.0))

	# Right wall (X+) — removed, camera faces from this side at 45° yaw

	# Back wall (Z-)
	_add_wall(nav_region, mat,
		Vector3(0.0, WALL_H * 0.5, -FLOOR_D * 0.5 - WALL_T * 0.5),
		Vector3(FLOOR_W, WALL_H, WALL_T))

	# Front wall (Z+) — removed for camera visibility, only lintel above doorway
	var door_half_w: float = 0.8
	var front_z: float = FLOOR_D * 0.5 + WALL_T * 0.5

	# Lintel above doorway opening
	var lintel_h: float = WALL_H - 2.0
	_add_wall(nav_region, mat,
		Vector3(0.0, 2.0 + lintel_h * 0.5, front_z),
		Vector3(door_half_w * 2.0, lintel_h, WALL_T))


func _add_wall(nav_region: NavigationRegion3D, mat: StandardMaterial3D,
		pos: Vector3, size: Vector3) -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.set_surface_override_material(0, mat)

	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(mesh_inst)
	body.add_child(col)

	nav_region.add_child(body)


func _build_counter(nav_region: NavigationRegion3D) -> void:
	var mat: StandardMaterial3D = _make_mat(COLOR_COUNTER)

	var size: Vector3 = Vector3(2.5, 0.9, 0.5)
	var pos: Vector3 = Vector3(0.0, size.y * 0.5, -FLOOR_D * 0.5 + 0.8)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.set_surface_override_material(0, mat)

	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(mesh_inst)
	body.add_child(col)

	nav_region.add_child(body)


func _build_tables(nav_region: NavigationRegion3D) -> void:
	var mat: StandardMaterial3D = _make_mat(COLOR_TABLE)

	var table_size: Vector3 = Vector3(1.0, 0.7, 0.8)
	var positions: Array[Vector3] = [
		Vector3(-3.0, table_size.y * 0.5, 2.0),
		Vector3(3.0, table_size.y * 0.5, 2.0),
		Vector3(-3.0, table_size.y * 0.5, 4.0),
		Vector3(3.0, table_size.y * 0.5, 4.0),
	]

	for pos: Vector3 in positions:
		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = table_size
		mesh_inst.mesh = box
		mesh_inst.set_surface_override_material(0, mat)

		var body: StaticBody3D = StaticBody3D.new()
		body.position = pos
		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = table_size
		col.shape = shape
		body.add_child(mesh_inst)
		body.add_child(col)

		nav_region.add_child(body)


func _build_void_ground() -> void:
	# Large dark plane below the floor to prevent the camera seeing the void.
	var mat: StandardMaterial3D = _make_mat(COLOR_VOID)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(60.0, 0.1, 60.0)
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(0.0, -0.6, 0.0)
	mesh_inst.set_surface_override_material(0, mat)
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(mesh_inst)


func _build_lights() -> void:
	var light_positions: Array[Vector3] = [
		Vector3(-3.5, 2.5, -2.0),
		Vector3(3.5, 2.5, -2.0),
		Vector3(-3.0, 2.5, 2.5),
		Vector3(3.0, 2.5, 2.5),
	]

	for pos: Vector3 in light_positions:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = pos
		light.light_color = COLOR_LIGHT
		light.light_energy = 0.8
		light.omni_range = 8.0
		light.shadow_enabled = false
		add_child(light)


func _build_spawn_point() -> void:
	var marker: Marker3D = Marker3D.new()
	marker.name = "SpawnPoint"
	marker.position = Vector3(0.0, 0.0, 4.0)
	add_child(marker)


func _build_exit_door() -> void:
	var door_z: float = FLOOR_D * 0.5 + WALL_T
	var door_half_w: float = 0.8

	# --- Visible door frame geometry (added to scene directly, not nav_region) ---

	var frame_mat: StandardMaterial3D = _make_mat(COLOR_DOOR_FRAME)
	var pillar_mat: StandardMaterial3D = _make_mat(COLOR_PILLAR)

	# Left door post
	_add_door_post(frame_mat, Vector3(-door_half_w - 0.1, 1.0, door_z), Vector3(0.2, 2.0, 0.2))

	# Right door post
	_add_door_post(frame_mat, Vector3(door_half_w + 0.1, 1.0, door_z), Vector3(0.2, 2.0, 0.2))

	# Top lintel beam
	_add_door_post(pillar_mat, Vector3(0.0, 2.05, door_z), Vector3(door_half_w * 2.0 + 0.4, 0.15, 0.2))

	# "Exit" label above the doorway
	var label: Label3D = Label3D.new()
	label.text = "Exit"
	label.font_size = 20
	label.modulate = Color(1.0, 0.85, 0.2)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 2.4, door_z)
	label.no_depth_test = true
	add_child(label)

	# --- Area3D trigger — walk through to exit ---
	var area: Area3D = Area3D.new()
	area.name = "ExitDoor"
	area.position = Vector3(0.0, 1.0, door_z)

	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(door_half_w * 2.0, 2.0, 0.5)
	col.shape = shape
	area.add_child(col)

	add_child(area)


func _add_door_post(mat: StandardMaterial3D, pos: Vector3, size: Vector3) -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.set_surface_override_material(0, mat)

	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(mesh_inst)
	body.add_child(col)

	add_child(body)


# --- Helpers ------------------------------------------------------------------

func _make_mat(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
