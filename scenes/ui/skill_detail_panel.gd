extends Control
## Tooltip-style popup showing detailed info for a single skill.
## Appears on hover over skill rows in the proficiency panel.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")
const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")

const TYPE_DISPLAY: Dictionary = {
	"melee_attack": "Melee Attack",
	"aoe_melee":    "Area Attack",
	"armor_pierce": "Armor Pierce",
	"bleed":        "Bleed",
}

var _player: Node
var _progression: Node
var _skills_comp: Node
var _panel: PanelContainer
var _content: VBoxContainer
var _current_skill_id: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(player: Node) -> void:
	_player = player
	_progression = player.get_node_or_null("ProgressionComponent")
	_skills_comp = player.get_node_or_null("SkillsComponent")


func show_skill(skill_id: String, anchor_pos: Vector2) -> void:
	if skill_id == _current_skill_id and visible:
		return
	_current_skill_id = skill_id
	_rebuild(skill_id)
	visible = true
	# Position to the right of the anchor
	if _panel:
		await get_tree().process_frame
		_panel.position = anchor_pos


func hide_skill() -> void:
	visible = false
	_current_skill_id = ""


func _rebuild(skill_id: String) -> void:
	if _panel:
		_panel.queue_free()
		_panel = null

	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.07, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.38, 0.25, 0.8)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(280, 0)
	add_child(_panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_panel.add_child(_content)

	if not _skills_comp or not _progression:
		return

	var skill: Dictionary = SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		return

	var skill_level: int = _skills_comp.get_skill_level(skill_id)
	var eff_percent: int = SkillDatabase.get_total_effectiveness_percent(skill_id, _progression)
	var primary: Dictionary = SkillDatabase.get_primary_proficiency(skill_id)

	_build_header(skill_id, skill, skill_level, eff_percent)
	_build_base_stats(skill_id, skill, skill_level)
	_add_separator()
	_build_primary_proficiency(skill_id, primary)
	_build_secondary_proficiencies(skill_id)

	if eff_percent < 30:
		_add_separator()
		_build_danger_warning(eff_percent)


# --- Section builders ---

func _build_header(skill_id: String, skill: Dictionary, skill_level: int, eff_percent: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content.add_child(row)

	# Skill icon 24x24
	var icon_texture: Texture2D = _load_skill_icon(skill_id)
	if icon_texture:
		var icon: TextureRect = TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

	var name_label: Label = Label.new()
	name_label.text = skill.get("name", skill_id)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", _effectiveness_color(eff_percent))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)

	var eff_label: Label = Label.new()
	eff_label.text = "%d%%" % eff_percent
	eff_label.add_theme_font_size_override("font_size", 13)
	eff_label.add_theme_color_override("font_color", _effectiveness_color(eff_percent))
	eff_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(eff_label)

	# Description
	var desc: String = skill.get("description", "")
	if not desc.is_empty():
		var desc_label: Label = Label.new()
		desc_label.text = desc
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(desc_label)

	_add_separator()


func _build_base_stats(skill_id: String, skill: Dictionary, skill_level: int) -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	_content.add_child(grid)

	var preview_level: int = maxi(1, skill_level)
	var eff_mult: float = SkillDatabase.get_effective_multiplier(skill_id, preview_level)
	var eff_cd: float = SkillDatabase.get_effective_cooldown(skill_id, preview_level)
	var skill_type: String = skill.get("type", "")

	_add_grid_row(grid, "DMG:", "%d%%" % roundi(eff_mult * 100), Color(0.9, 0.5, 0.3))
	_add_grid_row(grid, "CD:", "%.1fs" % eff_cd, Color(0.5, 0.7, 0.9))
	_add_grid_row(grid, "Type:", TYPE_DISPLAY.get(skill_type, skill_type), Color(0.7, 0.7, 0.7))

	if skill_type == "aoe_melee":
		var radius: float = skill.get("aoe_radius", 0.0)
		_add_grid_row(grid, "Radius:", "%.1fm" % radius, Color(0.8, 0.6, 0.9))
	elif skill_type == "bleed":
		var ticks: int = skill.get("bleed_ticks", 0)
		var duration: float = skill.get("bleed_duration", 0.0)
		_add_grid_row(grid, "Bleed:", "%d ticks / %.1fs" % [ticks, duration], Color(0.8, 0.3, 0.3))
	elif skill_type == "armor_pierce":
		var ignore_pct: float = skill.get("def_ignore_percent", 0.0)
		_add_grid_row(grid, "Pierce:", "%d%% DEF" % roundi(ignore_pct * 100), Color(0.9, 0.7, 0.3))


func _build_primary_proficiency(_skill_id: String, primary: Dictionary) -> void:
	var prof_id: String = primary.get("skill", "")
	var req_level: int = primary.get("level", 1)
	if prof_id.is_empty():
		return

	var current_level: int = _progression.get_proficiency_level(prof_id)
	var met: bool = current_level >= req_level
	var prof_def: Dictionary = ProficiencyDatabase.get_skill(prof_id)
	var display_name: String = prof_def.get("name", prof_id)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content.add_child(row)

	var label: Label = Label.new()
	label.text = "%s Lv. %d/%d" % [display_name, current_level, req_level]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3) if met else Color(0.8, 0.4, 0.3))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var marker: Label = Label.new()
	marker.text = "+" if met else "x"
	marker.add_theme_font_size_override("font_size", 11)
	marker.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3) if met else Color(0.9, 0.3, 0.3))
	row.add_child(marker)


