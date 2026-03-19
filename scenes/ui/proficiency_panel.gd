extends Control
## RuneScape-style proficiency skill list panel toggled with P key.

const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")
const CATEGORY_DISPLAY_NAMES: Dictionary = {
	"weapon": "Combat",
	"attribute": "Attributes",
	"gathering": "Gathering",
	"production": "Production",
}

const CATEGORY_ORDER: Array = ["weapon", "attribute", "gathering", "production"]

var _panel: PanelContainer
var _is_open: bool = false
var _player: Node

var _total_level_label: Label
var _skill_list: VBoxContainer


func set_player(p: Node) -> void:
	_player = p


func _ready() -> void:
	visible = false
	_build_ui()
	GameEvents.proficiency_xp_gained.connect(_on_proficiency_changed)
	GameEvents.proficiency_level_up.connect(_on_proficiency_level_up)


func _build_ui() -> void:
	var ui: Dictionary = UIHelper.create_titled_panel("Proficiencies", Vector2(280, 420), toggle)
	_panel = ui["panel"]
	add_child(_panel)

	var vbox: VBoxContainer = ui["vbox"]

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
	scroll.custom_minimum_size = Vector2(0, 340)
	vbox.add_child(scroll)

	_skill_list = VBoxContainer.new()
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_skill_list)


## P key now opens the unified skill panel instead — see skill_panel.gd
#func _input(event: InputEvent) -> void:
#	if event.is_action_pressed("toggle_proficiencies"):
#		if get_viewport().gui_get_focus_owner() is LineEdit:
#			return
#		toggle()


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
			var xp_data: Dictionary = prog.get_proficiency_xp(skill_id)
			var level: int = xp_data.get("level", 1)
			var xp: int = xp_data.get("xp", 0)
			var xp_to_next: int = xp_data.get("xp_to_next", 50)
			var is_max: bool = level >= ProficiencyDatabase.MAX_LEVEL

			var row_vbox := VBoxContainer.new()
			row_vbox.add_theme_constant_override("separation", 1)
			_skill_list.add_child(row_vbox)

			# Top row: name + level
			var top_row := HBoxContainer.new()
			top_row.add_theme_constant_override("separation", 4)
			row_vbox.add_child(top_row)

			var name_label := Label.new()
			name_label.text = "  " + skill_def.get("name", skill_id)
			name_label.add_theme_font_size_override("font_size", 14)
			name_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if is_max else Color.WHITE)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top_row.add_child(name_label)

			var level_label := Label.new()
			level_label.text = "Lv. %d" % level if not is_max else "MAX"
			level_label.add_theme_font_size_override("font_size", 13)
			level_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD if is_max else Color(0.8, 0.8, 0.8))
			level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			level_label.custom_minimum_size.x = 48
			top_row.add_child(level_label)

			# XP bar
			if not is_max:
				var bar_row := HBoxContainer.new()
				bar_row.add_theme_constant_override("separation", 4)
				row_vbox.add_child(bar_row)

				# Indent spacer
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

				var xp_label := Label.new()
				xp_label.text = "%d/%d" % [xp, xp_to_next]
				xp_label.add_theme_font_size_override("font_size", 11)
				xp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
				xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				xp_label.custom_minimum_size.x = 60
				bar_row.add_child(xp_label)


func _on_proficiency_changed(entity_id: String, _skill_id: String, _amount: int, _new_xp: int) -> void:
	if not _is_open or not _player:
		return
	var player_entity_id: String = _player.get("entity_id") if "entity_id" in _player else ""
	if entity_id == player_entity_id or player_entity_id.is_empty():
		_refresh()


func _on_proficiency_level_up(entity_id: String, _skill_id: String, _new_level: int) -> void:
	if not _is_open or not _player:
		return
	var player_entity_id: String = _player.get("entity_id") if "entity_id" in _player else ""
	if entity_id == player_entity_id or player_entity_id.is_empty():
		_refresh()


func is_open() -> bool:
	return _is_open
