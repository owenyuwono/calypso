extends Control
## Player HUD showing HP bar, XP bar, level, and gold with styled panel.

var _hp_bar: ProgressBar
var _hp_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _level_label: Label
var _gold_label: Label

const LevelData = preload("res://scripts/data/level_data.gd")
const UIHelper = preload("res://scripts/utils/ui_helper.gd")

func _ready() -> void:
	_build_ui()
	# Event-driven updates instead of _process polling
	GameEvents.entity_damaged.connect(func(id, _a, _b, _c): _refresh_if_player(id))
	GameEvents.entity_healed.connect(func(id, _a, _b): _refresh_if_player(id))
	GameEvents.xp_gained.connect(func(id, _a): _refresh_if_player(id))
	GameEvents.level_up.connect(_on_level_up)
	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_respawned.connect(func(id): _refresh_if_player(id))
	GameEvents.item_purchased.connect(func(id, _a, _b): _refresh_if_player(id))
	GameEvents.item_sold.connect(func(id, _a, _b): _refresh_if_player(id))
	GameEvents.item_looted.connect(func(id, _a, _b): _refresh_if_player(id))
	# Initial refresh
	_refresh_all()

func _build_ui() -> void:
	# Styled panel background
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(220, 0)
	panel.add_child(vbox)

	# Player name header
	var name_label := Label.new()
	name_label.text = "Player"
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)

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
	_gold_label.text = "100 G"
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	top_row.add_child(_gold_label)

	# HP bar
	var hp_row := HBoxContainer.new()
	vbox.add_child(hp_row)

	var hp_title := Label.new()
	hp_title.text = "HP"
	hp_title.add_theme_font_size_override("font_size", 13)
	hp_title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	hp_title.custom_minimum_size = Vector2(32, 0)
	hp_row.add_child(hp_title)

	_hp_bar = _create_styled_bar(
		Color(0.85, 0.15, 0.15), Color(0.3, 0.05, 0.05),
		Color(1.0, 0.4, 0.4), Color(0.1, 0, 0), 20
	)
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
	xp_title.text = "EXP"
	xp_title.add_theme_font_size_override("font_size", 11)
	xp_title.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	xp_title.custom_minimum_size = Vector2(32, 0)
	xp_row.add_child(xp_title)

	_xp_bar = _create_styled_bar(
		Color(0.2, 0.5, 0.9), Color(0.05, 0.1, 0.2),
		Color(0.5, 0.7, 1.0), Color(0, 0, 0.1), 14
	)
	xp_row.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.text = "0/100"
	_xp_label.add_theme_font_size_override("font_size", 12)
	_xp_label.custom_minimum_size = Vector2(60, 0)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_row.add_child(_xp_label)

func _create_styled_bar(fill_color: Color, bg_color: Color, fill_border: Color, bg_border: Color, bar_height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, bar_height)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.border_color = bg_border
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.border_color = fill_border
	fill_style.border_width_left = 1
	fill_style.border_width_right = 1
	fill_style.border_width_top = 1
	fill_style.border_width_bottom = 1
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill_style)

	return bar

func _format_number(n: int) -> String:
	var s := str(absi(n))
	var result := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			result += ","
		result += s[i]
	if n < 0:
		return "-" + result
	return result

func _refresh_all() -> void:
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
	_gold_label.text = "%s G" % _format_number(gold)

func _refresh_if_player(entity_id: String) -> void:
	if entity_id == "player":
		_refresh_all()

func _on_entity_died(entity_id: String, killer_id: String) -> void:
	if entity_id == "player" or killer_id == "player":
		_refresh_all()

func _on_level_up(entity_id: String, new_level: int) -> void:
	if entity_id != "player":
		return
	_refresh_all()
	# Spawn a floating "LEVEL UP!" text with outline and scale animation
	var label := Label.new()
	label.text = "LEVEL UP!"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.8, 0.4, 0.0))
	label.position = Vector2(120, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.3, 0.3)
	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", 40, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(label.queue_free)
