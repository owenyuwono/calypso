extends Node3D
## Bullet that flies in a straight line from muzzle in the player's facing direction.
## Detects enemies by raycasting along its path each frame. Deals damage on hit, then dies.

const HitVFX = preload("res://scripts/vfx/hit_vfx.gd")

var speed: float = 60.0
var direction: Vector3
var max_distance: float = 50.0
var _traveled: float = 0.0

var shooter_node: Node3D
var shooter_rid: RID
var atk: int = 0
var phys_type: String = "pierce"

# Trail
var _trail_points: Array[Vector3] = []
var _trail_mesh: MeshInstance3D
var _trail_mat: StandardMaterial3D


func _ready() -> void:
	# Bullet mesh — bright elongated capsule
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.06
	capsule.height = 0.5
	mesh_inst.mesh = capsule
	mesh_inst.rotation.x = PI / 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.3)
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# Trail
	_trail_mesh = MeshInstance3D.new()
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.albedo_color = Color(1.0, 0.9, 0.3, 0.6)
	_trail_mat.emission_enabled = true
	_trail_mat.emission = Color(1.0, 0.8, 0.2)
	_trail_mat.emission_energy_multiplier = 2.0
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mesh.material_override = _trail_mat
	get_tree().current_scene.add_child(_trail_mesh)

	if direction.length_squared() > 0.01:
		look_at(global_position + direction, Vector3.UP)

	_trail_points.append(global_position)


func _physics_process(delta: float) -> void:
	var step: float = speed * delta
	var prev_pos: Vector3 = global_position
	global_position += direction * step
	_traveled += step
	_trail_points.append(global_position)
	_update_trail()

	# Raycast from previous position to current position to detect hits
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(prev_pos, global_position)
	query.collision_mask = 1 | (1 << 8)  # physics + perception
	if shooter_rid.is_valid():
		query.exclude = [shooter_rid]
	var result: Dictionary = space_state.intersect_ray(query)

	if not result.is_empty():
		var hit_body: Node = result["collider"]
		var hit_pos: Vector3 = result["position"]
		global_position = hit_pos

		var hit_id: String = WorldState.get_entity_id_for_node(hit_body)
		if not hit_id.is_empty():
			var edata: Dictionary = WorldState.get_entity_data(hit_id)
			if edata.get("type", "") == "monster" and WorldState.is_alive(hit_id):
				_deal_damage(hit_id, hit_body, hit_pos)

		_die()
		return

	# Max range
	if _traveled >= max_distance:
		_die()


func _deal_damage(hit_id: String, hit_body: Node, hit_pos: Vector3) -> void:
	if not shooter_node or not is_instance_valid(shooter_node):
		return
	var shooter_combat: Node = shooter_node.get_node_or_null("CombatComponent")
	if not shooter_combat:
		return

	var target_combat: Node = hit_body.get_node_or_null("CombatComponent")
	var def_val: int = target_combat.get_effective_def() if target_combat else 0
	var raw: float = maxf(1.0, atk - def_val)

	# Pierce vs armor type
	var armor_type: String = target_combat.get_armor_type() if target_combat else "light"
	var ARMOR_TABLE: Dictionary = {"heavy": {"slash": "resist", "pierce": "neutral", "blunt": "weak"}, "medium": {"slash": "neutral", "pierce": "weak", "blunt": "neutral"}, "light": {"slash": "weak", "pierce": "neutral", "blunt": "neutral"}}
	var RESIST_MULT: Dictionary = {"fatal": 2.0, "weak": 1.5, "neutral": 1.0, "resist": 0.5, "immune": 0.0}
	var phys_level: String = ARMOR_TABLE.get(armor_type, {}).get(phys_type, "neutral")
	var phys_mod: float = RESIST_MULT.get(phys_level, 1.0)

	var damage: int = maxi(1, int(raw * phys_mod))

	var crit_result: Dictionary = shooter_combat.roll_crit()
	var is_crit: bool = crit_result["is_crit"]
	if is_crit and damage > 0:
		damage = maxi(1, int(damage * crit_result["multiplier"]))

	var hit_type: String = "normal"
	if phys_mod >= 1.5:
		hit_type = "weak"
	elif phys_mod <= 0.5:
		hit_type = "resist"

	var actual: int = shooter_combat.apply_flat_damage_to(hit_id, damage)
	if actual > 0:
		HitVFX.spawn_hit_effect(self, hit_pos, direction)
		var visuals: Node = shooter_node.get_node_or_null("EntityVisuals")
		if visuals:
			visuals.spawn_styled_damage_number(hit_id, actual, hit_type, is_crit, hit_pos)
			visuals.flash_target(hit_id)


func _update_trail() -> void:
	while _trail_points.size() > 10:
		_trail_points.remove_at(0)
	if _trail_points.size() < 2:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in _trail_points:
		im.surface_add_vertex(point)
	im.surface_end()
	_trail_mesh.mesh = im


func _die() -> void:
	set_physics_process(false)
	if _trail_mesh and is_instance_valid(_trail_mesh):
		var tween := _trail_mesh.create_tween()
		tween.tween_property(_trail_mat, "albedo_color:a", 0.0, 0.2)
		tween.tween_callback(_trail_mesh.queue_free)
	queue_free()
