extends Control
## Active skill panel toggled with S key. Shows skills unlocked via proficiency milestones.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")
const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

var _panel: PanelContainer
var _is_open: bool = false
var _info_label: Label
var _skill_list: VBoxContainer
var _player: Node

func set_player(p: Node) -> void:
	_player = p

func _ready() -> void:
	visible = false
	_build_ui()
	GameEvents.skill_learned.connect(func(_a, _b, _c): _refresh())
	GameEvents.skill_used.connect(func(_a, _b): _refresh())
	GameEvents.proficiency_level_up.connect(func(_a, _b, _c): _refresh())

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
	drag_handle.setup(_panel, "Active Skills")
	drag_handle.close_pressed.connect(toggle)
	vbox.add_child(drag_handle)

	# Info label (replaces old SP label)
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_info_label)

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
		UIHelper.center_panel(_panel)
		_refresh()

func _refresh() -> void:
	if not _is_open or not _player:
		return

	for child in _skill_list.get_children():
		child.queue_free()

	var skills_comp = _player.get_node("SkillsComponent")
	var progression = _player.get_node("ProgressionComponent")
	if not skills_comp or not progression:
		return

	_info_label.text = "Skills unlock via proficiency milestones. Level up by using them."

	for skill_id in SkillDatabase.SKILLS:
		var skill: Dictionary = SkillDatabase.SKILLS[skill_id]
		var current_level: int = skills_comp.get_skill_level(skill_id)
		var max_level: int = skill.get("max_level", 5)
		var skill_color: Color = skill.get("color", Color.WHITE)

		# Check proficiency requirement
		var req: Dictionary = skill.get("required_proficiency", {})
		var req_skill: String = req.get("skill", "")
		var req_level: int = req.get("level", 1)
		var meets_req: bool = true
		if not req_skill.is_empty():
			meets_req = progression.get_proficiency_level(req_skill) >= req_level

		var row_vbox := VBoxContainer.new()
		row_vbox.add_theme_constant_override("separation", 2)
		_skill_list.add_child(row_vbox)

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

		var desc_label := Label.new()
		desc_label.text = skill.get("description", "")
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row_vbox.add_child(desc_label)

		var preview_level := maxi(1, current_level)
		var mult := SkillDatabase.get_effective_multiplier(skill_id, preview_level)
		var cd := SkillDatabase.get_effective_cooldown(skill_id, preview_level)
		var stats_text: String = "DMG: %d%% | CD: %.1fs" % [roundi(mult * 100), cd]
		var type_info: String = _get_type_info(skill)
		if not type_info.is_empty():
			stats_text += "\n" + type_info
		if not meets_req:
			var req_skill_data := ProficiencyDatabase.get_skill(req_skill)
			var req_skill_name: String = req_skill_data.get("name", req_skill)
			stats_text = "Requires %s Lv. %d" % [req_skill_name, req_level]

		var stats_label := Label.new()
		stats_label.text = stats_text
		stats_label.add_theme_font_size_override("font_size", 12)
		stats_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5) if meets_req else Color(0.7, 0.3, 0.3))
		row_vbox.add_child(stats_label)

		if current_level > 0:
			# Show XP progress for use-based leveling
			var xp: int = skills_comp.get_skill_xp(skill_id)
			var xp_needed: int = current_level * 50
			if current_level < max_level:
				var xp_label := Label.new()
				xp_label.text = "XP: %d/%d" % [xp, xp_needed]
				xp_label.add_theme_font_size_override("font_size", 11)
				xp_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
				row_vbox.add_child(xp_label)

			var hotbar_row := HBoxContainer.new()
			hotbar_row.add_theme_constant_override("separation", 4)
			row_vbox.add_child(hotbar_row)

			var hotbar_label := Label.new()
			hotbar_label.text = "Hotbar:"
			hotbar_label.add_theme_font_size_override("font_size", 12)
			hotbar_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			hotbar_row.add_child(hotbar_label)

			var hotbar: Array = skills_comp.get_hotbar()
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
	if _player:
		_player.get_node("SkillsComponent").set_hotbar_slot(slot, skill_id)
	_refresh()
	var hotbar_node := get_parent().get_node_or_null("SkillHotbar")
	if hotbar_node:
		hotbar_node.refresh()

func is_open() -> bool:
	return _is_open
