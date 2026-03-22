class_name UIHelper
extends RefCounted
## Shared UI utilities for panel styles and common UI setup patterns.

# Shared color constants
const COLOR_GOLD := Color(1, 0.85, 0.3)
const COLOR_HEADER := Color(1, 0.9, 0.6)
const COLOR_EQUIPMENT := Color(0.7, 0.85, 1.0)
const COLOR_DISABLED := Color(0.5, 0.5, 0.5)

const GAME_FONT: FontFile = preload("res://assets/fonts/Cinzel-Regular.ttf")
const GAME_FONT_BOLD: FontFile = preload("res://assets/fonts/Cinzel-Bold.ttf")

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

## Creates a gold display row (coin icon + amount label).
## Returns {"container": HBoxContainer, "label": Label}.
static func create_gold_display(gold: int = 0) -> Dictionary:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var icon: TextureRect = create_icon("res://assets/textures/ui/stats/gold_coin.png", Vector2(16, 16))
	if icon != null:
		container.add_child(icon)

	var label: Label = create_label(str(gold), 14, COLOR_GOLD)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.add_child(label)

	return {"container": container, "label": label}
