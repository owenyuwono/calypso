extends CharacterBody3D
## Player controller with isometric movement, NPC interaction, and mouse hover system.

const SPEED: float = 6.0
const GRAVITY: float = 9.8
const INTERACT_RANGE: float = 4.0
const HOVER_RAY_LENGTH: float = 100.0
const TOOLTIP_OFFSET: Vector2 = Vector2(16, 16)

var _hovered_entity_id: String = ""
var _tooltip_label: Label
var _tooltip_panel: PanelContainer

func _ready() -> void:
	WorldState.register_entity("player", self, {
		"type": "player",
		"name": "Player",
		"inventory": [],
	})
	_setup_tooltip()

func _setup_tooltip() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
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

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y).rotated(Vector3.UP, deg_to_rad(45.0))

	if direction.length() > 0.1:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	move_and_slide()

	# Safety teleport if fallen off the world
	if global_position.y < -10.0:
		global_position = Vector3(0.0, 2.0, 0.0)
		velocity = Vector3.ZERO

func _process(_delta: float) -> void:
	_process_hover()

func _process_hover() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * HOVER_RAY_LENGTH
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self.get_rid()]
	var result := space.intersect_ray(query)

	var new_entity_id: String = ""
	if result:
		var collider: Node = result.collider
		if collider is Node3D:
			new_entity_id = WorldState.get_entity_id_for_node(collider)
			# Skip the player itself and unknown colliders
			if new_entity_id == "player" or new_entity_id == "":
				new_entity_id = ""

	if new_entity_id != _hovered_entity_id:
		# Unhighlight previous
		if _hovered_entity_id != "":
			var prev_node := WorldState.get_entity(_hovered_entity_id)
			if prev_node and is_instance_valid(prev_node) and prev_node.has_method("unhighlight"):
				prev_node.unhighlight()

		# Highlight new
		if new_entity_id != "":
			var new_node := WorldState.get_entity(new_entity_id)
			if new_node and is_instance_valid(new_node) and new_node.has_method("highlight"):
				new_node.highlight()

		_hovered_entity_id = new_entity_id

	# Update tooltip
	if _hovered_entity_id != "":
		var data := WorldState.get_entity_data(_hovered_entity_id)
		var display_name: String = data.get("name", _hovered_entity_id)
		_tooltip_label.text = display_name
		_tooltip_panel.visible = true
		_tooltip_panel.position = mouse_pos + TOOLTIP_OFFSET
	else:
		_tooltip_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact_with_nearest_npc()

func _interact_with_nearest_npc() -> void:
	var nearby := WorldState.get_nearby_entities(global_position, INTERACT_RANGE)
	for entry in nearby:
		var data := WorldState.get_entity_data(entry.id)
		if data.get("type", "") == "npc":
			_talk_to_npc(entry.id, entry.node)
			return

func _talk_to_npc(target_npc_id: String, target_node: Node3D) -> void:
	# Emit a player dialogue event
	GameEvents.npc_spoke.emit("player", "Hello there!", target_npc_id)

	# Trigger reactive response from the NPC brain
	var brain: Node = target_node.get_node_or_null("NPCBrain")
	if brain and brain.has_method("request_reactive_response"):
		brain.request_reactive_response("player", "Hello there!")
