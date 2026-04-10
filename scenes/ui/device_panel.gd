extends Control
## Popup panel for interacting with a base device or storage container.
## Shows status, rates, fill level, and on/off toggle (devices only).

const UIHelper = preload("res://scripts/utils/ui_helper.gd")
const DeviceDatabase = preload("res://scripts/data/device_database.gd")

var _panel: PanelContainer
var _vbox: VBoxContainer
var _device_id: String = ""
var _is_device: bool = false  # true = device, false = container
var _status_label: Label
var _production_label: Label
var _consumption_label: Label
var _fill_label: Label
var _toggle_btn: Button
var _is_open: bool = false

const PANEL_SIZE := Vector2(340, 260)


func setup(device_id: String) -> void:
	_device_id = device_id
	_is_device = ResourceManager.get_device(_device_id) != null
	_build_panel()
	visible = false


func _build_panel() -> void:
	var def: Dictionary
	var title: String

	if _is_device:
		var device = ResourceManager.get_device(_device_id)
		def = DeviceDatabase.get_device(device.type)
		title = def.get("name", device.type)
	else:
		var container = ResourceManager.get_container(_device_id)
		if not container:
			return
		def = DeviceDatabase.get_device(container.type)
		title = def.get("name", container.type)

	var result: Dictionary = UIHelper.create_titled_panel(title, PANEL_SIZE, _close)
	_panel = result["panel"]
	_vbox = result["vbox"]
	_vbox.add_theme_constant_override("separation", 8)

	if _is_device:
		_build_device_content()
	else:
		_build_container_content()

	add_child(_panel)
	UIHelper.center_panel(_panel)


func _build_device_content() -> void:
	var device = ResourceManager.get_device(_device_id)

	# Status
	var status_hbox := HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(status_hbox)
	status_hbox.add_child(UIHelper.create_label("Status:", 14, Color(0.5, 0.5, 0.53)))
	_status_label = UIHelper.create_label("Running", 14, Color(0.4, 0.8, 0.4))
	status_hbox.add_child(_status_label)

	# Production
	if not device.produces.is_empty():
		var prod_hbox := HBoxContainer.new()
		prod_hbox.add_theme_constant_override("separation", 8)
		_vbox.add_child(prod_hbox)
		prod_hbox.add_child(UIHelper.create_label("Produces:", 14, Color(0.5, 0.5, 0.53)))
		_production_label = UIHelper.create_label("", 14, Color(0.4, 0.8, 0.4))
		prod_hbox.add_child(_production_label)

	# Consumption
	if not device.consumes.is_empty():
		var cons_hbox := HBoxContainer.new()
		cons_hbox.add_theme_constant_override("separation", 8)
		_vbox.add_child(cons_hbox)
		cons_hbox.add_child(UIHelper.create_label("Consumes:", 14, Color(0.5, 0.5, 0.53)))
		_consumption_label = UIHelper.create_label("", 14, Color(0.9, 0.45, 0.35))
		cons_hbox.add_child(_consumption_label)

	# Separator
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.35, 0.3)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(sep)

	# Toggle button
	_toggle_btn = Button.new()
	_toggle_btn.custom_minimum_size = Vector2(120, 36)
	_toggle_btn.add_theme_font_override("font", UIHelper.GAME_FONT_DISPLAY)
	_toggle_btn.add_theme_font_size_override("font_size", 16)
	_toggle_btn.pressed.connect(_on_toggle)
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_child(_toggle_btn)
	_vbox.add_child(btn_container)


func _build_container_content() -> void:
	# Fill level
	var fill_hbox := HBoxContainer.new()
	fill_hbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(fill_hbox)
	fill_hbox.add_child(UIHelper.create_label("Stored:", 14, Color(0.5, 0.5, 0.53)))
	_fill_label = UIHelper.create_label("", 16, UIHelper.COLOR_GOLD)
	fill_hbox.add_child(_fill_label)

	# Status
	var status_hbox := HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(status_hbox)
	status_hbox.add_child(UIHelper.create_label("Status:", 14, Color(0.5, 0.5, 0.53)))
	_status_label = UIHelper.create_label("", 14, Color(0.4, 0.8, 0.4))
	status_hbox.add_child(_status_label)


func open() -> void:
	_refresh()
	visible = true
	_is_open = true
	AudioManager.play_ui_sfx("ui_panel_open")


func _close() -> void:
	visible = false
	_is_open = false
	AudioManager.play_ui_sfx("ui_panel_close")


func is_open() -> bool:
	return _is_open


func _on_toggle() -> void:
	var device = ResourceManager.get_device(_device_id)
	if device:
		ResourceManager.set_device_active(_device_id, not device.active)
		_refresh()


func _refresh() -> void:
	if _is_device:
		_refresh_device()
	else:
		_refresh_container()


func _refresh_device() -> void:
	var device = ResourceManager.get_device(_device_id)
	if not device:
		return

	if device.shutdown:
		_status_label.text = "SHUTDOWN (no resource)"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif not device.active:
		_status_label.text = "OFF"
		_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		_status_label.text = "Running"
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))

	if _production_label:
		var parts: PackedStringArray = []
		var hour: int = int(TimeManager.get_game_hour())
		var effective: Dictionary = device.get_effective_production(hour)
		for res_type in effective:
			var rate: float = effective[res_type]
			parts.append("%.1f %s/hr" % [rate, _get_unit(res_type)])
		_production_label.text = ", ".join(parts) if not parts.is_empty() else "None"

	if _consumption_label:
		var parts: PackedStringArray = []
		for res_type in device.consumes:
			var rate: float = device.consumes[res_type]
			parts.append("%.1f %s/hr" % [rate, _get_unit(res_type)])
		_consumption_label.text = ", ".join(parts) if not parts.is_empty() else "None"

	if _toggle_btn:
		_toggle_btn.text = "Turn OFF" if device.active else "Turn ON"


func _refresh_container() -> void:
	var container = ResourceManager.get_container(_device_id)
	if not container:
		return

	var unit: String = _get_unit(container.resource_type)
	_fill_label.text = "%.1f / %.1f %s" % [container.current, container.capacity, unit]

	var pct: float = container.get_fill_percent()
	if pct > 0.5:
		_status_label.text = "Good"
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	elif pct > 0.2:
		_status_label.text = "Low"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	elif pct > 0.0:
		_status_label.text = "Critical"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		_status_label.text = "Empty"
		_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


func _get_unit(resource_type: String) -> String:
	match resource_type:
		"electricity":
			return "kWh"
		"water":
			return "L"
		"fuel":
			return "L"
	return ""


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_close()
		get_viewport().set_input_as_handled()
