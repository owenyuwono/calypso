## Shared static helpers for building and prop creation used across district modules.
class_name BuildingHelper

const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")
const InteriorDatabase = preload("res://scripts/data/interior_database.gd")
const DoorTrigger = preload("res://scripts/world/door_trigger.gd")


## Return the terrain height at (x, z) — used to snap props to ground.
static func snap_y(noise: FastNoiseLite, x: float, z: float, height_scale: float) -> float:
	return TerrainGenerator.get_height_at(noise, x, z, height_scale)


## Return the combined AABB of all MeshInstance3D descendants of node.
static func _get_model_aabb(node: Node3D) -> AABB:
	var combined := AABB()
	var first := true
	for child in node.get_children():
		if child is Node3D:
			for sub in child.get_children():
				if sub is MeshInstance3D and (sub as MeshInstance3D).mesh:
					var mesh_aabb: AABB = (sub as MeshInstance3D).mesh.get_aabb()
					if first:
						combined = mesh_aabb
						first = false
					else:
						combined = combined.merge(mesh_aabb)
	return combined


## Create a complete building: walled box + roof + optional door/chimney.
## When a GLB model exists at res://assets/models/environment/buildings/{building_type}.glb
## it is loaded instead of the procedural box; falls back to procedural when absent.
## Returns the root Node3D (already added to nav_region).
static func create_building(ctx: WorldBuilderContext, nav_region: Node3D, pos: Vector3, wall_size: Vector3,
		wall_color: Color, roof_type: String, roof_color: Color,
		roof_overhang: float = 0.5, has_chimney: bool = false,
		has_door: bool = true, rot_y: float = 0.0,
		building_type: String = "") -> Node3D:
	# --- GLB model override ---
	if not building_type.is_empty():
		var model_path: String = "res://assets/models/environment/buildings/%s.glb" % building_type
		if ResourceLoader.exists(model_path):
			var scene: PackedScene = load(model_path) as PackedScene
			if scene:
				var instance: Node3D = scene.instantiate()
				instance.position = pos
				if rot_y != 0.0:
					instance.rotation.y = rot_y
				# Meshy center-origin Y adjustment: shift up so base sits on ground
				var aabb: AABB = _get_model_aabb(instance)
				if aabb.position.y < -0.1:
					instance.position.y -= aabb.position.y
				# Add collision sized to wall_size
				var col := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = wall_size
				col.shape = box
				col.position.y = wall_size.y / 2.0
				var body := StaticBody3D.new()
				body.add_child(col)
				instance.add_child(body)
				nav_region.add_child(instance)
				return instance

	var building := Node3D.new()
	building.position = pos
	if rot_y != 0.0:
		building.rotation.y = rot_y
	if building_type != "":
		building.set_meta("building_type", building_type)

	# --- Walls ---
	var wall_body := StaticBody3D.new()
	wall_body.position = Vector3(0, wall_size.y * 0.5, 0)
	var wall_mesh_inst := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = wall_size
	wall_mesh_inst.mesh = wall_box
	var wall_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, wall_color)
	wall_mesh_inst.set_surface_override_material(0, wall_mat)
	wall_body.add_child(wall_mesh_inst)
	var wall_col := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = wall_size
	wall_col.shape = wall_shape
	wall_body.add_child(wall_col)
	building.add_child(wall_body)

	# --- Roof ---
	var roof_mesh_inst := MeshInstance3D.new()
	var roof_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, roof_color)

	if roof_type == "peaked":
		var roof_box := BoxMesh.new()
		var roof_w := wall_size.x + roof_overhang
		var roof_d := wall_size.z + roof_overhang
		roof_box.size = Vector3(roof_w, 0.3, roof_d)
		roof_mesh_inst.mesh = roof_box
		roof_mesh_inst.position = Vector3(0, wall_size.y + 0.15, 0)
		# Ridge for peaked feel
		var ridge := MeshInstance3D.new()
		var ridge_mesh := BoxMesh.new()
		ridge_mesh.size = Vector3(roof_w * 0.15, 0.8, roof_d + 0.2)
		ridge.mesh = ridge_mesh
		ridge.position = Vector3(0, wall_size.y + 0.7, 0)
		ridge.set_surface_override_material(0, roof_mat)
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		building.add_child(ridge)
	else:
		# Flat roof
		var roof_box := BoxMesh.new()
		roof_box.size = Vector3(wall_size.x + roof_overhang, 0.2, wall_size.z + roof_overhang)
		roof_mesh_inst.mesh = roof_box
		roof_mesh_inst.position = Vector3(0, wall_size.y + 0.1, 0)

	roof_mesh_inst.set_surface_override_material(0, roof_mat)
	building.add_child(roof_mesh_inst)

	# --- Door ---
	if has_door:
		# Door position: front face of the building, vertically centered at mid-door height.
		var door_pos := Vector3(0, 0.8, wall_size.z * 0.5 + 0.05)
		if not building_type.is_empty() and InteriorDatabase.has_interior(building_type):
			# Clickable DoorTrigger for buildings with interiors.
			var trigger: StaticBody3D = StaticBody3D.new()
			trigger.set_script(DoorTrigger)
			trigger.position = door_pos
			building.add_child(trigger)
			var did: String = "door_%s_%d_%d" % [building_type, int(pos.x), int(pos.z)]
			trigger.setup(building_type, did)
		else:
			# Decorative-only door mesh for buildings without interiors.
			var door := MeshInstance3D.new()
			var door_mesh := BoxMesh.new()
			door_mesh.size = Vector3(0.8, 1.6, 0.1)
			door.mesh = door_mesh
			door.position = door_pos
			var door_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, wall_color * 0.6)
			door.set_surface_override_material(0, door_mat)
			door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			building.add_child(door)

	# --- Chimney ---
	if has_chimney:
		var chimney := MeshInstance3D.new()
		var chimney_mesh := BoxMesh.new()
		chimney_mesh.size = Vector3(0.5, 1.2, 0.5)
		chimney.mesh = chimney_mesh
		chimney.position = Vector3(wall_size.x * 0.3, wall_size.y + 0.6, -wall_size.z * 0.3)
		var chimney_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.35, 0.32, 0.3))
		chimney.set_surface_override_material(0, chimney_mat)
		chimney.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		building.add_child(chimney)

	nav_region.add_child(building)
	return building


