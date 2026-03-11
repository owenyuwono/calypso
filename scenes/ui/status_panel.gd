extends Control
## Player status/character screen toggled with C key.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const LevelData = preload("res://scripts/data/level_data.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

var _panel: PanelContainer
var _is_open: bool = false

# Dynamic label refs
var _name_label: Label
var _level_label: Label
var _hp_value: Label
var _atk_value: Label
var _atk_bonus: Label
var _def_value: Label
var _def_bonus: Label
var _speed_value: Label
var _range_value: Label
var _weapon_name_label: Label
var _armor_name_label: Label
var _unequip_weapon_btn: Button
var _unequip_armor_btn: Button
var _xp_bar: ProgressBar
var _xp_label: Label
var _gold_label: Label

func _ready() -> void:
	visible = false
	_build_ui()

	# Live update signals
	GameEvents.entity_damaged.connect(func(_a, _b, _c, _d): _refresh())
	GameEvents.entity_healed.connect(func(_a, _b, _c): _refresh())
	GameEvents.xp_gained.connect(func(_a, _b): _refresh())
	GameEvents.level_up.connect(func(_a, _b): _refresh())
	GameEvents.item_looted.connect(func(_a, _b, _c): _refresh())
	GameEvents.item_purchased.connect(func(_a, _b, _c): _refresh())
	GameEvents.item_sold.connect(func(_a, _b, _c): _refresh())

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 420)

	_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# Draggable title bar
	var drag_handle := DragHandle.new()
	drag_handle.setup(_panel, "Status")
	drag_handle.close_pressed.connect(toggle)
	vbox.add_child(drag_handle)

	# Name + Level row
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)

	_name_label = Label.new()
	_name_label.text = "Player"
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_label)

	_level_label = Label.new()
	_level_label.text = "Lv. 1"
	_level_label.add_theme_font_size_override("font_size", 16)
	_level_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	name_row.add_child(_level_label)

	vbox.add_child(HSeparator.new())

	# Stats section header
	var stats_header := Label.new()
	stats_header.text = "Stats"
	stats_header.add_theme_font_size_override("font_size", 14)
	stats_header.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	vbox.add_child(stats_header)

	# HP row
	var hp_row := _create_stat_row("HP")
	_hp_value = hp_row.value
	vbox.add_child(hp_row.container)

	# ATK row
	var atk_row := _create_stat_row("ATK")
	_atk_value = atk_row.value
	_atk_bonus = atk_row.bonus
	vbox.add_child(atk_row.container)

	# DEF row
	var def_row := _create_stat_row("DEF")
	_def_value = def_row.value
	_def_bonus = def_row.bonus
	vbox.add_child(def_row.container)

	# Speed row
	var speed_row := _create_stat_row("Speed")
	_speed_value = speed_row.value
	vbox.add_child(speed_row.container)

	# Range row
	var range_row := _create_stat_row("Range")
	_range_value = range_row.value
	vbox.add_child(range_row.container)

	vbox.add_child(HSeparator.new())

	# Equipment section header
	var equip_header := Label.new()
	equip_header.text = "Equipment"
	equip_header.add_theme_font_size_override("font_size", 14)
	equip_header.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	vbox.add_child(equip_header)

	# Weapon row
	var weapon_row := _create_equipment_row("Weapon")
	_weapon_name_label = weapon_row.name_label
	_unequip_weapon_btn = weapon_row.button
	_unequip_weapon_btn.pressed.connect(_unequip_weapon)
	vbox.add_child(weapon_row.container)

	# Armor row
	var armor_row := _create_equipment_row("Armor")
	_armor_name_label = armor_row.name_label
	_unequip_armor_btn = armor_row.button
	_unequip_armor_btn.pressed.connect(_unequip_armor)
	vbox.add_child(armor_row.container)

	vbox.add_child(HSeparator.new())

	# Progression section header
	var prog_header := Label.new()
	prog_header.text = "Progression"
	prog_header.add_theme_font_size_override("font_size", 14)
	prog_header.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	vbox.add_child(prog_header)

	# XP bar
	var xp_row := HBoxContainer.new()
	vbox.add_child(xp_row)

	var xp_name := Label.new()
	xp_name.text = "XP"
	xp_name.add_theme_font_size_override("font_size", 14)
	xp_name.custom_minimum_size.x = 60
	xp_row.add_child(xp_name)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(120, 18)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.2)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	_xp_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.3, 0.6, 1.0)
	bar_fill.corner_radius_top_left = 2
	bar_fill.corner_radius_top_right = 2
	bar_fill.corner_radius_bottom_left = 2
	bar_fill.corner_radius_bottom_right = 2
	_xp_bar.add_theme_stylebox_override("fill", bar_fill)
	xp_row.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.add_theme_font_size_override("font_size", 12)
	_xp_label.custom_minimum_size.x = 70
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_row.add_child(_xp_label)

	# Gold
	var gold_row := HBoxContainer.new()
	vbox.add_child(gold_row)

	var gold_name := Label.new()
	gold_name.text = "Gold"
	gold_name.add_theme_font_size_override("font_size", 14)
	gold_name.custom_minimum_size.x = 60
	gold_row.add_child(gold_name)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	gold_row.add_child(_gold_label)


