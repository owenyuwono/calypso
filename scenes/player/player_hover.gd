extends Node
## Handles all hover/raycast logic: entity highlight, tooltip display,
## cursor updates, and hover ring management.
## Call setup(player) from player._ready() after adding as child.

const HOVER_RAY_LENGTH: float = 100.0
const TOOLTIP_OFFSET: Vector2 = Vector2(16, 16)
const NpcTraits = preload("res://scripts/data/npc_traits.gd")

var _player: Node3D
var _cursor_manager: RefCounted

# Lock ring (world-space torus that tracks the locked target)
var _lock_ring: MeshInstance3D
var _lock_ring_material: StandardMaterial3D
var _ring_target_id: String = ""

# Hover ring (world-space torus that tracks the currently hovered entity)
var _hover_ring: MeshInstance3D
var _hover_ring_material: StandardMaterial3D
var _hover_ring_target_id: String = ""

# Tooltip
var _tooltip_label: Label
var _tooltip_panel: PanelContainer

# Hover state
var _hovered_entity_id: String = ""
var _hover_timer: float = 0.0


func setup(player: Node3D, cursor_manager: RefCounted) -> void:
	_player = player
	_cursor_manager = cursor_manager
	_setup_tooltip()
	_setup_lock_ring()
	_setup_hover_ring()


## Returns the current hovered entity id (empty string if none).
func get_hovered_entity_id() -> String:
	return _hovered_entity_id


## Lock/unlock the lock ring onto a target entity.
func lock_ring(target_id: String, color: Color) -> void:
	_ring_target_id = target_id
	_lock_ring_material.albedo_color = color
	var target_node := WorldState.get_entity(target_id)
	if target_node and is_instance_valid(target_node):
		_lock_ring.global_position = target_node.global_position + Vector3(0, 0.05, 0)
		_lock_ring.visible = true
	# If this target was showing the hover ring, hide hover ring — lock takes priority
	if target_id == _hover_ring_target_id:
		_hover_ring.visible = false


## Hide and clear the lock ring.
func clear_ring() -> void:
	var was_target: String = _ring_target_id
	_ring_target_id = ""
	_lock_ring.visible = false
	# Restore hover ring if the entity we just unlocked is still being hovered
	if was_target != "" and was_target == _hover_ring_target_id:
		var hover_node := WorldState.get_entity(was_target)
		if hover_node and is_instance_valid(hover_node):
			_hover_ring.global_position = hover_node.global_position + Vector3(0, 0.05, 0)
			_hover_ring.visible = true


## Returns whether the lock ring is currently visible.
func is_ring_visible() -> bool:
	return _lock_ring.visible


