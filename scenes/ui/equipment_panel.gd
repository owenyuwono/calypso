extends Control
## Equipment panel showing equipped gear, attack type, and effective stats.
## Toggled with Q key.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

const WEAPON_COLORS: Dictionary = {
	"sword":  Color(0.9, 0.85, 0.3),
	"axe":    Color(0.8, 0.4, 0.2),
	"mace":   Color(0.6, 0.6, 0.7),
	"dagger": Color(0.4, 0.8, 0.4),
	"staff":  Color(0.5, 0.4, 0.9),
}

const CELL_SIZE := 64

var _panel: PanelContainer
var _is_open: bool = false

var _player: Node
var _equipment: Node
var _combat: Node
var _stats: Node

# Attack type banner
var _attack_type_label: Label

# Weapon slot widgets
var _weapon_cell: PanelContainer
var _weapon_cell_letter: Label
var _weapon_name_label: Label
var _weapon_bonus_label: Label
var _weapon_unequip_btn: Button

# Armor slot widgets
var _armor_cell: PanelContainer
var _armor_cell_letter: Label
var _armor_name_label: Label
var _armor_bonus_label: Label
var _armor_unequip_btn: Button

# Stats labels
var _atk_label: Label
var _def_label: Label
var _speed_label: Label

# Periodic refresh timer
var _refresh_timer: Timer


func _ready() -> void:
	visible = false
	_build_ui()
	GameEvents.item_looted.connect(func(_a, _b, _c): _refresh())

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.5
	_refresh_timer.autostart = false
	_refresh_timer.timeout.connect(_refresh)
	add_child(_refresh_timer)


func set_player(p: Node) -> void:
	_player = p
	_equipment = p.get_node_or_null("EquipmentComponent")
	_combat = p.get_node_or_null("CombatComponent")
	_stats = p.get_node_or_null("StatsComponent")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_equipment"):
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle()


func toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		UIHelper.center_panel(_panel)
		_refresh()
		_refresh_timer.start()
	else:
		_refresh_timer.stop()


func is_open() -> bool:
	return _is_open


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 350)
	_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# Title bar
	var drag_handle := DragHandle.new()
	drag_handle.setup(_panel, "Equipment")
	drag_handle.close_pressed.connect(toggle)
	vbox.add_child(drag_handle)

	# Attack type banner
	_attack_type_label = Label.new()
	_attack_type_label.add_theme_font_size_override("font_size", 18)
	_attack_type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_attack_type_label.text = "Attack Type: Unarmed"
	_attack_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_attack_type_label)

	# Separator
	vbox.add_child(HSeparator.new())

	# Weapon slot row
	vbox.add_child(_build_slot_row("weapon"))

	# Armor slot row
	vbox.add_child(_build_slot_row("armor"))

	# Separator
	vbox.add_child(HSeparator.new())

	# Effective stats section
	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(stats_vbox)

	var stats_header := Label.new()
	stats_header.text = "Effective Stats"
	stats_header.add_theme_font_size_override("font_size", 12)
	stats_header.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
	stats_vbox.add_child(stats_header)

	_atk_label = Label.new()
	_atk_label.add_theme_font_size_override("font_size", 14)
	_atk_label.add_theme_color_override("font_color", Color.WHITE)
	stats_vbox.add_child(_atk_label)

	_def_label = Label.new()
	_def_label.add_theme_font_size_override("font_size", 14)
	_def_label.add_theme_color_override("font_color", Color.WHITE)
	stats_vbox.add_child(_def_label)

	_speed_label = Label.new()
	_speed_label.add_theme_font_size_override("font_size", 14)
	_speed_label.add_theme_color_override("font_color", Color.WHITE)
	stats_vbox.add_child(_speed_label)


func _build_slot_row(slot: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Colored cell
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	var cell_style := StyleBoxFlat.new()
	cell_style.bg_color = Color(0.08, 0.08, 0.12)
	cell_style.border_color = Color(0.2, 0.2, 0.25)
	cell_style.set_border_width_all(1)
	cell_style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("panel", cell_style)

	var cell_margin := MarginContainer.new()
	cell_margin.add_theme_constant_override("margin_left", 4)
	cell_margin.add_theme_constant_override("margin_right", 4)
	cell_margin.add_theme_constant_override("margin_top", 4)
	cell_margin.add_theme_constant_override("margin_bottom", 4)
	cell.add_child(cell_margin)

	var cell_letter := Label.new()
	cell_letter.text = ""
	cell_letter.add_theme_font_size_override("font_size", 22)
	cell_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell_letter.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	cell_letter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell_letter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell_margin.add_child(cell_letter)
	row.add_child(cell)

	# Center: name + bonus
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)

	var slot_header := Label.new()
	slot_header.text = slot.capitalize()
	slot_header.add_theme_font_size_override("font_size", 11)
	slot_header.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
	info_vbox.add_child(slot_header)

	var name_label := Label.new()
	name_label.text = "(none)"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", UIHelper.COLOR_EQUIPMENT)
	name_label.clip_text = true
	info_vbox.add_child(name_label)

	var bonus_label := Label.new()
	bonus_label.text = ""
	bonus_label.add_theme_font_size_override("font_size", 12)
	bonus_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	info_vbox.add_child(bonus_label)

	row.add_child(info_vbox)

	# Right: unequip button
	var unequip_btn := Button.new()
	unequip_btn.text = "Unequip"
	unequip_btn.custom_minimum_size = Vector2(64, 0)
	unequip_btn.add_theme_font_size_override("font_size", 11)
	unequip_btn.visible = false
	unequip_btn.pressed.connect(_unequip.bind(slot))
	row.add_child(unequip_btn)

	# Store refs by slot
	if slot == "weapon":
		_weapon_cell = cell
		_weapon_cell_letter = cell_letter
		_weapon_name_label = name_label
		_weapon_bonus_label = bonus_label
		_weapon_unequip_btn = unequip_btn
	else:
		_armor_cell = cell
		_armor_cell_letter = cell_letter
		_armor_name_label = name_label
		_armor_bonus_label = bonus_label
		_armor_unequip_btn = unequip_btn

	return row


