class_name UIHelper
extends RefCounted
## Shared UI utilities for panel styles and common UI setup patterns.

# Shared color constants
const COLOR_GOLD := Color(1, 0.85, 0.3)
const COLOR_HEADER := Color(1, 0.9, 0.6)
const COLOR_EQUIPMENT := Color(0.7, 0.85, 1.0)
const COLOR_DISABLED := Color(0.5, 0.5, 0.5)

static func center_panel(panel: PanelContainer) -> void:
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	var vp_size := panel.get_viewport_rect().size
	panel.position = (vp_size - panel.custom_minimum_size) * 0.5

static func set_corner_radius(style: StyleBoxFlat, radius: int) -> void:
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

static func set_border_width(style: StyleBoxFlat, width: int) -> void:
	style.border_width_left = width
	style.border_width_right = width
	style.border_width_top = width
	style.border_width_bottom = width

## Creates a standard titled draggable panel.
## Returns {"panel": PanelContainer, "vbox": VBoxContainer, "drag_handle": DragHandle}.
## The caller is responsible for add_child(result.panel) and populating result.vbox.
static func create_titled_panel(title: String, size: Vector2, close_callback: Callable) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.add_theme_stylebox_override("panel", create_panel_style())

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var drag_handle := DragHandle.new()
	drag_handle.setup(panel, title)
	drag_handle.close_pressed.connect(close_callback)
	vbox.add_child(drag_handle)

	return {"panel": panel, "vbox": vbox, "drag_handle": drag_handle}

static var _panel_texture: Texture2D = null

static func create_panel_style(_bg_color: Color = Color.BLACK, _border_color: Color = Color.BLACK) -> StyleBoxTexture:
	if _panel_texture == null:
		_panel_texture = load("res://assets/textures/ui/panel/frame.png")
	var style := StyleBoxTexture.new()
	style.texture = _panel_texture
	var margin: float = 6.0
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
