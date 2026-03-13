extends Control
## Player HUD showing HP bar, proficiency XP bar, total level, and gold with styled panel.

var _hp_bar: ProgressBar
var _hp_label: Label
var _sta_bar: ProgressBar
var _sta_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _xp_title: Label
var _level_label: Label
var _gold_label: Label
var _player: Node
var _recent_skill_id: String = ""  # Most recently gained proficiency skill
var _time_label: Label
var _day_label: Label

const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")
const UIHelper = preload("res://scripts/utils/ui_helper.gd")

func _ready() -> void:
	_build_ui()
	# Event-driven updates instead of _process polling
	GameEvents.entity_damaged.connect(func(id, _a, _b, _c): _refresh_if_player(id))
	GameEvents.entity_healed.connect(func(id, _a, _b): _refresh_if_player(id))
	GameEvents.proficiency_xp_gained.connect(_on_proficiency_xp_gained)
	GameEvents.proficiency_level_up.connect(_on_proficiency_level_up)
	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_respawned.connect(func(id): _refresh_if_player(id))
	GameEvents.item_purchased.connect(func(id, _a, _b): _refresh_if_player(id))
	GameEvents.item_sold.connect(func(id, _a, _b): _refresh_if_player(id))
	GameEvents.item_looted.connect(func(id, _a, _b): _refresh_if_player(id))
	GameEvents.stamina_changed.connect(_on_stamina_changed)
	GameEvents.game_hour_changed.connect(_on_game_hour_changed)
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
	_level_label.text = "Total Lv: 13/130"
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	top_row.add_child(_level_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	_gold_label = Label.new()
	_gold_label.text = "100 G"
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
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

	# Stamina bar
	var sta_row := HBoxContainer.new()
	vbox.add_child(sta_row)

	var sta_title := Label.new()
	sta_title.text = "STA"
	sta_title.add_theme_font_size_override("font_size", 13)
	sta_title.add_theme_color_override("font_color", Color(0.2, 0.75, 0.5))
	sta_title.custom_minimum_size = Vector2(32, 0)
	sta_row.add_child(sta_title)

	_sta_bar = _create_styled_bar(
		Color(0.15, 0.65, 0.4), Color(0.05, 0.15, 0.1),
		Color(0.3, 0.8, 0.55), Color(0, 0.05, 0.02), 18
	)
	sta_row.add_child(_sta_bar)

	_sta_label = Label.new()
	_sta_label.text = "100/100"
	_sta_label.add_theme_font_size_override("font_size", 12)
	_sta_label.custom_minimum_size = Vector2(60, 0)
	_sta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sta_row.add_child(_sta_label)

	# XP bar
	var xp_row := HBoxContainer.new()
	vbox.add_child(xp_row)

	_xp_title = Label.new()
	_xp_title.text = "---"
	_xp_title.add_theme_font_size_override("font_size", 11)
	_xp_title.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	_xp_title.custom_minimum_size = Vector2(32, 0)
	xp_row.add_child(_xp_title)

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

	# Time panel — separate panel to the left of the minimap
	_build_time_panel()

func _build_time_panel() -> void:
	# Minimap is 184px wide, 10px from right edge.
	# Place this panel to the left of the minimap using absolute positioning.
	var viewport_w := get_viewport().get_visible_rect().size.x
	var minimap_left := viewport_w - 184.0 - 10.0  # minimap left edge
	var panel_w := 86.0
	var gap := 6.0

	var time_panel := PanelContainer.new()
	time_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	time_panel.position = Vector2(minimap_left - panel_w - gap, 10)
	add_child(time_panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(72, 0)
	time_panel.add_child(vbox)

	_time_label = Label.new()
	_time_label.text = "08:00"
	_time_label.add_theme_font_size_override("font_size", 18)
	_time_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_time_label)

	_day_label = Label.new()
	_day_label.text = "Day 1 - day"
	_day_label.add_theme_font_size_override("font_size", 11)
	_day_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_day_label)

