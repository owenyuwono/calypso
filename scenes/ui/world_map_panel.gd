extends Control
## World map panel — shows full city + field layout with district labels and entity dots.
## Toggle with W key.

const DragHandle = preload("res://scripts/utils/drag_handle.gd")

const MAP_W := 500.0
const MAP_H := 400.0

# World extents for mapping
const WORLD_MIN_X := -150.0
const WORLD_MAX_X := 150.0
const WORLD_MIN_Z := -50.0
const WORLD_MAX_Z := 50.0

const COLOR_BG := Color(0.08, 0.08, 0.12, 0.92)
const COLOR_CITY := Color(0.2, 0.35, 0.2, 0.2)
const COLOR_FIELD := Color(0.35, 0.35, 0.15, 0.2)
const COLOR_WALL := Color(0.5, 0.45, 0.35, 0.8)
const UPDATE_INTERVAL := 0.5

const DISTRICT_LABELS: Array = [
	{"name": "Central Plaza", "pos": Vector2(0, 0)},
	{"name": "Market", "pos": Vector2(-45, 25)},
	{"name": "Residential", "pos": Vector2(-45, -30)},
	{"name": "Noble Quarter", "pos": Vector2(5, -35)},
	{"name": "Park", "pos": Vector2(45, -30)},
	{"name": "Craft", "pos": Vector2(0, 30)},
	{"name": "Garrison", "pos": Vector2(45, 30)},
	{"name": "East Gate", "pos": Vector2(65, 0)},
	{"name": "Field", "pos": Vector2(110, 0)},
	{"name": "West Gate", "pos": Vector2(-65, 0)},
	{"name": "West Field", "pos": Vector2(-110, 0)},
]

var _panel: PanelContainer
var _is_open: bool = false
var _timer: float = 0.0
var _dots: Array = []  # [{pos: Vector2, color: Color, radius: float}]
var _player_world_pos := Vector2.ZERO


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(MAP_W + 20, MAP_H + 50)
	_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# Draggable title bar
	var drag_handle := DragHandle.new()
	drag_handle.setup(_panel, "World Map")
	drag_handle.close_pressed.connect(toggle)
	vbox.add_child(drag_handle)

	# Drawing area — a Control node that we draw on
	var draw_area := Control.new()
	draw_area.custom_minimum_size = Vector2(MAP_W, MAP_H)
	draw_area.draw.connect(_on_draw_area_draw.bind(draw_area))
	vbox.add_child(draw_area)


func _process(delta: float) -> void:
	if not _is_open:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_INTERVAL
		_update_dots()
		# Find draw area and redraw
		var draw_area := _panel.get_child(0).get_child(1) as Control
		if draw_area:
			draw_area.queue_redraw()


func _update_dots() -> void:
	_dots.clear()
	var player_node: Node3D = WorldState.get_entity("player")
	if not player_node or not is_instance_valid(player_node):
		return
	_player_world_pos = Vector2(player_node.global_position.x, player_node.global_position.z)

	for id in WorldState.entities:
		var node: Node3D = WorldState.entities[id]
		if not node or not is_instance_valid(node):
			continue
		var data: Dictionary = WorldState.get_entity_data(id)
		var entity_type: String = data.get("type", "unknown")

		var color: Color
		var radius: float

		match entity_type:
			"player":
				color = Color.WHITE
				radius = 5.0
			"npc":
				color = Color(0.4, 0.9, 0.4)
				radius = 3.5
			"monster":
				if data.get("hp", 0) <= 0:
					continue
				color = Color(1.0, 0.3, 0.3)
				radius = 3.0
			"loot_drop":
				color = Color(1.0, 0.9, 0.2)
				radius = 2.5
			_:
				continue

		var wx: float = node.global_position.x
		var wz: float = node.global_position.z
		_dots.append({"pos": Vector2(wx, wz), "color": color, "radius": radius})


