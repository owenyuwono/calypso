extends Control
## Player HUD showing HP bar, proficiency XP bar, total level, and gold with styled panel.

var _hp_bar: ProgressBar
var _hp_label: Label
var _sta_bar: ProgressBar
var _sta_label: Label
var _player: Node
var _time_label: Label
var _stats: Node
var _stamina_comp: Node

const UIHelper = preload("res://scripts/utils/ui_helper.gd")

func _ready() -> void:
	_build_ui()
	# Event-driven updates instead of _process polling
	GameEvents.entity_damaged.connect(func(id, _a, _b, _c): _refresh_if_player(id))
	GameEvents.entity_healed.connect(func(id, _a, _b): _refresh_if_player(id))
	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_respawned.connect(func(id): _refresh_if_player(id))
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
	vbox.custom_minimum_size = Vector2(180, 0)
	panel.add_child(vbox)

	# HP bar
	var hp_row := HBoxContainer.new()
	vbox.add_child(hp_row)

	var hp_header := HBoxContainer.new()
	hp_header.custom_minimum_size = Vector2(32, 0)
	hp_header.add_theme_constant_override("separation", 2)
	hp_row.add_child(hp_header)

	var hp_icon: TextureRect = UIHelper.create_icon("res://assets/textures/ui/stats/stat_hp.png", Vector2(16, 16))
	if hp_icon:
		hp_header.add_child(hp_icon)

	var hp_title: Label = UIHelper.create_label("HP", 13, Color(1, 0.3, 0.3))
	hp_header.add_child(hp_title)

	_hp_bar = _create_styled_bar(
		Color(0.85, 0.15, 0.15), Color(0.3, 0.05, 0.05),
		Color(1.0, 0.4, 0.4), Color(0.1, 0, 0), 20
	)
	hp_row.add_child(_hp_bar)

	_hp_label = UIHelper.create_label("50/50", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_hp_label.custom_minimum_size = Vector2(60, 0)
	hp_row.add_child(_hp_label)

	# Stamina bar
	var sta_row := HBoxContainer.new()
	vbox.add_child(sta_row)

	var sta_title: Label = UIHelper.create_label("STA", 13, Color(0.2, 0.75, 0.5))
	sta_title.custom_minimum_size = Vector2(32, 0)
	sta_row.add_child(sta_title)

	_sta_bar = _create_styled_bar(
		Color(0.15, 0.65, 0.4), Color(0.05, 0.15, 0.1),
		Color(0.3, 0.8, 0.55), Color(0, 0.05, 0.02), 18
	)
	sta_row.add_child(_sta_bar)

	_sta_label = UIHelper.create_label("100/100", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_sta_label.custom_minimum_size = Vector2(60, 0)
	sta_row.add_child(_sta_label)

	# Time panel — separate panel to the left of the minimap
	_build_time_panel()

func _build_time_panel() -> void:
	# Single-line time display to the left of the minimap
	var viewport_w := get_viewport().get_visible_rect().size.x
	var minimap_left := viewport_w - 184.0 - 10.0

	var time_panel := PanelContainer.new()
	time_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	time_panel.position = Vector2(minimap_left - 160.0, 10)
	add_child(time_panel)

	_time_label = UIHelper.create_label("08:00 - Day 1 (day)", 12, Color(0.9, 0.85, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	time_panel.add_child(_time_label)

func _create_styled_bar(fill_color: Color, bg_color: Color, fill_border: Color, bg_border: Color, bar_height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, bar_height)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg_style: StyleBoxFlat = UIHelper.create_style_box(bg_color, bg_border, 3, 1)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style: StyleBoxFlat = UIHelper.create_style_box(fill_color, fill_border, 3, 1)
	bar.add_theme_stylebox_override("fill", fill_style)

	return bar

func set_player(p: Node) -> void:
	_player = p
	_stats = p.get_node_or_null("StatsComponent")
	_stamina_comp = p.get_node_or_null("StaminaComponent")
	_refresh_all()

func _refresh_all() -> void:
	if not _player:
		return
	if not _stats:
		return

	_hp_bar.max_value = _stats.max_hp
	_hp_bar.value = _stats.hp
	_hp_label.text = "%d/%d" % [_stats.hp, _stats.max_hp]

	_refresh_stamina()
	_refresh_time()

func _refresh_if_player(entity_id: String) -> void:
	if entity_id == "player":
		_refresh_all()

func _on_entity_died(entity_id: String, killer_id: String) -> void:
	if entity_id == "player" or killer_id == "player":
		_refresh_all()

func _on_stamina_changed(entity_id: String, _stamina: float, _max_stamina: float) -> void:
	if entity_id == "player":
		_refresh_stamina()

func _on_game_hour_changed(_hour: int) -> void:
	_refresh_time()

func _refresh_stamina() -> void:
	if not _stamina_comp:
		return
	var sta: float = _stamina_comp.get_stamina()
	var max_sta: float = _stamina_comp.get_max_stamina()
	_sta_bar.max_value = max_sta
	_sta_bar.value = sta
	_sta_label.text = "%d/%d" % [int(sta), int(max_sta)]

func _refresh_time() -> void:
	_time_label.text = "%s - Day %d (%s)" % [TimeManager.get_time_display(), TimeManager.get_day(), TimeManager.get_phase()]