func _create_styled_bar(fill_color: Color, bg_color: Color, fill_border: Color, bg_border: Color, bar_height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, bar_height)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.border_color = bg_border
	UIHelper.set_border_width(bg_style, 1)
	UIHelper.set_corner_radius(bg_style, 3)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.border_color = fill_border
	UIHelper.set_border_width(fill_style, 1)
	UIHelper.set_corner_radius(fill_style, 3)
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

func set_player(p: Node) -> void:
	_player = p
	_refresh_all()

func _refresh_all() -> void:
	if not _player:
		return
	var stats = _player.get_node("StatsComponent")
	var inv = _player.get_node("InventoryComponent")
	if not stats or not inv:
		return

	var hp: int = stats.hp
	var max_hp: int = stats.max_hp
	var gold: int = inv.gold

	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d/%d" % [hp, max_hp]

	var progression = _player.get_node_or_null("ProgressionComponent")
	var total_level: int = stats.level
	if progression and progression.has_method("get_total_level"):
		total_level = progression.get_total_level()
	_level_label.text = "Total Lv: %d/130" % total_level

	if _recent_skill_id != "" and progression and progression.has_method("get_proficiency_xp"):
		var prof_data: Dictionary = progression.get_proficiency_xp(_recent_skill_id)
		var skill_xp: int = prof_data.get("xp", 0)
		var xp_to_next: int = prof_data.get("xp_to_next", 1)
		var skill_data := ProficiencyDatabase.get_skill(_recent_skill_id)
		var skill_name: String = skill_data.get("name", _recent_skill_id)
		_xp_title.text = skill_name
		_xp_bar.max_value = xp_to_next
		_xp_bar.value = skill_xp
		_xp_label.text = "%d/%d" % [skill_xp, xp_to_next]
	else:
		_xp_title.text = "---"
		_xp_bar.max_value = 1
		_xp_bar.value = 0
		_xp_label.text = "---"

	_gold_label.text = "%s G" % _format_number(gold)

	_refresh_stamina()
	_refresh_time()

func _refresh_if_player(entity_id: String) -> void:
	if entity_id == "player":
		_refresh_all()

func _on_entity_died(entity_id: String, killer_id: String) -> void:
	if entity_id == "player" or killer_id == "player":
		_refresh_all()

func _on_proficiency_xp_gained(entity_id: String, skill_id: String, _amount: int, _new_xp: int) -> void:
	if entity_id != "player":
		return
	_recent_skill_id = skill_id
	_refresh_all()

func _on_stamina_changed(entity_id: String, _stamina: float, _max_stamina: float) -> void:
	if entity_id == "player":
		_refresh_stamina()

func _on_game_hour_changed(_hour: int) -> void:
	_refresh_time()

func _refresh_stamina() -> void:
	var player_node = WorldState.get_entity("player")
	if not player_node:
		return
	var comp = player_node.get_node_or_null("StaminaComponent")
	if not comp:
		return
	var sta: float = comp.get_stamina()
	var max_sta: float = comp.get_max_stamina()
	_sta_bar.max_value = max_sta
	_sta_bar.value = sta
	_sta_label.text = "%d/%d" % [int(sta), int(max_sta)]

func _refresh_time() -> void:
	_time_label.text = TimeManager.get_time_display()
	_day_label.text = "Day %d - %s" % [TimeManager.get_day(), TimeManager.get_phase()]

func _on_proficiency_level_up(entity_id: String, skill_id: String, new_level: int) -> void:
	if entity_id != "player":
		return
	_refresh_all()
	# Spawn a floating "<Skill> Lv <N>!" text with outline and scale animation
	var skill_data := ProficiencyDatabase.get_skill(skill_id)
	var skill_name: String = skill_data.get("name", skill_id)
	var label := Label.new()
	label.text = "%s Lv %d!" % [skill_name, new_level]
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