func _world_to_map(world_pos: Vector2) -> Vector2:
	var mx: float = (world_pos.x - WORLD_MIN_X) / (WORLD_MAX_X - WORLD_MIN_X) * MAP_W
	var my: float = (world_pos.y - WORLD_MIN_Z) / (WORLD_MAX_Z - WORLD_MIN_Z) * MAP_H
	return Vector2(mx, my)


func _on_draw_area_draw(draw_area: Control) -> void:
	# Background
	draw_area.draw_rect(Rect2(0, 0, MAP_W, MAP_H), COLOR_BG)

	# City zone rect (x:-70..70, z:-50..50)
	var city_tl := _world_to_map(Vector2(-70, -50))
	var city_br := _world_to_map(Vector2(70, 50))
	draw_area.draw_rect(Rect2(city_tl, city_br - city_tl), COLOR_CITY)

	# East field zone rect (x:70..150, z:-40..40)
	var field_tl := _world_to_map(Vector2(70, -40))
	var field_br := _world_to_map(Vector2(150, 40))
	draw_area.draw_rect(Rect2(field_tl, field_br - field_tl), COLOR_FIELD)

	# West field zone rect (x:-150..-70, z:-40..40)
	var wfield_tl := _world_to_map(Vector2(-150, -40))
	var wfield_br := _world_to_map(Vector2(-70, 40))
	draw_area.draw_rect(Rect2(wfield_tl, wfield_br - wfield_tl), COLOR_FIELD)

	# City wall outline
	var wall_top_left := _world_to_map(Vector2(-70, -50))
	var wall_top_right := _world_to_map(Vector2(70, -50))
	var wall_bot_left := _world_to_map(Vector2(-70, 50))
	var wall_bot_right := _world_to_map(Vector2(70, 50))
	var gate_top := _world_to_map(Vector2(70, -5))
	var gate_bot := _world_to_map(Vector2(70, 5))

	var wgate_top := _world_to_map(Vector2(-70, -5))
	var wgate_bot := _world_to_map(Vector2(-70, 5))

	draw_area.draw_line(wall_top_left, wall_top_right, COLOR_WALL, 2.0)  # North
	draw_area.draw_line(wall_bot_left, wall_bot_right, COLOR_WALL, 2.0)  # South
	draw_area.draw_line(wall_top_left, wgate_top, COLOR_WALL, 2.0)       # West top
	draw_area.draw_line(wgate_bot, wall_bot_left, COLOR_WALL, 2.0)       # West bottom
	draw_area.draw_line(wall_top_right, gate_top, COLOR_WALL, 2.0)       # East top
	draw_area.draw_line(gate_bot, wall_bot_right, COLOR_WALL, 2.0)       # East bottom

	# District labels
	var font := ThemeDB.fallback_font
	for label_def in DISTRICT_LABELS:
		var map_pos := _world_to_map(label_def["pos"])
		var label_text: String = label_def["name"]
		var text_width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_area.draw_string(font, Vector2(map_pos.x - text_width * 0.5, map_pos.y - 6), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.72, 0.6, 0.7))

	# Entity dots — non-player first
	for dot in _dots:
		var map_pos := _world_to_map(dot["pos"])
		if map_pos.x < 0 or map_pos.x > MAP_W or map_pos.y < 0 or map_pos.y > MAP_H:
			continue
		if dot["color"] == Color.WHITE:
			continue
		draw_area.draw_circle(map_pos, dot["radius"], dot["color"])

	# Player dot last (on top)
	var player_map := _world_to_map(_player_world_pos)
	if player_map.x >= 0 and player_map.x <= MAP_W and player_map.y >= 0 and player_map.y <= MAP_H:
		draw_area.draw_circle(player_map, 6.0, Color.BLACK)
		draw_area.draw_circle(player_map, 5.0, Color.WHITE)


func toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		UIHelper.center_panel(_panel)
		_update_dots()
		var draw_area := _panel.get_child(0).get_child(1) as Control
		if draw_area:
			draw_area.queue_redraw()


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is LineEdit:
				return
			toggle()
			get_viewport().set_input_as_handled()
