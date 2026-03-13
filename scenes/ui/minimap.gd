extends Control
## Minimap overlay — draws entity dots on a player-centered 2D projection of the world.
## Toggle with M key.

const MAP_SIZE := 180.0
const MAP_RADIUS := 30.0  # world units visible around player
const BORDER := 2.0
const UPDATE_INTERVAL := 0.3

const COLOR_BG := Color(0.1, 0.1, 0.15, 0.85)
const COLOR_BORDER := Color(0.4, 0.35, 0.2)

# Zone rectangles in world XZ (Rect2 uses x,y = world x,z)
const ZONE_TOWN := Rect2(-70, -50, 140, 100)
const ZONE_FIELD := Rect2(70, -40, 80, 80)

const COLOR_ZONE_TOWN := Color(0.2, 0.3, 0.2, 0.15)
const COLOR_ZONE_FIELD := Color(0.3, 0.3, 0.15, 0.15)

var _timer: float = 0.0
var _dots: Array = []  # [{pos: Vector2, color: Color, radius: float, is_player: bool}]
var _zone_label_text: String = "Town"
var _player_pos := Vector3.ZERO

func _ready() -> void:
	# Anchor top-right
	anchors_preset = PRESET_TOP_RIGHT
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	var total_w := MAP_SIZE + BORDER * 2
	var total_h := MAP_SIZE + BORDER * 2 + 22  # extra for zone label
	offset_left = -total_w - 10
	offset_right = -10
	offset_top = 10
	offset_bottom = 10 + total_h
	custom_minimum_size = Vector2(total_w, total_h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	# Determine zone
	if _player_pos.x >= 70:
		_zone_label_text = "Field"
	else:
		_zone_label_text = "City"

	for id in WorldState.entities:
		var node: Node3D = WorldState.entities[id]
		if not node or not is_instance_valid(node):
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
			"npc":
				color = Color(0.4, 0.9, 0.4)
				radius = 3.0
			"monster":
				if data.get("hp", 0) <= 0:
					continue
				color = Color(1.0, 0.3, 0.3)
				radius = 2.5
			"loot_drop":
				color = Color(1.0, 0.9, 0.2)
				radius = 2.0
			"shop_npc":
				color = Color(0.5, 0.8, 1.0)
				radius = 3.0
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
	var map_rect := Rect2(0, 0, MAP_SIZE + BORDER * 2, MAP_SIZE + BORDER * 2)

	# Background
	draw_rect(map_rect, COLOR_BG)
	# Border
	draw_rect(map_rect, COLOR_BORDER, false, BORDER)

	# Zone hint rectangles
	_draw_zone_rect(ZONE_TOWN, COLOR_ZONE_TOWN)
	_draw_zone_rect(ZONE_FIELD, COLOR_ZONE_FIELD)

	# Draw non-player dots first, player last
	for dot in _dots:
		if dot.is_player:
			continue
		draw_circle(dot.pos, dot.radius, dot.color)

	for dot in _dots:
		if dot.is_player:
			# Black outline then white fill
			draw_circle(dot.pos, dot.radius + 1.5, Color.BLACK)
			draw_circle(dot.pos, dot.radius, Color.WHITE)

	# Zone label below map
	var label_pos := Vector2(BORDER + 4, MAP_SIZE + BORDER * 2 + 14)
	draw_string(ThemeDB.fallback_font, label_pos, _zone_label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.7))

func _draw_zone_rect(zone: Rect2, color: Color) -> void:
	# Convert world Rect2 (x,z) to map pixels relative to player
	var x1 := (zone.position.x - _player_pos.x) / MAP_RADIUS * (MAP_SIZE * 0.5) + BORDER + MAP_SIZE * 0.5
	var z1 := (zone.position.y - _player_pos.z) / MAP_RADIUS * (MAP_SIZE * 0.5) + BORDER + MAP_SIZE * 0.5
	var x2 := ((zone.position.x + zone.size.x) - _player_pos.x) / MAP_RADIUS * (MAP_SIZE * 0.5) + BORDER + MAP_SIZE * 0.5
	var z2 := ((zone.position.y + zone.size.y) - _player_pos.z) / MAP_RADIUS * (MAP_SIZE * 0.5) + BORDER + MAP_SIZE * 0.5

	# Clamp to map area
	x1 = clampf(x1, BORDER, BORDER + MAP_SIZE)
	z1 = clampf(z1, BORDER, BORDER + MAP_SIZE)
	x2 = clampf(x2, BORDER, BORDER + MAP_SIZE)
	z2 = clampf(z2, BORDER, BORDER + MAP_SIZE)

	if x2 > x1 and z2 > z1:
		draw_rect(Rect2(x1, z1, x2 - x1, z2 - z1), color)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			# Don't toggle if a LineEdit has focus
			var focused := get_viewport().gui_get_focus_owner()
			if focused is LineEdit:
				return
			visible = not visible
			get_viewport().set_input_as_handled()
