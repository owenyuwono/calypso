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
	return ModelHelper.fade_out(_mesh_instances, get_parent())

func restore_materials() -> void:
	ModelHelper.restore_materials(_mesh_instances)

func clear_overlay() -> void:
	if _overlay_material:
		ModelHelper.clear_overlay(_overlay_material)

# --- HP Bar ---

func setup_hp_bar(y_offset: float = 1.8) -> void:
	_hp_bar = ModelHelper.create_hp_bar(get_parent(), y_offset)

func update_hp_bar(entity_id: String) -> void:
	ModelHelper.update_entity_hp_bar(_hp_bar, entity_id)

func set_hp_bar_visible(vis: bool) -> void:
	if _hp_bar:
		_hp_bar.visible = vis

# --- Damage / Combat Visuals ---

func spawn_damage_number(target_id: String, damage: int, color: Color = Color(1, 1, 1), target_pos: Vector3 = Vector3.INF) -> void:
	var parent: Node3D = get_parent()
	ModelHelper.spawn_damage_number(parent, target_id, damage, color, parent.global_position, target_pos)

func flash_target(target_id: String) -> void:
	ModelHelper.flash_target(target_id)

# --- Accessors ---

func get_model() -> Node3D:
	return _model

func get_overlay() -> StandardMaterial3D:
	return _overlay_material

func get_anim_player() -> AnimationPlayer:
	return _anim_player