func _setup_tooltip() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	UIHelper.set_corner_radius(style, 4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	_tooltip_label = Label.new()
	_tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	_tooltip_label.add_theme_font_size_override("font_size", 14)
	_tooltip_panel.add_child(_tooltip_label)

	canvas_layer.add_child(_tooltip_panel)


func _setup_lock_ring() -> void:
	_lock_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.6
	_lock_ring.mesh = torus
	_lock_ring.top_level = true

	_lock_ring_material = StandardMaterial3D.new()
	_lock_ring_material.albedo_color = Color(1.0, 0.3, 0.2, 0.6)
	_lock_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lock_ring_material.no_depth_test = false
	_lock_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lock_ring.material_override = _lock_ring_material

	_lock_ring.visible = false
	add_child(_lock_ring)

	# Looping pulse tween
	var tween := get_tree().create_tween().set_loops()
	tween.tween_property(_lock_ring, "scale", Vector3(1.15, 1.0, 1.15), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_lock_ring, "scale", Vector3(1.0, 1.0, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _setup_hover_ring() -> void:
	_hover_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.6
	_hover_ring.mesh = torus
	_hover_ring.top_level = true

	_hover_ring_material = StandardMaterial3D.new()
	_hover_ring_material.albedo_color = Color(1.0, 0.9, 0.6, 0.35)
	_hover_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hover_ring_material.no_depth_test = false
	_hover_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_ring.material_override = _hover_ring_material

	_hover_ring.visible = false
	add_child(_hover_ring)


func _process(delta: float) -> void:
	if not _player:
		return

	# Track lock ring to locked target every frame
	if _lock_ring.visible and _ring_target_id != "":
		var entity := WorldState.get_entity(_ring_target_id)
		if entity and is_instance_valid(entity):
			_lock_ring.global_position = entity.global_position + Vector3(0, 0.05, 0)
		else:
			_lock_ring.visible = false
			_ring_target_id = ""

	# Track hover ring to hovered entity every frame
	if _hover_ring.visible and _hover_ring_target_id != "":
		var hover_entity := WorldState.get_entity(_hover_ring_target_id)
		if hover_entity and is_instance_valid(hover_entity):
			_hover_ring.global_position = hover_entity.global_position + Vector3(0, 0.05, 0)
		else:
			_hover_ring.visible = false
			_hover_ring_target_id = ""

	_hover_timer -= delta
	if _hover_timer <= 0.0:
		_hover_timer = 0.1
		_process_hover()
	elif _tooltip_panel.visible:
		# Keep tooltip following mouse between raycast ticks
		_tooltip_panel.position = get_viewport().get_mouse_position() + TOOLTIP_OFFSET


func _process_hover() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * HOVER_RAY_LENGTH
	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_player.get_rid()]
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	var result := space.intersect_ray(query)

	var new_entity_id: String = ""

	if result:
		var collider: Node = result.collider
		if collider is Node3D:
			# Walk up the parent chain to find the registered entity —
			# raycast may hit a child node (e.g. PerceptionArea) rather than the root.
			var check_node: Node = collider
			while check_node and check_node is Node3D:
				new_entity_id = WorldState.get_entity_id_for_node(check_node)
				if new_entity_id != "" and new_entity_id != "player":
					break
				new_entity_id = ""
				check_node = check_node.get_parent()
			if new_entity_id == "player":
				new_entity_id = ""

	if new_entity_id != _hovered_entity_id:
		if _hovered_entity_id != "":
			var prev_node := WorldState.get_entity(_hovered_entity_id)
			if prev_node and is_instance_valid(prev_node) and prev_node.has_method("unhighlight"):
				prev_node.unhighlight()
		if new_entity_id != "":
			var new_node := WorldState.get_entity(new_entity_id)
			if new_node and is_instance_valid(new_node) and new_node.has_method("highlight"):
				new_node.highlight()
		_hovered_entity_id = new_entity_id

		# Update hover ring to follow new hovered entity
		if new_entity_id != "" and new_entity_id != _ring_target_id:
			var new_node := WorldState.get_entity(new_entity_id)
			if new_node and is_instance_valid(new_node):
				_hover_ring.global_position = new_node.global_position + Vector3(0, 0.05, 0)
				_hover_ring.visible = true
				_hover_ring_target_id = new_entity_id
			else:
				_hover_ring.visible = false
				_hover_ring_target_id = ""
		else:
			_hover_ring.visible = false
			_hover_ring_target_id = ""

	# Update tooltip, cursor, and hover ring
	if _hovered_entity_id != "":
		var data := WorldState.get_entity_data(_hovered_entity_id)
		var display_name: String = data.get("name", _hovered_entity_id)
		var entity_type: String = data.get("type", "")
		if entity_type == "monster":
			var hp: int = data.get("hp", 0)
			var max_hp: int = data.get("max_hp", 0)
			display_name += " (HP: %d/%d)" % [hp, max_hp]
			_cursor_manager.set_cursor("attack")
		elif entity_type == "loot_drop":
			display_name += " [Loot]"
			_cursor_manager.set_cursor("click")
		elif entity_type == "npc":
			var npc_node := WorldState.get_entity(_hovered_entity_id)
			var tooltip_lines: Array = ["Talk to " + display_name + "  Lv.%d" % data.get("level", 1)]
			if npc_node and is_instance_valid(npc_node) and "trait_profile" in npc_node:
				var trait_summary: String = NpcTraitHelpers.get_trait_summary(npc_node.trait_profile)
				if not trait_summary.is_empty():
					tooltip_lines.append(trait_summary)
			var goal: String = data.get("goal", "idle")
			tooltip_lines.append(goal.capitalize().replace("_", " "))
			if npc_node and is_instance_valid(npc_node) and "current_mood" in npc_node:
				var mood: String = npc_node.current_mood
				if not mood.is_empty() and mood != "neutral":
					tooltip_lines.append("Mood: %s" % mood)
			display_name = "\n".join(tooltip_lines)
			_cursor_manager.set_cursor("talk")
		elif entity_type == "tree":
			var tier: String = data.get("tree_tier", "")
			if not tier.is_empty():
				display_name += " (%s)" % tier.capitalize()
			_cursor_manager.set_cursor("woodcut")
		elif entity_type == "rock":
			var tier: String = data.get("rock_tier", "")
			if not tier.is_empty():
				display_name += " (%s)" % tier.capitalize()
			_cursor_manager.set_cursor("mine")
		elif entity_type == "fishing_spot":
			var tier: String = data.get("fish_tier", "")
			if not tier.is_empty():
				display_name += " (%s)" % tier.capitalize()
			_cursor_manager.set_cursor("click")
		elif entity_type == "interior_npc":
			display_name = "Talk to " + display_name
			_cursor_manager.set_cursor("talk")
		elif entity_type == "door":
			var interior_name: String = data.get("interior_name", "Interior")
			display_name = "Enter %s" % interior_name
			_cursor_manager.set_cursor("click")
		else:
			_cursor_manager.set_cursor("default")
		_tooltip_label.text = display_name
		_tooltip_panel.visible = true
		_tooltip_panel.position = mouse_pos + TOOLTIP_OFFSET
	else:
		_tooltip_panel.visible = false
		_cursor_manager.set_cursor("default")
