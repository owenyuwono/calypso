extends Control
## Toggle button bar for Debug, Status, and Skills panels.
## Anchored top-right below the minimap.

var debug_panel: Control
var status_panel: Control
var skill_panel: Control
var chat_input: Control

var _buttons: Dictionary = {}  # key -> Button
var _hbox: HBoxContainer

const BUTTON_DEFS: Array = [
	{"key": "debug", "label": "Debug", "hint": "D"},
	{"key": "status", "label": "Status", "hint": "C"},
	{"key": "skills", "label": "Skills", "hint": "S"},
]

func _ready() -> void:
	# Anchor top-right, below minimap
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -200
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

func _process(_delta: float) -> void:
	var chatting: bool = chat_input != null and chat_input.is_open()

	for key in _buttons:
		var btn: Button = _buttons[key]
		btn.disabled = chatting

		# Update visual to reflect panel open state
		var panel_open := _is_panel_open(key)
		if panel_open and not chatting:
			# Apply gold highlight via override
			var active_style := btn.get_theme_stylebox("pressed")
			btn.add_theme_stylebox_override("normal", active_style)
		else:
			# Restore default normal style
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

func _on_button_pressed(key: String) -> void:
	var panel := _get_panel(key)
	if panel and panel.has_method("toggle"):
		panel.toggle()

func _get_panel(key: String) -> Control:
	match key:
		"debug": return debug_panel
		"status": return status_panel
		"skills": return skill_panel
	return null

func _is_panel_open(key: String) -> bool:
	var panel := _get_panel(key)
	if panel and panel.has_method("is_open"):
		return panel.is_open()
	return false
