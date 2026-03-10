extends Control
## Chat input bar at bottom-center of screen. Hidden by default.
## Press Enter to open, type message, Enter to send, Escape to cancel.

signal message_sent(text: String)

var _line_edit: LineEdit
var _panel: PanelContainer

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Anchor to bottom-left, directly under chat log
	anchors_preset = PRESET_BOTTOM_LEFT
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 10
	offset_right = 410
	offset_top = -50
	offset_bottom = -10

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "Type a message..."
	_line_edit.add_theme_color_override("font_color", Color.WHITE)
	_line_edit.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.4))
	_line_edit.add_theme_font_size_override("font_size", 16)
	_line_edit.text_submitted.connect(_on_text_submitted)
	_panel.add_child(_line_edit)

func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_line_edit.clear()
	_line_edit.grab_focus()

func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_edit.clear()
	_line_edit.release_focus()

func is_open() -> bool:
	return visible

func _on_text_submitted(text: String) -> void:
	var trimmed := text.strip_edges()
	if not trimmed.is_empty():
		message_sent.emit(trimmed)
	close()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
