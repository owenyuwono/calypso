extends Control
## Quest Journal panel — shows active and completed quests with objective progress.
## Toggled with J key.

const QuestDatabase = preload("res://scripts/data/quest_database.gd")

var _player: Node
var _quest_comp: Node
var _panel: PanelContainer
var _quest_list: VBoxContainer
var _is_open: bool = false


func set_player(player: Node) -> void:
	_player = player
	_quest_comp = player.get_node_or_null("QuestComponent")


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	GameEvents.quest_accepted.connect(func(_eid, _qid): refresh())
	GameEvents.quest_objective_updated.connect(func(_eid, _qid, _idx, _prog): refresh())
	GameEvents.quest_completed.connect(func(_eid, _qid, _rewards): refresh())


func _build_ui() -> void:
	var ui: Dictionary = UIHelper.create_titled_panel("Quest Journal", Vector2(400, 500), _toggle)
	_panel = ui["panel"]
	add_child(_panel)

	var vbox: VBoxContainer = ui["vbox"]
	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(margin)

	_quest_list = VBoxContainer.new()
	_quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_list.add_theme_constant_override("separation", 10)
	margin.add_child(_quest_list)


func _toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		AudioManager.play_ui_sfx("ui_panel_open")
		UIHelper.center_panel(_panel)
		refresh()
	else:
		AudioManager.play_ui_sfx("ui_panel_close")


func is_open() -> bool:
	return _is_open


func refresh() -> void:
	if not _is_open:
		return
	if not _quest_comp:
		if _player:
			_quest_comp = _player.get_node_or_null("QuestComponent")
	_rebuild_quest_list()


func _rebuild_quest_list() -> void:
	for child in _quest_list.get_children():
		child.queue_free()

	if not _quest_comp:
		var empty_label: Label = UIHelper.create_label("No active quests.", 14, UIHelper.COLOR_HEADER)
		_quest_list.add_child(empty_label)
		return

	var active: Dictionary = _quest_comp.get_active_quests()
	var completed: Array = _quest_comp.get_completed_quests()

	if active.is_empty() and completed.is_empty():
		var empty_label: Label = UIHelper.create_label("No active quests.", 14, UIHelper.COLOR_HEADER)
		_quest_list.add_child(empty_label)
		return

	# Active quests section
	if not active.is_empty():
		var section_label: Label = UIHelper.create_label("ACTIVE", 12, UIHelper.COLOR_GOLD)
		section_label.add_theme_font_size_override("font_size", 12)
		_quest_list.add_child(section_label)
		_quest_list.add_child(HSeparator.new())

		for quest_id in active:
			_add_quest_entry(quest_id, active[quest_id], false)

	# Completed quests section
	if not completed.is_empty():
		if not active.is_empty():
			_quest_list.add_child(HSeparator.new())

		var section_label: Label = UIHelper.create_label("COMPLETED", 12, Color(0.5, 0.5, 0.5, 1.0))
		_quest_list.add_child(section_label)
		_quest_list.add_child(HSeparator.new())

		for quest_id in completed:
			_add_quest_entry(quest_id, {}, true)


func _add_quest_entry(quest_id: String, active_data: Dictionary, is_completed: bool) -> void:
	var quest: Dictionary = QuestDatabase.get_quest(quest_id)
	if quest.is_empty():
		return

	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 4)

	# Quest name
	var name_color: Color = UIHelper.COLOR_GOLD if not is_completed else Color(0.5, 0.5, 0.5, 1.0)
	var name_label: Label = UIHelper.create_label(quest.get("name", quest_id), 15, name_color)
	entry.add_child(name_label)

	# Description
	var desc_color: Color = UIHelper.COLOR_HEADER if not is_completed else Color(0.45, 0.45, 0.45, 1.0)
	var desc_label: Label = UIHelper.create_label(quest.get("description", ""), 12, desc_color)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(desc_label)

	# Objectives (only for active quests)
	if not is_completed and not active_data.is_empty():
		var progress: Dictionary = active_data.get("progress", {})
		var objectives: Array = quest.get("objectives", [])
		for i in objectives.size():
			var obj: Dictionary = objectives[i]
			var current: int = progress.get(i, 0)
			var target: int = obj.get("count", 1)
			var obj_desc: String = obj.get("description", "")
			var done: bool = current >= target
			var icon: String = "✓" if done else "○"
			var line: String
			if obj.has("count"):
				line = "%s %s (%d/%d)" % [icon, obj_desc, current, target]
			else:
				line = "%s %s" % [icon, obj_desc]
			var obj_color: Color = Color(0.5, 0.8, 0.5, 1.0) if done else UIHelper.COLOR_HEADER
			var obj_label: Label = UIHelper.create_label(line, 12, obj_color)
			obj_label.add_theme_constant_override("margin_left", 8)
			entry.add_child(obj_label)

	_quest_list.add_child(entry)