func _unequip(slot: String) -> void:
	if _equipment:
		_equipment.unequip(slot)
		_refresh()


func _refresh() -> void:
	if not _is_open or not _player:
		return
	if not _equipment or not _stats or not _combat:
		return

	var equipment: Dictionary = _equipment.get_equipment()
	var weapon_id: String = equipment.get("weapon", "")
	var armor_id: String = equipment.get("armor", "")

	# Attack type banner
	if weapon_id.is_empty():
		_attack_type_label.text = "Attack Type: Unarmed"
		_attack_type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	else:
		var weapon_type: String = _combat.get_equipped_weapon_type()
		var display_type: String = weapon_type.capitalize()
		_attack_type_label.text = "Attack Type: " + display_type
		var type_color: Color = WEAPON_COLORS.get(weapon_type, Color(0.9, 0.85, 0.3))
		_attack_type_label.add_theme_color_override("font_color", type_color)

	# Weapon slot
	_refresh_slot(
		weapon_id,
		"weapon",
		_weapon_cell,
		_weapon_cell_letter,
		_weapon_name_label,
		_weapon_bonus_label,
		_weapon_unequip_btn
	)

	# Armor slot
	_refresh_slot(
		armor_id,
		"armor",
		_armor_cell,
		_armor_cell_letter,
		_armor_name_label,
		_armor_bonus_label,
		_armor_unequip_btn
	)

	# Effective stats
	var base_atk: int = _stats.atk
	var base_def: int = _stats.def
	var effective_atk: int = _combat.get_effective_atk()
	var effective_def: int = _combat.get_effective_def()
	var atk_bonus: int = _equipment.get_atk_bonus()
	var def_bonus: int = _equipment.get_def_bonus()

	_atk_label.text = _build_stat_text("ATK", base_atk, atk_bonus, effective_atk)
	_def_label.text = _build_stat_text("DEF", base_def, def_bonus, effective_def)

	# Attack speed: base attack_speed adjusted by weapon speed and penalty multiplier
	var base_speed: float = _stats.attack_speed
	var speed_mult: float = _combat.get_attack_speed_multiplier()
	var effective_speed: float = base_speed * speed_mult
	_speed_label.text = "Speed: %.1fs" % effective_speed


func _refresh_slot(
	item_id: String,
	slot: String,
	cell: PanelContainer,
	cell_letter: Label,
	name_label: Label,
	bonus_label: Label,
	unequip_btn: Button
) -> void:
	if item_id.is_empty():
		# Empty slot
		var empty_style := StyleBoxFlat.new()
		empty_style.bg_color = Color(0.08, 0.08, 0.12)
		empty_style.border_color = Color(0.2, 0.2, 0.25)
		empty_style.set_border_width_all(1)
		empty_style.set_corner_radius_all(4)
		cell.add_theme_stylebox_override("panel", empty_style)
		cell_letter.text = ""
		name_label.text = "(none)"
		bonus_label.text = ""
		unequip_btn.visible = false
		return

	var item_data: Dictionary = ItemDatabase.get_item(item_id)
	var item_name: String = item_data.get("name", item_id)

	# Cell color based on slot
	var cell_style := StyleBoxFlat.new()
	if slot == "weapon":
		cell_style.bg_color = Color(0.35, 0.35, 0.45)
	else:
		cell_style.bg_color = Color(0.2, 0.3, 0.5)
	cell_style.border_color = Color(0.5, 0.5, 0.6)
	cell_style.set_border_width_all(1)
	cell_style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("panel", cell_style)

	cell_letter.text = item_name.substr(0, 1).to_upper()
	name_label.text = item_name

	if slot == "weapon":
		var raw_bonus: int = item_data.get("atk_bonus", 0)
		bonus_label.text = "ATK +%d" % raw_bonus
	else:
		var raw_bonus: int = item_data.get("def_bonus", 0)
		bonus_label.text = "DEF +%d" % raw_bonus

	unequip_btn.visible = true


func _build_stat_text(stat_name: String, base: int, bonus: int, effective: int) -> String:
	# No bonus — show plain value
	if bonus == 0:
		return "%s: %d" % [stat_name, base]

	# Check for penalty: if effective < base + bonus, penalty is active
	var full_value: int = base + bonus
	if effective < full_value:
		return "%s: %d + %d = %d (penalty)" % [stat_name, base, bonus, effective]

	return "%s: %d + %d = %d" % [stat_name, base, bonus, effective]
