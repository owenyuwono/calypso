extends Node
## Composition node that owns visual state (model, overlay, animations, HP bar)
## for all entity types: player, NPC, monster, and shop NPC.

const ModelHelper = preload("res://scripts/utils/model_helper.gd")

var _model: Node3D
var _mesh_instances: Array[MeshInstance3D] = []
var _overlay_material: StandardMaterial3D
var _anim_player: AnimationPlayer
var _current_anim: String = ""
var _hp_bar: Node3D
var _vend_sign: StaticBody3D

# --- Setup ---

func setup_model(path: String, scale_val: float, fallback_color: Color, use_box: bool = false) -> void:
	var parent: Node3D = get_parent()
	var result: Dictionary = {"model": null, "anim_player": null}
	if not path.is_empty():
		result = ModelHelper.instantiate_model(path, scale_val)
	if result.model == null:
		push_warning("EntityVisuals: Could not load model '%s', using fallback" % path)
		var fb := ModelHelper.create_fallback_mesh(parent, fallback_color, use_box)
		_model = fb.model
		_mesh_instances = fb.mesh_instances
		_overlay_material = fb.overlay
		return

	_model = result.model
	parent.add_child(_model)
	_anim_player = result.anim_player
	_finish_model_setup()

func setup_model_with_anims(mesh_path: String, anim_paths: Dictionary, scale_val: float, fallback_color: Color) -> void:
	var parent: Node3D = get_parent()
	var result: Dictionary = {"model": null, "anim_player": null}
	if not mesh_path.is_empty():
		result = ModelHelper.instantiate_model_with_anims(mesh_path, anim_paths, scale_val)
	if result.model == null:
		push_warning("EntityVisuals: Could not load model '%s', using fallback" % mesh_path)
		var fb := ModelHelper.create_fallback_mesh(parent, fallback_color, false)
		_model = fb.model
		_mesh_instances = fb.mesh_instances
		_overlay_material = fb.overlay
		return

	_model = result.model
	parent.add_child(_model)
	_anim_player = result.anim_player

	# Detect center-origin models (AABB starts below ground) and shift up so feet sit at y=0
	var aabb := AABB()
	var first := true
	for mi in ModelHelper.find_mesh_instances(_model):
		if mi.mesh:
			var mesh_aabb: AABB = mi.get_aabb()
			if first:
				aabb = mesh_aabb
				first = false
			else:
				aabb = aabb.merge(mesh_aabb)
	if not first and aabb.position.y < -0.01:
		_model.position.y += abs(aabb.position.y) * scale_val

	_finish_model_setup()

func _finish_model_setup() -> void:
	_mesh_instances = ModelHelper.find_mesh_instances(_model)
	_overlay_material = ModelHelper.create_overlay_material()
	ModelHelper.apply_overlay(_mesh_instances, _overlay_material)
	ModelHelper.apply_toon_to_model(_model)
	if _anim_player:
		play_anim("Idle")

## Register a pre-built model (e.g. slime procedural mesh). Caller must add model to the scene tree first.
func setup_custom_model(model: Node3D, mesh_instances: Array[MeshInstance3D]) -> void:
	_model = model
	_mesh_instances = mesh_instances
	_overlay_material = ModelHelper.create_overlay_material()
	ModelHelper.apply_overlay(_mesh_instances, _overlay_material)
	ModelHelper.apply_toon_to_model(_model)

# --- Animation ---

func play_anim(anim_name: String, force: bool = false) -> void:
	if not _anim_player:
		return
	if not force and _current_anim == anim_name and _anim_player.is_playing():
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)
		_current_anim = anim_name

func get_hit_delay(anim_name: String) -> float:
	return ModelHelper.get_hit_delay(_anim_player, anim_name)

func reset_anim() -> void:
	_current_anim = ""

# --- Facing ---

func face_direction(dir: Vector3) -> void:
	ModelHelper.face_direction(_model, dir)

# --- Visual Effects ---

func flash_hit() -> void:
	if not _overlay_material:
		return
	ModelHelper.flash_hit(_overlay_material, get_parent())

func highlight() -> void:
	if _overlay_material:
		ModelHelper.set_highlight(_overlay_material, true)

func unhighlight() -> void:
	if _overlay_material:
		ModelHelper.set_highlight(_overlay_material, false)

