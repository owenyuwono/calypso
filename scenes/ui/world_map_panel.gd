extends Control
## World map panel — shows full city + field layout with district labels.
## Content builder pattern: call build_content(parent) to inject into a tab container.

const COLOR_BG := Color(0.08, 0.08, 0.12, 0.92)
const COLOR_WALL := Color(0.5, 0.45, 0.35, 0.8)
const UPDATE_INTERVAL := 0.5

# Zone padding in world units so entities at edges aren't clipped in zone mode
const ZONE_PADDING := 8.0

# World extents computed once from ZoneDatabase at startup
var _world_min_x: float = 0.0
var _world_max_x: float = 0.0
var _world_min_z: float = 0.0
var _world_max_z: float = 0.0

# View mode: "zone" shows only the current zone, "world" shows all zones
var _view_mode: String = "zone"

const CITY_DISTRICT_LABELS: Array = [
	{"name": "Central Plaza", "pos": Vector2(0, 0)},
	{"name": "Market", "pos": Vector2(-45, 25)},
	{"name": "Residential", "pos": Vector2(-45, -30)},
	{"name": "Noble Quarter", "pos": Vector2(5, -35)},
	{"name": "Park", "pos": Vector2(45, -30)},
	{"name": "Craft", "pos": Vector2(0, 30)},
	{"name": "Garrison", "pos": Vector2(45, 30)},
	{"name": "East Gate", "pos": Vector2(65, 0)},
	{"name": "West Gate", "pos": Vector2(-65, 0)},
]

const FIELD_LABELS: Array = [
	{"name": "Field", "pos": Vector2(110, 0), "zone": "east_field"},
	{"name": "West Field", "pos": Vector2(-110, 0), "zone": "west_field"},
]

# World mode zone display colors (more vivid than ZoneDatabase defaults)
const ZONE_COLORS: Dictionary = {
	"city": Color(0.6, 0.45, 0.25, 0.8),
	"east_field": Color(0.3, 0.55, 0.25, 0.8),
	"west_field": Color(0.25, 0.5, 0.3, 0.8),
}

const ZONE_DESCRIPTIONS: Dictionary = {
	"city": "The fortified capital of Prontera. A bustling city with 8 districts, markets, and craftsmen.",
	"east_field": "Rolling grasslands east of the city. Home to slimes, wolves, and goblins.",
	"west_field": "Untamed wilderness west of the city walls. Dangerous creatures lurk here.",
}

var _content_parent: Control = null
var _draw_area: Control
var _toggle_btn: Button
var _zone_title_label: Label
var _timer: float = 0.0
# Cached zone extents for zone mode (updated each time map opens or zone changes)
var _zone_min_x: float = 0.0
var _zone_max_x: float = 0.0
var _zone_min_z: float = 0.0
var _zone_max_z: float = 0.0

# Entity dots for zone mode
var _dots: Array = []
var _player_dot: Vector2 = Vector2.ZERO

# World mode hover state
var _hover_popup: PanelContainer
var _hover_name_label: Label
var _hover_desc_label: Label
var _hovered_zone: String = ""
var _zone_rects: Dictionary = {}  # zone_id -> Rect2 (screen coords in _draw_area space)


func _ready() -> void:
	_compute_world_extents()
	if ZoneManager.has_signal("zone_changed"):
		ZoneManager.zone_changed.connect(_on_zone_changed)


func _on_zone_changed(_old_zone_id: String, _new_zone_id: String) -> void:
	_compute_zone_extents(_get_current_zone_id())
	_update_zone_title()


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


func _compute_zone_extents(zone_id: String) -> void:
	if not zone_id in ZoneDatabase.ZONES:
		# Fallback to world extents
		_zone_min_x = _world_min_x
		_zone_max_x = _world_max_x
		_zone_min_z = _world_min_z
		_zone_max_z = _world_max_z
		return
	var bounds: Rect2 = ZoneDatabase.ZONES[zone_id]["bounds"]
	_zone_min_x = bounds.position.x - ZONE_PADDING
	_zone_max_x = bounds.position.x + bounds.size.x + ZONE_PADDING
	_zone_min_z = bounds.position.y - ZONE_PADDING
	_zone_max_z = bounds.position.y + bounds.size.y + ZONE_PADDING


