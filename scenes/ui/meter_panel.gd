extends Control
## Popup panel for utility meter interaction (electric box, water meter).
## Opened via player E-key interaction with a meter entity.

const UIHelper = preload("res://scripts/utils/ui_helper.gd")

var _panel: PanelContainer
var _vbox: VBoxContainer
var _meter_type: String = ""  # "electricity" or "water"
var _status_label: Label
var _usage_label: Label
var _cost_label: Label
var _grid_toggle_btn: Button
var _is_open: bool = false

const PANEL_SIZE := Vector2(320, 260)


func setup(meter_type: String) -> void:
	_meter_type = meter_type
	_build_panel()
	visible = false


func _build_panel() -> void:
	var title: String = "Electric Meter" if _meter_type == "electricity" else "Water Meter"
	var result: Dictionary = UIHelper.create_titled_panel(title, PANEL_SIZE, _close)
	_panel = result["panel"]
	_vbox = result["vbox"]

	_vbox.add_theme_constant_override("separation", 10)

	# Status
	var status_hbox := HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(status_hbox)
	var status_title := UIHelper.create_label("Grid Status:", 14, Color(0.5, 0.5, 0.53))
	status_hbox.add_child(status_title)
	_status_label = UIHelper.create_label("Connected", 14, Color(0.4, 0.8, 0.4))
	status_hbox.add_child(_status_label)

	# Usage rate
	var usage_hbox := HBoxContainer.new()
	usage_hbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(usage_hbox)
	var usage_title := UIHelper.create_label("Current Draw:", 14, Color(0.5, 0.5, 0.53))
	usage_hbox.add_child(usage_title)
	var unit: String = "kWh/hr" if _meter_type == "electricity" else "L/hr"
	_usage_label = UIHelper.create_label("0.0 %s" % unit, 14, UIHelper.COLOR_GOLD)
	usage_hbox.add_child(_usage_label)

	# Cost
	var cost_hbox := HBoxContainer.new()
	cost_hbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(cost_hbox)
	var cost_title := UIHelper.create_label("Hourly Cost:", 14, Color(0.5, 0.5, 0.53))
	cost_hbox.add_child(cost_title)
	_cost_label = UIHelper.create_label("0 gold", 14, UIHelper.COLOR_GOLD)
	cost_hbox.add_child(_cost_label)

	# Separator
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.35, 0.3)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(sep)

	# Storage info
	var storage_title := UIHelper.create_label("Storage:", 14, Color(0.5, 0.5, 0.53))
	_vbox.add_child(storage_title)
	# Will be populated in _refresh

	add_child(_panel)
	UIHelper.center_panel(_panel)


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


func _refresh() -> void:
	# Grid status
	if ResourceManager.grid_failed:
		_status_label.text = "FAILED"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif not ResourceManager.is_grid_active():
		_status_label.text = "Outage"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	else:
		_status_label.text = "Connected"
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))

	# Calculate current draw from all devices consuming this resource
	var total_draw: float = 0.0
	var devices: Dictionary = ResourceManager.get_all_devices()
	for device in devices.values():
		if device.is_running():
			total_draw += device.consumes.get(_meter_type, 0.0)

	var unit: String = "kWh/hr" if _meter_type == "electricity" else "L/hr"
	_usage_label.text = "%.1f %s" % [total_draw, unit]

	# Hourly cost
	var base_cost: int = ResourceManager.GRID_BASE_COST.get(_meter_type, 0)
	var hourly_cost: float = base_cost * ResourceManager.grid_cost_multiplier
	_cost_label.text = "%d gold/hr (x%.1f)" % [int(ceilf(hourly_cost)), ResourceManager.grid_cost_multiplier]

	# Storage totals
	var total: float = ResourceManager.get_resource_total(_meter_type)
	var capacity: float = ResourceManager.get_resource_capacity(_meter_type)
	if capacity > 0.0:
		_cost_label.text += "\nStored: %.1f / %.1f" % [total, capacity]


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_close()
		get_viewport().set_input_as_handled()
