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

const COLOR_ACTIVE := Color(0.788, 0.659, 0.298)  # #c9a84c
const COLOR_INACTIVE := Color(0.533, 0.533, 0.533)  # #888888


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	var ui: Dictionary = UIHelper.create_titled_panel("Settings", Vector2(400, 300), close)
	_panel = ui["panel"]
	add_child(_panel)
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
		btn.add_theme_font_size_override("font_size", 14)
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
		"game":
			_build_game_content()


func _build_audio_content() -> void:
	_master_slider = _add_volume_row(_content_area, "Master", "Master")
	_sfx_slider = _add_volume_row(_content_area, "SFX", "SFX")
	_ambient_slider = _add_volume_row(_content_area, "Ambient", "Ambient")


func _build_game_content() -> void:
	var quit_btn: Button = Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.pressed.connect(_on_quit_pressed)
	_content_area.add_child(quit_btn)


func _add_volume_row(parent: Control, label_text: String, bus_name: String) -> HSlider:
	var hbox: HBoxContainer = HBoxContainer.new()
	var label: Label = UIHelper.create_label(label_text, 14, Color.WHITE)
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_settings"):
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle()
		get_viewport().set_input_as_handled()


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


func set_player(p: Node) -> void:
	_player = p


func is_open() -> bool:
	return _is_open
