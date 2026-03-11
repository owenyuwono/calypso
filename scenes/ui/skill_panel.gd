extends Control
## Skill learning/upgrading panel toggled with S key.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

var _panel: PanelContainer
var _is_open: bool = false
var _sp_label: Label
var _skill_list: VBoxContainer

func _ready() -> void:
	visible = false
	_build_ui()
	GameEvents.level_up.connect(func(_a, _b): _refresh())
	GameEvents.skill_learned.connect(func(_a, _b, _c): _refresh())

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 400)

	_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# Draggable title bar
	var drag_handle := DragHandle.new()
	drag_handle.setup(_panel, "Skills")
	drag_handle.close_pressed.connect(toggle)
	vbox.add_child(drag_handle)

	# Skill points label
	_sp_label = Label.new()
	_sp_label.add_theme_font_size_override("font_size", 15)
	_sp_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(_sp_label)

	vbox.add_child(HSeparator.new())

	# Scrollable skill list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	vbox.add_child(scroll)

	_skill_list = VBoxContainer.new()
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_skill_list)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_skills"):
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle()

func toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		_center_panel()
		_refresh()

func _center_panel() -> void:
	UIHelper.center_panel(_panel)

func _refresh() -> void:
	if not _is_open:
		return

	# Clear old rows
	for child in _skill_list.get_children():
		child.queue_free()

	var data := WorldState.get_entity_data("player")
	var sp: int = data.get("skill_points", 0)
	var player_level: int = data.get("level", 1)
	var learned_skills: Dictionary = data.get("skills", {})

	_sp_label.text = "Skill Points: %d" % sp

	for skill_id in SkillDatabase.SKILLS:
		var skill: Dictionary = SkillDatabase.SKILLS[skill_id]
		var current_level: int = learned_skills.get(skill_id, 0)
		var max_level: int = skill.get("max_level", 5)
		var required_level: int = skill.get("required_level", 1)
		var skill_color: Color = skill.get("color", Color.WHITE)
		var meets_level := player_level >= required_level

		var row_vbox := VBoxContainer.new()
		row_vbox.add_theme_constant_override("separation", 2)
		_skill_list.add_child(row_vbox)

		# Row 1: Name | Level | Learn/Upgrade button
		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		row_vbox.add_child(top_row)

		var name_label := Label.new()
		name_label.text = skill.get("name", skill_id)
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", skill_color if meets_level else Color(0.5, 0.5, 0.5))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(name_label)

		var level_label := Label.new()
		level_label.text = "Lv. %d/%d" % [current_level, max_level]
		level_label.add_theme_font_size_override("font_size", 13)
		level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		top_row.add_child(level_label)

		var btn := Button.new()
		if current_level <= 0:
			btn.text = "Learn"
		else:
			btn.text = "Upgrade"
		btn.disabled = sp <= 0 or current_level >= max_level or not meets_level
		btn.pressed.connect(_learn_skill.bind(skill_id))
		top_row.add_child(btn)

		# Row 2: Description
		var desc_label := Label.new()
		desc_label.text = skill.get("description", "")
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row_vbox.add_child(desc_label)

		# Row 3: Stats preview
		var preview_level := maxi(1, current_level)
		var mult := SkillDatabase.get_effective_multiplier(skill_id, preview_level)
		var cd := SkillDatabase.get_effective_cooldown(skill_id, preview_level)
		var stats_text := "DMG: %d%% | CD: %.1fs" % [roundi(mult * 100), cd]
		if not meets_level:
			stats_text = "Requires Lv. %d" % required_level

		var stats_label := Label.new()
		stats_label.text = stats_text
		stats_label.add_theme_font_size_override("font_size", 12)
		stats_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5) if meets_level else Color(0.7, 0.3, 0.3))
		row_vbox.add_child(stats_label)

		# Row 4: Hotbar assignment (only if learned)
		if current_level > 0:
			var hotbar_row := HBoxContainer.new()
			hotbar_row.add_theme_constant_override("separation", 4)
			row_vbox.add_child(hotbar_row)

			var hotbar_label := Label.new()
			hotbar_label.text = "Hotbar:"
			hotbar_label.add_theme_font_size_override("font_size", 12)
			hotbar_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			hotbar_row.add_child(hotbar_label)

			var hotbar: Array = WorldState.get_hotbar("player")
			for slot_i in range(5):
				var slot_btn := Button.new()
				slot_btn.text = str(slot_i + 1)
				slot_btn.custom_minimum_size = Vector2(28, 24)
				slot_btn.add_theme_font_size_override("font_size", 11)
				# Highlight current assignment
				if slot_i < hotbar.size() and hotbar[slot_i] == skill_id:
					var active_style := StyleBoxFlat.new()
					active_style.bg_color = Color(0.3, 0.25, 0.1, 0.9)
					active_style.border_color = Color(1, 0.85, 0.3)
					active_style.border_width_left = 1
					active_style.border_width_right = 1
					active_style.border_width_top = 1
					active_style.border_width_bottom = 1
					active_style.corner_radius_top_left = 3
					active_style.corner_radius_top_right = 3
					active_style.corner_radius_bottom_left = 3
					active_style.corner_radius_bottom_right = 3
					slot_btn.add_theme_stylebox_override("normal", active_style)
				slot_btn.pressed.connect(_assign_hotbar.bind(slot_i, skill_id))
				hotbar_row.add_child(slot_btn)

func _learn_skill(skill_id: String) -> void:
	WorldState.learn_skill("player", skill_id)
	_refresh()

func _assign_hotbar(slot: int, skill_id: String) -> void:
	WorldState.set_hotbar_slot("player", slot, skill_id)
	_refresh()
	# Refresh the hotbar UI
	var hotbar_node := get_parent().get_node_or_null("SkillHotbar")
	if hotbar_node and hotbar_node.has_method("refresh"):
		hotbar_node.refresh()

func is_open() -> bool:
	return _is_open
