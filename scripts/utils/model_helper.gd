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

## Load a mesh .glb and merge animations from separate .glb files into its AnimationPlayer.
## anim_paths: { target_name: String -> anim_glb_path: String }
## Returns {"model": Node3D, "anim_player": AnimationPlayer} same as instantiate_model().
static func instantiate_model_with_anims(mesh_path: String, anim_paths: Dictionary, scale_val: float) -> Dictionary:
	var result := instantiate_model(mesh_path, scale_val)
	if not result["model"]:
		return result

	var model: Node3D = result["model"]
	var anim_player: AnimationPlayer = result["anim_player"]

	# Create an AnimationPlayer if the mesh .glb didn't include one
	if not anim_player:
		anim_player = AnimationPlayer.new()
		model.add_child(anim_player)
		anim_player.add_animation_library("", AnimationLibrary.new())
		result["anim_player"] = anim_player

	# Ensure the default library exists
	if not anim_player.has_animation_library(""):
		anim_player.add_animation_library("", AnimationLibrary.new())

	var library: AnimationLibrary = anim_player.get_animation_library("")

	for target_name in anim_paths:
		var anim_path: String = anim_paths[target_name]
		var anim_scene := load_model(anim_path)
		if not anim_scene:
			push_warning("ModelHelper: Animation .glb not found: %s" % anim_path)
			continue

		var anim_instance: Node3D = anim_scene.instantiate()
		var src_player := find_animation_player(anim_instance)
		if not src_player:
			push_warning("ModelHelper: No AnimationPlayer in %s" % anim_path)
			anim_instance.queue_free()
			continue

		# Pick the first animation from the source (Meshy puts one anim per file)
		var src_library_names := src_player.get_animation_library_list()
		var animation: Animation = null
		for lib_name in src_library_names:
			var src_lib: AnimationLibrary = src_player.get_animation_library(lib_name)
			var anim_list := src_lib.get_animation_list()
			if anim_list.size() > 0:
				animation = src_lib.get_animation(anim_list[0])
				break

		if not animation:
			push_warning("ModelHelper: No animations found in %s" % anim_path)
			anim_instance.queue_free()
			continue

		if library.has_animation(target_name):
			library.remove_animation(target_name)
		library.add_animation(target_name, animation)

		anim_instance.queue_free()

	# Ensure an Idle animation exists — Meshy base meshes only contain a T-pose clip
	# that gets stripped before this point. A zero-track animation holds the rest pose.
	if not anim_player.has_animation("Idle"):
		var idle_anim := Animation.new()
		idle_anim.length = 0.1
		idle_anim.loop_mode = Animation.LOOP_LINEAR
		var lib: AnimationLibrary = anim_player.get_animation_library("")
		lib.add_animation("Idle", idle_anim)

	return result

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

static func fade_out(meshes: Array[MeshInstance3D], node: Node, overlay: StandardMaterial3D = null) -> Tween:
	var tween := node.create_tween()
	if overlay:
		# Darken via overlay — keeps entity opaque for screen-space effects
		tween.tween_property(overlay, "albedo_color", Color(0, 0, 0, 0.7), 0.5)
	else:
		tween.set_parallel(true)
		for mesh in meshes:
			var surf_count: int = mesh.mesh.get_surface_count() if mesh.mesh else 0
			for i in surf_count:
				var orig_mat: Material = mesh.mesh.surface_get_material(i)
				if orig_mat:
					var dup := orig_mat.duplicate() as StandardMaterial3D
					if dup:
						dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						mesh.set_surface_override_material(i, dup)
						tween.tween_property(dup, "albedo_color:a", 0.3, 0.5)
	return tween

static func restore_materials(meshes: Array[MeshInstance3D], overlay: StandardMaterial3D = null) -> void:
	if overlay:
		overlay.albedo_color = Color(0, 0, 0, 0)
	for mesh in meshes:
		var surf_count: int = mesh.mesh.get_surface_count() if mesh.mesh else 0
		for i in surf_count:
			var override_mat := mesh.get_surface_override_material(i)
			if override_mat and override_mat is ShaderMaterial and override_mat.has_meta("is_toon"):
				pass # Toon materials stay as overrides
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
static func spawn_damage_number(caller: Node, target_id: String, damage: int, color: Color = Color(1, 1, 1), attacker_pos: Vector3 = Vector3.ZERO, target_pos: Vector3 = Vector3.ZERO) -> void:
	# Skip damage numbers for off-screen combat: only spawn if attacker or target is within 30m of player.
	const CULL_DISTANCE_SQ: float = 900.0  # 30m^2
	var player_node: Node = WorldState.get_entity("player")
	if player_node and is_instance_valid(player_node):
		var player_pos: Vector3 = player_node.global_position
		var attacker_in_range: bool = attacker_pos.distance_squared_to(player_pos) <= CULL_DISTANCE_SQ
		var target_in_range: bool = target_pos.distance_squared_to(player_pos) <= CULL_DISTANCE_SQ
		if not attacker_in_range and not target_in_range:
			return
	var dmg_scene := load_model("res://scenes/ui/damage_number.tscn")
	if not dmg_scene:
		return
	var dmg := dmg_scene.instantiate()
	caller.get_tree().current_scene.add_child(dmg)
	# Compute direction away from attacker on XZ plane
	var direction := Vector3.ZERO
	if attacker_pos.length_squared() > 0.01:
		direction = target_pos - attacker_pos
		direction.y = 0
		if direction.length_squared() > 0.01:
			direction = direction.normalized()
	# Spawn offset to the side (in the away-from-attacker direction), not on top of target
	var spawn_offset := direction * 1.0 if direction.length_squared() > 0.01 else Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	dmg.global_position = target_pos + Vector3(0, 1.5, 0) + spawn_offset
	dmg.setup(damage, color, direction)

