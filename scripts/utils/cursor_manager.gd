extends RefCounted
## Procedural fantasy cursor manager with contextual icons.
## Generates 32x32 cursor textures: default (gauntlet), attack (sword), talk (bubble), move (hand).

var _cursors: Dictionary = {}
var _current_type: String = ""

func _init() -> void:
	_cursors["default"] = _create_gauntlet_cursor()
	_cursors["attack"] = _create_sword_cursor()
	_cursors["talk"] = _create_talk_cursor()
	_cursors["move"] = _create_move_cursor()
	set_cursor("default")

func set_cursor(type: String) -> void:
	if type == _current_type:
		return
	_current_type = type
	var tex: ImageTexture = _cursors.get(type, _cursors["default"])
	var hotspot := Vector2(3, 1) if type == "default" else Vector2(5, 3) if type == "attack" else Vector2(16, 16)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hotspot)

func reset() -> void:
	_current_type = ""
	set_cursor("default")

# --- Drawing helpers ---

func _set_pixel_safe(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)

func _draw_line_h(img: Image, x0: int, x1: int, y: int, color: Color) -> void:
	for x in range(x0, x1 + 1):
		_set_pixel_safe(img, x, y, color)

func _draw_line_v(img: Image, x: int, y0: int, y1: int, color: Color) -> void:
	for y in range(y0, y1 + 1):
		_set_pixel_safe(img, x, y, color)