func _get_current_zone_id() -> String:
	var loaded_zone: Node3D = ZoneManager.get_loaded_zone()
	if loaded_zone and "zone_id" in loaded_zone:
		return loaded_zone.zone_id
	return ""


func build_content(parent: Control) -> void:
	_content_parent = parent

	# Zone title label row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	parent.add_child(title_row)

	_zone_title_label = Label.new()
	_zone_title_label.text = "Zone"
	_zone_title_label.add_theme_font_size_override("font_size", 13)
	_zone_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_zone_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_zone_title_label)

	# View mode toggle button (top-right of title row)
	_toggle_btn = Button.new()
	_toggle_btn.text = "World"
	_toggle_btn.custom_minimum_size = Vector2(60, 24)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	btn_style.border_color = Color(0.7, 0.6, 0.2)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(3)
	btn_style.content_margin_left = 6
	btn_style.content_margin_right = 6
	btn_style.content_margin_top = 2
	btn_style.content_margin_bottom = 2
	_toggle_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.2, 0.17, 0.1, 0.95)
	_toggle_btn.add_theme_stylebox_override("hover", btn_hover)
	_toggle_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_toggle_btn.add_theme_font_size_override("font_size", 12)
	_toggle_btn.pressed.connect(_on_view_toggle_pressed)
	title_row.add_child(_toggle_btn)

	# Drawing area — expands to fill available tab space
	_draw_area = Control.new()
	_draw_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draw_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_draw_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_draw_area.draw.connect(_on_draw_area_draw.bind(_draw_area))
	_draw_area.gui_input.connect(_on_draw_area_input)
	parent.add_child(_draw_area)

	# Hover popup — top_level so it renders above other tab content
	_hover_popup = PanelContainer.new()
	_hover_popup.visible = false
	_hover_popup.top_level = true
	_hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var popup_style: StyleBoxTexture = UIHelper.create_panel_style()
	_hover_popup.add_theme_stylebox_override("panel", popup_style)
	_hover_popup.custom_minimum_size = Vector2(160, 0)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.add_theme_constant_override("separation", 2)
	_hover_popup.add_child(popup_vbox)

	_hover_name_label = Label.new()
	_hover_name_label.add_theme_font_size_override("font_size", 12)
	_hover_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_hover_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	popup_vbox.add_child(_hover_name_label)

	_hover_desc_label = Label.new()
	_hover_desc_label.add_theme_font_size_override("font_size", 9)
	_hover_desc_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	_hover_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_desc_label.custom_minimum_size = Vector2(150, 0)
	popup_vbox.add_child(_hover_desc_label)

	# Initialize zone extents and title now that we have a parent
	var zone_id: String = _get_current_zone_id()
	_compute_zone_extents(zone_id)
	_update_zone_title()


func get_overlay_nodes() -> Array[Control]:
	var result: Array[Control] = []
	if _hover_popup:
		result.append(_hover_popup)
	return result


func refresh() -> void:
	if not _content_parent or not _content_parent.visible:
		return
	var zone_id: String = _get_current_zone_id()
	_compute_zone_extents(zone_id)
	_update_zone_title()
	if _draw_area:
		_draw_area.queue_redraw()


func _on_view_toggle_pressed() -> void:
	if _view_mode == "zone":
		_view_mode = "world"
		_toggle_btn.text = "Zone"
	else:
		_view_mode = "zone"
		_toggle_btn.text = "World"
		_hide_hover_popup()
	_update_zone_title()
	_draw_area.queue_redraw()


func _update_zone_title() -> void:
	if not _zone_title_label:
		return
	var zone_id: String = _get_current_zone_id()
	if _view_mode == "world":
		_zone_title_label.text = "All Zones"
	elif zone_id != "":
		_zone_title_label.text = ZoneDatabase.get_zone_name(zone_id)
	else:
		_zone_title_label.text = "Unknown Zone"