func _build_secondary_proficiencies(skill_id: String) -> void:
	var secondaries: Array = SkillDatabase.get_secondary_synergies(skill_id)
	if secondaries.is_empty():
		return

	for entry in secondaries:
		var prof_id: String = entry.get("skill", "")
		var bonus_type: String = entry.get("bonus_type", "")
		var weight: float = entry.get("weight", 0.0)
		if prof_id.is_empty():
			continue

		var current_level: int = _progression.get_proficiency_level(prof_id)
		var prof_def: Dictionary = ProficiencyDatabase.get_skill(prof_id)
		var display_name: String = prof_def.get("name", prof_id)
		var computed_value: float = (current_level / 10.0) * weight * 100.0
		var bonus_label_text: String = SkillDatabase.BONUS_TYPE_LABELS.get(bonus_type, bonus_type)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_content.add_child(row)

		var lbl: Label = Label.new()
		lbl.text = "%s: %s +%.1f%%" % [display_name, bonus_label_text, computed_value]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		row.add_child(lbl)


func _build_danger_warning(eff_percent: int) -> void:
	var warn_label: Label = Label.new()
	warn_label.text = "! Risk of self-harm (%d%%)" % eff_percent
	warn_label.add_theme_font_size_override("font_size", 11)
	warn_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_content.add_child(warn_label)


# --- Helpers ---

func _add_separator() -> void:
	_content.add_child(HSeparator.new())


func _add_grid_row(grid: GridContainer, label_text: String, value_text: String, value_color: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.38))
	grid.add_child(lbl)

	var val: Label = Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 11)
	val.add_theme_color_override("font_color", value_color)
	grid.add_child(val)


func _load_skill_icon(skill_id: String) -> Texture2D:
	var path: String = "res://assets/textures/ui/skills/" + skill_id + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var category: String = SkillDatabase.get_skill_category(skill_id)
	var base_path: String = "res://assets/textures/ui/skills/bases/" + category + "_base.png"
	if ResourceLoader.exists(base_path):
		return load(base_path) as Texture2D
	return null


func _effectiveness_color(eff_percent: int) -> Color:
	if eff_percent >= 100:
		return Color(0.9, 0.85, 0.5)
	elif eff_percent >= 70:
		return Color.WHITE
	elif eff_percent >= 30:
		return Color(0.9, 0.65, 0.3)
	else:
		return Color(0.85, 0.35, 0.35)
