extends Control
## Minimap overlay — draws entity dots on a player-centered 2D projection of the world.
## Toggle with M key.

const MAP_SIZE := 180.0
const MAP_RADIUS := 30.0  # world units visible around player
const BORDER := 2.0
const UPDATE_INTERVAL := 0.3

const COLOR_BG := Color(0.1, 0.1, 0.15, 0.85)
const COLOR_BORDER := Color(0.4, 0.35, 0.2)

var _timer: float = 0.0
var _dots: Array = []  # [{pos: Vector2, color: Color, radius: float, is_player: bool}]
var _player_pos := Vector3.ZERO

func _ready() -> void:
	# Anchor top-right
	anchors_preset = PRESET_TOP_RIGHT
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	var total_w := MAP_SIZE + BORDER * 2
	var total_h := MAP_SIZE + BORDER * 2
	offset_left = -total_w - 10
	offset_right = -10
	offset_top = 10
	offset_bottom = 10 + total_h
	custom_minimum_size = Vector2(total_w, total_h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_INTERVAL
		_update_dots()
		queue_redraw()

func _update_dots() -> void:
	_dots.clear()
	var player_node: Node3D = WorldState.get_entity("player")
	if not player_node or not is_instance_valid(player_node):
		return
	_player_pos = player_node.global_position

	for id in WorldState.entities:
		var node: Node3D = WorldState.entities[id]
		if not node or not is_instance_valid(node):
			continue
		# Early distance cull — skip entities beyond minimap display radius
		if node.global_position.distance_to(_player_pos) > MAP_RADIUS:
			continue
		var data: Dictionary = WorldState.get_entity_data(id)
		var entity_type: String = data.get("type", "unknown")

		var color: Color
		var radius: float
		var is_player := false

		match entity_type:
			"player":
				color = Color.WHITE
				radius = 4.0
				is_player = true
			"loot_drop":
				color = Color(1.0, 0.9, 0.2)
				radius = 2.0
			_:
				continue

		var world_offset := node.global_position - _player_pos
		var map_x := (world_offset.x / MAP_RADIUS) * (MAP_SIZE * 0.5)
		var map_z := (world_offset.z / MAP_RADIUS) * (MAP_SIZE * 0.5)

		# Skip if outside map bounds
		if absf(map_x) > MAP_SIZE * 0.5 or absf(map_z) > MAP_SIZE * 0.5:
			continue

		var screen_pos := Vector2(
			BORDER + MAP_SIZE * 0.5 + map_x,
			BORDER + MAP_SIZE * 0.5 + map_z
		)
		_dots.append({
			"pos": screen_pos,
			"color": color,
			"radius": radius,
			"is_player": is_player,
		})


func _draw() -> void:
	var center := Vector2(BORDER + MAP_SIZE * 0.5, BORDER + MAP_SIZE * 0.5)
	var radius := MAP_SIZE * 0.5

	# Circular background
	draw_circle(center, radius, COLOR_BG)

	# Draw non-player dots first, player last
	for dot in _dots:
		if dot.get("is_player", false):
			continue
		if not _is_inside_circle(dot.pos, center, radius):
			continue
		draw_circle(dot.pos, dot.radius, dot.color)

	for dot in _dots:
		if dot.get("is_player", false):
			# Black outline then white fill
			draw_circle(dot.pos, dot.radius + 1.5, Color.BLACK)
			draw_circle(dot.pos, dot.radius, Color.WHITE)

	# Circular border (drawn on top)
	draw_arc(center, radius, 0, TAU, 64, COLOR_BORDER, BORDER)


func _is_inside_circle(point: Vector2, center: Vector2, radius: float) -> bool:
	return point.distance_to(center) <= radius