func _process(delta: float) -> void:
	if not _content_parent or not _content_parent.visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_INTERVAL
		if _view_mode == "zone":
			_update_dots()
		_draw_area.queue_redraw()


func _update_dots() -> void:
	_dots.clear()
	_player_dot = Vector2.ZERO
	var current_zone_id: String = _get_current_zone_id()
	var zone_bounds: Rect2 = Rect2()
	var has_bounds: bool = false
	if current_zone_id in ZoneDatabase.ZONES:
		zone_bounds = ZoneDatabase.ZONES[current_zone_id]["bounds"]
		has_bounds = true

	for eid in WorldState.entities:
		var node: Node3D = WorldState.entities[eid]
		if not node or not is_instance_valid(node):
			continue
		var wx: float = node.global_position.x
		var wz: float = node.global_position.z
		# Cull entities outside current zone bounds
		if has_bounds and not zone_bounds.has_point(Vector2(wx, wz)):
			continue
		var data: Dictionary = WorldState.get_entity_data(eid)
		var etype: String = data.get("type", "")
		match etype:
			"player":
				_player_dot = _world_to_map(Vector2(wx, wz))
			"npc":
				_dots.append({"pos": _world_to_map(Vector2(wx, wz)), "color": Color(0.3, 0.8, 0.3)})
			"monster":
				if data.get("hp", 1) <= 0:
					continue
				_dots.append({"pos": _world_to_map(Vector2(wx, wz)), "color": Color(0.9, 0.25, 0.2)})
			"loot_drop":
				_dots.append({"pos": _world_to_map(Vector2(wx, wz)), "color": Color(0.95, 0.85, 0.2)})


func _world_to_map(world_pos: Vector2) -> Vector2:
	var map_w: float = _draw_area.size.x if _draw_area else 500.0
	var map_h: float = _draw_area.size.y if _draw_area else 400.0
	if _view_mode == "zone":
		var mx: float = (world_pos.x - _zone_min_x) / (_zone_max_x - _zone_min_x) * map_w
		var my: float = (world_pos.y - _zone_min_z) / (_zone_max_z - _zone_min_z) * map_h
		return Vector2(mx, my)
	else:
		var mx: float = (world_pos.x - _world_min_x) / (_world_max_x - _world_min_x) * map_w
		var my: float = (world_pos.y - _world_min_z) / (_world_max_z - _world_min_z) * map_h
		return Vector2(mx, my)


func _on_draw_area_draw(draw_area: Control) -> void:
	var map_w: float = draw_area.size.x
	var map_h: float = draw_area.size.y

	# Background
	draw_area.draw_rect(Rect2(0, 0, map_w, map_h), COLOR_BG)

	var current_zone_id: String = _get_current_zone_id()

	if _view_mode == "zone":
		_draw_zone_mode(draw_area, current_zone_id)
	else:
		_draw_world_mode(draw_area, current_zone_id)


