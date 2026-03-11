extends RefCounted
## Shared utilities for 3D model effects: mesh discovery, overlay materials, hit flash, death fade, respawn.
## Includes toon shader material creation and application.

const ANIM_WHITELIST: PackedStringArray = [
	"Idle", "Walking_A", "Running_A", "1H_Melee_Attack_Chop", "Death_A", "RESET"
]

static var _scene_cache: Dictionary = {}
static var _toon_shader: Shader = null

static func _get_toon_shader() -> Shader:
	if _toon_shader == null:
		_toon_shader = load("res://assets/shaders/toon.gdshader") as Shader
	return _toon_shader

static func load_model(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path]
	if not ResourceLoader.exists(path):
		push_warning("ModelHelper: Resource not found: %s" % path)
		return null
	var scene := load(path) as PackedScene
	if scene:
		_scene_cache[path] = scene
	return scene

static func instantiate_model(path: String, scale_val: float) -> Dictionary:
	var scene := load_model(path)
	if not scene:
		return { "model": null, "anim_player": null }
	var instance: Node3D = scene.instantiate()
	instance.scale = Vector3.ONE * scale_val
	var anim_player := find_animation_player(instance)
	if anim_player:
		strip_unused_animations(anim_player)
	return { "model": instance, "anim_player": anim_player }

static func strip_unused_animations(anim_player: AnimationPlayer, keep_list: PackedStringArray = ANIM_WHITELIST) -> void:
	for lib_name in anim_player.get_animation_library_list():
		var library: AnimationLibrary = anim_player.get_animation_library(lib_name)
		var to_remove: Array[StringName] = []
		for anim_name in library.get_animation_list():
			if String(anim_name) not in keep_list:
				to_remove.append(anim_name)
		for anim_name in to_remove:
			library.remove_animation(anim_name)

static func find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	return meshes

static func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, meshes)

static func create_overlay_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

static func apply_overlay(meshes: Array[MeshInstance3D], overlay: StandardMaterial3D) -> void:
	for mesh in meshes:
		mesh.material_overlay = overlay

static func flash_hit(overlay: StandardMaterial3D, node: Node) -> void:
	overlay.albedo_color = Color(1, 0.3, 0.3, 0.5)
	var tween := node.create_tween()
	tween.tween_property(overlay, "albedo_color:a", 0.0, 0.2)

static func set_highlight(overlay: StandardMaterial3D, enabled: bool) -> void:
	if enabled:
		overlay.emission_enabled = true
		overlay.emission = Color(1, 1, 0.8)
		overlay.emission_energy_multiplier = 0.3
	else:
		overlay.emission_enabled = false

static func set_state_tint(overlay: StandardMaterial3D, color: Color) -> void:
	overlay.albedo_color = color

static func clear_overlay(overlay: StandardMaterial3D) -> void:
	overlay.albedo_color = Color(0, 0, 0, 0)
	overlay.emission_enabled = false

static func fade_out(meshes: Array[MeshInstance3D], node: Node) -> Tween:
	var tween := node.create_tween()
	tween.set_parallel(true)
	for mesh in meshes:
		var surf_count: int = mesh.mesh.get_surface_count() if mesh.mesh else 0
		for i in surf_count:
			var override_mat := mesh.get_surface_override_material(i)
			if override_mat and override_mat is ShaderMaterial and override_mat.has_meta("is_toon"):
				# Toon material: tween alpha_multiplier directly
				tween.tween_property(override_mat, "shader_parameter/alpha_multiplier", 0.3, 0.5)
			else:
				# StandardMaterial3D: duplicate + tween albedo alpha
				var orig_mat: Material = mesh.mesh.surface_get_material(i)
				if orig_mat:
					var dup := orig_mat.duplicate() as StandardMaterial3D
					if dup:
						dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						mesh.set_surface_override_material(i, dup)
						tween.tween_property(dup, "albedo_color:a", 0.3, 0.5)
	return tween

static func restore_materials(meshes: Array[MeshInstance3D]) -> void:
	for mesh in meshes:
		var surf_count: int = mesh.mesh.get_surface_count() if mesh.mesh else 0
		for i in surf_count:
			var override_mat := mesh.get_surface_override_material(i)
			if override_mat and override_mat is ShaderMaterial and override_mat.has_meta("is_toon"):
				# Toon material: reset alpha, keep the override
				override_mat.set_shader_parameter("alpha_multiplier", 1.0)
			else:
				mesh.set_surface_override_material(i, null)

static func find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var result := find_animation_player(child)
		if result:
			return result
	return null

# --- Toon Shader Material Functions ---

