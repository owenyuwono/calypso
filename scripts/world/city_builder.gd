extends RefCounted
## Static utility for building city district structures.
## Called from game_world.gd via: CityBuilder.build_all_districts(nav_region, terrain_noise, height_scale)
##
## City Layout (140x100, center at origin, x:-70..70, z:-50..50)
## Districts:
##   Central Plaza       (x:-15..20, z:-10..10)
##   Market District     (x:-70..-20, z:-10..50)
##   Residential Quarter (x:-70..-20, z:-50..-10)
##   Noble/Temple Quarter(x:-20..25, z:-50..-10)
##   Park/Gardens        (x:25..70, z:-50..-10)
##   Craft/Workshop      (x:-20..25, z:10..50)
##   Garrison/Training   (x:25..70, z:10..50)
##   City Gate Area      (x:55..70, z:-10..10)

const TerrainGenerator = preload("res://scripts/utils/terrain_generator.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")
const DUNGEON_DIR := "res://assets/models/environment/dungeon/"

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

static func build_all_districts(nav_region: Node3D, noise: FastNoiseLite, height_scale: float) -> void:
	_build_central_plaza(nav_region, noise, height_scale)
	_build_market_district(nav_region, noise, height_scale)
	_build_residential_quarter(nav_region, noise, height_scale)
	_build_noble_quarter(nav_region, noise, height_scale)
	_build_park_gardens(nav_region, noise, height_scale)
	_build_craft_district(nav_region, noise, height_scale)
	_build_garrison(nav_region, noise, height_scale)
	_build_gate_area(nav_region, noise, height_scale)

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

static func _snap_y(noise: FastNoiseLite, x: float, z: float, height_scale: float) -> float:
	return TerrainGenerator.get_height_at(noise, x, z, height_scale)


## Create a complete building: walled box + roof + optional door/chimney.
## Returns the root Node3D (already added to nav_region).
static func _create_building(nav_region: Node3D, pos: Vector3, wall_size: Vector3,
		wall_color: Color, roof_type: String, roof_color: Color,
		roof_overhang: float = 0.5, has_chimney: bool = false,
		has_door: bool = true, rot_y: float = 0.0) -> Node3D:
	var building := Node3D.new()
	building.position = pos
	if rot_y != 0.0:
		building.rotation.y = rot_y

	# --- Walls ---
	var wall_body := StaticBody3D.new()
	wall_body.position = Vector3(0, wall_size.y * 0.5, 0)
	var wall_mesh_inst := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = wall_size
	wall_mesh_inst.mesh = wall_box
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = wall_color
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
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = roof_color

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
		var door := MeshInstance3D.new()
		var door_mesh := BoxMesh.new()
		door_mesh.size = Vector3(0.8, 1.6, 0.1)
		door.mesh = door_mesh
		door.position = Vector3(0, 0.8, wall_size.z * 0.5 + 0.05)
		var door_mat := StandardMaterial3D.new()
		door_mat.albedo_color = wall_color * 0.6
		door.set_surface_override_material(0, door_mat)
		building.add_child(door)

	# --- Chimney ---
	if has_chimney:
		var chimney := MeshInstance3D.new()
		var chimney_mesh := BoxMesh.new()
		chimney_mesh.size = Vector3(0.5, 1.2, 0.5)
		chimney.mesh = chimney_mesh
		chimney.position = Vector3(wall_size.x * 0.3, wall_size.y + 0.6, -wall_size.z * 0.3)
		var chimney_mat := StandardMaterial3D.new()
		chimney_mat.albedo_color = Color(0.35, 0.32, 0.3)
		chimney.set_surface_override_material(0, chimney_mat)
		building.add_child(chimney)

	nav_region.add_child(building)
	return building

# ---------------------------------------------------------------------------
# District: Central Plaza (x:-15..20, z:-10..10)
# ---------------------------------------------------------------------------