func _draw_zone_mode(draw_area: Control, current_zone_id: String) -> void:
	var map_w: float = draw_area.size.x
	var map_h: float = draw_area.size.y

	# Draw the current zone's rect with its color (highlighted)
	if current_zone_id in ZoneDatabase.ZONES:
		var zone_data: Dictionary = ZoneDatabase.ZONES[current_zone_id]
		var bounds: Rect2 = zone_data["bounds"]
		var zone_color: Color = zone_data["color"]
		var tl: Vector2 = _world_to_map(bounds.position)
		var br: Vector2 = _world_to_map(bounds.position + bounds.size)
		var fill_rect := Rect2(tl, br - tl)
		var highlight_color := Color(zone_color.r, zone_color.g, zone_color.b, zone_color.a * 2.5)
		draw_area.draw_rect(fill_rect, highlight_color)
		draw_area.draw_rect(fill_rect, Color(0.8, 0.75, 0.5, 0.7), false, 2.0)

	# City walls — only when in the city zone
	if current_zone_id == "city":
		_draw_city_walls(draw_area)

	# District labels — city labels only in city zone, otherwise skip
	var font := ThemeDB.fallback_font
	if current_zone_id == "city":
		for label_def in CITY_DISTRICT_LABELS:
			var map_pos: Vector2 = _world_to_map(label_def["pos"])
			if map_pos.x < 0 or map_pos.x > map_w or map_pos.y < 0 or map_pos.y > map_h:
				continue
			var label_text: String = label_def["name"]
			var text_width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_area.draw_string(font, Vector2(map_pos.x - text_width * 0.5, map_pos.y - 6), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.82, 0.65, 0.85))
	elif current_zone_id == "east_field":
		var label_text := "East Field"
		var map_pos: Vector2 = _world_to_map(Vector2(110, 0))
		if map_pos.x >= 0 and map_pos.x <= map_w and map_pos.y >= 0 and map_pos.y <= map_h:
			var text_width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_area.draw_string(font, Vector2(map_pos.x - text_width * 0.5, map_pos.y - 6), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.82, 0.65, 0.85))
	elif current_zone_id == "west_field":
		var label_text := "West Field"
		var map_pos: Vector2 = _world_to_map(Vector2(-110, 0))
		if map_pos.x >= 0 and map_pos.x <= map_w and map_pos.y >= 0 and map_pos.y <= map_h:
			var text_width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_area.draw_string(font, Vector2(map_pos.x - text_width * 0.5, map_pos.y - 6), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.82, 0.65, 0.85))

	# Portal markers for current zone
	_draw_portals_for_zone(draw_area, current_zone_id)

	# Entity dots
	for dot in _dots:
		draw_area.draw_circle(dot.pos, 3.0, dot.color)
	# Player on top with black outline
	if _player_dot != Vector2.ZERO:
		draw_area.draw_circle(_player_dot, 6.0, Color.BLACK)
		draw_area.draw_circle(_player_dot, 5.0, Color.WHITE)


