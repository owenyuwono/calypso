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

	_build_compass_button()


func _build_compass_button() -> void:
	var compass_btn := Button.new()
	compass_btn.custom_minimum_size = Vector2(26, 26)
	compass_btn.tooltip_text = "World Map"
	compass_btn.mouse_filter = Control.MOUSE_FILTER_STOP

	# Load the map icon if it exists
	var icon_tex: Texture2D = load("res://assets/textures/ui/buttons/btn_map.png")
	if icon_tex:
		compass_btn.icon = icon_tex
		compass_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		compass_btn.texture_filter = TEXTURE_FILTER_NEAREST

	# Dark style with gold border to match the panel toggles aesthetic
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.1, 0.15, 0.92)
	normal_style.border_color = Color(0.55, 0.45, 0.2)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(3)
	normal_style.content_margin_left = 3
	normal_style.content_margin_right = 3
	normal_style.content_margin_top = 3
	normal_style.content_margin_bottom = 3
	compass_btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.18, 0.16, 0.22, 0.95)
	hover_style.border_color = Color(1.0, 0.85, 0.3)
	compass_btn.add_theme_stylebox_override("hover", hover_style)

	# Position at bottom-right inside the minimap area
	compass_btn.anchor_left = 1.0
	compass_btn.anchor_top = 1.0
	compass_btn.anchor_right = 1.0
	compass_btn.anchor_bottom = 1.0
	var btn_size: float = 26.0
	# offset_bottom anchors from bottom — 22px label area + 2px gap above it
	compass_btn.offset_left = -(btn_size + 4)
	compass_btn.offset_right = -4
	compass_btn.offset_top = -(22 + btn_size + 4)
	compass_btn.offset_bottom = -(22 + 4)

	compass_btn.pressed.connect(_on_compass_pressed)
	add_child(compass_btn)


func _on_compass_pressed() -> void:
	pass


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

	# Determine zone name from the currently loaded zone
	var loaded_zone: Node3D = ZoneManager.get_loaded_zone()
	if loaded_zone and "zone_id" in loaded_zone:
		_zone_label_text = ZoneDatabase.get_zone_name(loaded_zone.zone_id)
	else:
		_zone_label_text = ZoneDatabase.get_zone_name(ZoneDatabase.get_zone_at_position(_player_pos))

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

	# Portal markers for current zone
	var current_zone_id: String = ""
	if loaded_zone and "zone_id" in loaded_zone:
		current_zone_id = loaded_zone.zone_id

	var portals: Array = ZoneDatabase.get_portals(current_zone_id)
	for portal_def in portals:
		var rect: Rect2 = portal_def["source_rect"]
		var portal_world_pos: Vector3 = Vector3(
			rect.position.x + rect.size.x / 2.0,
			0,
			rect.position.y + rect.size.y / 2.0
		)
		if portal_world_pos.distance_to(_player_pos) > MAP_RADIUS:
			continue
		var world_offset: Vector3 = portal_world_pos - _player_pos
		var map_x: float = (world_offset.x / MAP_RADIUS) * (MAP_SIZE * 0.5)
		var map_z: float = (world_offset.z / MAP_RADIUS) * (MAP_SIZE * 0.5)
		if absf(map_x) > MAP_SIZE * 0.5 or absf(map_z) > MAP_SIZE * 0.5:
			continue
		var screen_pos: Vector2 = Vector2(
			BORDER + MAP_SIZE * 0.5 + map_x,
			BORDER + MAP_SIZE * 0.5 + map_z
		)
		_dots.append({
			"pos": screen_pos,
			"color": Color(0.4, 0.7, 1.0),
			"radius": 4.0,
			"is_player": false,
			"is_portal": true,
		})

func _draw() -> void:
	var map_rect := Rect2(0, 0, MAP_SIZE + BORDER * 2, MAP_SIZE + BORDER * 2)

	# Background
	draw_rect(map_rect, COLOR_BG)
	# Border
	draw_rect(map_rect, COLOR_BORDER, false, BORDER)

	# Zone hint rectangles — drawn from ZoneDatabase with per-zone colors
	for zone_id in ZoneDatabase.ZONES:
		var zone_data: Dictionary = ZoneDatabase.ZONES[zone_id]
		var bounds: Rect2 = zone_data["bounds"]
		var base_color: Color = zone_data["color"]
		var zone_color := Color(base_color.r, base_color.g, base_color.b, 0.15)
		_draw_zone_rect(bounds, zone_color)

	# Draw portal markers as diamonds (before entity dots)
	for dot in _dots:
		if not dot.get("is_portal", false):
			continue
		var p: Vector2 = dot.pos
		var r: float = dot.radius
		var points: PackedVector2Array = PackedVector2Array([
			Vector2(p.x, p.y - r),      # top
			Vector2(p.x + r, p.y),      # right
			Vector2(p.x, p.y + r),      # bottom
			Vector2(p.x - r, p.y),      # left
		])
		draw_colored_polygon(points, dot.color)

	# Draw non-player dots first, player last
	for dot in _dots:
		if dot.get("is_player", false):
			continue
		if dot.get("is_portal", false):
			continue
		draw_circle(dot.pos, dot.radius, dot.color)

	for dot in _dots:
		if dot.get("is_player", false):
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
