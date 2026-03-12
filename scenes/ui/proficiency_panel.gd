extends Control
## RuneScape-style proficiency skill list panel toggled with P key.

const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

const CATEGORY_DISPLAY_NAMES: Dictionary = {
	"weapon": "Combat",
	"attribute": "Attributes",
	"gathering": "Gathering",
	"production": "Production",
}

# Category display order (matches CATEGORIES in ProficiencyDatabase)
const CATEGORY_ORDER: Array = ["weapon", "attribute", "gathering", "production"]

var _panel: PanelContainer
var _is_open: bool = false
var _player: Node

var _total_level_label: Label
var _skill_list: VBoxContainer
var _xp_info_label: Label


func set_player(p: Node) -> void:
	_player = p


func _ready() -> void:
	visible = false
	_build_ui()
	GameEvents.proficiency_xp_gained.connect(_on_proficiency_changed)
	GameEvents.proficiency_level_up.connect(_on_proficiency_level_up)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(280, 420)
	_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# Draggable title bar
	var drag_handle := DragHandle.new()
	drag_handle.setup(_panel, "Proficiencies")
	drag_handle.close_pressed.connect(toggle)
	vbox.add_child(drag_handle)

	# Total level label
	_total_level_label = Label.new()
	_total_level_label.text = "Total Level: --"
	_total_level_label.add_theme_font_size_override("font_size", 15)
	_total_level_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	vbox.add_child(_total_level_label)

	vbox.add_child(HSeparator.new())

	# Scrollable skill list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 260)
	vbox.add_child(scroll)

	_skill_list = VBoxContainer.new()
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_skill_list)

	vbox.add_child(HSeparator.new())

	# XP info label — shows details when a skill row is clicked
	_xp_info_label = Label.new()
	_xp_info_label.text = ""
	_xp_info_label.add_theme_font_size_override("font_size", 13)
	_xp_info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_xp_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_info_label.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(_xp_info_label)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_proficiencies"):
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle()


func toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		UIHelper.center_panel(_panel)
		_refresh()


func _refresh() -> void:
	if not _is_open or not _player:
		return

	var prog := _player.get_node_or_null("ProgressionComponent")
	if not prog:
		return

	# Update total level
	var total_level: int = prog.get_total_level()
	var max_total: int = ProficiencyDatabase.MAX_LEVEL * ProficiencyDatabase.SKILLS.size()
	_total_level_label.text = "Total Level: %d/%d" % [total_level, max_total]

	# Rebuild skill list
	for child in _skill_list.get_children():
		child.queue_free()

	for category in CATEGORY_ORDER:
		var display_name: String = CATEGORY_DISPLAY_NAMES.get(category, category.capitalize())
		var skills_in_cat: Dictionary = ProficiencyDatabase.get_skills_by_category(category)
		if skills_in_cat.is_empty():
			continue

		# Category header
		var header := Label.new()
		header.text = "-- %s --" % display_name
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_skill_list.add_child(header)

		# Skill rows
		for skill_id in skills_in_cat:
			var skill_def: Dictionary = ProficiencyDatabase.get_skill(skill_id)
			var level: int = prog.get_proficiency_level(skill_id)
			var is_max: bool = level >= ProficiencyDatabase.MAX_LEVEL

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			_skill_list.add_child(row)

			var name_label := Label.new()
			name_label.text = "  " + skill_def.get("name", skill_id)
			name_label.add_theme_font_size_override("font_size", 14)
			name_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if is_max else Color.WHITE)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)

			var level_label := Label.new()
			level_label.text = str(level)
			level_label.add_theme_font_size_override("font_size", 14)
			level_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if is_max else Color.WHITE)
			level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			level_label.custom_minimum_size.x = 24
			row.add_child(level_label)

			# Click to show XP info — store skill_id in a closure
			var btn := Button.new()
			btn.text = "?"
			btn.custom_minimum_size = Vector2(22, 22)
			btn.add_theme_font_size_override("font_size", 11)
			btn.pressed.connect(_show_xp_info.bind(skill_id))
			row.add_child(btn)


func _show_xp_info(skill_id: String) -> void:
	if not _player:
		return
	var prog := _player.get_node_or_null("ProgressionComponent")
	if not prog:
		return

	var xp_data: Dictionary = prog.get_proficiency_xp(skill_id)
	var skill_def: Dictionary = ProficiencyDatabase.get_skill(skill_id)
	var skill_name: String = skill_def.get("name", skill_id)
	var level: int = xp_data.get("level", 1)
	var xp: int = xp_data.get("xp", 0)
	var xp_to_next: int = xp_data.get("xp_to_next", 50)

	if level >= ProficiencyDatabase.MAX_LEVEL:
		_xp_info_label.text = "%s: MAX LEVEL" % skill_name
		_xp_info_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	else:
		_xp_info_label.text = "%s: %d/%d XP (Lv %d)" % [skill_name, xp, xp_to_next, level]
		_xp_info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))


func _on_proficiency_changed(entity_id: String, _skill_id: String, _amount: int, _new_xp: int) -> void:
	# Only refresh for the player entity
	if not _is_open:
		return
	if not _player:
		return
	var player_entity_id: String = _player.get("entity_id") if "entity_id" in _player else ""
	if entity_id == player_entity_id or player_entity_id.is_empty():
		_refresh()


func _on_proficiency_level_up(entity_id: String, _skill_id: String, _new_level: int) -> void:
	if not _is_open:
		return
	if not _player:
		return
	var player_entity_id: String = _player.get("entity_id") if "entity_id" in _player else ""
	if entity_id == player_entity_id or player_entity_id.is_empty():
		_refresh()


func is_open() -> bool:
	return _is_open
