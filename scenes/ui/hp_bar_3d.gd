extends Node3D
## 3D HP bar using Sprite3D with SubViewport for rendering above entities.

var _viewport: SubViewport
var _sprite: Sprite3D
var _bar_bg: ColorRect
var _bar_fill: ColorRect

const BAR_WIDTH: int = 80
const BAR_HEIGHT: int = 8

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(BAR_WIDTH + 4, BAR_HEIGHT + 4)
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	# Background
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	_bar_bg.position = Vector2(2, 2)
	_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_viewport.add_child(_bar_bg)

	# Fill
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.1, 0.8, 0.1, 1.0)
	_bar_fill.position = Vector2(2, 2)
	_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_viewport.add_child(_bar_fill)

	# Sprite3D
	_sprite = Sprite3D.new()
	_sprite.pixel_size = 0.01
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.transparent = true
	_sprite.texture = _viewport.get_texture()
	add_child(_sprite)

func update_bar(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	var ratio := clampf(float(current) / float(maximum), 0.0, 1.0)
	_bar_fill.size.x = BAR_WIDTH * ratio

	# Color: green -> yellow -> red
	if ratio > 0.5:
		_bar_fill.color = Color(0.1, 0.8, 0.1)
	elif ratio > 0.25:
		_bar_fill.color = Color(0.9, 0.8, 0.1)
	else:
		_bar_fill.color = Color(0.9, 0.1, 0.1)
