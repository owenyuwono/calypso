extends Node3D
## 3D HP bar using Sprite3D with SubViewport for rendering above entities.
## RO-style: thin bar with name label above, border, gradient highlight.

var _viewport: SubViewport
var _sprite: Sprite3D
var _bar_border: ColorRect
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _bar_highlight: ColorRect
var _name_label: Label
var _prev_ratio: float = -1.0

const BAR_WIDTH: int = 140
const BAR_HEIGHT: int = 10
const BORDER: int = 1
const LABEL_HEIGHT: int = 14
const LABEL_MARGIN: int = 2
# Total viewport height: label + margin + border + bar + border
const VIEWPORT_WIDTH: int = BAR_WIDTH + BORDER * 2
const VIEWPORT_HEIGHT: int = LABEL_HEIGHT + LABEL_MARGIN + BORDER * 2 + BAR_HEIGHT

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)

	# Name label above the bar
	_name_label = Label.new()
	_name_label.text = ""
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85))
	_name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.position = Vector2(0, 0)
	_name_label.size = Vector2(VIEWPORT_WIDTH, LABEL_HEIGHT)
	_viewport.add_child(_name_label)

	# Bar area starts after label + margin
	var bar_y: int = LABEL_HEIGHT + LABEL_MARGIN

	# 1px black border
	_bar_border = ColorRect.new()
	_bar_border.color = Color(0.0, 0.0, 0.0, 0.9)
	_bar_border.position = Vector2(0, bar_y)
	_bar_border.size = Vector2(VIEWPORT_WIDTH, BORDER * 2 + BAR_HEIGHT)
	_viewport.add_child(_bar_border)

	# Dark red-brown background inside border
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.15, 0.05, 0.05, 0.9)
	_bar_bg.position = Vector2(BORDER, bar_y + BORDER)
	_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_viewport.add_child(_bar_bg)

	# Fill (width updated on each update_bar call)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.2, 0.8, 0.2)
	_bar_fill.position = Vector2(BORDER, bar_y + BORDER)
	_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_viewport.add_child(_bar_fill)

	# Gradient highlight: top half of the fill area, semi-transparent white
	_bar_highlight = ColorRect.new()
	_bar_highlight.color = Color(1.0, 1.0, 1.0, 0.2)
	_bar_highlight.position = Vector2(BORDER, bar_y + BORDER)
	_bar_highlight.size = Vector2(BAR_WIDTH, BAR_HEIGHT / 2)
	_viewport.add_child(_bar_highlight)

	# Sprite3D
	_sprite = Sprite3D.new()
	_sprite.pixel_size = 0.01
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.transparent = true
	_sprite.texture = _viewport.get_texture()
	add_child(_sprite)

func set_entity_name(entity_name: String) -> void:
	if _name_label:
		_name_label.text = entity_name
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func update_bar(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	var ratio := clampf(float(current) / float(maximum), 0.0, 1.0)
	if absf(ratio - _prev_ratio) < 0.001:
		return
	_prev_ratio = ratio

	var fill_width: int = int(BAR_WIDTH * ratio)
	_bar_fill.size.x = fill_width
	_bar_highlight.size.x = fill_width

	# Color: green -> yellow -> red (saturated RO-style)
	if ratio > 0.5:
		_bar_fill.color = Color(0.2, 0.8, 0.2)
	elif ratio > 0.25:
		_bar_fill.color = Color(0.9, 0.8, 0.1)
	else:
		_bar_fill.color = Color(0.85, 0.15, 0.15)

	# Trigger re-render only when values change
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