## Spawn a floating text label (e.g. "MISS") above a position.
## caller is needed because static functions can't call get_tree().
static func spawn_text_number(caller: Node, text: String, color: Color, attacker_pos: Vector3, target_pos: Vector3) -> void:
	const CULL_DISTANCE_SQ: float = 900.0  # 30m^2
	var player_node: Node = WorldState.get_entity("player")
	if player_node and is_instance_valid(player_node):
		var player_pos: Vector3 = player_node.global_position
		var attacker_in_range: bool = attacker_pos.distance_squared_to(player_pos) <= CULL_DISTANCE_SQ
		var target_in_range: bool = target_pos.distance_squared_to(player_pos) <= CULL_DISTANCE_SQ
		if not attacker_in_range and not target_in_range:
			return
	var dmg_scene := load_model("res://scenes/ui/damage_number.tscn")
	if not dmg_scene:
		return
	var dmg := dmg_scene.instantiate()
	caller.get_tree().current_scene.add_child(dmg)
	var direction := Vector3.ZERO
	if attacker_pos.length_squared() > 0.01:
		direction = target_pos - attacker_pos
		direction.y = 0
		if direction.length_squared() > 0.01:
			direction = direction.normalized()
	var spawn_offset := direction * 1.0 if direction.length_squared() > 0.01 else Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	dmg.global_position = target_pos + Vector3(0, 1.5, 0) + spawn_offset
	dmg.setup_text(text, color, direction)

## Spawn a styled floating damage number above a target entity.
## hit_type: "normal" | "crit" | "weak" | "fatal" | "resist" | "immune" | "miss"
## is_crit: whether the hit was a critical strike (affects style selection)
static func spawn_styled_damage_number(caller: Node, target_id: String, damage: int, hit_type: String, is_crit: bool, attacker_pos: Vector3, target_pos: Vector3) -> void:
	# Same culling logic as spawn_damage_number (30m from player)
	const CULL_DISTANCE_SQ: float = 900.0  # 30m^2
	var player_node: Node = WorldState.get_entity("player")
	if player_node and is_instance_valid(player_node):
		var player_pos: Vector3 = player_node.global_position
		var attacker_in_range: bool = attacker_pos.distance_squared_to(player_pos) <= CULL_DISTANCE_SQ
		var target_in_range: bool = target_pos.distance_squared_to(player_pos) <= CULL_DISTANCE_SQ
		if not attacker_in_range and not target_in_range:
			return
	var dmg_scene := load_model("res://scenes/ui/damage_number.tscn")
	if not dmg_scene:
		return
	var dmg := dmg_scene.instantiate()
	caller.get_tree().current_scene.add_child(dmg)
	# Compute direction away from attacker on XZ plane
	var direction := Vector3.ZERO
	if attacker_pos.length_squared() > 0.01:
		direction = target_pos - attacker_pos
		direction.y = 0
		if direction.length_squared() > 0.01:
			direction = direction.normalized()
	var spawn_offset := direction * 1.0 if direction.length_squared() > 0.01 else Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	dmg.global_position = target_pos + Vector3(0, 1.5, 0) + spawn_offset
	dmg.setup_styled(damage, hit_type, is_crit, direction)

## Flash-hit the target entity (calls its flash_hit() method if available).
static func flash_target(target_node: Node) -> void:
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

## Update an entity's HP bar with the given hp and max_hp values.
## Visibility is managed by the entity's combat state via update_hp_bar_combat().
static func update_entity_hp_bar(hp_bar: Node, hp: int, max_hp: int) -> void:
	if not hp_bar:
		return
	if hp_bar.has_method("update_bar"):
		hp_bar.update_bar(hp, max_hp)

