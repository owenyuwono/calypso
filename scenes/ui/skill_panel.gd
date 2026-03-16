extends Control
## Tabbed Skills & Proficiency panel toggled with S key.
## 7 tabs: sword/axe/mace/dagger/staff (proficiency + skills), attributes, other.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")
const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

const WEAPON_TABS: Array = ["sword", "axe", "mace", "dagger", "staff"]
const ALL_TABS: Array = ["sword", "axe", "mace", "dagger", "staff", "attributes", "other"]

const TAB_LABELS: Dictionary = {
	"sword": "Sword",
	"axe": "Axe",
	"mace": "Mace",
	"dagger": "Dagger",
	"staff": "Staff",
	"attributes": "Attributes",
	"other": "Other",
}

var _panel: PanelContainer
var _is_open: bool = false
var _player: Node
var _combat: Node
var _progression: Node
var _skills_comp: Node

var _tab_buttons: Array[Button] = []
var _current_tab: String = "sword"
var _content: VBoxContainer


func set_player(p: Node) -> void:
	_player = p
	_combat = p.get_node_or_null("CombatComponent")
	_progression = p.get_node_or_null("ProgressionComponent")
	_skills_comp = p.get_node_or_null("SkillsComponent")


func _ready() -> void:
	visible = false
	_build_ui()
	GameEvents.skill_learned.connect(func(_a, _b, _c): _refresh())
	GameEvents.skill_used.connect(func(_a, _b): _refresh())
	GameEvents.proficiency_level_up.connect(func(_a, _b, _c): _refresh())
	GameEvents.proficiency_xp_gained.connect(func(_a, _b, _c, _d): _refresh())


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(420, 500)
	_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# Draggable title bar
	var drag_handle := DragHandle.new()
	drag_handle.setup(_panel, "Skills & Proficiencies")
	drag_handle.close_pressed.connect(toggle)
	vbox.add_child(drag_handle)

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 2)
	vbox.add_child(tab_bar)

	for tab_name in ALL_TABS:
		var btn := Button.new()
		btn.text = TAB_LABELS[tab_name]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_switch_tab.bind(tab_name))
		_tab_buttons.append(btn)
		tab_bar.add_child(btn)

	vbox.add_child(HSeparator.new())

	# Scrollable content area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	vbox.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_skills") or event.is_action_pressed("toggle_proficiencies"):
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle()


func toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		UIHelper.center_panel(_panel)
		_select_default_tab()
		_refresh()


func is_open() -> bool:
	return _is_open


func _select_default_tab() -> void:
	if _combat:
		var weapon_type: String = _combat.get_equipped_weapon_type()
		if weapon_type in WEAPON_TABS:
			_current_tab = weapon_type
			return
	_current_tab = "sword"


func _switch_tab(tab_name: String) -> void:
	_current_tab = tab_name
	_refresh()


func _refresh() -> void:
	if not _is_open or not _player:
		return

	_update_tab_button_styles()
	_rebuild_content()


func _update_tab_button_styles() -> void:
	for i in range(ALL_TABS.size()):
		var tab_name: String = ALL_TABS[i]
		var btn: Button = _tab_buttons[i]
		if tab_name == _current_tab:
			var active_style := StyleBoxFlat.new()
			active_style.bg_color = Color(0.35, 0.3, 0.15, 0.95)
			active_style.border_color = UIHelper.COLOR_GOLD
			UIHelper.set_border_width(active_style, 1)
			UIHelper.set_corner_radius(active_style, 3)
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_stylebox_override("hover", active_style)
			btn.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
		else:
			var inactive_style := StyleBoxFlat.new()
			inactive_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
			inactive_style.border_color = Color(0.3, 0.3, 0.3)
			UIHelper.set_border_width(inactive_style, 1)
			UIHelper.set_corner_radius(inactive_style, 3)
			btn.add_theme_stylebox_override("normal", inactive_style)
			btn.add_theme_stylebox_override("hover", inactive_style)
			btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))


func _rebuild_content() -> void:
	for child in _content.get_children():
		child.queue_free()

	if _current_tab in WEAPON_TABS:
		_build_weapon_tab(_current_tab)
	elif _current_tab == "attributes":
		_build_proficiency_group(["constitution", "agility"])
	elif _current_tab == "other":
		_build_proficiency_category_group("Gathering", ["mining", "woodcutting", "fishing"])
		_content.add_child(HSeparator.new())
		_build_proficiency_category_group("Production", ["smithing", "cooking", "crafting"])


