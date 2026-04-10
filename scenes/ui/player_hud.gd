extends Control
## Player HUD: bare HP + stamina bars above the skill hotbar (bottom-center), no background panel.

var _hp_bar: ProgressBar
var _sta_bar: ProgressBar
var _player: Node
var _time_label: Label
var _stats: Node
var _stamina_comp: Node
var _ammo_comp: Node
var _ammo_panel: PanelContainer
var _ammo_label: Label
var _reserve_label: Label
var _reload_label: Label
var _ammo_flash_tween: Tween

const UIHelper = preload("res://scripts/utils/ui_helper.gd")

# Mirror hotbar constants so bars sit flush above it.
const SLOT_SIZE: float = 64.0
const BOTTOM_MARGIN: float = 16.0
const BAR_HEIGHT: int = 14
const BAR_WIDTH: float = 160.0
const BAR_GAP: float = 8.0

func _ready() -> void:
	_build_ui()
	# Event-driven updates instead of _process polling
	GameEvents.entity_damaged.connect(func(id, _a, _b, _c): _refresh_if_player(id))
	GameEvents.entity_healed.connect(func(id, _a, _b): _refresh_if_player(id))
	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_respawned.connect(func(id): _refresh_if_player(id))
	GameEvents.stamina_changed.connect(_on_stamina_changed)
	GameEvents.game_hour_changed.connect(_on_game_hour_changed)
	GameEvents.ammo_changed.connect(_on_ammo_changed)
	GameEvents.reload_started.connect(_on_reload_started)
	GameEvents.reload_finished.connect(_on_reload_finished)
	GameEvents.combat_mode_changed.connect(_on_combat_mode_changed)
	# Initial refresh
	_refresh_all()

func _build_ui() -> void:
	# Bare horizontal row — no panel container, no background
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(BAR_GAP))
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Anchor bottom-center, directly above the hotbar
	var total_width := BAR_WIDTH * 2.0 + BAR_GAP
	var hotbar_top_offset: float = -(SLOT_SIZE + BOTTOM_MARGIN)  # top edge of hotbar row
	hbox.anchor_left = 0.5
	hbox.anchor_right = 0.5
	hbox.anchor_top = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = -total_width * 0.5
	hbox.offset_right = total_width * 0.5
	hbox.offset_bottom = hotbar_top_offset - 4.0
	hbox.offset_top = hotbar_top_offset - 4.0 - BAR_HEIGHT

	_hp_bar = _create_styled_bar(
		Color(0.85, 0.15, 0.15), Color(0.3, 0.05, 0.05),
		Color(1.0, 0.4, 0.4), Color(0.1, 0, 0)
	)
	hbox.add_child(_hp_bar)

	_sta_bar = _create_styled_bar(
		Color(0.15, 0.65, 0.4), Color(0.05, 0.15, 0.1),
		Color(0.3, 0.8, 0.55), Color(0, 0.05, 0.02)
	)
	hbox.add_child(_sta_bar)

	add_child(hbox)

	# Ammo counter — bottom-right, visible only in gun mode
	_build_ammo_panel()

	# Time panel — separate panel to the left of the minimap
	_build_time_panel()

func _build_time_panel() -> void:
	# Time display centered under the minimap, slightly overlapping
	var viewport_w := get_viewport().get_visible_rect().size.x
	var minimap_size := 184.0  # MAP_SIZE + BORDER * 2
	var minimap_right := viewport_w - 10.0
	var minimap_center_x := minimap_right - minimap_size * 0.5
	var minimap_bottom := 10.0 + minimap_size

	var time_panel := PanelContainer.new()
	time_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	add_child(time_panel)

	_time_label = UIHelper.create_label("08:00 - Day 1 (day)", 12, Color(0.9, 0.85, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	time_panel.add_child(_time_label)

	# Position centered under minimap, overlapping by ~8px
	await get_tree().process_frame
	var panel_w := time_panel.size.x
	time_panel.position = Vector2(minimap_center_x - panel_w * 0.5, minimap_bottom - 8)

func _create_styled_bar(fill_color: Color, bg_color: Color, fill_border: Color, bg_border: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg_style: StyleBoxFlat = UIHelper.create_style_box(bg_color, bg_border, 3, 1)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style: StyleBoxFlat = UIHelper.create_style_box(fill_color, fill_border, 3, 1)
	bar.add_theme_stylebox_override("fill", fill_style)

	return bar

func _build_ammo_panel() -> void:
	_ammo_panel = PanelContainer.new()
	_ammo_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	_ammo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_ammo_panel.add_child(vbox)

	_ammo_label = UIHelper.create_label("12 / 12", 18, UIHelper.COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(_ammo_label)

	_reserve_label = UIHelper.create_label("Reserve: 48", 12, Color(0.7, 0.65, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(_reserve_label)

	_reload_label = UIHelper.create_label("RELOADING...", 14, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	_reload_label.visible = false
	vbox.add_child(_reload_label)

	# Anchor bottom-right
	_ammo_panel.anchor_left = 1.0
	_ammo_panel.anchor_right = 1.0
	_ammo_panel.anchor_top = 1.0
	_ammo_panel.anchor_bottom = 1.0
	_ammo_panel.offset_left = -140.0
	_ammo_panel.offset_right = -10.0
	_ammo_panel.offset_top = -100.0
	_ammo_panel.offset_bottom = -10.0

	_ammo_panel.visible = false
	add_child(_ammo_panel)

func set_player(p: Node) -> void:
	_player = p
	_stats = p.get_node_or_null("StatsComponent")
	_stamina_comp = p.get_node_or_null("StaminaComponent")
	_ammo_comp = p.get_node_or_null("AmmoComponent")
	_refresh_all()

func _refresh_all() -> void:
	if not _player:
		return
	if not _stats:
		return

	_hp_bar.max_value = _stats.max_hp
	_hp_bar.value = _stats.hp

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

func _refresh_time() -> void:
	_time_label.text = "%s - Day %d (%s)" % [TimeManager.get_time_display(), TimeManager.get_day(), TimeManager.get_phase()]

func _on_ammo_changed(entity_id: String, magazine_current: int, magazine_max: int, reserve: int) -> void:
	if entity_id != "player":
		return
	_ammo_label.text = "%d / %d" % [magazine_current, magazine_max]
	_reserve_label.text = "Reserve: %d" % reserve

	# Red flash when low ammo
	if magazine_current <= 3 and magazine_current > 0:
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if _ammo_flash_tween:
			_ammo_flash_tween.kill()
		_ammo_flash_tween = create_tween()
		_ammo_flash_tween.tween_property(_ammo_label, "theme_override_colors/font_color", UIHelper.COLOR_GOLD, 0.3).set_delay(0.2)
	elif magazine_current == 0:
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	else:
		_ammo_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)

	# Red reserve label when empty
	if reserve <= 0:
		_reserve_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		_reserve_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))

func _on_reload_started(entity_id: String) -> void:
	if entity_id != "player":
		return
	_reload_label.visible = true
	_ammo_label.visible = false

func _on_reload_finished(entity_id: String) -> void:
	if entity_id != "player":
		return
	_reload_label.visible = false
	_ammo_label.visible = true

func _on_combat_mode_changed(entity_id: String, mode: String) -> void:
	if entity_id != "player":
		return
	_ammo_panel.visible = mode == "gun"
	if mode == "gun" and _ammo_comp:
		_on_ammo_changed("player", _ammo_comp.get_magazine_current(), _ammo_comp.get_magazine_max(), _ammo_comp.get_reserve())

