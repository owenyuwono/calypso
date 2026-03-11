class_name UIHelper
extends RefCounted
## Shared UI utilities for panel styles and common UI setup patterns.

static func create_panel_style(bg_color: Color = Color(0.1, 0.1, 0.15, 0.95), border_color: Color = Color(0.4, 0.35, 0.2)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func center_panel(panel: PanelContainer) -> void:
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	var vp_size := panel.get_viewport_rect().size
	panel.position = (vp_size - panel.custom_minimum_size) * 0.5

static func create_section_header(title: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	return label