func _build_weapon_tab(weapon_type: String) -> void:
	if not _progression:
		return

	# --- Proficiency header ---
	var prof_def: Dictionary = ProficiencyDatabase.get_skill(weapon_type)
	var xp_data: Dictionary = _progression.get_proficiency_xp(weapon_type)
	var prof_level: int = xp_data.get("level", 1)
	var prof_xp: int = xp_data.get("xp", 0)
	var prof_xp_to_next: int = xp_data.get("xp_to_next", 50)
	var prof_is_max: bool = prof_level >= ProficiencyDatabase.MAX_LEVEL

	var prof_row := HBoxContainer.new()
	prof_row.add_theme_constant_override("separation", 4)
	_content.add_child(prof_row)

	var prof_name_label := Label.new()
	prof_name_label.text = prof_def.get("name", weapon_type) + " Proficiency"
	prof_name_label.add_theme_font_size_override("font_size", 15)
	prof_name_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if prof_is_max else Color.WHITE)
	prof_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prof_row.add_child(prof_name_label)

	var prof_level_label := Label.new()
	prof_level_label.text = "MAX" if prof_is_max else "Lv. %d" % prof_level
	prof_level_label.add_theme_font_size_override("font_size", 13)
	prof_level_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if prof_is_max else Color(0.8, 0.8, 0.8))
	prof_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prof_level_label.custom_minimum_size.x = 48
	prof_row.add_child(prof_level_label)

	if not prof_is_max:
		var bar_row := HBoxContainer.new()
		bar_row.add_theme_constant_override("separation", 4)
		_content.add_child(bar_row)

		var spacer := Control.new()
		spacer.custom_minimum_size.x = 8
		bar_row.add_child(spacer)

		var xp_bar := ProgressBar.new()
		xp_bar.custom_minimum_size = Vector2(120, 12)
		xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_bar.max_value = prof_xp_to_next
		xp_bar.value = prof_xp
		xp_bar.show_percentage = false
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.15, 0.15, 0.2)
		UIHelper.set_corner_radius(bar_bg, 2)
		xp_bar.add_theme_stylebox_override("background", bar_bg)
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.3, 0.6, 1.0)
		UIHelper.set_corner_radius(bar_fill, 2)
		xp_bar.add_theme_stylebox_override("fill", bar_fill)
		bar_row.add_child(xp_bar)

		var xp_text := Label.new()
		xp_text.text = "%d/%d" % [prof_xp, prof_xp_to_next]
		xp_text.add_theme_font_size_override("font_size", 11)
		xp_text.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		xp_text.custom_minimum_size.x = 60
		bar_row.add_child(xp_text)

	_content.add_child(HSeparator.new())

	# --- Skills for this weapon type ---
	var skill_ids: Array = SkillDatabase.get_skills_for_proficiency(weapon_type)
	if skill_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No skills for this weapon type."
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
		_content.add_child(empty_label)
		return

	for skill_id in skill_ids:
		_build_skill_row(skill_id)
		_content.add_child(HSeparator.new())


