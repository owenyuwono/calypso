extends Control
## World map panel — shows full city + field layout with district labels and entity dots.
## Toggle with W key.

const MAP_W := 500.0
const MAP_H := 400.0

const COLOR_BG := Color(0.08, 0.08, 0.12, 0.92)
const COLOR_WALL := Color(0.5, 0.45, 0.35, 0.8)
const UPDATE_INTERVAL := 0.5

# World extents computed once from ZoneDatabase at startup
var _world_min_x: float = 0.0
var _world_max_x: float = 0.0
var _world_min_z: float = 0.0
var _world_max_z: float = 0.0

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
	_compute_world_extents()
	_build_ui()


func _compute_world_extents() -> void:
	var first: bool = true
	for zone_id in ZoneDatabase.ZONES:
		var bounds: Rect2 = ZoneDatabase.ZONES[zone_id]["bounds"]
		var min_x: float = bounds.position.x
		var min_z: float = bounds.position.y
		var max_x: float = bounds.position.x + bounds.size.x
		var max_z: float = bounds.position.y + bounds.size.y
		if first:
			_world_min_x = min_x
			_world_max_x = max_x
			_world_min_z = min_z
			_world_max_z = max_z
			first = false
		else:
			_world_min_x = minf(_world_min_x, min_x)
			_world_max_x = maxf(_world_max_x, max_x)
			_world_min_z = minf(_world_min_z, min_z)
			_world_max_z = maxf(_world_max_z, max_z)


func _build_ui() -> void:
	var ui: Dictionary = UIHelper.create_titled_panel("World Map", Vector2(MAP_W + 20, MAP_H + 50), toggle)
	_panel = ui["panel"]
	add_child(_panel)

	var vbox: VBoxContainer = ui["vbox"]

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
	var mx: float = (world_pos.x - _world_min_x) / (_world_max_x - _world_min_x) * MAP_W
	var my: float = (world_pos.y - _world_min_z) / (_world_max_z - _world_min_z) * MAP_H
	return Vector2(mx, my)


func _on_draw_area_draw(draw_area: Control) -> void:
	# Background
	draw_area.draw_rect(Rect2(0, 0, MAP_W, MAP_H), COLOR_BG)

	# Zone rects — dynamic from ZoneDatabase; highlight the currently loaded zone
	var loaded_zone: Node3D = ZoneManager.get_loaded_zone()
	var current_zone_id: String = ""
	if loaded_zone and "zone_id" in loaded_zone:
		current_zone_id = loaded_zone.zone_id

	for zone_id in ZoneDatabase.ZONES:
		var zone_data: Dictionary = ZoneDatabase.ZONES[zone_id]
		var bounds: Rect2 = zone_data["bounds"]
		var zone_color: Color = zone_data["color"]
		var tl: Vector2 = _world_to_map(bounds.position)
		var br: Vector2 = _world_to_map(bounds.position + bounds.size)
		var fill_rect := Rect2(tl, br - tl)
		if zone_id == current_zone_id:
			# Brighter fill + highlighted border for active zone
			var highlight_color := Color(zone_color.r, zone_color.g, zone_color.b, zone_color.a * 2.5)
			draw_area.draw_rect(fill_rect, highlight_color)
			draw_area.draw_rect(fill_rect, Color(0.8, 0.75, 0.5, 0.7), false, 2.0)
		else:
			draw_area.draw_rect(fill_rect, zone_color)

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

	# Portal markers — deduplicate overlapping positions
	var drawn_portals: Dictionary = {}  # "x,z" -> true, to avoid duplicate markers
	for zone_id in ZoneDatabase.PORTALS:
		var portals: Array = ZoneDatabase.PORTALS[zone_id]
		for portal_def in portals:
			var rect: Rect2 = portal_def["source_rect"]
			var center_x: float = rect.position.x + rect.size.x / 2.0
			var center_z: float = rect.position.y + rect.size.y / 2.0
			var key: String = "%.0f,%.0f" % [center_x, center_z]
			if drawn_portals.has(key):
				continue
			drawn_portals[key] = true

			var map_pos: Vector2 = _world_to_map(Vector2(center_x, center_z))

			# Diamond shape
			var r: float = 5.0
			var points: PackedVector2Array = PackedVector2Array([
				Vector2(map_pos.x, map_pos.y - r),
				Vector2(map_pos.x + r, map_pos.y),
				Vector2(map_pos.x, map_pos.y + r),
				Vector2(map_pos.x - r, map_pos.y),
			])
			draw_area.draw_colored_polygon(points, Color(0.4, 0.7, 1.0, 0.9))

			# Destination label — pick one target to show (first portal found at this position)
			var dest_name: String = ZoneDatabase.get_zone_name(portal_def["target"])
			draw_area.draw_string(
				ThemeDB.fallback_font,
				Vector2(map_pos.x + 8, map_pos.y + 4),
				dest_name,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1, 9,
				Color(0.5, 0.8, 1.0, 0.8)
			)

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