func _draw_world_mode(draw_area: Control, current_zone_id: String) -> void:
	var map_w: float = draw_area.size.x
	var map_h: float = draw_area.size.y
	var font := ThemeDB.fallback_font
	_zone_rects.clear()

	# Compute layout: three side-by-side columns
	# West Field | City | East Field
	var margin: float = map_w * 0.19
	var gap: float = map_w * 0.032
	var available_w: float = map_w - margin * 2.0 - gap * 2.0
	# City is 140 wide, fields are 80 wide each → total 300 world units
	var total_world_w: float = 80.0 + 140.0 + 80.0
	var west_w: float = available_w * (80.0 / total_world_w)
	var city_w: float = available_w * (140.0 / total_world_w)
	var east_w: float = available_w * (80.0 / total_world_w)

	# Heights: city is 100 tall, fields are 80 tall
	var max_h: float = map_h - margin * 2.0
	var city_h: float = max_h
	var field_h: float = max_h * (80.0 / 100.0)

	var west_x: float = margin
	var city_x: float = margin + west_w + gap
	var east_x: float = city_x + city_w + gap
	var city_y: float = margin
	var field_y: float = margin + (city_h - field_h) * 0.5

	var rect_west := Rect2(west_x, field_y, west_w, field_h)
	var rect_city := Rect2(city_x, city_y, city_w, city_h)
	var rect_east := Rect2(east_x, field_y, east_w, field_h)

	_zone_rects["west_field"] = rect_west
	_zone_rects["city"] = rect_city
	_zone_rects["east_field"] = rect_east

	# Portal connection lines (draw behind zone rects)
	var city_east_mid := Vector2(rect_city.position.x + rect_city.size.x, rect_city.position.y + rect_city.size.y * 0.5)
	var east_west_mid := Vector2(rect_east.position.x, rect_east.position.y + rect_east.size.y * 0.5)
	var city_west_mid := Vector2(rect_city.position.x, rect_city.position.y + rect_city.size.y * 0.5)
	var west_east_mid := Vector2(rect_west.position.x + rect_west.size.x, rect_west.position.y + rect_west.size.y * 0.5)
	_draw_dashed_line(draw_area, city_east_mid, east_west_mid, Color(0.5, 0.7, 0.9, 0.5), 2.0, 8.0)
	_draw_dashed_line(draw_area, city_west_mid, west_east_mid, Color(0.5, 0.7, 0.9, 0.5), 2.0, 8.0)

	# Draw zone rectangles
	var zone_order: Array = ["west_field", "city", "east_field"]
	var zone_rect_map: Dictionary = {"west_field": rect_west, "city": rect_city, "east_field": rect_east}
	for zone_id in zone_order:
		var zone_rect: Rect2 = zone_rect_map[zone_id]
		var base_color: Color = ZONE_COLORS.get(zone_id, Color(0.3, 0.4, 0.3, 0.8))

		# Slightly brighten hovered zone
		var draw_color: Color = base_color
		if zone_id == _hovered_zone:
			draw_color = Color(base_color.r + 0.1, base_color.g + 0.1, base_color.b + 0.1, base_color.a)

		draw_area.draw_rect(zone_rect, draw_color)

		# Border — gold for active zone, subtle for others
		if zone_id == current_zone_id:
			draw_area.draw_rect(zone_rect, Color(0.85, 0.7, 0.2, 0.95), false, 3.0)
		else:
			draw_area.draw_rect(zone_rect, Color(0.4, 0.35, 0.2, 0.6), false, 1.5)

		# Zone name centered in rect
		var zone_name: String = ZoneDatabase.get_zone_name(zone_id)
		var name_size: float = 13.0
		var name_w: float = font.get_string_size(zone_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
		var name_pos := Vector2(
			zone_rect.position.x + (zone_rect.size.x - name_w) * 0.5,
			zone_rect.position.y + 18.0
		)
		draw_area.draw_string(font, name_pos, zone_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color(1.0, 0.95, 0.8, 1.0))

		# Simple icon inside each zone
		if zone_id == "city":
			_draw_castle_icon(draw_area, zone_rect)
		else:
			_draw_tree_icon(draw_area, zone_rect)

		# "YOU ARE HERE" marker if this is the current zone
		if zone_id == current_zone_id:
			var marker_text := "YOU ARE HERE"
			var marker_size: float = 9.0
			var marker_w: float = font.get_string_size(marker_text, HORIZONTAL_ALIGNMENT_LEFT, -1, marker_size).x
			var marker_pos := Vector2(
				zone_rect.position.x + (zone_rect.size.x - marker_w) * 0.5,
				zone_rect.position.y + zone_rect.size.y - 12.0
			)
			draw_area.draw_string(font, marker_pos, marker_text, HORIZONTAL_ALIGNMENT_LEFT, -1, marker_size, Color(0.85, 0.7, 0.2, 0.9))


func _draw_castle_icon(draw_area: Control, zone_rect: Rect2) -> void:
	# Simple castle: a wide base rect + two towers on the sides
	var cx: float = zone_rect.position.x + zone_rect.size.x * 0.5
	var cy: float = zone_rect.position.y + zone_rect.size.y * 0.5 + 10.0
	var base_w: float = minf(zone_rect.size.x * 0.45, 60.0)
	var base_h: float = minf(zone_rect.size.y * 0.3, 40.0)
	var tower_w: float = base_w * 0.28
	var tower_h: float = base_h * 1.4

	var icon_color := Color(0.9, 0.85, 0.65, 0.7)
	var shadow_color := Color(0.0, 0.0, 0.0, 0.25)

	# Main body (slight shadow offset)
	draw_area.draw_rect(Rect2(cx - base_w * 0.5 + 2, cy - base_h * 0.5 + 2, base_w, base_h), shadow_color)
	draw_area.draw_rect(Rect2(cx - base_w * 0.5, cy - base_h * 0.5, base_w, base_h), icon_color)

	# Left tower
	draw_area.draw_rect(Rect2(cx - base_w * 0.5 - tower_w * 0.3 + 2, cy - tower_h + base_h * 0.4 + 2, tower_w, tower_h), shadow_color)
	draw_area.draw_rect(Rect2(cx - base_w * 0.5 - tower_w * 0.3, cy - tower_h + base_h * 0.4, tower_w, tower_h), icon_color)

	# Right tower
	draw_area.draw_rect(Rect2(cx + base_w * 0.5 - tower_w * 0.7 + 2, cy - tower_h + base_h * 0.4 + 2, tower_w, tower_h), shadow_color)
	draw_area.draw_rect(Rect2(cx + base_w * 0.5 - tower_w * 0.7, cy - tower_h + base_h * 0.4, tower_w, tower_h), icon_color)

	# Gate arch (dark rectangle at base center)
	var gate_w: float = base_w * 0.22
	var gate_h: float = base_h * 0.55
	draw_area.draw_rect(Rect2(cx - gate_w * 0.5, cy + base_h * 0.5 - gate_h, gate_w, gate_h), Color(0.08, 0.08, 0.12, 0.8))

	# Merlons on left tower (3 small rectangles on top)
	var merlon_w: float = tower_w * 0.28
	var merlon_h: float = tower_w * 0.3
	var tower_left_x: float = cx - base_w * 0.5 - tower_w * 0.3
	var tower_top_y: float = cy - tower_h + base_h * 0.4
	for i in 3:
		draw_area.draw_rect(Rect2(tower_left_x + i * (merlon_w + 1.5), tower_top_y - merlon_h, merlon_w, merlon_h), icon_color)

	# Merlons on right tower
	var tower_right_x: float = cx + base_w * 0.5 - tower_w * 0.7
	for i in 3:
		draw_area.draw_rect(Rect2(tower_right_x + i * (merlon_w + 1.5), tower_top_y - merlon_h, merlon_w, merlon_h), icon_color)


func _draw_tree_icon(draw_area: Control, zone_rect: Rect2) -> void:
	# Two simple trees: triangle crown + rectangle trunk
	var cx: float = zone_rect.position.x + zone_rect.size.x * 0.5
	var cy: float = zone_rect.position.y + zone_rect.size.y * 0.5 + 10.0
	var tree_color := Color(0.25, 0.6, 0.25, 0.75)
	var trunk_color := Color(0.45, 0.3, 0.15, 0.75)
	var offsets: Array = [-18.0, 18.0]
	for ox in offsets:
		var tx: float = cx + ox
		var crown_h: float = 32.0
		var crown_w: float = 22.0
		var trunk_w: float = 6.0
		var trunk_h: float = 10.0
		# Crown triangle
		var pts := PackedVector2Array([
			Vector2(tx, cy - crown_h * 0.5),
			Vector2(tx - crown_w * 0.5, cy + crown_h * 0.5),
			Vector2(tx + crown_w * 0.5, cy + crown_h * 0.5),
		])
		draw_area.draw_colored_polygon(pts, tree_color)
		# Trunk
		draw_area.draw_rect(Rect2(tx - trunk_w * 0.5, cy + crown_h * 0.5, trunk_w, trunk_h), trunk_color)


func _draw_dashed_line(draw_area: Control, from: Vector2, to: Vector2, color: Color, width: float, dash_len: float) -> void:
	var total: float = from.distance_to(to)
	if total < 0.01:
		return
	var dir: Vector2 = (to - from) / total
	var traveled: float = 0.0
	var drawing: bool = true
	while traveled < total:
		var seg_end: float = minf(traveled + dash_len, total)
		if drawing:
			draw_area.draw_line(from + dir * traveled, from + dir * seg_end, color, width)
		traveled = seg_end + (dash_len * 0.5)
		drawing = not drawing


func _on_draw_area_input(event: InputEvent) -> void:
	if _view_mode != "world":
		_hide_hover_popup()
		return
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		var found_zone: String = ""
		for zone_id in _zone_rects:
			if _zone_rects[zone_id].has_point(mouse_pos):
				found_zone = zone_id
				break
		if found_zone != _hovered_zone:
			_hovered_zone = found_zone
			_draw_area.queue_redraw()
			if found_zone != "":
				_show_hover_popup(found_zone, mouse_pos)
			else:
				_hide_hover_popup()
		elif found_zone != "" and _hover_popup.visible:
			# Keep popup position updated as mouse moves within zone
			_position_hover_popup(mouse_pos)


func _show_hover_popup(zone_id: String, mouse_pos: Vector2) -> void:
	_hover_name_label.text = ZoneDatabase.get_zone_name(zone_id)
	_hover_desc_label.text = ZONE_DESCRIPTIONS.get(zone_id, "")
	_hover_popup.visible = true
	_position_hover_popup(mouse_pos)


func _position_hover_popup(mouse_pos: Vector2) -> void:
	# top_level=true means position is in global/screen coordinates
	var draw_area_global: Vector2 = _draw_area.get_global_rect().position
	var popup_pos: Vector2 = draw_area_global + mouse_pos + Vector2(12.0, 12.0)
	# Clamp so popup stays within content parent bounds
	var clamp_rect: Rect2 = _content_parent.get_global_rect() if _content_parent else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_hover_popup.reset_size()
	var popup_size: Vector2 = _hover_popup.size
	popup_pos.x = clampf(popup_pos.x, clamp_rect.position.x + 4.0, clamp_rect.end.x - popup_size.x - 4.0)
	popup_pos.y = clampf(popup_pos.y, clamp_rect.position.y + 4.0, clamp_rect.end.y - popup_size.y - 4.0)
	_hover_popup.global_position = popup_pos


func _hide_hover_popup() -> void:
	_hover_popup.visible = false
	if _hovered_zone != "":
		_hovered_zone = ""
		_draw_area.queue_redraw()


func _draw_city_walls(draw_area: Control) -> void:
	var wall_top_left := _world_to_map(Vector2(-70, -50))
	var wall_top_right := _world_to_map(Vector2(70, -50))
	var wall_bot_left := _world_to_map(Vector2(-70, 50))
	var wall_bot_right := _world_to_map(Vector2(70, 50))
	var gate_top := _world_to_map(Vector2(70, -5))
	var gate_bot := _world_to_map(Vector2(70, 5))
	var wgate_top := _world_to_map(Vector2(-70, -5))
	var wgate_bot := _world_to_map(Vector2(-70, 5))

	draw_area.draw_line(wall_top_left, wall_top_right, COLOR_WALL, 2.0)   # North
	draw_area.draw_line(wall_bot_left, wall_bot_right, COLOR_WALL, 2.0)   # South
	draw_area.draw_line(wall_top_left, wgate_top, COLOR_WALL, 2.0)        # West top
	draw_area.draw_line(wgate_bot, wall_bot_left, COLOR_WALL, 2.0)        # West bottom
	draw_area.draw_line(wall_top_right, gate_top, COLOR_WALL, 2.0)        # East top
	draw_area.draw_line(gate_bot, wall_bot_right, COLOR_WALL, 2.0)        # East bottom


func _draw_portals_for_zone(draw_area: Control, zone_id: String) -> void:
	var portals: Array = ZoneDatabase.get_portals(zone_id)
	for portal_def in portals:
		var rect: Rect2 = portal_def["source_rect"]
		var center_x: float = rect.position.x + rect.size.x / 2.0
		var center_z: float = rect.position.y + rect.size.y / 2.0
		_draw_portal_marker(draw_area, Vector2(center_x, center_z), portal_def["target"])


func _draw_portal_marker(draw_area: Control, world_pos: Vector2, dest_zone_id: String) -> void:
	var map_w: float = draw_area.size.x
	var map_h: float = draw_area.size.y
	var map_pos: Vector2 = _world_to_map(world_pos)
	if map_pos.x < 0 or map_pos.x > map_w or map_pos.y < 0 or map_pos.y > map_h:
		return
	var r: float = 5.0
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(map_pos.x, map_pos.y - r),
		Vector2(map_pos.x + r, map_pos.y),
		Vector2(map_pos.x, map_pos.y + r),
		Vector2(map_pos.x - r, map_pos.y),
	])
	draw_area.draw_colored_polygon(points, Color(0.4, 0.7, 1.0, 0.9))
	var dest_name: String = ZoneDatabase.get_zone_name(dest_zone_id)
	draw_area.draw_string(
		ThemeDB.fallback_font,
		Vector2(map_pos.x + 8, map_pos.y + 4),
		dest_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1, 9,
		Color(0.5, 0.8, 1.0, 0.8)
	)
