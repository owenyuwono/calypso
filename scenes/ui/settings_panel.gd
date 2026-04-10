extends Control
## Settings panel — sidebar + content layout. Esc key toggle.

var _panel: PanelContainer
var _is_open: bool = false
var _player: Node
var _master_slider: HSlider
var _sfx_slider: HSlider
var _ambient_slider: HSlider

var _current_category: String = "audio"
var _content_area: VBoxContainer
var _sidebar_buttons: Dictionary = {}

# WASD navigation state
var _active: bool = false
var _nav_zone: String = "sidebar"
var _sidebar_idx: int = 0
var _content_idx: int = 0
var _content_items: Array = []
var _sidebar_keys: Array = ["audio", "game"]
var _quit_btn: Button
var _cursor_hand: TextureRect
var _slider_editing: bool = false

const COLOR_ACTIVE := Color(0.65, 0.78, 0.95)
const COLOR_INACTIVE := Color(0.45, 0.45, 0.48)
const COLOR_HIGHLIGHT_BORDER := Color(0.65, 0.78, 0.95, 0.5)


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	var ui: Dictionary = UIHelper.create_titled_panel("Settings", Vector2(400, 300), close)
	_panel = ui["panel"]
	add_child(_panel)
	ui["drag_handle"].queue_free()
	var vbox: VBoxContainer = ui["vbox"]

	# --- Body: sidebar + separator + content ---
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	vbox.add_child(hbox)

	# Sidebar
	var sidebar: VBoxContainer = _build_sidebar()
	hbox.add_child(sidebar)

	# Vertical separator
	var vsep: VSeparator = VSeparator.new()
	vsep.custom_minimum_size.x = 8
	hbox.add_child(vsep)

	# Content area
	_content_area = VBoxContainer.new()
	_content_area.add_theme_constant_override("separation", 8)
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_content_area)

	_show_category("audio")

	# Cursor hand icon
	_cursor_hand = TextureRect.new()
	var cursor_tex: Texture2D = load("res://assets/textures/ui/dialogue/cursor_hand.png") as Texture2D
	if cursor_tex:
		_cursor_hand.texture = cursor_tex
	_cursor_hand.custom_minimum_size = Vector2(24, 24)
	_cursor_hand.size = Vector2(24, 24)
	_cursor_hand.visible = false
	_cursor_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_hand.z_index = 10
	add_child(_cursor_hand)


func _build_sidebar() -> VBoxContainer:
	var sidebar: VBoxContainer = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 80
	sidebar.add_theme_constant_override("separation", 4)

	for category in ["audio", "game"]:
		var btn: Button = Button.new()
		btn.text = category.capitalize()
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_override("font", UIHelper.GAME_FONT)
		btn.add_theme_font_size_override("font_size", 21)
		btn.pressed.connect(_show_category.bind(category))
		sidebar.add_child(btn)
		_sidebar_buttons[category] = btn

	return sidebar


func _show_category(category: String) -> void:
	_current_category = category

	# Update sidebar button colors
	for cat: String in _sidebar_buttons:
		var btn: Button = _sidebar_buttons[cat]
		var color: Color = COLOR_ACTIVE if cat == category else COLOR_INACTIVE
		btn.add_theme_color_override("font_color", color)
		btn.add_theme_color_override("font_hover_color", color)
		btn.add_theme_color_override("font_pressed_color", color)
		btn.add_theme_color_override("font_focus_color", color)

	# Clear and rebuild content
	for child in _content_area.get_children():
		child.queue_free()

	match category:
		"audio":
			_build_audio_content()
			_content_items = [_master_slider, _sfx_slider, _ambient_slider]
		"game":
			_build_game_content()
			_content_items = [_quit_btn]

	_content_idx = 0
	if _active:
		call_deferred("_update_highlight")


func _build_audio_content() -> void:
	_master_slider = _add_volume_row(_content_area, "Master", "Master")
	_sfx_slider = _add_volume_row(_content_area, "SFX", "SFX")
	_ambient_slider = _add_volume_row(_content_area, "Ambient", "Ambient")


func _build_game_content() -> void:
	_quit_btn = Button.new()
	_quit_btn.text = "Quit Game"
	_quit_btn.pressed.connect(_on_quit_pressed)
	_content_area.add_child(_quit_btn)


