extends Control
## Player status/character screen toggled with C key.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

var _panel: PanelContainer
var _is_open: bool = false
var _player: Node

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
var _prof_grid: GridContainer
var _gold_label: Label

func _ready() -> void:
	visible = false
	_build_ui()

	# Live update signals
	GameEvents.entity_damaged.connect(func(_a, _b, _c, _d): _refresh())
	GameEvents.entity_healed.connect(func(_a, _b, _c): _refresh())
	GameEvents.proficiency_xp_gained.connect(func(_a, _b, _c, _d): _refresh())
	GameEvents.proficiency_level_up.connect(func(_a, _b, _c): _refresh())
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
	stats_header.add_theme_color_override("font_color", UIHelper.COLOR_HEADER)
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
	equip_header.add_theme_color_override("font_color", UIHelper.COLOR_HEADER)
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

	# Proficiency levels section header
	var prof_header := Label.new()
	prof_header.text = "Proficiencies"
	prof_header.add_theme_font_size_override("font_size", 14)
	prof_header.add_theme_color_override("font_color", UIHelper.COLOR_HEADER)
	vbox.add_child(prof_header)

	# 2-column grid: skill name + level
	_prof_grid = GridContainer.new()
	_prof_grid.columns = 4  # name1 level1 name2 level2
	_prof_grid.add_theme_constant_override("h_separation", 6)
	_prof_grid.add_theme_constant_override("v_separation", 1)
	vbox.add_child(_prof_grid)

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
	_gold_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
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
	item_lbl.add_theme_color_override("font_color", UIHelper.COLOR_EQUIPMENT)
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
		UIHelper.center_panel(_panel)
		_refresh()

func set_player(p: Node) -> void:
	_player = p

func _refresh() -> void:
	if not _is_open or not _player:
		return

	var stats = _player.get_node("StatsComponent")
	var inv = _player.get_node("InventoryComponent")
	var equip = _player.get_node("EquipmentComponent")
	if not stats or not inv or not equip:
		return

	var level: int = stats.level
	var hp: int = stats.hp
	var max_hp: int = stats.max_hp
	var base_atk: int = stats.atk
	var base_def: int = stats.def
	var attack_speed: float = stats.attack_speed
	var attack_range: float = stats.attack_range
	var progression = _player.get_node("ProgressionComponent")
	var gold: int = inv.gold
	var equipment: Dictionary = equip.get_equipment()

	_name_label.text = "Player"
	_level_label.text = "Total Lv. %d" % level

	# Stats
	_hp_value.text = "%d / %d" % [hp, max_hp]
	_hp_value.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if hp < max_hp else Color.WHITE)

	# ATK with equipment bonus
	var atk_bonus: int = equip.get_atk_bonus()
	_atk_value.text = str(base_atk)
	_atk_bonus.text = "(+%d)" % atk_bonus if atk_bonus > 0 else ""

	# DEF with equipment bonus
	var def_bonus: int = equip.get_def_bonus()
	_def_value.text = str(base_def)
	_def_bonus.text = "(+%d)" % def_bonus if def_bonus > 0 else ""

	_speed_value.text = "%.1fs" % attack_speed
	_range_value.text = "%.1f" % attack_range

	# Equipment
	var weapon_id: String = equipment.get("weapon", "")
	var armor_id: String = equipment.get("armor", "")
	var weapon_name := ItemDatabase.get_item_name(weapon_id) if not weapon_id.is_empty() else "None"
	var armor_name := ItemDatabase.get_item_name(armor_id) if not armor_id.is_empty() else "None"
	_weapon_name_label.text = weapon_name
	_unequip_weapon_btn.visible = not weapon_id.is_empty()
	_armor_name_label.text = armor_name
	_unequip_armor_btn.visible = not armor_id.is_empty()

	# Proficiency levels grid
	for child in _prof_grid.get_children():
		child.queue_free()
	if progression:
		var skills := ProficiencyDatabase.get_all_skills()
		# Show only weapon + attribute categories in compact 2-col layout
		for skill_id in skills:
			var skill_def: Dictionary = skills[skill_id]
			var cat: String = skill_def.get("category", "")
			if cat != "weapon" and cat != "attribute":
				continue
			var lvl: int = progression.get_proficiency_level(skill_id)
			var name_lbl := Label.new()
			name_lbl.text = skill_def.get("name", skill_id)
			name_lbl.add_theme_font_size_override("font_size", 12)
			name_lbl.custom_minimum_size.x = 70
			_prof_grid.add_child(name_lbl)
			var lvl_lbl := Label.new()
			lvl_lbl.text = str(lvl)
			lvl_lbl.add_theme_font_size_override("font_size", 12)
			lvl_lbl.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if lvl >= ProficiencyDatabase.MAX_LEVEL else Color(0.7, 0.9, 0.7))
			lvl_lbl.custom_minimum_size.x = 20
			_prof_grid.add_child(lvl_lbl)

	_gold_label.text = str(gold)

func _unequip_weapon() -> void:
	if _player:
		_player.get_node("EquipmentComponent").unequip("weapon")
	_refresh()

func _unequip_armor() -> void:
	if _player:
		_player.get_node("EquipmentComponent").unequip("armor")
	_refresh()

func is_open() -> bool:
	return _is_open
