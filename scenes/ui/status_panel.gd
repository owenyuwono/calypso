extends Control
## Player status/character screen toggled with C key.

const _STAT_ICONS: Dictionary = {
	"HP": "res://assets/textures/ui/stats/stat_hp.png",
	"ATK": "res://assets/textures/ui/stats/stat_atk.png",
	"MATK": "res://assets/textures/ui/stats/stat_matk.png",
	"DEF": "res://assets/textures/ui/stats/stat_def.png",
	"MDEF": "res://assets/textures/ui/stats/stat_mdef.png",
	"Accuracy": "res://assets/textures/ui/stats/stat_accuracy.png",
	"Evasion": "res://assets/textures/ui/stats/stat_evasion.png",
	"Crit Rate": "res://assets/textures/ui/stats/stat_crit_rate.png",
	"Crit Dmg": "res://assets/textures/ui/stats/stat_crit_dmg.png",
	"Atk Speed": "res://assets/textures/ui/stats/stat_atk_speed.png",
	"Move Spd": "res://assets/textures/ui/stats/stat_move_spd.png",
	"Cast Spd": "res://assets/textures/ui/stats/stat_cast_spd.png",
	"Stamina": "res://assets/textures/ui/stats/stat_stamina.png",
	"HP Regen": "res://assets/textures/ui/stats/stat_hp_regen.png",
	"CDR": "res://assets/textures/ui/stats/stat_cdr.png",
}

const _COLOR_BONUS: Color = Color(0.4, 0.9, 0.4)
const _COLOR_SECTION: Color = Color(0.8, 0.75, 0.5)

var _panel: PanelContainer
var _is_open: bool = false
var _player: Node

# Dynamic label refs — name/level
var _name_label: Label
var _level_label: Label

# Offensive stats
var _atk_value: Label
var _atk_bonus: Label
var _matk_value: Label
var _matk_bonus: Label
var _accuracy_value: Label
var _crit_rate_value: Label
var _crit_dmg_value: Label

# Defensive stats
var _hp_value: Label
var _def_value: Label
var _def_bonus: Label
var _mdef_value: Label
var _mdef_bonus: Label
var _evasion_value: Label

# Speed stats
var _atk_speed_value: Label
var _move_speed_value: Label
var _cast_speed_value: Label

# Resource stats
var _stamina_value: Label
var _hp_regen_value: Label
var _cdr_value: Label


func _ready() -> void:
	visible = false
	_build_ui()

	GameEvents.entity_damaged.connect(func(_a, _b, _c, _d): refresh())
	GameEvents.entity_healed.connect(func(_a, _b, _c): refresh())
	GameEvents.proficiency_xp_gained.connect(func(_a, _b, _c, _d): refresh())
	GameEvents.proficiency_level_up.connect(func(_a, _b, _c): refresh())
	GameEvents.stamina_changed.connect(_on_stamina_changed)

func _build_ui() -> void:
	var ui: Dictionary = UIHelper.create_titled_panel("Status", Vector2(520, 0), toggle)
	_panel = ui["panel"]
	add_child(_panel)
	ui["drag_handle"].queue_free()

	var vbox: VBoxContainer = ui["vbox"]

	# Name + Level row
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)

	_name_label = Label.new()
	_name_label.text = "Player"
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_label)

	_level_label = Label.new()
	_level_label.text = "Lv. 1"
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	name_row.add_child(_level_label)

	vbox.add_child(HSeparator.new())

	# Two-column stats area
	var stats_columns := HBoxContainer.new()
	stats_columns.add_theme_constant_override("separation", 8)
	vbox.add_child(stats_columns)

	# --- Left column: Offensive + Defensive ---
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 2)
	stats_columns.add_child(left_col)

	_add_column_header(left_col, "Offensive")

	var atk_row := _create_stat_row("ATK", true)
	_atk_value = atk_row.value
	_atk_bonus = atk_row.bonus
	left_col.add_child(atk_row.container)

	var matk_row := _create_stat_row("MATK", true)
	_matk_value = matk_row.value
	_matk_bonus = matk_row.bonus
	left_col.add_child(matk_row.container)

	var acc_row := _create_stat_row("Accuracy", false)
	_accuracy_value = acc_row.value
	left_col.add_child(acc_row.container)

	var crit_row := _create_stat_row("Crit Rate", false)
	_crit_rate_value = crit_row.value
	left_col.add_child(crit_row.container)

	var critdmg_row := _create_stat_row("Crit Dmg", false)
	_crit_dmg_value = critdmg_row.value
	left_col.add_child(critdmg_row.container)

	left_col.add_child(HSeparator.new())
	_add_column_header(left_col, "Defensive")

	var hp_row := _create_stat_row("HP", false)
	_hp_value = hp_row.value
	left_col.add_child(hp_row.container)

	var def_row := _create_stat_row("DEF", true)
	_def_value = def_row.value
	_def_bonus = def_row.bonus
	left_col.add_child(def_row.container)

	var mdef_row := _create_stat_row("MDEF", true)
	_mdef_value = mdef_row.value
	_mdef_bonus = mdef_row.bonus
	left_col.add_child(mdef_row.container)

	var eva_row := _create_stat_row("Evasion", false)
	_evasion_value = eva_row.value
	left_col.add_child(eva_row.container)

	# Column divider
	stats_columns.add_child(VSeparator.new())

	# --- Right column: Speed + Resource ---
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 2)
	stats_columns.add_child(right_col)

	_add_column_header(right_col, "Speed")

	var aspd_row := _create_stat_row("Atk Speed", false)
	_atk_speed_value = aspd_row.value
	right_col.add_child(aspd_row.container)

	var mspd_row := _create_stat_row("Move Spd", false)
	_move_speed_value = mspd_row.value
	right_col.add_child(mspd_row.container)

	var cspd_row := _create_stat_row("Cast Spd", false)
	_cast_speed_value = cspd_row.value
	right_col.add_child(cspd_row.container)

	right_col.add_child(HSeparator.new())
	_add_column_header(right_col, "Resource")

	var stamina_row := _create_stat_row("Stamina", false)
	_stamina_value = stamina_row.value
	right_col.add_child(stamina_row.container)

	var hpregen_row := _create_stat_row("HP Regen", false)
	_hp_regen_value = hpregen_row.value
	right_col.add_child(hpregen_row.container)

	var cdr_row := _create_stat_row("CDR", false)
	_cdr_value = cdr_row.value
	right_col.add_child(cdr_row.container)


