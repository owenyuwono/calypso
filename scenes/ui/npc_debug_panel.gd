extends Control
## Debug panel showing NPC internal state.

@onready var content_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/Content
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/Title
@onready var panel: Panel = $Panel

var _visible: bool = true
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.5

func _ready() -> void:
	visible = _visible

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

	# Find all NPCs
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
		var inventory: Array = data.get("inventory", [])

		var thought: String = node.last_thought if "last_thought" in node else ""
		var action: String = node.current_action if "current_action" in node else ""
		var target: String = node.current_target if "current_target" in node else ""

		var pos := node.global_position
		text += "[b]%s[/b] [color=#888](%s)[/color]\n" % [npc_name, entity_id]
		text += "  State: [color=%s]%s[/color]\n" % [_state_color(state), state.to_upper()]
		text += "  Pos: (%.1f, %.1f, %.1f)\n" % [pos.x, pos.y, pos.z]
		text += "  Goal: %s\n" % goal
		if not action.is_empty():
			text += "  Action: %s → %s\n" % [action, target]
		if not thought.is_empty():
			text += "  Thought: [i]%s[/i]\n" % thought
		if not inventory.is_empty():
			text += "  Inventory: %s\n" % ", ".join(inventory)

		# Show memory observations
		var memory_node = node.get_node_or_null("NPCMemory")
		if memory_node:
			var obs: Array = memory_node.get_recent_observations(3)
			if not obs.is_empty():
				text += "  Memory:\n"
				for o in obs:
					text += "    %s\n" % o

		text += "\n"

	# Show LLM status
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
	return "#ffffff"
