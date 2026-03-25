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
var _mesh_path: String = ""
var _anim_paths: Dictionary = {}

# --- Setup ---

func setup_model(path: String, scale_val: float, fallback_color: Color, use_box: bool = false) -> void:
	_mesh_path = path
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
	_mesh_path = mesh_path
	_anim_paths = anim_paths
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

func play_anim_speed(anim_name: String, speed: float = 1.0) -> void:
	if not _anim_player:
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name, -1, speed)
		_current_anim = anim_name

func crossfade_anim(anim_name: String, blend_time: float = 0.3, force: bool = false) -> void:
	if not _anim_player:
		return
	if not force and _current_anim == anim_name and _anim_player.is_playing():
		return
	if _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name, blend_time)
		_current_anim = anim_name

func is_anim_playing() -> bool:
	return _anim_player and _anim_player.is_playing()

func get_hit_delay(anim_name: String) -> float:
	return ModelHelper.get_hit_delay(_anim_player, anim_name)

func reset_anim() -> void:
	_current_anim = ""

# --- Facing ---

func face_direction(dir: Vector3) -> void:
	if not _model or dir.length_squared() < 0.01:
		return
	var target_y: float = atan2(dir.x, dir.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_y, 0.15)

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
	if _hp_bar:
		_hp_bar.visible = false

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

func spawn_miss_number(target_pos: Vector3 = Vector3.ZERO) -> void:
	var parent: Node3D = get_parent()
	ModelHelper.spawn_text_number(parent, "MISS", Color(0.8, 0.8, 0.8), parent.global_position, target_pos)

func spawn_styled_damage_number(target_id: String, damage: int, hit_type: String, is_crit: bool, target_pos: Vector3, color_override: Color = Color(-1, -1, -1)) -> void:
	var parent: Node3D = get_parent()
	var attacker_pos: Vector3 = parent.global_position if parent else target_pos
	ModelHelper.spawn_styled_damage_number(parent, target_id, damage, hit_type, is_crit, attacker_pos, target_pos, color_override)

func flash_target(target_id: String) -> void:
	var target_node: Node = WorldState.get_entity(target_id)
	ModelHelper.flash_target(target_node)

# --- Accessors ---

func get_anim_player() -> AnimationPlayer:
	return _anim_player

func get_model() -> Node3D:
	return _model
