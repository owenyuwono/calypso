extends Control
## NPC info panel — click an NPC to see traits, stats, memories, and relationships.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const NpcTraits = preload("res://scripts/data/npc_traits.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")
const PromptBuilder = preload("res://scripts/llm/prompt_builder.gd")

var _panel: PanelContainer
var _drag_handle: PanelContainer
var _content: RichTextLabel
var _refresh_timer: Timer
var _is_open: bool = false
var _current_npc_id: String = ""

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(300, 400)
	_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(vbox)

	# Draggable title bar
	_drag_handle = DragHandle.new()
	_drag_handle.setup(_panel, "NPC Info")
	_drag_handle.close_pressed.connect(close)
	vbox.add_child(_drag_handle)

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_content = RichTextLabel.new()
	_content.bbcode_enabled = true
	_content.fit_content = true
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_font_size_override("normal_font_size", 13)
	_content.add_theme_font_size_override("bold_font_size", 13)
	_content.add_theme_font_size_override("italics_font_size", 13)
	scroll.add_child(_content)

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.5
	_refresh_timer.one_shot = false
	_refresh_timer.timeout.connect(_refresh)
	add_child(_refresh_timer)

func _input(event: InputEvent) -> void:
	if _is_open and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func show_npc(npc_id: String) -> void:
	_current_npc_id = npc_id
	_is_open = true
	visible = true
	AudioManager.play_ui_sfx("ui_panel_open")
	UIHelper.center_panel(_panel)
	_refresh()
	_refresh_timer.start()

func close() -> void:
	_refresh_timer.stop()
	_is_open = false
	visible = false
	AudioManager.play_ui_sfx("ui_panel_close")
	_current_npc_id = ""

func is_open() -> bool:
	return _is_open

func toggle() -> void:
	if _is_open:
		close()

