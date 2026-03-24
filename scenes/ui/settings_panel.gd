extends Node
## Settings panel — audio volume controls + quit game. Content builder for GameMenu.

var _player: Node
var _master_slider: HSlider
var _sfx_slider: HSlider
var _ambient_slider: HSlider
var _content_parent: Control


func set_player(p: Node) -> void:
	_player = p


func build_content(parent: Control) -> void:
	_content_parent = parent

	# --- Audio Section ---
	var audio_label: Label = UIHelper.create_label("Audio", 16, UIHelper.COLOR_HEADER)
	parent.add_child(audio_label)

	_master_slider = _add_volume_row(parent, "Master", "Master")
	_sfx_slider = _add_volume_row(parent, "SFX", "SFX")
	_ambient_slider = _add_volume_row(parent, "Ambient", "Ambient")

	# --- Separator ---
	var sep: HSeparator = HSeparator.new()
	parent.add_child(sep)

	# --- Quit Button ---
	var quit_btn: Button = Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.pressed.connect(_on_quit_pressed)
	parent.add_child(quit_btn)


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


func refresh() -> void:
	if not _content_parent or not _content_parent.visible:
		return


static func _percent_to_db(percent: float) -> float:
	if percent <= 0.0:
		return -80.0
	return linear_to_db(percent / 100.0)


static func _db_to_percent(db: float) -> float:
	if db <= -80.0:
		return 0.0
	return db_to_linear(db) * 100.0
