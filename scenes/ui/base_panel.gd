extends Control
## GameMenu "Base" tab — resource overview, device list, grid status, needs detail.

const UIHelper = preload("res://scripts/utils/ui_helper.gd")
const DeviceDatabase = preload("res://scripts/data/device_database.gd")

var _player: Node
var _content: VBoxContainer
var _resource_labels: Dictionary = {}
var _device_rows: Dictionary = {}
var _grid_label: Label
var _needs_labels: Dictionary = {}
var _is_active: bool = false


func set_player(p: Node) -> void:
	_player = p


func build_content(container: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

	_build_resource_section()
	_build_divider()
	_build_device_section()
	_build_divider()
	_build_grid_section()
	_build_divider()
	_build_needs_section()


func _build_divider() -> void:
	var div := ColorRect.new()
	div.color = Color(0.3, 0.3, 0.35, 0.3)
	div.custom_minimum_size = Vector2(0, 1)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(div)


# --- Resource Overview ---

func _build_resource_section() -> void:
	var header := UIHelper.create_label("RESOURCES", 16, UIHelper.COLOR_GOLD)
	_content.add_child(header)

	for res_type in ["electricity", "water", "fuel"]:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		_content.add_child(hbox)

		var name_label := UIHelper.create_label(res_type.capitalize(), 14, Color(0.7, 0.7, 0.72))
		name_label.custom_minimum_size.x = 100.0
		hbox.add_child(name_label)

		var value_label := UIHelper.create_label("0.0 / 0.0", 14, Color(0.82, 0.82, 0.84))
		hbox.add_child(value_label)
		_resource_labels[res_type] = value_label


# --- Device List ---

func _build_device_section() -> void:
	var header := UIHelper.create_label("DEVICES", 16, UIHelper.COLOR_GOLD)
	_content.add_child(header)

	# Populated dynamically in refresh()


func _refresh_device_list() -> void:
	# Remove old device rows
	for row_id in _device_rows:
		var row: Control = _device_rows[row_id]
		if is_instance_valid(row):
			row.queue_free()
	_device_rows.clear()

	var devices: Dictionary = ResourceManager.get_all_devices()
	if devices.is_empty():
		var empty_label := UIHelper.create_label("  No devices installed", 13, Color(0.5, 0.5, 0.53))
		empty_label.name = "NoDevicesLabel"
		_content.add_child(empty_label)
		_device_rows["_empty"] = empty_label
		return

	for device_id in devices:
		var device = devices[device_id]
		var def: Dictionary = DeviceDatabase.get_device(device.type)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var name_label := UIHelper.create_label(def.get("name", device.type), 13, Color(0.7, 0.7, 0.72))
		name_label.custom_minimum_size.x = 160.0
		hbox.add_child(name_label)

		var status_text: String
		var status_color: Color
		if device.shutdown:
			status_text = "SHUTDOWN"
			status_color = Color(1.0, 0.3, 0.3)
		elif not device.active:
			status_text = "OFF"
			status_color = Color(0.5, 0.5, 0.5)
		else:
			status_text = "Running"
			status_color = Color(0.4, 0.8, 0.4)

		var status_label := UIHelper.create_label(status_text, 13, status_color)
		hbox.add_child(status_label)

		_content.add_child(hbox)
		_device_rows[device_id] = hbox


# --- Grid Status ---

func _build_grid_section() -> void:
	var header := UIHelper.create_label("GRID", 16, UIHelper.COLOR_GOLD)
	_content.add_child(header)

	_grid_label = UIHelper.create_label("Connected", 14, Color(0.4, 0.8, 0.4))
	_content.add_child(_grid_label)


func _refresh_grid() -> void:
	if not _grid_label:
		return
	if ResourceManager.grid_failed:
		_grid_label.text = "FAILED (permanent)"
		_grid_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif not ResourceManager.is_grid_active():
		_grid_label.text = "Outage"
		_grid_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	else:
		var cost_text: String = "Cost: x%.1f" % ResourceManager.grid_cost_multiplier
		_grid_label.text = "Connected  (%s)" % cost_text
		_grid_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))


# --- Needs Detail ---

func _build_needs_section() -> void:
	var header := UIHelper.create_label("SURVIVAL NEEDS", 16, UIHelper.COLOR_GOLD)
	_content.add_child(header)

	var need_info: Dictionary = {
		"hunger": {"label": "Hunger", "tip": "Eat food to restore"},
		"thirst": {"label": "Thirst", "tip": "Drink water to restore"},
		"hygiene": {"label": "Hygiene", "tip": "Shower or brush teeth"},
		"health": {"label": "Health", "tip": "Rest with full hunger/thirst to heal"},
	}

	for need_type in ["hunger", "thirst", "hygiene", "health"]:
		var info: Dictionary = need_info[need_type]
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		_content.add_child(hbox)

		var name_label := UIHelper.create_label(info["label"], 14, Color(0.7, 0.7, 0.72))
		name_label.custom_minimum_size.x = 80.0
		hbox.add_child(name_label)

		var value_label := UIHelper.create_label("100", 14, Color(0.82, 0.82, 0.84))
		value_label.custom_minimum_size.x = 40.0
		hbox.add_child(value_label)
		_needs_labels[need_type] = value_label

		var tip_label := UIHelper.create_label(info["tip"], 12, Color(0.45, 0.45, 0.48))
		hbox.add_child(tip_label)


# --- Refresh ---

func refresh() -> void:
	_refresh_resources()
	_refresh_device_list()
	_refresh_grid()
	_refresh_needs()


func _refresh_resources() -> void:
	for res_type in ["electricity", "water", "fuel"]:
		var total: float = ResourceManager.get_resource_total(res_type)
		var cap: float = ResourceManager.get_resource_capacity(res_type)
		if _resource_labels.has(res_type):
			_resource_labels[res_type].text = "%.1f / %.1f" % [total, cap]


func _refresh_needs() -> void:
	if not _player:
		return
	var needs_comp: Node = _player.get_node_or_null("NeedsComponent")
	if not needs_comp:
		return
	var needs_map: Dictionary = {
		"hunger": needs_comp.hunger,
		"thirst": needs_comp.thirst,
		"hygiene": needs_comp.hygiene,
		"health": needs_comp.health,
	}
	for need_type in needs_map:
		if _needs_labels.has(need_type):
			var value: float = needs_map[need_type]
			_needs_labels[need_type].text = "%d" % int(value)
			var color: Color
			if value > 75.0:
				color = Color(0.4, 0.8, 0.4)
			elif value > 50.0:
				color = Color(0.9, 0.8, 0.2)
			elif value > 25.0:
				color = Color(0.9, 0.5, 0.1)
			else:
				color = Color(1.0, 0.2, 0.2)
			_needs_labels[need_type].add_theme_color_override("font_color", color)


func set_active(is_active: bool) -> void:
	_is_active = is_active
	if is_active:
		refresh()
