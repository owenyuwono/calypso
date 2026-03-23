extends PanelContainer
## Dialogue tree panel — displays scripted NPC dialogue with branching choices.
## Opened by player.gd on NPC left-click. Emits trade_requested to main.gd for shop routing.

const DialogueDatabase = preload("res://scripts/data/dialogue_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

signal trade_requested(npc_node: Node)

var _player: Node
var _npc_id: String = ""
var _npc_node: Node = null
var _current_node_id: String = ""

var _drag_handle: PanelContainer
var _npc_name_label: Label
var _dialogue_text: Label
var _choices_container: VBoxContainer

# Archetype lookup by trait profile prefix for generic greetings.
const PROFILE_TO_ARCHETYPE: Dictionary = {
	"bold_warrior": "warrior",
	"stern_guardian": "warrior",
	"wild_berserker": "warrior",
	"stoic_knight": "warrior",
	"cautious_mage": "mage",
	"devout_cleric": "mage",
	"gentle_healer": "mage",
	"earnest_apprentice": "mage",
	"sly_rogue": "rogue",
	"charming_bard": "rogue",
	"shadow_stalker": "rogue",
	"keen_archer": "ranger",
	"merchant": "merchant",
}


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(500, 350)
	add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	_build_ui()


func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	_drag_handle = DragHandle.new()
	_drag_handle.setup(self, "Conversation")
	_drag_handle.close_pressed.connect(close_dialogue)
	main_vbox.add_child(_drag_handle)

	# NPC name — gold, display font
	_npc_name_label = Label.new()
	_npc_name_label.add_theme_font_override("font", UIHelper.GAME_FONT_DISPLAY)
	_npc_name_label.add_theme_font_size_override("font_size", 20)
	_npc_name_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	_npc_name_label.add_theme_constant_override("outline_size", 0)
	_npc_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_npc_name_label)

	# Dialogue text — body font, word-wrapped
	_dialogue_text = Label.new()
	_dialogue_text.add_theme_font_override("font", UIHelper.GAME_FONT)
	_dialogue_text.add_theme_font_size_override("font_size", 14)
	_dialogue_text.add_theme_color_override("font_color", Color(0.9, 0.87, 0.8))
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_text.custom_minimum_size = Vector2(0, 80)
	main_vbox.add_child(_dialogue_text)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	main_vbox.add_child(sep)

	# Choice buttons container
	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", 4)
	_choices_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_choices_container)


func set_player(player: Node) -> void:
	_player = player


func open_dialogue(npc_id: String, npc_node: Node) -> void:
	_npc_id = npc_id
	_npc_node = npc_node

	var npc_name: String = npc_node.npc_name if "npc_name" in npc_node else npc_id
	_npc_name_label.text = npc_name
	_drag_handle.set_title("Conversation")

	var entry_node_id: String = DialogueDatabase.get_dialogue_entry(npc_id)
	if not entry_node_id.is_empty():
		_show_node(entry_node_id)
	else:
		_show_generic_greeting(npc_node)

	visible = true
	AudioManager.play_ui_sfx("ui_panel_open")
	UIHelper.center_panel(self)


func close_dialogue() -> void:
	visible = false
	AudioManager.play_ui_sfx("ui_panel_close")
	_npc_id = ""
	_npc_node = null
	_current_node_id = ""


func _show_node(node_id: String) -> void:
	_current_node_id = node_id
	var dialogue_node: Dictionary = DialogueDatabase.get_node(_npc_id, node_id)
	if dialogue_node.is_empty():
		close_dialogue()
		return

	_dialogue_text.text = dialogue_node.get("text", "...")

	_clear_choices()

	var choices: Array = dialogue_node.get("choices", [])
	for choice in choices:
		var condition: String = choice.get("condition", "")
		if not condition.is_empty():
			if not DialogueDatabase.evaluate_condition(condition, _player, _npc_node):
				continue

		var btn := _create_choice_button(choice.get("text", "..."))
		var next_node = choice.get("next", null)
		var action: String = choice.get("action", "")
		btn.pressed.connect(_on_choice_pressed.bind(next_node, action))
		_choices_container.add_child(btn)

	# Fallback: no choices were added — add a close button
	if _choices_container.get_child_count() == 0:
		var btn := _create_choice_button("Goodbye.")
		btn.pressed.connect(close_dialogue)
		_choices_container.add_child(btn)


func _show_generic_greeting(npc_node: Node) -> void:
	var archetype: String = _get_archetype(npc_node)
	var mood: String = _get_mood(npc_node)
	var node: Dictionary = DialogueDatabase.get_generic_greeting(archetype, mood)

	_dialogue_text.text = node.get("text", "...")

	_clear_choices()

	var choices: Array = node.get("choices", [])
	for choice in choices:
		var btn := _create_choice_button(choice.get("text", "Goodbye."))
		btn.pressed.connect(close_dialogue)
		_choices_container.add_child(btn)

	if _choices_container.get_child_count() == 0:
		var btn := _create_choice_button("Goodbye.")
		btn.pressed.connect(close_dialogue)
		_choices_container.add_child(btn)


func _on_choice_pressed(next_node, action: String) -> void:
	if not action.is_empty():
		_execute_action(action)
		return

	if next_node == null:
		close_dialogue()
		return

	_show_node(next_node)


func _execute_action(action: String) -> void:
	match action:
		"trade":
			close_dialogue()
			if _npc_node and is_instance_valid(_npc_node):
				trade_requested.emit(_npc_node)
		"info":
			close_dialogue()
		_:
			close_dialogue()


func _clear_choices() -> void:
	for child in _choices_container.get_children():
		_choices_container.remove_child(child)
		child.queue_free()


func _create_choice_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", UIHelper.GAME_FONT)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	btn.add_theme_color_override("font_hover_color", UIHelper.COLOR_GOLD)
	return btn


func _get_archetype(npc_node: Node) -> String:
	var profile: String = npc_node.trait_profile if "trait_profile" in npc_node else ""
	return PROFILE_TO_ARCHETYPE.get(profile, "warrior")


func _get_mood(npc_node: Node) -> String:
	var emotion: String = ""
	if "current_mood" in npc_node:
		emotion = npc_node.current_mood
	elif npc_node.has_node("NpcIdentity"):
		var identity: Node = npc_node.get_node("NpcIdentity")
		emotion = identity.emotion if "emotion" in identity else ""

	match emotion:
		"excited", "content", "energetic": return "happy"
		"sad", "afraid", "tired": return "sad"
		"angry": return "angry"
	return "neutral"


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()