static func create_toon_material(source: StandardMaterial3D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_toon_shader()
	if source:
		mat.set_shader_parameter("albedo_color", source.albedo_color)
		if source.albedo_texture:
			mat.set_shader_parameter("albedo_texture", source.albedo_texture)
			mat.set_shader_parameter("use_texture", true)
		else:
			mat.set_shader_parameter("use_texture", false)
	else:
		mat.set_shader_parameter("use_texture", false)
	mat.set_shader_parameter("alpha_multiplier", 1.0)
	mat.set_meta("is_toon", true)
	return mat

static func create_toon_material_color(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_toon_shader()
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("use_texture", false)
	mat.set_shader_parameter("alpha_multiplier", 1.0)
	mat.set_meta("is_toon", true)
	return mat

static func apply_toon_to_model(root: Node) -> void:
	var meshes := find_mesh_instances(root)
	for mesh in meshes:
		if not mesh.mesh:
			continue
		var surf_count := mesh.mesh.get_surface_count()
		for i in surf_count:
			var orig_mat := mesh.mesh.surface_get_material(i)
			var toon_mat: ShaderMaterial
			if orig_mat and orig_mat is StandardMaterial3D:
				toon_mat = create_toon_material(orig_mat as StandardMaterial3D)
			else:
				toon_mat = create_toon_material_color(Color.WHITE)
			mesh.set_surface_override_material(i, toon_mat)

# --- Consolidated Utility Functions ---

## Spawn a floating damage number above a target entity.
## caller is needed because static functions can't call get_tree().
static func spawn_damage_number(caller: Node, target_id: String, damage: int, color: Color = Color(1, 1, 1)) -> void:
	var target_node = WorldState.get_entity(target_id)
	if not target_node:
		return
	var dmg_scene := load_model("res://scenes/ui/damage_number.tscn")
	if not dmg_scene:
		return
	var dmg := dmg_scene.instantiate()
	caller.get_tree().current_scene.add_child(dmg)
	dmg.global_position = target_node.global_position + Vector3(0, 1.5, 0)
	dmg.setup(damage, color)

## Flash-hit the target entity (calls its flash_hit() method if available).
static func flash_target(target_id: String) -> void:
	var target_node = WorldState.get_entity(target_id)
	if not target_node or not is_instance_valid(target_node):
		return
	if target_node.has_method("flash_hit"):
		target_node.flash_hit()

## Create a fallback mesh (capsule or box) when a 3D model fails to load.
## Returns {"model": Node3D, "mesh_instances": Array[MeshInstance3D], "overlay": StandardMaterial3D}.
static func create_fallback_mesh(parent: Node3D, color: Color, use_box: bool = false) -> Dictionary:
	var model := Node3D.new()
	parent.add_child(model)
	var mesh_inst := MeshInstance3D.new()
	if use_box:
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 0.8, 0.8)
		mesh_inst.mesh = box
		mesh_inst.position.y = 0.4
	else:
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.3
		capsule.height = 1.2
		mesh_inst.mesh = capsule
		mesh_inst.position.y = 0.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.mesh.surface_set_material(0, mat)
	model.add_child(mesh_inst)
	var meshes: Array[MeshInstance3D] = [mesh_inst]
	var overlay := create_overlay_material()
	apply_overlay(meshes, overlay)
	apply_toon_to_model(model)
	return {"model": model, "mesh_instances": meshes, "overlay": overlay}

## Create and attach an HP bar above an entity.
static func create_hp_bar(parent: Node3D, y_offset: float = 1.8) -> Node:
	var hp_bar_scene := load_model("res://scenes/ui/hp_bar_3d.tscn")
	if not hp_bar_scene:
		return null
	var hp_bar := hp_bar_scene.instantiate()
	hp_bar.position.y = y_offset
	parent.add_child(hp_bar)
	return hp_bar

## Face a model toward a direction vector.
static func face_direction(model: Node3D, dir: Vector3) -> void:
	if model and dir.length_squared() > 0.01:
		model.rotation.y = atan2(dir.x, dir.z)

## Get the delay before a hit lands, based on animation length (50% mark).
static func get_hit_delay(anim_player: AnimationPlayer, anim_name: String) -> float:
	if anim_player and anim_player.has_animation(anim_name):
		return anim_player.get_animation(anim_name).length * 0.5
	return 0.4

## Update an entity's HP bar from WorldState data.
static func update_entity_hp_bar(hp_bar: Node, entity_id: String) -> void:
	if not hp_bar:
		return
	var data := WorldState.get_entity_data(entity_id)
	var hp: int = data.get("hp", 0)
	var max_hp: int = data.get("max_hp", 1)
	if hp_bar.has_method("update_bar"):
		hp_bar.update_bar(hp, max_hp)
	hp_bar.visible = hp < max_hp