## Create a stacked-cylinder fountain at world_pos. Parameterised so the plaza
## (smaller) and park (larger) variants can share the same code.
## base_radius: outer basin radius; base_height: basin height (plaza=0.4, park=0.5);
## pillar_height: center column height; top_radius: upper basin top radius.
## Returns the fountain Node3D (already added to nav_region).
static func create_fountain(ctx: WorldBuilderContext, nav_region: Node3D, world_pos: Vector3,
		base_radius: float, base_height: float, pillar_height: float, top_radius: float) -> Node3D:
	var fountain := Node3D.new()
	fountain.position = world_pos

	var stone_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.5, 0.48, 0.45))

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = base_radius
	base_mesh.bottom_radius = base_radius
	base_mesh.height = base_height
	base.mesh = base_mesh
	base.position = Vector3(0, base_height * 0.5, 0)
	base.set_surface_override_material(0, stone_mat)
	fountain.add_child(base)

	var pillar := MeshInstance3D.new()
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.3
	pillar_mesh.bottom_radius = 0.4
	pillar_mesh.height = pillar_height
	pillar.mesh = pillar_mesh
	pillar.position = Vector3(0, base_height + pillar_height * 0.5, 0)
	pillar.set_surface_override_material(0, stone_mat)
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fountain.add_child(pillar)

	var top_basin := MeshInstance3D.new()
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = top_radius
	top_mesh.bottom_radius = top_radius * 0.8
	top_mesh.height = 0.3
	top_basin.mesh = top_mesh
	top_basin.position = Vector3(0, base_height + pillar_height + 0.15, 0)
	var water_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.3, 0.5, 0.7))
	top_basin.set_surface_override_material(0, water_mat)
	top_basin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fountain.add_child(top_basin)

	# Collision
	var fountain_body := StaticBody3D.new()
	fountain_body.position = Vector3(0, base_height * 0.5, 0)
	var fountain_col := CollisionShape3D.new()
	var fountain_shape := CylinderShape3D.new()
	fountain_shape.radius = base_radius
	fountain_shape.height = 1.0
	fountain_col.shape = fountain_shape
	fountain_body.add_child(fountain_col)
	fountain.add_child(fountain_body)

	nav_region.add_child(fountain)
	return fountain


## Create a wooden bench (seat + back rest + 4 legs) at world_pos with optional Y rotation.
## Returns the root Node3D (already added to nav_region).
static func create_bench(ctx: WorldBuilderContext, nav_region: Node3D, world_pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var bench_mat: StandardMaterial3D = AssetSpawner.get_or_create_color_mat(ctx, Color(0.45, 0.32, 0.18))

	var bench: Node3D = Node3D.new()
	bench.position = world_pos
	bench.rotation.y = rot_y

	# --- Seat plank ---
	var seat: MeshInstance3D = MeshInstance3D.new()
	var seat_mesh: BoxMesh = BoxMesh.new()
	seat_mesh.size = Vector3(1.2, 0.08, 0.4)
	seat.mesh = seat_mesh
	seat.position = Vector3(0.0, 0.4, 0.0)
	seat.set_surface_override_material(0, bench_mat)
	seat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bench.add_child(seat)

	# --- Back rest ---
	var back: MeshInstance3D = MeshInstance3D.new()
	var back_mesh: BoxMesh = BoxMesh.new()
	back_mesh.size = Vector3(1.2, 0.5, 0.06)
	back.mesh = back_mesh
	back.position = Vector3(0.0, 0.65, -0.17)
	back.set_surface_override_material(0, bench_mat)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bench.add_child(back)

	# --- Legs (4 corners) ---
	var leg_offsets: Array = [
		Vector3(-0.55, 0.2, 0.15),   # front-left
		Vector3(0.55, 0.2, 0.15),    # front-right
		Vector3(-0.55, 0.2, -0.15),  # back-left
		Vector3(0.55, 0.2, -0.15),   # back-right
	]
	for offset in leg_offsets:
		var leg: MeshInstance3D = MeshInstance3D.new()
		var leg_mesh: BoxMesh = BoxMesh.new()
		leg_mesh.size = Vector3(0.06, 0.4, 0.06)
		leg.mesh = leg_mesh
		leg.position = offset
		leg.set_surface_override_material(0, bench_mat)
		leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bench.add_child(leg)

	nav_region.add_child(bench)
	return bench