func _refresh() -> void:
	if _current_npc_id.is_empty():
		return

	var node: Node3D = WorldState.get_entity(_current_npc_id)
	if not node or not is_instance_valid(node):
		close()
		return

	var stats = node.get_node_or_null("StatsComponent")
	var inv = node.get_node_or_null("InventoryComponent")
	var equip = node.get_node_or_null("EquipmentComponent")
	var combat = node.get_node_or_null("CombatComponent")

	var npc_name: String = node.npc_name if "npc_name" in node else _current_npc_id
	var level: int = stats.level if stats else 1
	var state: String = node.current_state if "current_state" in node else "unknown"
	var hp: int = stats.hp if stats else 0
	var max_hp: int = stats.max_hp if stats else 0
	var gold: int = inv.gold if inv else 0
	var goal: String = node.current_goal if "current_goal" in node else "idle"
	var personality: String = node.personality if "personality" in node else ""

	_drag_handle.set_title(npc_name)

	var text := ""

	# Name + Level + State
	text += "[b]%s[/b]  Lv.%d\n" % [npc_name, level]
	text += "State: [color=%s]%s[/color]" % [_state_color(state), state.to_upper()]
	if state == "combat" and "combat_target" in node and not node.combat_target.is_empty():
		var ct_node = WorldState.get_entity(node.combat_target)
		var ct_name: String = ct_node.npc_name if ct_node and "npc_name" in ct_node else node.combat_target
		text += " vs %s" % ct_name
	var mood: String = node.current_mood if "current_mood" in node else ""
	if not mood.is_empty() and mood != "neutral":
		text += "  [color=%s]%s[/color]" % [_mood_color(mood), mood]
	text += "\n"
	text += "Activity: %s\n" % PromptBuilder.get_activity_description(goal)

	# Action + thought
	var action: String = node.current_action if "current_action" in node else ""
	var target: String = node.current_target if "current_target" in node else ""
	if not action.is_empty():
		text += "Action: %s -> %s\n" % [action, target]
	var thought: String = node.last_thought if "last_thought" in node else ""
	if not thought.is_empty():
		text += "Thought: [i]%s[/i]\n" % thought

	# HP bar text
	var hp_color := "#ff6666" if float(hp) / float(max_hp) < 0.5 else "#aaffaa"
	text += "HP: [color=%s]%d / %d[/color]  |  Gold: [color=#ffdd66]%d[/color]\n" % [hp_color, hp, max_hp, gold]

	# Personality
	if not personality.is_empty():
		text += "[color=#aaa]%s[/color]\n" % personality

	# Traits
	var trait_profile: String = node.trait_profile if "trait_profile" in node else ""
	if not trait_profile.is_empty():
		var profile := NpcTraits.get_profile(trait_profile)
		if not profile.is_empty():
			text += "\n[color=#ffdd88][b]Traits[/b][/color] [color=#888](%s)[/color]\n" % trait_profile
			text += _format_trait_bar("Boldness", profile.get("boldness", 0.5))
			text += _format_trait_bar("Sociability", profile.get("sociability", 0.5))
			text += _format_trait_bar("Generosity", profile.get("generosity", 0.5))
			text += _format_trait_bar("Curiosity", profile.get("curiosity", 0.5))

	# Combat stats
	text += "\n[color=#ffdd88][b]Stats[/b][/color]\n"
	text += "ATK: %d  DEF: %d\n" % [
		combat.get_effective_atk() if combat else (stats.atk if stats else 0),
		combat.get_effective_def() if combat else (stats.def if stats else 0)]
	var equipment: Dictionary = equip.get_equipment() if equip else {}
	var weapon_id: String = equipment.get("main_hand", "")
	var armor_id: String = equipment.get("off_hand", "")
	text += "Weapon: %s\n" % (ItemDatabase.get_item_name(weapon_id) if not weapon_id.is_empty() else "[color=#666]None[/color]")
	text += "Armor: %s\n" % (ItemDatabase.get_item_name(armor_id) if not armor_id.is_empty() else "[color=#666]None[/color]")

	# Inventory
	var inv_items: Dictionary = inv.get_items() if inv else {}
	if not inv_items.is_empty():
		text += "\n[color=#ffdd88][b]Inventory[/b][/color]\n"
		for item_id in inv_items:
			text += "  %s x%d\n" % [ItemDatabase.get_item_name(item_id), inv_items[item_id]]

	# Memories
	var memory_node = node.get_node_or_null("NPCMemory")
	if memory_node:
		var mem_text: String = memory_node.get_memories_for_prompt(5)
		if not mem_text.is_empty():
			text += "\n[color=#ffdd88][b]Memories[/b][/color]\n"
			for line in mem_text.split("\n"):
				if not line.strip_edges().is_empty():
					text += "  [color=#aaa]%s[/color]\n" % line.strip_edges()

		# Relationships
		var rel_comp_panel = node.get_node_or_null("RelationshipComponent")
		if rel_comp_panel:
			var rel_summary: Dictionary = rel_comp_panel.get_relationships_summary()
			if not rel_summary.is_empty():
				text += "\n[color=#ffdd88][b]Relationships[/b][/color]\n"
				var sorted_ids: Array = rel_summary.keys()
				sorted_ids.sort_custom(func(a, b): return RelationshipComponent.TIER_LADDER.find(rel_summary[b].get("tier", "stranger")) > RelationshipComponent.TIER_LADDER.find(rel_summary[a].get("tier", "stranger")))
				for partner_id in sorted_ids:
					var partner_node = WorldState.get_entity(partner_id)
					var partner_name: String = partner_node.npc_name if partner_node and "npc_name" in partner_node else partner_id
					var label: String = rel_comp_panel.get_tier(partner_id)
					var label_color := _relationship_color(label)
					text += "  %s: [color=%s]%s[/color]" % [partner_name, label_color, label]
					var impression: String = rel_comp_panel.get_impression(partner_id)
					if impression != "No impression":
						text += " [color=#888][i]%s[/i][/color]" % impression
					text += "\n"

		# Recent observations
		var obs: Array = memory_node.get_recent_observations(3)
		if not obs.is_empty():
			text += "\n[color=#ffdd88][b]Recent Memory[/b][/color]\n"
			for o in obs:
				text += "  [color=#aaa]%s[/color]\n" % o

	_content.text = text

func _format_trait_bar(label: String, value: float) -> String:
	var filled := int(value * 10)
	var empty := 10 - filled
	var bar := "[color=#ffcc44]%s[/color][color=#333]%s[/color]" % [
		"█".repeat(filled), "█".repeat(empty)]
	var value_label: String
	if value >= 0.7:
		value_label = "[color=#ffcc44]%.0f%%[/color]" % (value * 100)
	elif value <= 0.3:
		value_label = "[color=#8888ff]%.0f%%[/color]" % (value * 100)
	else:
		value_label = "%.0f%%" % (value * 100)
	return "  %-12s %s %s\n" % [label, bar, value_label]

func _state_color(state: String) -> String:
	match state:
		"idle": return "#aaaaaa"
		"thinking": return "#ffcc00"
		"moving": return "#66aaff"
		"talking": return "#66ff66"
		"interacting": return "#ff9933"
		"failed": return "#ff4444"
		"combat": return "#ff6600"
		"dead": return "#880000"
	return "#ffffff"

func _relationship_color(label: String) -> String:
	match label:
		"stranger": return "#888888"
		"recognized": return "#bbbbbb"
		"acquaintance": return "#ffdd66"
		"friendly": return "#66cc66"
		"close": return "#6688ff"
		"bonded": return "#cc66ff"
	return "#cccccc"

func _mood_color(mood: String) -> String:
	match mood:
		"content": return "#66cc66"
		"excited": return "#ffdd44"
		"worried": return "#ff9933"
		"angry": return "#ff4444"
		"sad": return "#6688ff"
		"afraid": return "#cc66ff"
		"tired": return "#888899"
		"normal": return "#ffffff"
		"energetic": return "#ffdd44"
	return "#aaaaaa"
