extends Control
## Debug panel showing adventurer NPC state, stats, and combat info.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

@onready var content_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/Content
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/Title
@onready var panel: Panel = $Panel

var _visible: bool = true
var _expanded: bool = true
var _update_timer: float = 0.0
var _minimize_button: Button
var _collapsed_height: float = 50.0
var _full_height: float = 600.0
const UPDATE_INTERVAL: float = 0.5

func _ready() -> void:
	visible = _visible
	_full_height = offset_bottom

	# Reparent title into an HBoxContainer with a minimize button
	var vbox := title_label.get_parent()
	var hbox := HBoxContainer.new()
	hbox.name = "TitleBar"

	var title_index := title_label.get_index()
	vbox.remove_child(title_label)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_label)

	_minimize_button = Button.new()
	_minimize_button.text = "\u2212"
	_minimize_button.custom_minimum_size = Vector2(30, 0)
	_minimize_button.pressed.connect(_toggle_expand)
	hbox.add_child(_minimize_button)

	vbox.add_child(hbox)
	vbox.move_child(hbox, title_index)

func _toggle_expand() -> void:
	_expanded = not _expanded
	content_label.visible = _expanded
	_minimize_button.text = "\u2212" if _expanded else "+"
	offset_bottom = _full_height if _expanded else _collapsed_height

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F1:
		_visible = not _visible
		visible = _visible

func _refresh() -> void:
	var text := ""

	# Player stats
	var pdata := WorldState.get_entity_data("player")
	if not pdata.is_empty():
		text += "[b]Player[/b]\n"
		text += "  Lv.%d  HP: %d/%d  ATK: %d  DEF: %d\n" % [
			pdata.get("level", 1), pdata.get("hp", 0), pdata.get("max_hp", 0),
			WorldState.get_effective_atk("player"), WorldState.get_effective_def("player")]
		text += "  Gold: %d  XP: %d\n" % [pdata.get("gold", 0), pdata.get("xp", 0)]
		var equip: Dictionary = pdata.get("equipment", {})
		var w: String = equip.get("weapon", "")
		var a: String = equip.get("armor", "")
		text += "  Equip: %s / %s\n\n" % [
			ItemDatabase.get_item_name(w) if not w.is_empty() else "-",
			ItemDatabase.get_item_name(a) if not a.is_empty() else "-"]

	# NPC adventurers
	for entity_id in WorldState.entities:
		var data := WorldState.get_entity_data(entity_id)
		if data.get("type", "") != "npc":
			continue

		var node: Node3D = WorldState.get_entity(entity_id)
		if not node:
			continue

		var npc_name: String = data.get("name", entity_id)
		var state: String = data.get("state", "unknown")
		var goal: String = data.get("goal", "none")
		var hp: int = data.get("hp", 0)
		var max_hp: int = data.get("max_hp", 0)
		var level: int = data.get("level", 1)
		var gold: int = data.get("gold", 0)

		var thought: String = node.last_thought if "last_thought" in node else ""
		var action: String = node.current_action if "current_action" in node else ""
		var target: String = node.current_target if "current_target" in node else ""

		text += "[b]%s[/b] [color=#888](%s)[/color]\n" % [npc_name, entity_id]
		text += "  State: [color=%s]%s[/color]" % [_state_color(state), state.to_upper()]

		# Show combat target if in combat
		if state == "combat" and "combat_target" in node and not node.combat_target.is_empty():
			text += " vs %s" % node.combat_target
		text += "\n"

		text += "  Lv.%d  HP: %d/%d  ATK: %d  DEF: %d  Gold: %d\n" % [
			level, hp, max_hp,
			WorldState.get_effective_atk(entity_id), WorldState.get_effective_def(entity_id), gold]

		text += "  Goal: %s\n" % goal
		if not action.is_empty():
			text += "  Action: %s -> %s\n" % [action, target]
		if not thought.is_empty():
			text += "  Thought: [i]%s[/i]\n" % thought

		# Inventory summary
		var inv: Dictionary = WorldState.get_inventory(entity_id)
		if not inv.is_empty():
			var items: Array = []
			for item_id in inv:
				items.append("%s x%d" % [ItemDatabase.get_item_name(item_id), inv[item_id]])
			text += "  Items: %s\n" % ", ".join(items)

		# Recent memory
		var memory_node = node.get_node_or_null("NPCMemory")
		if memory_node:
			var obs: Array = memory_node.get_recent_observations(3)
			if not obs.is_empty():
				text += "  Memory:\n"
				for o in obs:
					text += "    %s\n" % o

		text += "\n"

	# LLM status
	text += "[b]LLM Status[/b]\n"
	text += "  Active requests: %d / %d\n" % [LLMClient.get_active_request_count(), LLMClient.MAX_CONCURRENT_REQUESTS]

	content_label.text = text

func _state_color(state: String) -> String:
	match state:
		"idle": return "#aaa"
		"thinking": return "#ffcc00"
		"moving": return "#66aaff"
		"talking": return "#66ff66"
		"interacting": return "#ff9933"
		"failed": return "#ff4444"
		"combat": return "#ff6600"
		"dead": return "#880000"
	return "#ffffff"