func _add_section_header(vbox: VBoxContainer, title: String) -> void:
	vbox.add_child(HSeparator.new())
	_add_column_header(vbox, title)

# Header without a leading separator — used for the first section at the top of a column.
func _add_column_header(vbox: VBoxContainer, title: String) -> void:
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", _COLOR_SECTION)
	vbox.add_child(header)

func _create_stat_row(stat_name: String, has_bonus: bool) -> Dictionary:
	var hbox := HBoxContainer.new()

	if _STAT_ICONS.has(stat_name):
		var icon := TextureRect.new()
		icon.texture = load(_STAT_ICONS[stat_name])
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture_filter = TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.custom_minimum_size.x = 68
	hbox.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.add_theme_font_size_override("font_size", 15)
	value_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(value_lbl)

	var bonus_lbl := Label.new()
	bonus_lbl.add_theme_font_size_override("font_size", 15)
	bonus_lbl.add_theme_color_override("font_color", _COLOR_BONUS)
	bonus_lbl.visible = has_bonus
	hbox.add_child(bonus_lbl)

	return {"container": hbox, "value": value_lbl, "bonus": bonus_lbl}



func toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		AudioManager.play_ui_sfx("ui_panel_open")
		UIHelper.center_panel(_panel)
		refresh()
	else:
		AudioManager.play_ui_sfx("ui_panel_close")

func build_content(container: Control) -> void:
	if not _panel:
		_build_ui()
	if _panel and _panel.get_parent():
		_panel.get_parent().remove_child(_panel)
	container.add_child(_panel)


func set_player(p: Node) -> void:
	_player = p

func _on_stamina_changed(entity_id: String, stamina: float, max_stamina: float) -> void:
	if entity_id != "player" or not _is_open:
		return
	_update_stamina_label(stamina, max_stamina)

func _update_stamina_label(stamina: float, max_stamina: float) -> void:
	_stamina_value.text = "%d / %d" % [int(stamina), int(max_stamina)]

func refresh() -> void:
	if not _player:
		return

	var stats: Node = _player.get_node_or_null("StatsComponent")
	var equip: Node = _player.get_node_or_null("EquipmentComponent")
	if not stats or not equip:
		return

	_name_label.text = "Player"
	_level_label.text = "Total Lv. %d" % stats.level

	# --- Offensive ---
	var atk_bonus: int = equip.get_atk_bonus()
	_atk_value.text = str(stats.atk)
	_atk_bonus.text = "+%d" % atk_bonus if atk_bonus > 0 else ""

	var matk_bonus: int = equip.get_matk_bonus()
	_matk_value.text = str(stats.matk)
	_matk_bonus.text = "+%d" % matk_bonus if matk_bonus > 0 else ""

	_accuracy_value.text = "%d%%" % stats.accuracy
	_crit_rate_value.text = "%d%%" % stats.crit_rate
	_crit_dmg_value.text = "%d%%" % stats.crit_damage

	# --- Defensive ---
	_hp_value.text = "%d / %d" % [stats.hp, stats.max_hp]
	_hp_value.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if stats.hp < stats.max_hp else Color.WHITE)

	var def_bonus: int = equip.get_def_bonus()
	_def_value.text = str(stats.def)
	_def_bonus.text = "+%d" % def_bonus if def_bonus > 0 else ""

	var mdef_bonus: int = equip.get_mdef_bonus()
	_mdef_value.text = str(stats.mdef)
	_mdef_bonus.text = "+%d" % mdef_bonus if mdef_bonus > 0 else ""

	_evasion_value.text = "%d%%" % stats.evasion

	# --- Speed ---
	_atk_speed_value.text = "%.2f×" % stats.attack_speed_mult
	_move_speed_value.text = "%.2f×" % stats.move_speed
	_cast_speed_value.text = "%.2f×" % stats.cast_speed

	# --- Resource ---
	var stamina_comp: Node = _player.get_node_or_null("StaminaComponent")
	if stamina_comp:
		_update_stamina_label(stamina_comp.get_stamina(), stamina_comp.get_max_stamina())
	else:
		_stamina_value.text = "—"

	var hp_regen: float = stats.hp_regen
	_hp_regen_value.text = "%.1f/sec" % hp_regen if hp_regen > 0.0 else "0/sec"

	var cdr: float = stats.cooldown_reduction
	_cdr_value.text = "%d%%" % int(cdr)


func is_open() -> bool:
	return _is_open
