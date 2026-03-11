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

static func create_panel_style(bg_color: Color = Color(0.1, 0.1, 0.15, 0.95), border_color: Color = Color(0.4, 0.35, 0.2)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	set_border_width(style, 2)
	set_corner_radius(style, 4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
