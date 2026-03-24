class_name RelationshipPanel
extends Control
## Shows the player's relationship tiers and progress toward each NPC they've met.
## Toggled with R key.

const TIER_COLORS: Dictionary = {
	"stranger": Color("#888888"),
	"recognized": Color("#bbbbbb"),
	"acquaintance": Color("#ffdd66"),
	"friendly": Color("#66cc66"),
	"close": Color("#6688ff"),
	"bonded": Color("#cc66ff"),
}

const TIER_LADDER: Array = ["stranger", "recognized", "acquaintance", "friendly", "close", "bonded"]

var _player: Node = null
var _panel: PanelContainer
var _npc_list: VBoxContainer
var _is_open: bool = false


func set_player(player: Node) -> void:
	_player = player


func is_open() -> bool:
	return _is_open


func toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		AudioManager.play_ui_sfx("ui_panel_open")
		UIHelper.center_panel(_panel)
		refresh()
	else:
		AudioManager.play_ui_sfx("ui_panel_close")


func refresh() -> void:
	if not _is_open:
		return
	_rebuild_list()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	GameEvents.relationship_tier_changed.connect(_on_tier_changed)


func _build_ui() -> void:
	var ui: Dictionary = UIHelper.create_titled_panel("Relationships", Vector2(350, 400), toggle)
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

	_npc_list = VBoxContainer.new()
	_npc_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_npc_list.add_theme_constant_override("separation", 8)
	margin.add_child(_npc_list)


func _rebuild_list() -> void:
	for child in _npc_list.get_children():
		child.queue_free()

	var grouped: Dictionary = _collect_relationships()

	if grouped.is_empty():
		var empty_label: Label = UIHelper.create_label(
			"No relationships yet.",
			14,
			UIHelper.COLOR_HEADER,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_npc_list.add_child(empty_label)
		return

	# Highest tier first — iterate ladder in reverse
	for i in range(TIER_LADDER.size() - 1, -1, -1):
		var tier: String = TIER_LADDER[i]
		var entries: Array = grouped.get(tier, [])
		if entries.is_empty():
			continue
		_add_tier_section(tier, entries)


func _collect_relationships() -> Dictionary:
	# Returns {tier: [{name, progress}]} for NPCs that have interacted with player
	var grouped: Dictionary = {}

	for entity_id in WorldState.entity_data:
		var data: Dictionary = WorldState.entity_data[entity_id]
		if data.get("type", "") not in ["npc", "shop_npc"]:
			continue

		var npc_node: Node = WorldState.get_entity(entity_id)
		if not npc_node or not is_instance_valid(npc_node):
			continue

		var rel_comp: Node = npc_node.get_node_or_null("RelationshipComponent")
		if not rel_comp:
			continue

		# Only include NPCs the player has actually had an interaction with
		var summary: Dictionary = rel_comp.get_relationships_summary()
		if not summary.has("player"):
			continue

		# Require at least one recorded event (not just a default entry)
		var event_count: int = rel_comp.get_event_count("player", "conversation") \
			+ rel_comp.get_event_count("player", "shared_combat") \
			+ rel_comp.get_event_count("player", "helped") \
			+ rel_comp.get_event_count("player", "saved_from_death") \
			+ rel_comp.get_event_count("player", "shared_secret")
		if event_count == 0:
			continue

		var tier: String = rel_comp.get_tier("player")
		var progress: float = rel_comp.get_progress_toward_next("player")
		var display_name: String = _get_npc_display_name(npc_node, entity_id)

		if not grouped.has(tier):
			grouped[tier] = []
		grouped[tier].append({
			"name": display_name,
			"tier": tier,
			"progress": progress,
		})

	# Sort each tier's entries alphabetically by name
	for tier in grouped:
		grouped[tier].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["name"] < b["name"]
		)

	return grouped


func _get_npc_display_name(npc_node: Node, entity_id: String) -> String:
	if npc_node.get("npc_name") != null:
		var n: String = npc_node.npc_name
		if not n.is_empty():
			return n
	return entity_id


func _add_tier_section(tier: String, entries: Array) -> void:
	var tier_color: Color = TIER_COLORS.get(tier, Color.WHITE)
	var tier_label: String = "★ " + _capitalize(tier)

	var header := Label.new()
	header.text = tier_label
	header.add_theme_font_override("font", UIHelper.GAME_FONT_DISPLAY)
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", tier_color)
	_npc_list.add_child(header)

	var section_box := VBoxContainer.new()
	section_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_box.add_theme_constant_override("separation", 3)

	var section_style: StyleBoxFlat = UIHelper.create_style_box(
		Color(0.12, 0.10, 0.08, 0.6),
		tier_color * Color(1, 1, 1, 0.25),
		3,
		1
	)
	var section_panel := PanelContainer.new()
	section_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_panel.add_theme_stylebox_override("panel", section_style)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 6)
	inner_margin.add_theme_constant_override("margin_right", 6)
	inner_margin.add_theme_constant_override("margin_top", 4)
	inner_margin.add_theme_constant_override("margin_bottom", 4)
	section_panel.add_child(inner_margin)
	inner_margin.add_child(section_box)

	_npc_list.add_child(section_panel)

	for entry in entries:
		section_box.add_child(_create_npc_row(entry))


func _create_npc_row(entry: Dictionary) -> HBoxContainer:
	var tier: String = entry["tier"]
	var progress: float = entry["progress"]
	var percent: int = int(progress * 100.0)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)

	# Name label
	var name_lbl := Label.new()
	name_lbl.text = entry["name"]
	name_lbl.add_theme_font_override("font", UIHelper.GAME_FONT)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.custom_minimum_size.x = 100
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	# Progress bar — fill color is next tier's color (or current if bonded)
	var fill_color: Color = _get_next_tier_color(tier)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(100, 8)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = progress
	bar.show_percentage = false
	_style_progress_bar(bar, fill_color)
	row.add_child(bar)

	# Percentage label
	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % percent
	pct_lbl.add_theme_font_override("font", UIHelper.GAME_FONT)
	pct_lbl.add_theme_font_size_override("font_size", 12)
	pct_lbl.add_theme_color_override("font_color", Color("#aaaaaa"))
	pct_lbl.custom_minimum_size.x = 36
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct_lbl)

	return row


func _style_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.12, 0.10, 1.0)
	UIHelper.set_corner_radius(bg_style, 3)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	UIHelper.set_corner_radius(fill_style, 3)
	bar.add_theme_stylebox_override("fill", fill_style)


func _get_next_tier_color(tier: String) -> Color:
	var idx: int = TIER_LADDER.find(tier)
	if idx < 0 or idx >= TIER_LADDER.size() - 1:
		# Bonded — show bonded color at full
		return TIER_COLORS.get("bonded", Color.WHITE)
	var next_tier: String = TIER_LADDER[idx + 1]
	return TIER_COLORS.get(next_tier, Color.WHITE)


func _capitalize(text: String) -> String:
	if text.is_empty():
		return text
	return text[0].to_upper() + text.substr(1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_relationships"):
		toggle()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") and _is_open:
		toggle()
		get_viewport().set_input_as_handled()


func _on_tier_changed(_entity_id: String, partner_id: String, _old_tier: String, _new_tier: String) -> void:
	if partner_id != "player":
		return
	refresh()
