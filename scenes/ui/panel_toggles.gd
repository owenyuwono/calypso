extends Control
## Toggle button bar for Status and Skills panels.
## Anchored top-right below the minimap.

var status_panel: Control
var inventory_panel: Control
var skill_panel: Control
var proficiency_panel: Control
var chat_input: Control
var world_map_panel: Control

var _buttons: Dictionary = {}  # key -> Button
var _normal_styles: Dictionary = {}  # key -> StyleBoxFlat
var _active_styles: Dictionary = {}  # key -> StyleBoxFlat
var _hbox: HBoxContainer

const BUTTON_DEFS: Array = [
	{"key": "status", "label": "Status", "hint": "C"},
	{"key": "inventory", "label": "Inv", "hint": "I"},
	{"key": "skills", "label": "Skills", "hint": "S"},
	{"key": "map", "label": "Map", "hint": "W"},
]

func _ready() -> void:
	# Anchor top-right, below minimap
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -280
	offset_top = 220
	offset_right = -10
	offset_bottom = 260

	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 4)
	_hbox.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(_hbox)

	for def in BUTTON_DEFS:
		var btn := Button.new()
		btn.text = "%s [%s]" % [def["label"], def["hint"]]
		btn.custom_minimum_size = Vector2(58, 32)
		btn.add_theme_font_size_override("font_size", 11)

		# Normal style
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
		normal_style.border_color = Color(0.4, 0.35, 0.2)
		normal_style.set_border_width_all(1)
		normal_style.set_corner_radius_all(3)
		normal_style.content_margin_left = 4
		normal_style.content_margin_right = 4
		normal_style.content_margin_top = 2
		normal_style.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", normal_style)

		# Hover style
		var hover_style := normal_style.duplicate()
		hover_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
		btn.add_theme_stylebox_override("hover", hover_style)

		# Pressed/active style (gold highlight)
		var active_style := StyleBoxFlat.new()
		active_style.bg_color = Color(0.25, 0.2, 0.1, 0.95)
		active_style.border_color = Color(1, 0.85, 0.3)
		active_style.set_border_width_all(1)
		active_style.set_corner_radius_all(3)
		active_style.content_margin_left = 4
		active_style.content_margin_right = 4
		active_style.content_margin_top = 2
		active_style.content_margin_bottom = 2
		btn.add_theme_stylebox_override("pressed", active_style)

		# Disabled style
		var disabled_style := normal_style.duplicate()
		disabled_style.bg_color = Color(0.08, 0.08, 0.1, 0.7)
		disabled_style.border_color = Color(0.25, 0.22, 0.15)
		btn.add_theme_stylebox_override("disabled", disabled_style)
		btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))

		var key: String = def["key"]
		btn.pressed.connect(_on_button_pressed.bind(key))
		_hbox.add_child(btn)
		_buttons[key] = btn
		_normal_styles[key] = normal_style
		_active_styles[key] = active_style

	# Poll at low frequency instead of every frame
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(_update_button_states)
	add_child(timer)

func _update_button_states() -> void:
	var chatting: bool = chat_input != null and chat_input.is_open()

	for key in _buttons:
		var btn: Button = _buttons[key]
		btn.disabled = chatting

		# Toggle between cached style instances — no allocation
		var panel_open := _is_panel_open(key)
		if panel_open and not chatting:
			btn.add_theme_stylebox_override("normal", _active_styles[key])
		else:
			btn.add_theme_stylebox_override("normal", _normal_styles[key])

func _on_button_pressed(key: String) -> void:
	var panel := _get_panel(key)
	if panel and panel.has_method("toggle"):
		panel.toggle()

func _get_panel(key: String) -> Control:
	match key:
		"status": return status_panel
		"inventory": return inventory_panel
		"skills": return skill_panel
		"map": return world_map_panel
	return null

func _is_panel_open(key: String) -> bool:
	var panel := _get_panel(key)
	if panel and panel.has_method("is_open"):
		return panel.is_open()
	return false
