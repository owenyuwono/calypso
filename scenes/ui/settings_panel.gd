extends Control
## Settings panel — audio volume controls + quit game. Esc key toggle.

var _panel: PanelContainer
var _is_open: bool = false
var _player: Node
var _master_slider: HSlider
var _sfx_slider: HSlider
var _ambient_slider: HSlider


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	var ui: Dictionary = UIHelper.create_titled_panel("Settings", Vector2(320, 280), close)
	_panel = ui["panel"]
	add_child(_panel)
	var vbox: VBoxContainer = ui["vbox"]

	# --- Audio Section ---
	var audio_label: Label = UIHelper.create_label("Audio", 16, UIHelper.COLOR_HEADER)
	vbox.add_child(audio_label)

	_master_slider = _add_volume_row(vbox, "Master", "Master")
	_sfx_slider = _add_volume_row(vbox, "SFX", "SFX")
	_ambient_slider = _add_volume_row(vbox, "Ambient", "Ambient")

	# --- Separator ---
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# --- Quit Button ---
	var quit_btn: Button = Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)


func _add_volume_row(parent: Control, label_text: String, bus_name: String) -> HSlider:
	var hbox: HBoxContainer = HBoxContainer.new()
	var label: Label = UIHelper.create_label(label_text, 14, Color.WHITE)
	label.custom_minimum_size.x = 80
	hbox.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = _db_to_percent(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name)))
	slider.custom_minimum_size.x = 180
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