static func _build_central_plaza(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# --- Upgraded fountain: stacked cylinders ---
	var fountain := Node3D.new()
	fountain.position = Vector3(0, _snap_y(noise, 0, 0, hs), 0)

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.5, 0.48, 0.45)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.5
	base_mesh.bottom_radius = 1.5
	base_mesh.height = 0.4
	base.mesh = base_mesh
	base.position = Vector3(0, 0.2, 0)
	base.set_surface_override_material(0, stone_mat)
	fountain.add_child(base)

	var pillar := MeshInstance3D.new()
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.3
	pillar_mesh.bottom_radius = 0.4
	pillar_mesh.height = 1.2
	pillar.mesh = pillar_mesh
	pillar.position = Vector3(0, 1.0, 0)
	pillar.set_surface_override_material(0, stone_mat)
	fountain.add_child(pillar)

	var top_basin := MeshInstance3D.new()
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 0.8
	top_mesh.bottom_radius = 0.6
	top_mesh.height = 0.3
	top_basin.mesh = top_mesh
	top_basin.position = Vector3(0, 1.75, 0)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.3, 0.5, 0.7)
	top_basin.set_surface_override_material(0, water_mat)
	fountain.add_child(top_basin)

	# Fountain collision body
	var fountain_body := StaticBody3D.new()
	fountain_body.position = Vector3(0, 0.5, 0)
	var fountain_col := CollisionShape3D.new()
	var fountain_shape := CylinderShape3D.new()
	fountain_shape.radius = 1.5
	fountain_shape.height = 1.0
	fountain_col.shape = fountain_shape
	fountain_body.add_child(fountain_col)
	fountain.add_child(fountain_body)

	nav_region.add_child(fountain)

	# --- Benches around fountain ---
	var bench_mat := StandardMaterial3D.new()
	bench_mat.albedo_color = Color(0.45, 0.32, 0.18)
	var bench_positions: Array = [Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3)]
	for bpos: Vector3 in bench_positions:
		var bench := MeshInstance3D.new()
		var bench_mesh := BoxMesh.new()
		bench_mesh.size = Vector3(1.5, 0.4, 0.5)
		bench.mesh = bench_mesh
		bench.position = Vector3(bpos.x, _snap_y(noise, bpos.x, bpos.z, hs) + 0.2, bpos.z)
		bench.set_surface_override_material(0, bench_mat)
		if bpos.x == 0:
			bench.rotation.y = PI * 0.5
		nav_region.add_child(bench)

	# --- Street lamps at road intersections ---
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.25, 0.25, 0.25)
	var lamp_glow_mat := StandardMaterial3D.new()
	lamp_glow_mat.albedo_color = Color(1.0, 0.9, 0.6)
	lamp_glow_mat.emission_enabled = true
	lamp_glow_mat.emission = Color(1.0, 0.85, 0.5)
	lamp_glow_mat.emission_energy_multiplier = 0.5

	var lamp_positions: Array = [Vector3(8, 0, 8), Vector3(-8, 0, 8), Vector3(8, 0, -8), Vector3(-8, 0, -8)]
	for lpos: Vector3 in lamp_positions:
		var lamp_post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.08
		post_mesh.bottom_radius = 0.1
		post_mesh.height = 3.0
		lamp_post.mesh = post_mesh
		lamp_post.position = Vector3(lpos.x, _snap_y(noise, lpos.x, lpos.z, hs) + 1.5, lpos.z)
		lamp_post.set_surface_override_material(0, lamp_mat)
		nav_region.add_child(lamp_post)

		var lamp_light := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		sphere.height = 0.3
		lamp_light.mesh = sphere
		lamp_light.position = Vector3(lpos.x, _snap_y(noise, lpos.x, lpos.z, hs) + 3.1, lpos.z)
		lamp_light.set_surface_override_material(0, lamp_glow_mat)
		nav_region.add_child(lamp_light)

# ---------------------------------------------------------------------------
# District: Market (x:-70..-20, z:-10..50)
# ---------------------------------------------------------------------------

