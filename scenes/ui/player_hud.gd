extends Control
## Player HUD showing HP bar, XP bar, level, and gold.

var _hp_bar: ProgressBar
var _hp_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _level_label: Label
var _gold_label: Label

const LevelData = preload("res://scripts/data/level_data.gd")

func _ready() -> void:
	_build_ui()
	GameEvents.level_up.connect(_on_level_up)

func _build_ui() -> void:
	# Main container at top-left
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16, 16)
	vbox.custom_minimum_size = Vector2(220, 0)
	add_child(vbox)

	# Level + Gold row
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	_level_label = Label.new()
	_level_label.text = "Lv. 1"
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	top_row.add_child(_level_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	_gold_label = Label.new()
	_gold_label.text = "Gold: 100"
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	top_row.add_child(_gold_label)

	# HP bar
	var hp_row := HBoxContainer.new()
	vbox.add_child(hp_row)

	var hp_title := Label.new()
	hp_title.text = "HP"
	hp_title.add_theme_font_size_override("font_size", 14)
	hp_title.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	hp_title.custom_minimum_size = Vector2(28, 0)
	hp_row.add_child(hp_title)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(150, 18)
	_hp_bar.show_percentage = false
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = Color(0.6, 0.1, 0.1)
	hp_style.corner_radius_top_left = 2
	hp_style.corner_radius_top_right = 2
	hp_style.corner_radius_bottom_left = 2
	hp_style.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("background", hp_style)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.9, 0.2, 0.2)
	hp_fill.corner_radius_top_left = 2
	hp_fill.corner_radius_top_right = 2
	hp_fill.corner_radius_bottom_left = 2
	hp_fill.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_row.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.text = "50/50"
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.custom_minimum_size = Vector2(60, 0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(_hp_label)

	# XP bar
	var xp_row := HBoxContainer.new()
	vbox.add_child(xp_row)

	var xp_title := Label.new()
	xp_title.text = "XP"
	xp_title.add_theme_font_size_override("font_size", 14)
	xp_title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	xp_title.custom_minimum_size = Vector2(28, 0)
	xp_row.add_child(xp_title)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(150, 12)
	_xp_bar.show_percentage = false
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var xp_style := StyleBoxFlat.new()
	xp_style.bg_color = Color(0.1, 0.15, 0.3)
	xp_style.corner_radius_top_left = 2
	xp_style.corner_radius_top_right = 2
	xp_style.corner_radius_bottom_left = 2
	xp_style.corner_radius_bottom_right = 2
	_xp_bar.add_theme_stylebox_override("background", xp_style)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.3, 0.6, 1.0)
	xp_fill.corner_radius_top_left = 2
	xp_fill.corner_radius_top_right = 2
	xp_fill.corner_radius_bottom_left = 2
	xp_fill.corner_radius_bottom_right = 2
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_row.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.text = "0/100"
	_xp_label.add_theme_font_size_override("font_size", 12)
	_xp_label.custom_minimum_size = Vector2(60, 0)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_row.add_child(_xp_label)

func _process(_delta: float) -> void:
	var data := WorldState.get_entity_data("player")
	if data.is_empty():
		return

	var hp: int = data.get("hp", 0)
	var max_hp: int = data.get("max_hp", 1)
	var xp: int = data.get("xp", 0)
	var level: int = data.get("level", 1)
	var gold: int = data.get("gold", 0)

	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d/%d" % [hp, max_hp]

	var xp_needed := LevelData.xp_to_next_level(level)
	_xp_bar.max_value = xp_needed
	_xp_bar.value = xp
	_xp_label.text = "%d/%d" % [xp, xp_needed]

	_level_label.text = "Lv. %d" % level
	_gold_label.text = "Gold: %d" % gold

func _on_level_up(entity_id: String, new_level: int) -> void:
	if entity_id != "player":
		return
	# Spawn a floating "LEVEL UP!" text
	var label := Label.new()
	label.text = "LEVEL UP!"
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	label.position = Vector2(120, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position:y", 40, 1.0).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tween.tween_callback(label.queue_free)