func set_state_tint(color: Color) -> void:
	if _overlay_material:
		ModelHelper.set_state_tint(_overlay_material, color)

func apply_tint(color: Color) -> void:
	if _overlay_material:
		_overlay_material.albedo_color = color

func fade_out() -> Tween:
	return ModelHelper.fade_out(_mesh_instances, get_parent(), _overlay_material)

func restore_materials() -> void:
	ModelHelper.restore_materials(_mesh_instances, _overlay_material)

func clear_overlay() -> void:
	if _overlay_material:
		ModelHelper.clear_overlay(_overlay_material)

# --- HP Bar ---

func setup_hp_bar(y_offset: float = 1.8, entity_name: String = "") -> void:
	_hp_bar = ModelHelper.create_hp_bar(get_parent(), y_offset)
	if _hp_bar and not entity_name.is_empty() and _hp_bar.has_method("set_entity_name"):
		_hp_bar.set_entity_name(entity_name)

func update_hp_bar(hp: int, max_hp: int) -> void:
	ModelHelper.update_entity_hp_bar(_hp_bar, hp, max_hp)

func update_hp_bar_combat(hp: int, max_hp: int, in_combat: bool) -> void:
	if _hp_bar:
		if _hp_bar.has_method("update_bar"):
			_hp_bar.update_bar(hp, max_hp)
		_hp_bar.visible = in_combat or hp < max_hp

func set_hp_bar_visible(vis: bool) -> void:
	if _hp_bar:
		_hp_bar.visible = vis

func hide_hp_bar_keep_name() -> void:
	if _hp_bar:
		_hp_bar.visible = true
		if _hp_bar.has_method("set_bar_visible"):
			_hp_bar.set_bar_visible(false)

# --- Damage / Combat Visuals ---

func spawn_damage_number(target_id: String, damage: int, color: Color = Color(1, 1, 1), target_pos: Vector3 = Vector3.ZERO) -> void:
	var parent: Node3D = get_parent()
	ModelHelper.spawn_damage_number(parent, target_id, damage, color, parent.global_position, target_pos)

func flash_target(target_id: String) -> void:
	var target_node: Node = WorldState.get_entity(target_id)
	ModelHelper.flash_target(target_node)

# --- Vend Sign ---

func show_vend_sign(title: String) -> void:
	hide_vend_sign()

	# StaticBody3D container — clickable by player raycast
	_vend_sign = StaticBody3D.new()
	_vend_sign.name = "VendSign"
	_vend_sign.position = Vector3(0, 2.8, 0)
	_vend_sign.collision_layer = 1 << 5
	_vend_sign.collision_mask = 0
	_vend_sign.add_to_group("vend_sign")

	# White border quad — behind panel, hidden by default, shown on hover
	var border := MeshInstance3D.new()
	border.name = "Border"
	var border_quad := QuadMesh.new()
	border_quad.size = Vector2(3.14, 0.94)
	border.mesh = border_quad
	border.position = Vector3(0, 0, 0.01)
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	border_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	border_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	border_mat.no_depth_test = true
	border_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border_mat.render_priority = -1
	border.material_override = border_mat
	border.visible = false
	_vend_sign.add_child(border)

	# Background panel — opaque, draws on top of border
	var panel := MeshInstance3D.new()
	panel.name = "Panel"
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 0.8)
	panel.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.1, 0.0, 1.0)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.render_priority = 0
	panel.material_override = mat
	_vend_sign.add_child(panel)

	# Label3D in front of the panel
	var label := Label3D.new()
	label.text = "[SHOP] " + title
	label.font_size = 48
	label.position = Vector3(0, 0, -0.02)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 12
	label.modulate = Color(1.0, 0.9, 0.2)
	label.outline_modulate = Color(0, 0, 0)
	label.no_depth_test = true
	label.render_priority = 1
	_vend_sign.add_child(label)

	# Collision shape for raycast detection — matches panel size
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 0.8, 2.0)
	col_shape.shape = box
	_vend_sign.add_child(col_shape)

	get_parent().add_child(_vend_sign)

func hide_vend_sign() -> void:
	if _vend_sign:
		_vend_sign.queue_free()
		_vend_sign = null

# --- Accessors ---

func get_anim_player() -> AnimationPlayer:
	return _anim_player

func get_model() -> Node3D:
	return _model