func _create_stat_row(stat_name: String) -> Dictionary:
	var hbox := HBoxContainer.new()

	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.custom_minimum_size.x = 60
	hbox.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.add_theme_font_size_override("font_size", 14)
	value_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(value_lbl)

	var bonus_lbl := Label.new()
	bonus_lbl.add_theme_font_size_override("font_size", 14)
	bonus_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	hbox.add_child(bonus_lbl)

	return {"container": hbox, "value": value_lbl, "bonus": bonus_lbl}

func _create_equipment_row(slot_name: String) -> Dictionary:
	var hbox := HBoxContainer.new()

	var name_lbl := Label.new()
	name_lbl.text = slot_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.custom_minimum_size.x = 60
	hbox.add_child(name_lbl)

	var item_lbl := Label.new()
	item_lbl.add_theme_font_size_override("font_size", 14)
	item_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(item_lbl)

	var btn := Button.new()
	btn.text = "Unequip"
	btn.visible = false
	hbox.add_child(btn)

	return {"container": hbox, "name_label": item_lbl, "button": btn}

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_status"):
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle()

func toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		_center_panel()
		_refresh()

func _center_panel() -> void:
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 0.0
	var vp_size := get_viewport_rect().size
	_panel.position = (vp_size - _panel.custom_minimum_size) * 0.5

func _refresh() -> void:
	if not _is_open:
		return

	var data := WorldState.get_entity_data("player")
	var level: int = data.get("level", 1)
	var hp: int = data.get("hp", 0)
	var max_hp: int = data.get("max_hp", 50)
	var base_atk: int = data.get("atk", 10)
	var base_def: int = data.get("def", 5)
	var attack_speed: float = data.get("attack_speed", 0.8)
	var attack_range: float = data.get("attack_range", 2.0)
	var xp: int = data.get("xp", 0)
	var gold: int = data.get("gold", 0)
	var equipment: Dictionary = data.get("equipment", {})

	_name_label.text = data.get("name", "Player")
	_level_label.text = "Lv. %d" % level

	# Stats
	_hp_value.text = "%d / %d" % [hp, max_hp]
	_hp_value.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if hp < max_hp else Color.WHITE)

	# ATK with equipment bonus
	var weapon_id: String = equipment.get("weapon", "")
	var atk_bonus: int = 0
	if not weapon_id.is_empty():
		atk_bonus = ItemDatabase.get_item(weapon_id).get("atk_bonus", 0)
	_atk_value.text = str(base_atk)
	_atk_bonus.text = "(+%d)" % atk_bonus if atk_bonus > 0 else ""

	# DEF with equipment bonus
	var armor_id: String = equipment.get("armor", "")
	var def_bonus: int = 0
	if not armor_id.is_empty():
		def_bonus = ItemDatabase.get_item(armor_id).get("def_bonus", 0)
	_def_value.text = str(base_def)
	_def_bonus.text = "(+%d)" % def_bonus if def_bonus > 0 else ""

	_speed_value.text = "%.1fs" % attack_speed
	_range_value.text = "%.1f" % attack_range

	# Equipment
	var weapon_name := ItemDatabase.get_item_name(weapon_id) if not weapon_id.is_empty() else "None"
	var armor_name := ItemDatabase.get_item_name(armor_id) if not armor_id.is_empty() else "None"
	_weapon_name_label.text = weapon_name
	_unequip_weapon_btn.visible = not weapon_id.is_empty()
	_armor_name_label.text = armor_name
	_unequip_armor_btn.visible = not armor_id.is_empty()

	# Progression
	var xp_needed := LevelData.xp_to_next_level(level) if level < LevelData.MAX_LEVEL else 1
	_xp_bar.max_value = xp_needed
	_xp_bar.value = xp if level < LevelData.MAX_LEVEL else xp_needed
	_xp_label.text = "%d/%d" % [xp, xp_needed] if level < LevelData.MAX_LEVEL else "MAX"

	_gold_label.text = str(gold)

func _unequip_weapon() -> void:
	WorldState.unequip_item("player", "weapon")
	_refresh()

func _unequip_armor() -> void:
	WorldState.unequip_item("player", "armor")
	_refresh()

func is_open() -> bool:
	return _is_open