func _fill_rect(img: Image, x0: int, y0: int, w: int, h: int, color: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_set_pixel_safe(img, x, y, color)

func _draw_circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				_set_pixel_safe(img, x, y, color)

func _draw_line_bresenham(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var x := x0
	var y := y0
	while true:
		_set_pixel_safe(img, x, y, color)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

func _make_texture(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

# --- Cursor generators ---

func _create_gauntlet_cursor() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var gold := Color(0.85, 0.65, 0.13, 1.0)
	var gold_light := Color(1.0, 0.85, 0.4, 1.0)
	var gold_dark := Color(0.6, 0.45, 0.1, 1.0)
	var outline := Color(0.2, 0.15, 0.05, 1.0)

	# Gauntlet pointer shape — pointing up-left
	# Outline
	var outline_pixels := [
		[3,0],[4,0],[5,0],
		[2,1],[6,1],
		[1,2],[7,2],
		[1,3],[8,3],
		[1,4],[9,4],
		[1,5],[10,5],
		[1,6],[10,6],
		[1,7],[10,7],
		[2,8],[10,8],
		[3,9],[10,9],
		[4,10],[11,10],
		[5,11],[12,11],
		[5,12],[13,12],
		[5,13],[14,13],
		[5,14],[14,14],
		[5,15],[14,15],
		[6,16],[13,16],
		[7,17],[12,17],
		[8,18],[11,18],
		[9,19],[10,19],
	]
	for p in outline_pixels:
		_set_pixel_safe(img, p[0], p[1], outline)

	# Fill body with gold
	for y in range(1, 9):
		var x_start := 3 if y < 2 else 2
		var x_end := 6 if y < 2 else (8 + y - 2)
		x_start = clampi(x_start, 2, 10)
		x_end = clampi(x_end, 3, 10)
		_draw_line_h(img, x_start, x_end, y, gold)

	# Lower gauntlet body
	for y in range(9, 19):
		var x_start := 4 + (y - 9) / 2
		var x_end := 10 + (y - 9) / 3
		x_start = clampi(x_start, 4, 9)
		x_end = clampi(x_end, 10, 14)
		_draw_line_h(img, x_start, x_end, y, gold)

	# Highlight on left edge
	_draw_line_v(img, 3, 1, 7, gold_light)
	_draw_line_v(img, 4, 1, 5, gold_light)

	# Shadow on right
	for y in range(5, 16):
		var x_r := 9 + (y - 5) / 3
		x_r = clampi(x_r, 9, 13)
		_set_pixel_safe(img, x_r, y, gold_dark)

	# Knuckle details
	_draw_line_h(img, 5, 9, 8, gold_dark)
	_draw_line_h(img, 6, 10, 10, gold_dark)

	return _make_texture(img)

func _create_sword_cursor() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var blade := Color(0.85, 0.88, 0.92, 1.0)
	var blade_edge := Color(0.95, 0.97, 1.0, 1.0)
	var guard := Color(0.85, 0.65, 0.13, 1.0)
	var grip := Color(0.45, 0.25, 0.1, 1.0)
	var outline := Color(0.15, 0.1, 0.05, 1.0)
	var pommel := Color(1.0, 0.3, 0.2, 1.0)

	# Blade — diagonal from top-left to center
	_draw_line_bresenham(img, 7, 3, 17, 13, outline)
	_draw_line_bresenham(img, 5, 5, 15, 15, outline)
	_draw_line_bresenham(img, 6, 3, 16, 13, blade_edge)
	_draw_line_bresenham(img, 6, 4, 16, 14, blade)
	_draw_line_bresenham(img, 5, 4, 15, 14, blade)
	# Tip
	_draw_line_bresenham(img, 4, 3, 6, 3, outline)
	_set_pixel_safe(img, 5, 3, blade_edge)

	# Crossguard
	_draw_line_bresenham(img, 20, 14, 13, 14, guard)
	_draw_line_bresenham(img, 20, 15, 13, 15, guard)
	_draw_line_bresenham(img, 19, 16, 14, 16, guard)

	# Grip
	_draw_line_bresenham(img, 17, 17, 21, 21, outline)
	_draw_line_bresenham(img, 16, 17, 20, 21, grip)
	_draw_line_bresenham(img, 15, 17, 19, 21, grip)
	_draw_line_bresenham(img, 14, 17, 18, 21, outline)

	# Pommel
	_draw_circle(img, 21, 23, 2, pommel)
	_draw_circle(img, 21, 23, 1, guard)

	return _make_texture(img)

func _create_talk_cursor() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var bubble := Color(1.0, 1.0, 1.0, 0.95)
	var outline := Color(0.2, 0.3, 0.6, 1.0)
	var dot_color := Color(0.3, 0.5, 1.0, 1.0)

	# Speech bubble — rounded rect with tail
	# Outline
	_draw_line_h(img, 8, 24, 5, outline)
	_draw_line_h(img, 8, 24, 19, outline)
	_draw_line_h(img, 6, 7, 6, outline)
	_draw_line_h(img, 25, 26, 6, outline)
	_draw_line_h(img, 6, 7, 18, outline)
	_draw_line_h(img, 25, 26, 18, outline)
	_draw_line_v(img, 5, 7, 17, outline)
	_draw_line_v(img, 27, 7, 17, outline)

	# Fill
	_fill_rect(img, 6, 6, 22, 14, bubble)

	# Tail (bottom-left triangle)
	_draw_line_bresenham(img, 9, 19, 7, 24, outline)
	_draw_line_bresenham(img, 14, 19, 9, 24, outline)
	# Fill tail
	for y in range(20, 24):
		var progress := float(y - 19) / 5.0
		var x_left := 9 - int(progress * 2)
		var x_right := 14 - int(progress * 5)
		if x_left < x_right:
			_draw_line_h(img, x_left + 1, x_right, y, bubble)

	# Three dots (ellipsis)
	_draw_circle(img, 11, 12, 2, dot_color)
	_draw_circle(img, 16, 12, 2, dot_color)
	_draw_circle(img, 21, 12, 2, dot_color)

	return _make_texture(img)

func _create_move_cursor() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var skin := Color(0.95, 0.82, 0.65, 1.0)
	var outline := Color(0.4, 0.25, 0.1, 1.0)
	var shadow := Color(0.8, 0.65, 0.45, 1.0)

	# Open hand pointing up — palm with five fingers spread

	# Palm
	_fill_rect(img, 10, 14, 12, 10, skin)
	# Palm outline
	_draw_line_h(img, 10, 21, 13, outline)
	_draw_line_v(img, 9, 14, 23, outline)
	_draw_line_v(img, 22, 14, 23, outline)
	_draw_line_h(img, 10, 21, 24, outline)

	# Fingers (from left: pinky, ring, middle, index)
	# Pinky
	_fill_rect(img, 10, 7, 2, 7, skin)
	_draw_line_v(img, 9, 7, 13, outline)
	_draw_line_v(img, 12, 7, 13, outline)
	_draw_line_h(img, 10, 11, 6, outline)

	# Ring
	_fill_rect(img, 13, 5, 2, 9, skin)
	_draw_line_v(img, 12, 5, 13, outline)
	_draw_line_v(img, 15, 5, 13, outline)
	_draw_line_h(img, 13, 14, 4, outline)

	# Middle (tallest)
	_fill_rect(img, 16, 3, 2, 11, skin)
	_draw_line_v(img, 15, 3, 13, outline)
	_draw_line_v(img, 18, 3, 13, outline)
	_draw_line_h(img, 16, 17, 2, outline)

	# Index
	_fill_rect(img, 19, 5, 2, 9, skin)
	_draw_line_v(img, 18, 5, 13, outline)
	_draw_line_v(img, 21, 5, 13, outline)
	_draw_line_h(img, 19, 20, 4, outline)

	# Thumb (right side, angled out)
	_fill_rect(img, 22, 15, 3, 2, skin)
	_fill_rect(img, 24, 14, 2, 2, skin)
	_draw_line_h(img, 22, 25, 13, outline)
	_draw_line_h(img, 22, 25, 17, outline)
	_draw_line_v(img, 26, 13, 17, outline)

	# Palm shadow
	_draw_line_h(img, 10, 21, 15, shadow)
	_draw_line_h(img, 10, 21, 18, shadow)

	return _make_texture(img)