func _add_volume_row(parent: Control, label_text: String, bus_name: String) -> HSlider:
	var hbox: HBoxContainer = HBoxContainer.new()
	var label: Label = UIHelper.create_label(label_text, 21, Color.WHITE)
	label.custom_minimum_size.x = 60
	hbox.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = _db_to_percent(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name)))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(val: float) -> void: _on_volume_changed(bus_name, val))
	hbox.add_child(slider)
	parent.add_child(hbox)
	return slider


func _on_volume_changed(bus_name: String, percent: float) -> void:
	var db: float = _percent_to_db(percent)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), db)


func _on_quit_pressed() -> void:
	get_tree().quit()


static func _percent_to_db(percent: float) -> float:
	if percent <= 0.0:
		return -80.0
	return linear_to_db(percent / 100.0)


static func _db_to_percent(db: float) -> float:
	if db <= -80.0:
		return 0.0
	return db_to_linear(db) * 100.0




func get_overlay_nodes() -> Array:
	var overlays: Array = []
	if _cursor_hand:
		overlays.append(_cursor_hand)
	return overlays


func set_active(active: bool) -> void:
	_active = active
	_slider_editing = false
	if active:
		_nav_zone = "sidebar"
		_sidebar_idx = _sidebar_keys.find(_current_category)
		if _sidebar_idx < 0:
			_sidebar_idx = 0
		_content_idx = 0
		call_deferred("_update_highlight")
	else:
		_clear_all_highlights()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if not event is InputEventKey or not event.pressed:
		return

	var keycode: int = event.keycode

	if _nav_zone == "sidebar":
		match keycode:
			KEY_W:
				_sidebar_idx = maxi(_sidebar_idx - 1, 0)
				_update_highlight()
				get_viewport().set_input_as_handled()
			KEY_S:
				_sidebar_idx = mini(_sidebar_idx + 1, _sidebar_keys.size() - 1)
				_update_highlight()
				get_viewport().set_input_as_handled()
			KEY_D:
				if _content_items.size() > 0:
					_nav_zone = "content"
					_content_idx = 0
					_update_highlight()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				var cat: String = _sidebar_keys[_sidebar_idx]
				if cat != _current_category:
					_show_category(cat)
				else:
					_update_highlight()
				get_viewport().set_input_as_handled()
	elif _nav_zone == "content":
		var item: Control = _content_items[_content_idx] if _content_idx < _content_items.size() else null
		if _slider_editing and item is HSlider:
			# In slider edit mode: A/D adjust, Escape exits
			match keycode:
				KEY_A:
					item.value = maxf(item.value - 5.0, item.min_value)
					get_viewport().set_input_as_handled()
				KEY_D:
					item.value = minf(item.value + 5.0, item.max_value)
					get_viewport().set_input_as_handled()
				KEY_ESCAPE:
					_slider_editing = false
					_update_highlight()
					get_viewport().set_input_as_handled()
			return
		match keycode:
			KEY_W:
				_content_idx = maxi(_content_idx - 1, 0)
				_update_highlight()
				get_viewport().set_input_as_handled()
			KEY_S:
				_content_idx = mini(_content_idx + 1, _content_items.size() - 1)
				_update_highlight()
				get_viewport().set_input_as_handled()
			KEY_A:
				_nav_zone = "sidebar"
				_update_highlight()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if item is HSlider:
					_slider_editing = true
					_update_highlight()
				elif item is Button:
					item.emit_signal("pressed")
				get_viewport().set_input_as_handled()


func _update_highlight() -> void:
	_clear_all_highlights()

	if _nav_zone == "sidebar":
		for i in _sidebar_keys.size():
			var cat: String = _sidebar_keys[i]
			var btn: Button = _sidebar_buttons[cat]
			var color: Color = COLOR_ACTIVE if i == _sidebar_idx else COLOR_INACTIVE
			btn.add_theme_color_override("font_color", color)
			btn.add_theme_color_override("font_hover_color", color)
			btn.add_theme_color_override("font_pressed_color", color)
			btn.add_theme_color_override("font_focus_color", color)
		# Position cursor hand next to focused sidebar button
		var focused_cat: String = _sidebar_keys[_sidebar_idx]
		var focused_btn: Button = _sidebar_buttons.get(focused_cat)
		if focused_btn:
			_position_cursor_hand(focused_btn)
	else:
		for cat: String in _sidebar_buttons:
			var btn: Button = _sidebar_buttons[cat]
			var color: Color = COLOR_ACTIVE if cat == _current_category else COLOR_INACTIVE
			btn.add_theme_color_override("font_color", color)
			btn.add_theme_color_override("font_hover_color", color)
			btn.add_theme_color_override("font_pressed_color", color)
			btn.add_theme_color_override("font_focus_color", color)

		if _content_idx < _content_items.size():
			var item: Control = _content_items[_content_idx]
			if item is HSlider:
				_highlight_slider(item, true)
				# Position cursor on the slider's parent row
				_position_cursor_hand(item.get_parent() if item.get_parent() else item)
			elif item is Button:
				_highlight_button(item, true)
				_position_cursor_hand(item)
		else:
			if _cursor_hand:
				_cursor_hand.visible = false


