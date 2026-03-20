extends Control
## Skills & Proficiencies panel — sidebar layout.
## Left sidebar: proficiency list grouped by category.
## Right content: proficiency info + skills for selected proficiency.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")
const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")


## Drag source for skill rows. Wraps skill content and provides drag data.
class SkillDragSource extends PanelContainer:
	var skill_id: String = ""
	var skill_name: String = ""

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview := PanelContainer.new()
		var preview_style := StyleBoxFlat.new()
		preview_style.bg_color = Color(0.1, 0.09, 0.07, 0.95)
		UIHelper.set_corner_radius(preview_style, 4)
		UIHelper.set_border_width(preview_style, 1)
		preview_style.border_color = UIHelper.COLOR_GOLD
		preview.add_theme_stylebox_override("panel", preview_style)
		var label := Label.new()
		label.text = skill_name
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
		preview.add_child(label)
		set_drag_preview(preview)
		return {"skill_id": skill_id, "type": "skill_drag"}

const CATEGORY_LABELS: Dictionary = {
	"weapon": "WEAPON",
	"attribute": "ATTRIBUTES",
	"gathering": "GATHERING",
	"production": "PRODUCTION",
}

var _panel: PanelContainer
var _is_open: bool = false
var _player: Node
var _combat: Node
var _progression: Node
var _skills_comp: Node

var _selected_prof_id: String = "sword"
var _sidebar: VBoxContainer
var _right_content: VBoxContainer
var _detail_panel: Control = null


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
	var ui: Dictionary = UIHelper.create_titled_panel("Proficiencies & Skills", Vector2(600, 480), toggle)
	_panel = ui["panel"]
	add_child(_panel)

	var vbox: VBoxContainer = ui["vbox"]

	vbox.add_child(HSeparator.new())

	# Main horizontal split
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 0)
	vbox.add_child(hbox)

	# --- Left sidebar ---
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.custom_minimum_size = Vector2(150, 0)
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(sidebar_scroll)

	var sidebar_margin: MarginContainer = MarginContainer.new()
	sidebar_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_margin.add_theme_constant_override("margin_left", 4)
	sidebar_margin.add_theme_constant_override("margin_right", 6)
	sidebar_margin.add_theme_constant_override("margin_top", 4)
	sidebar_margin.add_theme_constant_override("margin_bottom", 4)
	sidebar_scroll.add_child(sidebar_margin)

	_sidebar = VBoxContainer.new()
	_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar.add_theme_constant_override("separation", 4)
	sidebar_margin.add_child(_sidebar)

	# --- Vertical divider ---
	hbox.add_child(VSeparator.new())

	# --- Right content ---
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(right_scroll)

	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 12)
	right_margin.add_theme_constant_override("margin_right", 12)
	right_margin.add_theme_constant_override("margin_top", 12)
	right_margin.add_theme_constant_override("margin_bottom", 12)
	right_scroll.add_child(right_margin)

	_right_content = VBoxContainer.new()
	_right_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_content.add_theme_constant_override("separation", 6)
	right_margin.add_child(_right_content)


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
		_refresh()
	else:
		if _detail_panel:
			_detail_panel.hide_skill()


func is_open() -> bool:
	return _is_open


func _refresh() -> void:
	if not _is_open or not _player:
		return
	_build_sidebar()
	_build_right_content(_selected_prof_id)


# --- Sidebar ---

func _build_sidebar() -> void:
	for child in _sidebar.get_children():
		child.queue_free()

	for category in ProficiencyDatabase.CATEGORIES:
		var prof_ids: Array = _get_prof_ids_in_category(category)
		if prof_ids.is_empty():
			continue

		# Category label
		var cat_label := Label.new()
		cat_label.text = CATEGORY_LABELS.get(category, category.to_upper())
		cat_label.add_theme_font_size_override("font_size", 11)
		cat_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
		cat_label.add_theme_constant_override("margin_top", 4)
		_sidebar.add_child(cat_label)

		for prof_id in prof_ids:
			_sidebar.add_child(_build_sidebar_entry(prof_id))

		_sidebar.add_child(HSeparator.new())