func _build_skill_row(skill_id: String) -> void:
	if not _skills_comp or not _progression:
		return

	var skill: Dictionary = SkillDatabase.SKILLS[skill_id]
	var current_level: int = _skills_comp.get_skill_level(skill_id)
	var max_level: int = skill.get("max_level", 5)
	var skill_color: Color = skill.get("color", Color.WHITE)

	var req: Dictionary = skill.get("required_proficiency", {})
	var req_skill: String = req.get("skill", "")
	var req_level: int = req.get("level", 1)
	var meets_req: bool = true
	if not req_skill.is_empty():
		var prof_level: int = _progression.get_proficiency_level(req_skill)
		meets_req = prof_level >= req_level

	var row_vbox := VBoxContainer.new()
	row_vbox.add_theme_constant_override("separation", 2)
	_content.add_child(row_vbox)

	# Name + level
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	row_vbox.add_child(top_row)

	var name_label := Label.new()
	name_label.text = skill.get("name", skill_id)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", skill_color if meets_req else UIHelper.COLOR_DISABLED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)

	var level_label := Label.new()
	if current_level > 0:
		level_label.text = "Lv. %d/%d" % [current_level, max_level]
	else:
		level_label.text = "Locked"
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8) if current_level > 0 else UIHelper.COLOR_DISABLED)
	top_row.add_child(level_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = skill.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row_vbox.add_child(desc_label)

	# Stats or requirement
	var stats_label := Label.new()
	stats_label.add_theme_font_size_override("font_size", 12)
	if not meets_req:
		var req_skill_data: Dictionary = ProficiencyDatabase.get_skill(req_skill)
		var req_skill_name: String = req_skill_data.get("name", req_skill)
		stats_label.text = "Requires %s Lv. %d" % [req_skill_name, req_level]
		stats_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	else:
		var preview_level: int = maxi(1, current_level)
		var mult: float = SkillDatabase.get_effective_multiplier(skill_id, preview_level)
		var cd: float = SkillDatabase.get_effective_cooldown(skill_id, preview_level)
		var stats_text: String = "DMG: %d%% | CD: %.1fs" % [roundi(mult * 100), cd]
		var type_info: String = _get_type_info(skill)
		if not type_info.is_empty():
			stats_text += "\n" + type_info
		stats_label.text = stats_text
		stats_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	row_vbox.add_child(stats_label)

	if current_level > 0:
		# XP progress
		var xp: int = _skills_comp.get_skill_xp(skill_id)
		var xp_needed: int = current_level * 50
		if current_level < max_level:
			var xp_label := Label.new()
			xp_label.text = "XP: %d/%d" % [xp, xp_needed]
			xp_label.add_theme_font_size_override("font_size", 11)
			xp_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
			row_vbox.add_child(xp_label)

		# Hotbar buttons
		var hotbar_row := HBoxContainer.new()
		hotbar_row.add_theme_constant_override("separation", 4)
		row_vbox.add_child(hotbar_row)

		var hotbar_label := Label.new()
		hotbar_label.text = "Hotbar:"
		hotbar_label.add_theme_font_size_override("font_size", 12)
		hotbar_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hotbar_row.add_child(hotbar_label)

		var hotbar: Array = _skills_comp.get_hotbar()
		for slot_i in range(5):
			var slot_btn := Button.new()
			slot_btn.text = str(slot_i + 1)
			slot_btn.custom_minimum_size = Vector2(28, 24)
			slot_btn.add_theme_font_size_override("font_size", 11)
			if slot_i < hotbar.size() and hotbar[slot_i] == skill_id:
				var active_style := StyleBoxFlat.new()
				active_style.bg_color = Color(0.3, 0.25, 0.1, 0.9)
				active_style.border_color = UIHelper.COLOR_GOLD
				UIHelper.set_border_width(active_style, 1)
				UIHelper.set_corner_radius(active_style, 3)
				slot_btn.add_theme_stylebox_override("normal", active_style)
			slot_btn.pressed.connect(_assign_hotbar.bind(slot_i, skill_id))
			hotbar_row.add_child(slot_btn)


func _build_proficiency_group(prof_ids: Array) -> void:
	for prof_id in prof_ids:
		_build_proficiency_row(prof_id)


func _build_proficiency_category_group(header_text: String, prof_ids: Array) -> void:
	var header := Label.new()
	header.text = "-- %s --" % header_text
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(header)

	_build_proficiency_group(prof_ids)


func _build_proficiency_row(prof_id: String) -> void:
	if not _progression:
		return

	var skill_def: Dictionary = ProficiencyDatabase.get_skill(prof_id)
	var xp_data: Dictionary = _progression.get_proficiency_xp(prof_id)
	var level: int = xp_data.get("level", 1)
	var xp: int = xp_data.get("xp", 0)
	var xp_to_next: int = xp_data.get("xp_to_next", 50)
	var is_max: bool = level >= ProficiencyDatabase.MAX_LEVEL

	var row_vbox := VBoxContainer.new()
	row_vbox.add_theme_constant_override("separation", 1)
	_content.add_child(row_vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	row_vbox.add_child(top_row)

	var name_label := Label.new()
	name_label.text = "  " + skill_def.get("name", prof_id)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if is_max else Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)

	var level_label := Label.new()
	level_label.text = "MAX" if is_max else "Lv. %d" % level
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if is_max else Color(0.8, 0.8, 0.8))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.custom_minimum_size.x = 48
	top_row.add_child(level_label)

	if not is_max:
		var bar_row := HBoxContainer.new()
		bar_row.add_theme_constant_override("separation", 4)
		row_vbox.add_child(bar_row)

		var spacer := Control.new()
		spacer.custom_minimum_size.x = 12
		bar_row.add_child(spacer)

		var xp_bar := ProgressBar.new()
		xp_bar.custom_minimum_size = Vector2(120, 12)
		xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_bar.max_value = xp_to_next
		xp_bar.value = xp
		xp_bar.show_percentage = false
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.15, 0.15, 0.2)
		UIHelper.set_corner_radius(bar_bg, 2)
		xp_bar.add_theme_stylebox_override("background", bar_bg)
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.3, 0.6, 1.0)
		UIHelper.set_corner_radius(bar_fill, 2)
		xp_bar.add_theme_stylebox_override("fill", bar_fill)
		bar_row.add_child(xp_bar)

		var xp_text := Label.new()
		xp_text.text = "%d/%d" % [xp, xp_to_next]
		xp_text.add_theme_font_size_override("font_size", 11)
		xp_text.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		xp_text.custom_minimum_size.x = 60
		bar_row.add_child(xp_text)


func _get_type_info(skill: Dictionary) -> String:
	var skill_type: String = skill.get("type", "")
	if skill_type == "aoe_melee":
		var radius: float = skill.get("aoe_radius", 0.0)
		var center: String = skill.get("aoe_center", "target")
		return "AoE | Radius: %.1f | Center: %s" % [radius, center]
	elif skill_type == "bleed":
		var ticks: int = skill.get("bleed_ticks", 0)
		var duration: float = skill.get("bleed_duration", 0.0)
		return "Bleed | %d ticks over %.1fs" % [ticks, duration]
	elif skill_type == "armor_pierce":
		var ignore_pct: float = skill.get("def_ignore_percent", 0.0)
		return "Pierce | Ignores %d%% DEF" % [roundi(ignore_pct * 100)]
	return ""


func _assign_hotbar(slot: int, skill_id: String) -> void:
	if _skills_comp:
		_skills_comp.set_hotbar_slot(slot, skill_id)
	_refresh()
	var hotbar_node := get_parent().get_node_or_null("SkillHotbar")
	if hotbar_node:
		hotbar_node.refresh()