func _position_cursor_hand(cell: Control) -> void:
	if not _cursor_hand:
		return
	_cursor_hand.visible = true
	_cursor_hand.global_position = Vector2(
		cell.global_position.x - 24,
		cell.global_position.y + cell.size.y / 2.0 - 12.0
	)


func _clear_all_highlights() -> void:
	if _cursor_hand:
		_cursor_hand.visible = false
	# Restore sidebar to category-based colors
	for cat: String in _sidebar_buttons:
		var btn: Button = _sidebar_buttons[cat]
		var color: Color = COLOR_ACTIVE if cat == _current_category else COLOR_INACTIVE
		btn.add_theme_color_override("font_color", color)
		btn.add_theme_color_override("font_hover_color", color)
		btn.add_theme_color_override("font_pressed_color", color)
		btn.add_theme_color_override("font_focus_color", color)

	# Clear content highlights
	for item in _content_items:
		if not is_instance_valid(item):
			continue
		if item is HSlider:
			_highlight_slider(item, false)
		elif item is Button:
			_highlight_button(item, false)


func _highlight_slider(slider: HSlider, highlighted: bool) -> void:
	var row: Control = slider.get_parent()
	if not row:
		return
	var label: Label = null
	for child in row.get_children():
		if child is Label:
			label = child
			break
	if highlighted:
		var is_editing: bool = _slider_editing
		var color: Color = Color(1.0, 0.9, 0.3) if is_editing else COLOR_ACTIVE
		if label:
			label.add_theme_color_override("font_color", color)
			if is_editing:
				label.text = label.text.trim_suffix(" [A/D]") + " [A/D]"
		var grabber_style: StyleBoxFlat = StyleBoxFlat.new()
		grabber_style.bg_color = color
		grabber_style.corner_radius_top_left = 4
		grabber_style.corner_radius_top_right = 4
		grabber_style.corner_radius_bottom_left = 4
		grabber_style.corner_radius_bottom_right = 4
		grabber_style.content_margin_left = 6
		grabber_style.content_margin_right = 6
		grabber_style.content_margin_top = 6
		grabber_style.content_margin_bottom = 6
		slider.add_theme_stylebox_override("grabber_area", grabber_style)
		slider.add_theme_stylebox_override("grabber_area_highlight", grabber_style)
	else:
		if label:
			label.add_theme_color_override("font_color", Color.WHITE)
			label.text = label.text.trim_suffix(" [A/D]")
		slider.remove_theme_stylebox_override("grabber_area")
		slider.remove_theme_stylebox_override("grabber_area_highlight")


func _highlight_button(btn: Button, highlighted: bool) -> void:
	if highlighted:
		btn.add_theme_color_override("font_color", COLOR_ACTIVE)
		btn.add_theme_color_override("font_hover_color", COLOR_ACTIVE)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.788, 0.659, 0.298, 0.15)
		style.border_color = COLOR_HIGHLIGHT_BORDER
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", style)
	else:
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_color_override("font_hover_color")
		btn.remove_theme_stylebox_override("normal")


func toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		AudioManager.play_ui_sfx("ui_panel_open")
		UIHelper.center_panel(_panel)
	else:
		AudioManager.play_ui_sfx("ui_panel_close")


func close() -> void:
	_is_open = false
	visible = false
	AudioManager.play_ui_sfx("ui_panel_close")


func build_content(container: Control) -> void:
	if not _panel:
		_build_ui()
	if _panel and _panel.get_parent():
		_panel.get_parent().remove_child(_panel)
	container.add_child(_panel)


func set_player(p: Node) -> void:
	_player = p


func is_open() -> bool:
	return _is_open
