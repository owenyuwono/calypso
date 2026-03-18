extends Control
## Skills & Proficiencies panel with grid overview + drill-down detail.
## Level 1: grid of 13 proficiency buttons with XP fill.
## Level 2: drill-down showing proficiency detail + skills (weapon only).

const SkillDatabase = preload("res://scripts/data/skill_database.gd")
const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

const CATEGORY_LABELS: Dictionary = {
	"weapon": "Weapon",
	"attribute": "Attributes",
	"gathering": "Gathering",
	"production": "Production",
}

var _panel: PanelContainer
var _is_open: bool = false
var _player: Node
var _combat: Node
var _progression: Node
var _skills_comp: Node

var _content: VBoxContainer
var _view: String = "grid"
var _detail_prof_id: String = ""


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

	var drag_handle := DragHandle.new()
	drag_handle.setup(_panel, "Skills & Proficiencies")
	drag_handle.close_pressed.connect(toggle)
	vbox.add_child(drag_handle)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 420)
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
		_show_grid()


func is_open() -> bool:
	return _is_open


func _refresh() -> void:
	if not _is_open or not _player:
		return
	if _view == "grid":
		_show_grid()
	else:
		_show_detail(_detail_prof_id)


func _show_grid() -> void:
	_view = "grid"
	_clear_content()
	_build_grid()


func _show_detail(prof_id: String) -> void:
	_view = "detail"
	_detail_prof_id = prof_id
	_clear_content()
	_build_detail(prof_id)


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()


# --- Grid View ---

func _build_grid() -> void:
	for category in ProficiencyDatabase.CATEGORIES:
		var prof_ids: Array = _get_prof_ids_in_category(category)
		if prof_ids.is_empty():
			continue

		var header_row := HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 6)
		_content.add_child(header_row)

		var sep_left := HSeparator.new()
		sep_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sep_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_row.add_child(sep_left)

		var header := Label.new()
		header.text = CATEGORY_LABELS.get(category, category)
		header.add_theme_font_size_override("font_size", 10)
		header.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
		header_row.add_child(header)

		var sep_right := HSeparator.new()
		sep_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sep_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_row.add_child(sep_right)

		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		_content.add_child(grid)

		for prof_id in prof_ids:
			var btn: Control = _build_prof_button(prof_id)
			grid.add_child(btn)


func _get_prof_ids_in_category(category: String) -> Array:
	var result: Array = []
	for prof_id in ProficiencyDatabase.SKILLS:
		if ProficiencyDatabase.SKILLS[prof_id].get("category", "") == category:
			result.append(prof_id)
	return result


func _build_prof_button(prof_id: String) -> Control:
	if not _progression:
		var fallback := Label.new()
		fallback.text = prof_id
		return fallback

	var xp_data: Dictionary = _progression.get_proficiency_xp(prof_id)
	var level: int = xp_data.get("level", 1)
	var xp: int = xp_data.get("xp", 0)
	var xp_to_next: int = xp_data.get("xp_to_next", 50)
	var is_max: bool = level >= ProficiencyDatabase.MAX_LEVEL
	var ratio: float = 1.0 if is_max else (float(xp) / float(xp_to_next) if xp_to_next > 0 else 0.0)

	var prof_def: Dictionary = ProficiencyDatabase.get_skill(prof_id)
	var display_name: String = prof_def.get("name", prof_id)
	var label_text: String = "%s Lv. %d" % [display_name, level] if not is_max else "%s MAX" % display_name

	var is_equipped: bool = _combat != null and prof_id == _combat.get_equipped_weapon_type()

	# Compute width from content: icon(24) + separation(4) + text + padding(12)
	var font: Font = ThemeDB.fallback_font
	var text_width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var btn_width: float = 8 + 24 + 4 + text_width + 8

	var container := Control.new()
	container.custom_minimum_size = Vector2(btn_width, 36)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_prof_button_input.bind(prof_id))

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(btn_width, 36)
	progress.max_value = 1.0
	progress.value = ratio
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.18)
	var border_color: Color = Color(1.0, 0.85, 0.3) if is_equipped else Color(0.3, 0.3, 0.35)
	bg_style.border_color = border_color
	bg_style.set_border_width_all(2 if is_equipped else 1)
	bg_style.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.4, 0.35, 0.15) if is_max else Color(0.2, 0.35, 0.55)
	fill_style.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("fill", fill_style)

	container.add_child(progress)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 4)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.offset_left = 8

	var icon := TextureRect.new()
	icon.texture = load("res://assets/textures/ui/proficiencies/" + prof_id + ".png")
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if is_max else Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(label)

	container.add_child(hbox)

	return container


func _on_prof_button_input(event: InputEvent, prof_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_detail(prof_id)


# --- Detail View ---

func _build_detail(prof_id: String) -> void:
	if not _progression:
		return

	# Back button
	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(80, 28)
	back_btn.add_theme_font_size_override("font_size", 12)
	back_btn.pressed.connect(_show_grid)
	_content.add_child(back_btn)

	var prof_def: Dictionary = ProficiencyDatabase.get_skill(prof_id)
	var xp_data: Dictionary = _progression.get_proficiency_xp(prof_id)
	var level: int = xp_data.get("level", 1)
	var xp: int = xp_data.get("xp", 0)
	var xp_to_next: int = xp_data.get("xp_to_next", 50)
	var is_max: bool = level >= ProficiencyDatabase.MAX_LEVEL
	var display_name: String = prof_def.get("name", prof_id)

	# Proficiency name + icon + level
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	_content.add_child(title_row)

	var title_icon := TextureRect.new()
	title_icon.texture = load("res://assets/textures/ui/proficiencies/" + prof_id + ".png")
	title_icon.custom_minimum_size = Vector2(32, 32)
	title_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_icon.texture_filter = TEXTURE_FILTER_LINEAR
	title_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(title_icon)

	var name_label := Label.new()
	name_label.text = display_name + " Proficiency"
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if is_max else Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)

	var level_label := Label.new()
	level_label.text = "MAX" if is_max else "Lv. %d" % level
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if is_max else Color(0.8, 0.8, 0.8))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.custom_minimum_size.x = 52
	title_row.add_child(level_label)

	# XP progress bar + text
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	_content.add_child(bar_row)

	var xp_bar := ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(120, 14)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.max_value = xp_to_next if not is_max else 1
	xp_bar.value = xp if not is_max else 1
	xp_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.2)
	UIHelper.set_corner_radius(bar_bg, 2)
	xp_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.4, 0.35, 0.15) if is_max else Color(0.3, 0.6, 1.0)
	UIHelper.set_corner_radius(bar_fill, 2)
	xp_bar.add_theme_stylebox_override("fill", bar_fill)
	bar_row.add_child(xp_bar)

	var xp_text := Label.new()
	xp_text.text = "MAX" if is_max else "%d/%d XP" % [xp, xp_to_next]
	xp_text.add_theme_font_size_override("font_size", 11)
	xp_text.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if is_max else Color(0.6, 0.6, 0.6))
	xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_text.custom_minimum_size.x = 70
	bar_row.add_child(xp_text)

	_content.add_child(HSeparator.new())

	# Skills section — weapon proficiencies only
	var category: String = prof_def.get("category", "")
	if category == "weapon":
		_build_weapon_skills_section(prof_id)
	else:
		var desc_label := Label.new()
		desc_label.text = prof_def.get("description", "")
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(desc_label)


func _build_weapon_skills_section(weapon_type: String) -> void:
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
