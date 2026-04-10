class_name UIHelper
extends RefCounted
## Shared UI utilities for panel styles and common UI setup patterns.

# Shared color constants — modern minimal palette
const COLOR_ACCENT := Color(0.65, 0.78, 0.95)
const COLOR_HEADER := Color(0.9, 0.9, 0.92)
const COLOR_EQUIPMENT := Color(0.65, 0.78, 0.95)
const COLOR_DISABLED := Color(0.4, 0.4, 0.42)
const COLOR_TEXT := Color(0.82, 0.82, 0.84)
const COLOR_TEXT_DIM := Color(0.5, 0.5, 0.53)
const COLOR_BORDER := Color(0.28, 0.28, 0.32, 0.5)
const COLOR_DIVIDER := Color(0.3, 0.3, 0.35, 0.3)
const COLOR_BG := Color(0.08, 0.08, 0.1, 0.94)
# Legacy alias
const COLOR_GOLD := COLOR_ACCENT

const GAME_FONT: FontFile = preload("res://assets/fonts/Marcellus-Regular.ttf")
const GAME_FONT_DISPLAY: FontFile = preload("res://assets/fonts/Philosopher-Bold.ttf")

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

static func create_panel_style(bg_color: Color = COLOR_BG, border_color: Color = COLOR_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	set_border_width(style, 1)
	set_corner_radius(style, 6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

## Creates a TextureRect icon from a texture path.
## Returns null if the path is empty or the resource does not exist.
static func create_icon(texture_path: String, size: Vector2 = Vector2(16, 16), filter: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_NEAREST) -> TextureRect:
	if texture_path.is_empty():
		return null
	if not ResourceLoader.exists(texture_path):
		return null
	var icon := TextureRect.new()
	icon.texture = load(texture_path) as Texture2D
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = filter
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

## Creates a Label with the given text, font size, color, and horizontal alignment.
static func create_label(text: String, font_size: int = 14, color: Color = Color.WHITE, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	return label

## Creates a StyleBoxFlat with background color, border, and corner radius.
static func create_style_box(bg_color: Color, border_color: Color = Color.TRANSPARENT, corner_radius: int = 4, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	set_corner_radius(style, corner_radius)
	set_border_width(style, border_width)
	return style
