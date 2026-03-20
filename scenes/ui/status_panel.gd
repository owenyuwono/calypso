extends Control
## Player status/character screen toggled with C key.

const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")

const _STAT_ICONS: Dictionary = {
	"HP": "res://assets/textures/ui/stats/stat_hp.png",
	"ATK": "res://assets/textures/ui/stats/stat_atk.png",
	"DEF": "res://assets/textures/ui/stats/stat_def.png",
}

# Proficiency display order within each category
const _CATEGORY_ORDER: Array = ["weapon", "attribute", "gathering", "production"]
const _CATEGORY_LABELS: Dictionary = {
	"weapon": "Weapon",
	"attribute": "Attributes",
	"gathering": "Gathering",
	"production": "Production",
}
const _PROF_ICON_BASE: String = "res://assets/textures/ui/proficiencies/"
const _COLOR_CATEGORY: Color = Color(0.6, 0.55, 0.45)
const _COLOR_BONUS: Color = Color(0.4, 0.9, 0.4)

var _panel: PanelContainer
var _is_open: bool = false
var _player: Node

# Dynamic label refs — stats
var _name_label: Label
var _level_label: Label
var _hp_value: Label
var _atk_value: Label
var _atk_bonus: Label
var _def_value: Label
var _def_bonus: Label
var _speed_value: Label
var _range_value: Label
var _stamina_value: Label

# Proficiency level labels: {skill_id: Label}
var _prof_level_labels: Dictionary = {}

func _ready() -> void:
	visible = false
	_build_ui()

	GameEvents.entity_damaged.connect(func(_a, _b, _c, _d): _refresh())
	GameEvents.entity_healed.connect(func(_a, _b, _c): _refresh())
	GameEvents.proficiency_xp_gained.connect(func(_a, _b, _c, _d): _refresh())
	GameEvents.proficiency_level_up.connect(func(_a, _b, _c): _refresh())
	GameEvents.stamina_changed.connect(_on_stamina_changed)

func _build_ui() -> void:
	var ui: Dictionary = UIHelper.create_titled_panel("Status", Vector2(280, 0), toggle)
	_panel = ui["panel"]
	add_child(_panel)

	var vbox: VBoxContainer = ui["vbox"]

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

	# Stamina row
	var stamina_row := _create_stat_row("Stamina")
	_stamina_value = stamina_row.value
	vbox.add_child(stamina_row.container)

	# Proficiency section
	vbox.add_child(HSeparator.new())
	_build_proficiency_section(vbox)

func _create_stat_row(stat_name: String) -> Dictionary:
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
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.custom_minimum_size.x = 60
	hbox.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.add_theme_font_size_override("font_size", 14)
	value_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(value_lbl)

	var bonus_lbl := Label.new()
	bonus_lbl.add_theme_font_size_override("font_size", 14)
	bonus_lbl.add_theme_color_override("font_color", _COLOR_BONUS)
	hbox.add_child(bonus_lbl)

	return {"container": hbox, "value": value_lbl, "bonus": bonus_lbl}

func _build_proficiency_section(vbox: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "PROFICIENCIES"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Build rows per category in fixed order
	for category in _CATEGORY_ORDER:
		_build_category_row(vbox, category)

func _build_category_row(vbox: VBoxContainer, category: String) -> void:
	# Category label
	var cat_label := Label.new()
	cat_label.text = _CATEGORY_LABELS.get(category, category)
	cat_label.add_theme_font_size_override("font_size", 11)
	cat_label.add_theme_color_override("font_color", _COLOR_CATEGORY)
	vbox.add_child(cat_label)

	# Icon row — HBoxContainer of icon+level pairs
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	# Iterate skills in insertion order, keeping only those in this category
	for skill_id in ProficiencyDatabase.SKILLS:
		var skill_def: Dictionary = ProficiencyDatabase.SKILLS[skill_id]
		if skill_def.get("category", "") != category:
			continue
		var entry := _build_prof_entry(skill_id, skill_def.get("name", skill_id))
		row.add_child(entry)

func _build_prof_entry(skill_id: String, skill_name: String) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)

	var icon_path: String = _PROF_ICON_BASE + skill_id + ".png"
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = TEXTURE_FILTER_NEAREST
		icon.tooltip_text = skill_name
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon)
	else:
		# Fallback: colored square placeholder
		var placeholder := ColorRect.new()
		placeholder.custom_minimum_size = Vector2(18, 18)
		placeholder.color = Color(0.4, 0.35, 0.25)
		placeholder.tooltip_text = skill_name
		placeholder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(placeholder)

	var level_lbl := Label.new()
	level_lbl.text = "1"
	level_lbl.add_theme_font_size_override("font_size", 10)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(level_lbl)

	_prof_level_labels[skill_id] = level_lbl
	return vbox

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_status"):
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle()

func toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		AudioManager.play_ui_sfx("ui_panel_open")
		UIHelper.center_panel(_panel)
		_refresh()
	else:
		AudioManager.play_ui_sfx("ui_panel_close")

func set_player(p: Node) -> void:
	_player = p

func _on_stamina_changed(entity_id: String, stamina: float, max_stamina: float) -> void:
	if entity_id != "player" or not _is_open:
		return
	_update_stamina_label(stamina, max_stamina)

func _update_stamina_label(stamina: float, max_stamina: float) -> void:
	var pct: int = int(stamina / max_stamina * 100.0) if max_stamina > 0.0 else 0
	_stamina_value.text = "%d%%" % pct
	if pct >= 70:
		_stamina_value.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	elif pct >= 35:
		_stamina_value.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		_stamina_value.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _refresh() -> void:
	if not _is_open or not _player:
		return

	var stats: Node = _player.get_node_or_null("StatsComponent")
	var equip: Node = _player.get_node_or_null("EquipmentComponent")
	if not stats or not equip:
		return

	var level: int = stats.level
	var hp: int = stats.hp
	var max_hp: int = stats.max_hp
	var base_atk: int = stats.atk
	var base_def: int = stats.def
	var attack_speed: float = stats.attack_speed
	var attack_range: float = stats.attack_range

	_name_label.text = "Player"
	_level_label.text = "Total Lv. %d" % level

	# HP
	_hp_value.text = "%d / %d" % [hp, max_hp]
	_hp_value.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if hp < max_hp else Color.WHITE)

	# ATK with equipment bonus in green
	var atk_bonus: int = equip.get_atk_bonus()
	_atk_value.text = str(base_atk)
	_atk_bonus.text = "+%d" % atk_bonus if atk_bonus > 0 else ""

	# DEF with equipment bonus in green
	var def_bonus: int = equip.get_def_bonus()
	_def_value.text = str(base_def)
	_def_bonus.text = "+%d" % def_bonus if def_bonus > 0 else ""

	_speed_value.text = "%.1fs" % attack_speed
	_range_value.text = "%.1f" % attack_range

	# Stamina
	var stamina_comp: Node = _player.get_node_or_null("StaminaComponent")
	if stamina_comp:
		_update_stamina_label(stamina_comp.get_stamina(), stamina_comp.get_max_stamina())
	else:
		_stamina_value.text = "—"

	# Proficiencies
	var progression: Node = _player.get_node_or_null("ProgressionComponent")
	if progression:
		for skill_id in _prof_level_labels:
			var lvl: int = progression.get_proficiency_level(skill_id)
			_prof_level_labels[skill_id].text = str(lvl)

func is_open() -> bool:
	return _is_open