func _build_sidebar_entry(prof_id: String) -> Control:
	var is_selected: bool = prof_id == _selected_prof_id

	var level: int = 1
	var xp_percent: float = 0.0
	if _progression:
		var xp_data: Dictionary = _progression.get_proficiency_xp(prof_id)
		level = xp_data.get("level", 1)
		var xp: int = xp_data.get("xp", 0)
		var xp_next: int = xp_data.get("xp_to_next", 1)
		if level >= ProficiencyDatabase.MAX_LEVEL:
			xp_percent = 1.0
		elif xp_next > 0:
			xp_percent = clampf(float(xp) / float(xp_next), 0.0, 1.0)

	var prof_def: Dictionary = ProficiencyDatabase.get_skill(prof_id)
	var display_name: String = prof_def.get("name", prof_id)
	var is_max: bool = level >= ProficiencyDatabase.MAX_LEVEL

	# Outer container — holds the progress bar background + content overlay
	var wrapper: Control = Control.new()
	wrapper.custom_minimum_size = Vector2(0, 30)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.gui_input.connect(_on_prof_entry_input.bind(prof_id, wrapper))
	wrapper.mouse_entered.connect(_on_sidebar_hover.bind(wrapper, true))
	wrapper.mouse_exited.connect(_on_sidebar_hover.bind(wrapper, false))

	# Button background (PanelContainer styled)
	var bg_panel: PanelContainer = PanelContainer.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	if is_selected:
		bg_style.bg_color = Color(0.18, 0.15, 0.08, 0.9)
		bg_style.set_border_width_all(1)
		bg_style.border_color = UIHelper.COLOR_GOLD
	else:
		bg_style.bg_color = Color(0.12, 0.11, 0.09, 0.7)
		bg_style.set_border_width_all(1)
		bg_style.border_color = Color(0.3, 0.28, 0.22, 0.5)
	UIHelper.set_corner_radius(bg_style, 3)
	bg_style.set_content_margin_all(0)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	wrapper.add_child(bg_panel)

	# Progress bar fill (drawn over background, under content)
	var fill: ColorRect = ColorRect.new()
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.anchor_right = xp_percent
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_max:
		fill.color = Color(0.6, 0.5, 0.15, 0.3)
	elif is_selected:
		fill.color = Color(0.35, 0.28, 0.1, 0.4)
	else:
		fill.color = Color(0.2, 0.18, 0.1, 0.3)
	wrapper.add_child(fill)

	# Content row (icon + name + level) on top of fill
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Padding
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	wrapper.add_child(margin)

	# Icon (20x20)
	var icon_path: String = "res://assets/textures/ui/proficiencies/" + prof_id + ".png"
	if ResourceLoader.exists(icon_path):
		var icon: TextureRect = TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

	# Name label
	var name_label: Label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 12)
	var name_color: Color
	if is_selected:
		name_color = UIHelper.COLOR_GOLD
	elif is_max:
		name_color = Color(0.9, 0.85, 0.6)
	else:
		name_color = Color(0.78, 0.75, 0.68)
	name_label.add_theme_color_override("font_color", name_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	# Level label (right-aligned)
	var level_label: Label = Label.new()
	level_label.text = "MAX" if is_max else str(level)
	level_label.add_theme_font_size_override("font_size", 12)
	var level_color: Color
	if is_max:
		level_color = UIHelper.COLOR_GOLD
	elif is_selected:
		level_color = Color(0.9, 0.85, 0.7)
	else:
		level_color = Color(0.6, 0.58, 0.5)
	level_label.add_theme_color_override("font_color", level_color)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(level_label)

	# Store references for hover state
	wrapper.set_meta("bg_style", bg_style)
	wrapper.set_meta("is_selected", is_selected)

	return wrapper


func _on_sidebar_hover(wrapper: Control, hovered: bool) -> void:
	var bg_style: StyleBoxFlat = wrapper.get_meta("bg_style") as StyleBoxFlat
	var is_selected: bool = wrapper.get_meta("is_selected") as bool
	if not bg_style:
		return
	if is_selected:
		return  # Selected state doesn't change on hover
	if hovered:
		bg_style.bg_color = Color(0.18, 0.16, 0.1, 0.85)
		bg_style.border_color = Color(0.5, 0.45, 0.3, 0.7)
	else:
		bg_style.bg_color = Color(0.12, 0.11, 0.09, 0.7)
		bg_style.border_color = Color(0.3, 0.28, 0.22, 0.5)


func _on_prof_entry_input(event: InputEvent, prof_id: String, wrapper: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_animate_click(wrapper, prof_id)


func _animate_click(wrapper: Control, prof_id: String) -> void:
	wrapper.pivot_offset = wrapper.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(wrapper, "scale", Vector2(0.93, 0.93), 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(wrapper, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(_on_prof_selected.bind(prof_id)).set_delay(0.0)


func _on_prof_selected(prof_id: String) -> void:
	_selected_prof_id = prof_id
	_build_sidebar()
	_build_right_content(prof_id)


# --- Right content ---

func _build_right_content(prof_id: String) -> void:
	for child in _right_content.get_children():
		child.queue_free()

	if not _progression:
		return

	var prof_def: Dictionary = ProficiencyDatabase.get_skill(prof_id)
	var xp_data: Dictionary = _progression.get_proficiency_xp(prof_id)
	var level: int = xp_data.get("level", 1)
	var xp: int = xp_data.get("xp", 0)
	var xp_to_next: int = xp_data.get("xp_to_next", 50)
	var is_max: bool = level >= ProficiencyDatabase.MAX_LEVEL
	var display_name: String = prof_def.get("name", prof_id)

	# --- Proficiency header row: icon + name + level ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_right_content.add_child(header)

	var icon_path: String = "res://assets/textures/ui/proficiencies/" + prof_id + ".png"
	if ResourceLoader.exists(icon_path):
		var title_icon: TextureRect = TextureRect.new()
		title_icon.texture = load(icon_path)
		title_icon.custom_minimum_size = Vector2(24, 24)
		title_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_icon.texture_filter = TEXTURE_FILTER_LINEAR
		title_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(title_icon)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if is_max else Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var level_label := Label.new()
	level_label.text = "MAX" if is_max else "Lv. %d" % level
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if is_max else Color(0.8, 0.8, 0.8))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.custom_minimum_size.x = 52
	header.add_child(level_label)

	# --- XP bar row ---
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	_right_content.add_child(bar_row)

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

	_right_content.add_child(HSeparator.new())

	# --- Skills or description ---
	var category: String = prof_def.get("category", "")
	if category == "weapon":
		_build_weapon_skills_section(prof_id)
	else:
		var desc_label := Label.new()
		desc_label.text = prof_def.get("description", "")
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_right_content.add_child(desc_label)


func _build_weapon_skills_section(weapon_type: String) -> void:
	var skill_ids: Array = SkillDatabase.get_skills_for_proficiency(weapon_type)
	if skill_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No skills for this weapon type."
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
		_right_content.add_child(empty_label)
		return

	for skill_id in skill_ids:
		_build_skill_row(skill_id)
		_right_content.add_child(HSeparator.new())


func _build_skill_row(skill_id: String) -> void:
	if not _skills_comp or not _progression:
		return

	var skill: Dictionary = SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		return
	var skill_color: Color = skill.get("color", Color.WHITE)
	var eff_percent: int = SkillDatabase.get_total_effectiveness_percent(skill_id, _progression)

	# Drag source wrapper — outer container receives drag and hover
	var drag_source: SkillDragSource = SkillDragSource.new()
	drag_source.skill_id = skill_id
	drag_source.skill_name = skill.get("name", skill_id)
	drag_source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drag_source.mouse_filter = Control.MOUSE_FILTER_STOP

	var row_default_style: StyleBoxFlat = StyleBoxFlat.new()
	row_default_style.bg_color = Color(0.12, 0.11, 0.09, 0.0)
	row_default_style.set_border_width_all(1)
	row_default_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	UIHelper.set_corner_radius(row_default_style, 3)
	drag_source.add_theme_stylebox_override("panel", row_default_style)
	drag_source.set_meta("bg_style", row_default_style)

	drag_source.mouse_entered.connect(_on_skill_row_hover.bind(drag_source, skill_id))
	drag_source.mouse_exited.connect(_on_skill_row_unhover.bind(drag_source, skill_id))
	_right_content.add_child(drag_source)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_source.add_child(row)

	# Icon (24x24)
	var icon_path: String = "res://assets/textures/ui/skills/" + skill_id + ".png"
	var icon_texture: Texture2D = null
	if ResourceLoader.exists(icon_path):
		icon_texture = load(icon_path)
	else:
		var skill_category: String = SkillDatabase.get_skill_category(skill_id)
		var base_path: String = "res://assets/textures/ui/skills/bases/" + skill_category + "_base.png"
		if ResourceLoader.exists(base_path):
			icon_texture = load(base_path)
	if icon_texture:
		var skill_icon: TextureRect = TextureRect.new()
		skill_icon.texture = icon_texture
		skill_icon.custom_minimum_size = Vector2(24, 24)
		skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		skill_icon.texture_filter = TEXTURE_FILTER_LINEAR
		skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(skill_icon)

	# Name + description vertical stack
	var name_col: VBoxContainer = VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 1)
	name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_col)

	var name_label: Label = Label.new()
	name_label.text = skill.get("name", skill_id)
	name_label.add_theme_font_size_override("font_size", 14)
	var name_color: Color = skill_color
	if eff_percent < 70:
		name_color = skill_color.lerp(Color(0.5, 0.5, 0.5), 0.5)
	name_label.add_theme_color_override("font_color", name_color)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.add_child(name_label)

	var desc_label: Label = Label.new()
	desc_label.text = skill.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.add_child(desc_label)

	# Effectiveness %
	var eff_label: Label = Label.new()
	eff_label.text = str(eff_percent) + "%"
	eff_label.add_theme_font_size_override("font_size", 14)
	var eff_color: Color
	if eff_percent >= 100:
		eff_color = Color(0.3, 1.0, 0.3)
	elif eff_percent >= 70:
		eff_color = Color(1.0, 1.0, 0.3)
	elif eff_percent >= 30:
		eff_color = Color(1.0, 0.6, 0.2)
	else:
		eff_color = Color(1.0, 0.2, 0.2)
	eff_label.add_theme_color_override("font_color", eff_color)
	eff_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eff_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(eff_label)


func _on_skill_row_hover(drag_source: Control, skill_id: String) -> void:
	var bg_style: StyleBoxFlat = drag_source.get_meta("bg_style") as StyleBoxFlat
	if bg_style:
		bg_style.bg_color = Color(0.18, 0.16, 0.13)
		bg_style.border_color = Color(0.7, 0.6, 0.3, 0.5)
	if not _detail_panel:
		var DetailPanel: GDScript = preload("res://scenes/ui/skill_detail_panel.gd")
		_detail_panel = DetailPanel.new()
		_detail_panel.setup(_player)
		get_tree().root.add_child(_detail_panel)
	# Position tooltip to the right of the panel
	var row_global: Vector2 = drag_source.global_position
	var anchor_pos: Vector2 = Vector2(_panel.global_position.x + _panel.size.x + 8, row_global.y)
	_detail_panel.show_skill(skill_id, anchor_pos)


func _on_skill_row_unhover(drag_source: Control, _skill_id: String) -> void:
	var bg_style: StyleBoxFlat = drag_source.get_meta("bg_style") as StyleBoxFlat
	if bg_style:
		bg_style.bg_color = Color(0.12, 0.11, 0.09, 0.0)
		bg_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	if _detail_panel:
		_detail_panel.hide_skill()


func _get_prof_ids_in_category(category: String) -> Array:
	var result: Array = []
	for prof_id in ProficiencyDatabase.SKILLS:
		if ProficiencyDatabase.SKILLS[prof_id].get("category", "") == category:
			result.append(prof_id)
	return result


func _exit_tree() -> void:
	if _detail_panel and is_instance_valid(_detail_panel):
		_detail_panel.queue_free()