static func _build_market_district(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Weapon Shop at (-45, 0, 20)
	_create_building(nav_region,
		Vector3(-45, _snap_y(noise, -45, 20, hs), 20),
		Vector3(6, 3.5, 5), Color(0.55, 0.38, 0.22), "peaked", Color(0.5, 0.18, 0.1), 0.6, false, true, PI / 2)

	# Item Shop at (-55, 0, 30)
	_create_building(nav_region,
		Vector3(-55, _snap_y(noise, -55, 30, hs), 30),
		Vector3(5, 3, 4), Color(0.55, 0.48, 0.35), "peaked", Color(0.2, 0.4, 0.15), 0.5)

	# Market stalls (open-air: 4 posts + flat canopy roof)
	var stall_positions: Array = [Vector3(-35, 0, 15), Vector3(-40, 0, 35), Vector3(-55, 0, 15), Vector3(-30, 0, 40)]
	var stall_mat := StandardMaterial3D.new()
	stall_mat.albedo_color = Color(0.45, 0.35, 0.22)
	var canopy_colors: Array = [Color(0.7, 0.2, 0.15), Color(0.2, 0.5, 0.2), Color(0.6, 0.5, 0.15), Color(0.3, 0.3, 0.6)]

	for i: int in stall_positions.size():
		var spos: Vector3 = stall_positions[i]
		var stall := Node3D.new()
		stall.position = Vector3(spos.x, _snap_y(noise, spos.x, spos.z, hs), spos.z)
		stall.rotation.y = [0.0, 0.2, -0.15, 0.3][i]

		# 4 corner posts
		for px: float in [-1.2, 1.2]:
			for pz: float in [-0.8, 0.8]:
				var post := MeshInstance3D.new()
				var post_mesh := CylinderMesh.new()
				post_mesh.top_radius = 0.06
				post_mesh.bottom_radius = 0.08
				post_mesh.height = 2.5
				post.mesh = post_mesh
				post.position = Vector3(px, 1.25, pz)
				post.set_surface_override_material(0, stall_mat)
				stall.add_child(post)

		# Canopy
		var canopy := MeshInstance3D.new()
		var canopy_mesh := BoxMesh.new()
		canopy_mesh.size = Vector3(3.0, 0.1, 2.0)
		canopy.mesh = canopy_mesh
		canopy.position = Vector3(0, 2.55, 0)
		var canopy_mat := StandardMaterial3D.new()
		canopy_mat.albedo_color = canopy_colors[i]
		canopy.set_surface_override_material(0, canopy_mat)
		stall.add_child(canopy)

		# Counter
		var counter := MeshInstance3D.new()
		var counter_mesh := BoxMesh.new()
		counter_mesh.size = Vector3(2.4, 0.8, 0.4)
		counter.mesh = counter_mesh
		counter.position = Vector3(0, 0.4, 0.6)
		counter.set_surface_override_material(0, stall_mat)
		stall.add_child(counter)

		nav_region.add_child(stall)

# ---------------------------------------------------------------------------
# District: Residential Quarter (x:-70..-20, z:-50..-10)
# ---------------------------------------------------------------------------

static func _build_residential_quarter(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Houses with varied sizes, colors and chimney options
	var house_configs: Array = [
		{"pos": Vector3(-53, 0, -21), "size": Vector3(4, 3, 4),   "color": Color(0.65, 0.58, 0.45), "roof": Color(0.45, 0.25, 0.15), "chimney": false, "rot_y": 0.15},
		{"pos": Vector3(-62, 0, -33), "size": Vector3(5, 3.5, 5), "color": Color(0.6, 0.55, 0.42),  "roof": Color(0.35, 0.2, 0.15),  "chimney": true, "rot_y": PI / 2},
		{"pos": Vector3(-46, 0, -42), "size": Vector3(4.5, 3, 4), "color": Color(0.62, 0.56, 0.48), "roof": Color(0.4, 0.22, 0.12),  "chimney": false, "rot_y": -0.1},
		{"pos": Vector3(-34, 0, -21), "size": Vector3(4, 3, 4.5), "color": Color(0.58, 0.52, 0.4),  "roof": Color(0.3, 0.3, 0.3),   "chimney": true, "rot_y": 0.0},
		{"pos": Vector3(-51, 0, -43), "size": Vector3(5, 3, 4),   "color": Color(0.55, 0.5, 0.4),   "roof": Color(0.42, 0.2, 0.12),  "chimney": false, "rot_y": PI / 2},
	]
	for cfg: Dictionary in house_configs:
		var p: Vector3 = cfg["pos"]
		_create_building(nav_region,
			Vector3(p.x, _snap_y(noise, p.x, p.z, hs), p.z),
			cfg["size"], cfg["color"], "peaked", cfg["roof"], 0.5, cfg["chimney"], true, cfg.get("rot_y", 0.0))

	# Inn/Tavern at (-45, 0, -30) — two-story
	var inn_pos := Vector3(-45, 0, -30)
	var inn_y: float = _snap_y(noise, inn_pos.x, inn_pos.z, hs)

	# Ground floor
	_create_building(nav_region,
		Vector3(inn_pos.x, inn_y, inn_pos.z),
		Vector3(7, 3, 6), Color(0.5, 0.38, 0.25), "flat", Color(0.35, 0.28, 0.2), 0.3)

	# Upper floor (slightly smaller)
	var upper := MeshInstance3D.new()
	var upper_mesh := BoxMesh.new()
	upper_mesh.size = Vector3(6.5, 2.5, 5.5)
	upper.mesh = upper_mesh
	upper.position = Vector3(inn_pos.x, inn_y + 4.25, inn_pos.z)
	var inn_mat := StandardMaterial3D.new()
	inn_mat.albedo_color = Color(0.52, 0.4, 0.28)
	upper.set_surface_override_material(0, inn_mat)
	nav_region.add_child(upper)

	# Inn peaked roof
	var inn_roof := MeshInstance3D.new()
	var inn_roof_mesh := BoxMesh.new()
	inn_roof_mesh.size = Vector3(7.0, 0.3, 6.0)
	inn_roof.mesh = inn_roof_mesh
	inn_roof.position = Vector3(inn_pos.x, inn_y + 5.65, inn_pos.z)
	var inn_roof_mat := StandardMaterial3D.new()
	inn_roof_mat.albedo_color = Color(0.4, 0.18, 0.1)
	inn_roof.set_surface_override_material(0, inn_roof_mat)
	nav_region.add_child(inn_roof)

# ---------------------------------------------------------------------------
# District: Noble/Temple Quarter (x:-20..25, z:-50..-10)
# ---------------------------------------------------------------------------

static func _build_noble_quarter(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Temple at (0, 0, -35) — tall with spire
	var temple_pos := Vector3(10, _snap_y(noise, 10, -35, hs), -35)
	_create_building(nav_region, temple_pos,
		Vector3(8, 5, 10), Color(0.6, 0.58, 0.55), "peaked", Color(0.35, 0.3, 0.28), 0.8, false, true)

	# Spire on top of temple
	var spire := MeshInstance3D.new()
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.1
	spire_mesh.bottom_radius = 0.5
	spire_mesh.height = 3.0
	spire.mesh = spire_mesh
	spire.position = Vector3(temple_pos.x, temple_pos.y + 7.5, temple_pos.z)
	var spire_mat := StandardMaterial3D.new()
	spire_mat.albedo_color = Color(0.4, 0.35, 0.3)
	spire.set_surface_override_material(0, spire_mat)
	nav_region.add_child(spire)

	# Front steps
	var steps := MeshInstance3D.new()
	var steps_mesh := BoxMesh.new()
	steps_mesh.size = Vector3(4, 0.3, 1.5)
	steps.mesh = steps_mesh
	steps.position = Vector3(temple_pos.x, temple_pos.y + 0.15, temple_pos.z + 5.75)
	var step_mat := StandardMaterial3D.new()
	step_mat.albedo_color = Color(0.55, 0.52, 0.48)
	steps.set_surface_override_material(0, step_mat)
	nav_region.add_child(steps)

	# Guild Hall at (15, 0, -25)
	_create_building(nav_region,
		Vector3(15, _snap_y(noise, 15, -25, hs), -25),
		Vector3(10, 4, 7), Color(0.5, 0.45, 0.4), "flat", Color(0.3, 0.28, 0.25), 0.4, false, true, PI / 2)

	# Manor at (-10, 0, -40) — L-shaped via two connected boxes
	var manor_pos := Vector3(-10, _snap_y(noise, -10, -40, hs), -40)
	_create_building(nav_region, manor_pos,
		Vector3(6, 3.5, 5), Color(0.62, 0.58, 0.52), "peaked", Color(0.38, 0.3, 0.25), 0.5, true, true, 0.12)
	_create_building(nav_region,
		Vector3(manor_pos.x + 4, manor_pos.y, manor_pos.z - 1),
		Vector3(4, 3, 3), Color(0.62, 0.58, 0.52), "peaked", Color(0.38, 0.3, 0.25), 0.5, false, false)

	# Statue at (5, 0, -30)
	var statue := Node3D.new()
	statue.position = Vector3(5, _snap_y(noise, 5, -30, hs), -30)

	var pedestal := MeshInstance3D.new()
	var ped_mesh := BoxMesh.new()
	ped_mesh.size = Vector3(1.0, 1.0, 1.0)
	pedestal.mesh = ped_mesh
	pedestal.position = Vector3(0, 0.5, 0)
	var ped_mat := StandardMaterial3D.new()
	ped_mat.albedo_color = Color(0.5, 0.48, 0.45)
	pedestal.set_surface_override_material(0, ped_mat)
	statue.add_child(pedestal)

	var figure := MeshInstance3D.new()
	var fig_mesh := CylinderMesh.new()
	fig_mesh.top_radius = 0.2
	fig_mesh.bottom_radius = 0.25
	fig_mesh.height = 1.5
	figure.mesh = fig_mesh
	figure.position = Vector3(0, 1.75, 0)
	var fig_mat := StandardMaterial3D.new()
	fig_mat.albedo_color = Color(0.55, 0.52, 0.48)
	figure.set_surface_override_material(0, fig_mat)
	statue.add_child(figure)

	nav_region.add_child(statue)

# ---------------------------------------------------------------------------
# District: Park/Gardens (x:25..70, z:-50..-10)
# ---------------------------------------------------------------------------

static func _build_park_gardens(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Larger decorative fountain at (45, 0, -30)
	var f_pos := Vector3(45, _snap_y(noise, 45, -30, hs), -30)
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.5, 0.48, 0.45)

	var f_base := MeshInstance3D.new()
	var f_base_mesh := CylinderMesh.new()
	f_base_mesh.top_radius = 2.0
	f_base_mesh.bottom_radius = 2.0
	f_base_mesh.height = 0.5
	f_base.mesh = f_base_mesh
	f_base.position = Vector3(f_pos.x, f_pos.y + 0.25, f_pos.z)
	f_base.set_surface_override_material(0, stone_mat)
	nav_region.add_child(f_base)

	var f_center := MeshInstance3D.new()
	var f_center_mesh := CylinderMesh.new()
	f_center_mesh.top_radius = 0.3
	f_center_mesh.bottom_radius = 0.4
	f_center_mesh.height = 1.5
	f_center.mesh = f_center_mesh
	f_center.position = Vector3(f_pos.x, f_pos.y + 1.25, f_pos.z)
	f_center.set_surface_override_material(0, stone_mat)
	nav_region.add_child(f_center)

	var f_top := MeshInstance3D.new()
	var f_top_mesh := CylinderMesh.new()
	f_top_mesh.top_radius = 1.0
	f_top_mesh.bottom_radius = 0.8
	f_top_mesh.height = 0.4
	f_top.mesh = f_top_mesh
	f_top.position = Vector3(f_pos.x, f_pos.y + 2.2, f_pos.z)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.3, 0.5, 0.7)
	f_top.set_surface_override_material(0, water_mat)
	nav_region.add_child(f_top)

	# Fountain collision
	var f_body := StaticBody3D.new()
	f_body.position = Vector3(f_pos.x, f_pos.y + 0.5, f_pos.z)
	var f_col := CollisionShape3D.new()
	var f_shape := CylinderShape3D.new()
	f_shape.radius = 2.0
	f_shape.height = 1.0
	f_col.shape = f_shape
	f_body.add_child(f_col)
	nav_region.add_child(f_body)

	# Benches throughout the park
	var bench_mat := StandardMaterial3D.new()
	bench_mat.albedo_color = Color(0.45, 0.32, 0.18)
	var bench_spots: Array = [
		Vector3(40, 0, -25), Vector3(50, 0, -25),
		Vector3(40, 0, -35), Vector3(50, 0, -35),
		Vector3(35, 0, -30), Vector3(55, 0, -30),
	]
	for bp: Vector3 in bench_spots:
		var bench := MeshInstance3D.new()
		var bench_mesh := BoxMesh.new()
		bench_mesh.size = Vector3(1.5, 0.4, 0.5)
		bench.mesh = bench_mesh
		bench.position = Vector3(bp.x, _snap_y(noise, bp.x, bp.z, hs) + 0.2, bp.z)
		bench.set_surface_override_material(0, bench_mat)
		nav_region.add_child(bench)

# ---------------------------------------------------------------------------
# District: Craft/Workshop (x:-20..25, z:10..50)
# ---------------------------------------------------------------------------

static func _build_craft_district(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Forge at (0, 0, 30) — stone walls, flat roof, chimney
	_create_building(nav_region,
		Vector3(8, _snap_y(noise, 8, 30, hs), 30),
		Vector3(6, 3.5, 5), Color(0.4, 0.38, 0.35), "flat", Color(0.3, 0.28, 0.25), 0.3, true, true, PI / 4)

	# Workshop 1 at (-10, 0, 35) — open-sided lean-to style
	var ws1 := Node3D.new()
	ws1.position = Vector3(-10, _snap_y(noise, -10, 35, hs), 35)
	ws1.rotation.y = -0.2
	var ws_mat := StandardMaterial3D.new()
	ws_mat.albedo_color = Color(0.45, 0.35, 0.22)

	# Back wall only
	var back_wall := MeshInstance3D.new()
	var bw_mesh := BoxMesh.new()
	bw_mesh.size = Vector3(4, 2.5, 0.2)
	back_wall.mesh = bw_mesh
	back_wall.position = Vector3(0, 1.25, -1.5)
	back_wall.set_surface_override_material(0, ws_mat)
	ws1.add_child(back_wall)

	# Front posts
	for px: float in [-1.8, 1.8]:
		var post := MeshInstance3D.new()
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 0.08
		p_mesh.bottom_radius = 0.1
		p_mesh.height = 2.5
		post.mesh = p_mesh
		post.position = Vector3(px, 1.25, 1.5)
		post.set_surface_override_material(0, ws_mat)
		ws1.add_child(post)

	# Lean-to roof
	var ws_roof := MeshInstance3D.new()
	var wsr_mesh := BoxMesh.new()
	wsr_mesh.size = Vector3(4.5, 0.15, 3.5)
	ws_roof.mesh = wsr_mesh
	ws_roof.position = Vector3(0, 2.6, 0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.35, 0.28, 0.2)
	ws_roof.set_surface_override_material(0, roof_mat)
	ws1.add_child(ws_roof)

	nav_region.add_child(ws1)

	# Workshop 2 at (12, 0, 42)
	_create_building(nav_region,
		Vector3(12, _snap_y(noise, 12, 42, hs), 42),
		Vector3(4, 3, 4), Color(0.48, 0.42, 0.35), "peaked", Color(0.35, 0.25, 0.18), 0.4, false, true, PI / 2)

	# Anvil outside forge
	var anvil := MeshInstance3D.new()
	var anvil_mesh := BoxMesh.new()
	anvil_mesh.size = Vector3(0.6, 0.5, 0.4)
	anvil.mesh = anvil_mesh
	anvil.position = Vector3(11, _snap_y(noise, 11, 28, hs) + 0.25, 28)
	var anvil_mat := StandardMaterial3D.new()
	anvil_mat.albedo_color = Color(0.2, 0.2, 0.22)
	anvil.set_surface_override_material(0, anvil_mat)
	nav_region.add_child(anvil)

	# Lumber pile near workshop
	var lumber_mat := StandardMaterial3D.new()
	lumber_mat.albedo_color = Color(0.5, 0.35, 0.2)
	for i: int in 3:
		var log := MeshInstance3D.new()
		var log_mesh := BoxMesh.new()
		log_mesh.size = Vector3(2.0, 0.3, 0.3)
		log.mesh = log_mesh
		log.position = Vector3(20, _snap_y(noise, 20, 25, hs) + 0.15 + i * 0.3, 25 + i * 0.15)
		log.rotation.y = 0.1 * i
		log.set_surface_override_material(0, lumber_mat)
		nav_region.add_child(log)

# ---------------------------------------------------------------------------
# District: Garrison/Training (x:25..70, z:10..50)
# ---------------------------------------------------------------------------

static func _build_garrison(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Barracks at (45, 0, 35) — long flat-roof building
	_create_building(nav_region,
		Vector3(45, _snap_y(noise, 45, 35, hs), 35),
		Vector3(12, 3.5, 5), Color(0.42, 0.4, 0.38), "flat", Color(0.3, 0.28, 0.25), 0.3, false, true, PI / 2)

	# Training dummies in the yard
	var dummy_mat := StandardMaterial3D.new()
	dummy_mat.albedo_color = Color(0.45, 0.35, 0.22)
	var dummy_positions: Array = [
		Vector3(35, 0, 18), Vector3(38, 0, 22), Vector3(42, 0, 18),
		Vector3(45, 0, 22), Vector3(48, 0, 18), Vector3(40, 0, 15),
	]
	for dpos: Vector3 in dummy_positions:
		var dummy := Node3D.new()
		dummy.position = Vector3(dpos.x, _snap_y(noise, dpos.x, dpos.z, hs), dpos.z)
		dummy.rotation.y = dpos.x * 0.3

		# Post
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.06
		post_mesh.bottom_radius = 0.08
		post_mesh.height = 1.8
		post.mesh = post_mesh
		post.position = Vector3(0, 0.9, 0)
		post.set_surface_override_material(0, dummy_mat)
		dummy.add_child(post)

		# Crossbar
		var crossbar := MeshInstance3D.new()
		var cb_mesh := BoxMesh.new()
		cb_mesh.size = Vector3(1.0, 0.12, 0.12)
		crossbar.mesh = cb_mesh
		crossbar.position = Vector3(0, 1.4, 0)
		crossbar.set_surface_override_material(0, dummy_mat)
		dummy.add_child(crossbar)

		# Head
		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.15
		head_mesh.height = 0.3
		head.mesh = head_mesh
		head.position = Vector3(0, 1.9, 0)
		var head_mat := StandardMaterial3D.new()
		head_mat.albedo_color = Color(0.6, 0.5, 0.35)
		head.set_surface_override_material(0, head_mat)
		dummy.add_child(head)

		nav_region.add_child(dummy)

	# Weapon racks along barracks wall
	var rack_mat := StandardMaterial3D.new()
	rack_mat.albedo_color = Color(0.4, 0.3, 0.2)
	for rx: float in [40.0, 44.0, 48.0]:
		var rack := Node3D.new()
		rack.position = Vector3(rx, _snap_y(noise, rx, 32, hs), 32)
		rack.rotation.y = 0.15

		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(1.5, 0.08, 0.08)
		bar.mesh = bar_mesh
		bar.position = Vector3(0, 1.2, 0)
		bar.set_surface_override_material(0, rack_mat)
		rack.add_child(bar)

		# A-frame legs
		for side: float in [-0.6, 0.6]:
			var leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.08, 1.4, 0.08)
			leg.mesh = leg_mesh
			leg.position = Vector3(side, 0.7, 0)
			leg.set_surface_override_material(0, rack_mat)
			rack.add_child(leg)

		nav_region.add_child(rack)

	# Archery targets
	var target_mat := StandardMaterial3D.new()
	target_mat.albedo_color = Color(0.8, 0.3, 0.2)
	var target_positions: Array = [Vector3(55, 0, 15), Vector3(58, 0, 20)]
	for tpos: Vector3 in target_positions:
		# Vertical post
		var target_post := MeshInstance3D.new()
		var tp_mesh := CylinderMesh.new()
		tp_mesh.top_radius = 0.06
		tp_mesh.bottom_radius = 0.08
		tp_mesh.height = 1.5
		target_post.mesh = tp_mesh
		target_post.position = Vector3(tpos.x, _snap_y(noise, tpos.x, tpos.z, hs) + 0.75, tpos.z)
		target_post.set_surface_override_material(0, rack_mat)
		nav_region.add_child(target_post)

		# Circular face
		var target_face := MeshInstance3D.new()
		var tf_mesh := CylinderMesh.new()
		tf_mesh.top_radius = 0.5
		tf_mesh.bottom_radius = 0.5
		tf_mesh.height = 0.1
		target_face.mesh = tf_mesh
		target_face.position = Vector3(tpos.x, _snap_y(noise, tpos.x, tpos.z, hs) + 1.3, tpos.z)
		target_face.rotation.x = PI * 0.5
		target_face.set_surface_override_material(0, target_mat)
		nav_region.add_child(target_face)

# ---------------------------------------------------------------------------
# District: City Gate Area (x:55..70, z:-10..10)
# ---------------------------------------------------------------------------

static func _build_gate_area(nav_region: Node3D, noise: FastNoiseLite, hs: float) -> void:
	# Guard posts flanking the gate on the inside
	_create_building(nav_region,
		Vector3(65, _snap_y(noise, 65, -7, hs), -7),
		Vector3(2, 2.5, 2), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28), 0.2)
	_create_building(nav_region,
		Vector3(65, _snap_y(noise, 65, 7, hs), 7),
		Vector3(2, 2.5, 2), Color(0.45, 0.42, 0.38), "flat", Color(0.35, 0.32, 0.28), 0.2)
