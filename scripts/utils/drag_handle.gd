class_name DragHandle
extends PanelContainer
## Reusable draggable title bar for UI panels.
## Attach to a PanelContainer to make it draggable by its title bar.

signal close_pressed

var _target: Control
var _title_label: Label
var _dragging: bool = false
var _drag_offset: Vector2

func setup(target: Control, title_text: String, extra_right: Control = null) -> void:
	_target = target

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	mouse_default_cursor_shape = Control.CURSOR_MOVE

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	# Title
	_title_label = Label.new()
	_title_label.text = title_text
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", UIHelper.COLOR_HEADER)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_title_label)

	# Optional extra control on the right
	if extra_right:
		extra_right.reparent(hbox)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "\u2715"
	close_btn.custom_minimum_size = Vector2(26, 26)
	close_btn.add_theme_font_size_override("font_size", 13)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.22, 0.6)
	UIHelper.set_corner_radius(btn_style, 4)
	btn_style.content_margin_left = 4
	btn_style.content_margin_right = 4
	btn_style.content_margin_top = 2
	btn_style.content_margin_bottom = 2
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.8, 0.25, 0.25, 0.8)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_stylebox_override("hover", btn_hover)
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
	close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	close_btn.pressed.connect(func(): close_pressed.emit())
	hbox.add_child(close_btn)

func set_title(text: String) -> void:
	if _title_label:
		_title_label.text = text

func _gui_input(event: InputEvent) -> void:
	if not _target:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_offset = _target.position - mb.global_position
			else:
				_dragging = false
			accept_event()

	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var new_pos: Vector2 = motion.global_position + _drag_offset
		var vp_size := get_viewport_rect().size
		var panel_size := _target.size
		new_pos.x = clampf(new_pos.x, 0.0, vp_size.x - panel_size.x)
		new_pos.y = clampf(new_pos.y, 0.0, vp_size.y - panel_size.y)
		_target.position = new_pos
		accept_event()
