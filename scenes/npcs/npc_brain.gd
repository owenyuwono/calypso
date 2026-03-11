extends Node
## NPC brain — LLM decision loop for adventurer NPCs with combat awareness.

const NPC_DECISION_INTERVAL: float = 5.0
const CONVERSATION_HOLD_TIME: float = 10.0
const CHAT_RANGE: float = 8.0
const READING_DELAY: float = 3.0  # seconds to "read" before responding to NPC speech

const PromptBuilder = preload("res://scripts/llm/prompt_builder.gd")
const ResponseParser = preload("res://scripts/llm/response_parser.gd")
const ActionSchema = preload("res://scripts/llm/action_schema.gd")

var npc: CharacterBody3D  # NPCBase, duck-typed
var memory: Node  # NPCMemory
var executor: Node  # NPCActionExecutor
var _decision_timer: float = 0.0
var _enabled: bool = true
var _waiting_for_llm: bool = false
var _use_llm: bool = false
var _use_llm_chat: bool = true  # LLM for reactive conversation only
var _responding_to: String = ""  # Guard against infinite talk_to recursion
var _pending_chat: Dictionary = {}  # {speaker_id, spoken_text} — buffered player chat when decision is in flight
var _conversation_hold: float = 0.0
var _reading_queue: Dictionary = {}  # {speaker_id, spoken_text, timer} — delayed NPC-NPC response

var _canned_greetings: Array = [
	"Hey %s, how's the hunting going?",
	"Watch yourself out there, %s.",
	"%s! Good to see you.",
	"The monsters seem tougher today, %s.",
]

# Test action queue (fallback when LLM unavailable)
var _test_actions: Array = []
var _test_action_index: int = 0

func _ready() -> void:
	npc = get_parent()
	memory = npc.get_node("NPCMemory")
	executor = npc.get_node("NPCActionExecutor")

	GameEvents.npc_action_completed.connect(_on_action_completed)
	GameEvents.npc_spoke.connect(_on_npc_spoke)
	LLMClient.request_completed.connect(_on_llm_response)
	LLMClient.request_failed.connect(_on_llm_failed)

func _process(delta: float) -> void:
	if not _enabled or _waiting_for_llm:
		return
	if _conversation_hold > 0.0:
		_conversation_hold -= delta
		return
	# Tick reading delay for NPC-NPC responses
	if not _reading_queue.is_empty():
		_reading_queue["timer"] -= delta
		if _reading_queue["timer"] <= 0.0:
			var queued := _reading_queue
			_reading_queue = {}
			request_reactive_response(queued["speaker_id"], queued["spoken_text"])
		return
	# Don't make decisions while in combat, dead, or already acting
	if npc.current_state in ["combat", "dead"]:
		return
	if npc.current_state != "idle":
		return

	_decision_timer += delta
	if _decision_timer >= NPC_DECISION_INTERVAL:
		_decision_timer = 0.0
		_make_decision()

func _make_decision() -> void:
	if _use_llm and LLMClient.is_available():
		_request_llm_decision()
	else:
		_use_test_action()

func _request_llm_decision() -> void:
	npc.change_state("thinking")
	_waiting_for_llm = true

	var messages: Array = [
		PromptBuilder.build_system_message(npc.npc_name, npc.personality, npc.current_goal),
		PromptBuilder.build_user_message(npc.npc_id, npc, memory),
	]

	var schema := ActionSchema.get_schema()
	var req_id: String = npc.npc_id
	LLMClient.send_chat(req_id, messages, schema)

func _on_llm_response(req_id: String, response: Dictionary) -> void:
	# Route chat responses separately
	if req_id.begins_with("chat_"):
		if req_id.substr(5) != npc.npc_id:
			return
		_handle_chat_response(response)
		return

	if req_id != npc.npc_id:
		return
	_waiting_for_llm = false
	_responding_to = ""

	var parsed := ResponseParser.parse(response)

	if not parsed.valid:
		push_warning("NPC %s: Invalid LLM response: %s" % [npc.npc_id, parsed.error])
		memory.add_observation("Had a confused thought (LLM parse error)")
		npc.change_state("idle")
		return

	npc.last_thought = parsed.thinking
	memory.add_observation("Thinking: %s -> %s %s" % [parsed.thinking, parsed.action, parsed.target])

	# Update goal if requested
	if not parsed.goal_update.is_empty():
		npc.set_goal(parsed.goal_update)
		memory.add_goal(parsed.goal_update)

	executor.execute(parsed.action, parsed.target, parsed.dialogue, parsed.get("action_data", {}))

	# After processing decision, check for buffered player chat
	if not _pending_chat.is_empty():
		var pending := _pending_chat
		_pending_chat = {}
		request_reactive_response(pending["speaker_id"], pending["spoken_text"])

func _on_llm_failed(req_id: String, error: String) -> void:
	# Route chat failures separately
	if req_id.begins_with("chat_"):
		if req_id.substr(5) != npc.npc_id:
			return
		push_warning("NPC %s: Chat LLM failed: %s — using fallback greeting" % [npc.npc_id, error])
		_waiting_for_llm = false
		var speaker_id := _responding_to
		var greeting := "Well met, traveler!" if speaker_id == "player" else "Hello, %s." % _get_display_name(speaker_id)
		executor.execute("talk_to", speaker_id, greeting)
		_responding_to = ""
		return

	if req_id != npc.npc_id:
		return
	_waiting_for_llm = false
	_responding_to = ""

	push_warning("NPC %s: LLM request failed: %s" % [npc.npc_id, error])
	memory.add_observation("Couldn't think clearly (LLM error: %s)" % error)

	npc.change_state("idle")
	if not _test_actions.is_empty():
		_use_test_action()

	# After processing failure, check for buffered player chat
	if not _pending_chat.is_empty():
		var pending := _pending_chat
		_pending_chat = {}
		request_reactive_response(pending["speaker_id"], pending["spoken_text"])

func _use_test_action() -> void:
	if _test_actions.is_empty():
		return

	if _test_action_index >= _test_actions.size():
		_test_action_index = 0

	var action_data: Dictionary = _test_actions[_test_action_index]
	_test_action_index += 1

	var action: String = action_data.get("action", "wait")
	var target: String = action_data.get("target", "")
	var dialogue: String = action_data.get("dialogue", "")

	npc.last_thought = action_data.get("thinking", "Following routine")
	memory.add_observation("Decided to %s %s" % [action, target])

	executor.execute(action, target, dialogue)

func set_test_actions(actions: Array) -> void:
	_test_actions = actions
	_test_action_index = 0

func set_use_llm(enabled: bool) -> void:
	_use_llm = enabled

func set_use_llm_chat(enabled: bool) -> void:
	_use_llm_chat = enabled

func is_busy() -> bool:
	return _waiting_for_llm or not _responding_to.is_empty() or _conversation_hold > 0.0 or not _reading_queue.is_empty()

## Reactive conversation — triggered when another entity speaks to this NPC.
func request_reactive_response(speaker_id: String, spoken_text: String) -> void:
	if _waiting_for_llm:
		# Buffer the chat — process after current LLM response completes
		_pending_chat = {"speaker_id": speaker_id, "spoken_text": spoken_text}
		return

	# Don't respond if dead or in combat
	if npc.current_state in ["dead", "combat"]:
		return

	# Range check — ignore if speaker is too far away
	var speaker_node := WorldState.get_entity(speaker_id)
	if speaker_node and is_instance_valid(speaker_node):
		var dist := npc.global_position.distance_to(speaker_node.global_position)
		if dist > CHAT_RANGE:
			return

	# Prevent infinite ping-pong: don't respond if already responding to this speaker
	if _responding_to == speaker_id:
		return

	# Turn limit: stop after MAX_CONVERSATION_TURNS per partner
	if not memory.can_continue_conversation(speaker_id):
		return

	_responding_to = speaker_id
	memory.increment_turn(speaker_id)
	memory.add_observation("%s spoke to me: '%s'" % [speaker_id, spoken_text])
	memory.add_conversation(speaker_id, speaker_id, spoken_text)

	if _use_llm_chat:
		npc.change_state("thinking")
		_waiting_for_llm = true
		_decision_timer = 0.0

		var speaker_name := _get_display_name(speaker_id)
		var activity := PromptBuilder.get_activity_description(npc.current_goal)
		var is_player := speaker_id == "player"
		var messages: Array = [
			PromptBuilder.build_chat_system_message(npc.npc_name, npc.personality, activity, is_player),
			PromptBuilder.build_chat_user_message(npc.npc_name, npc.npc_id, speaker_name, spoken_text, memory),
		]

		var req_id: String = "chat_" + npc.npc_id
		LLMClient.send_chat(req_id, messages)
	else:
		var greeting := "Well met, traveler!" if speaker_id == "player" else "Hello, %s." % _get_display_name(speaker_id)
		executor.execute("talk_to", speaker_id, greeting)
		_responding_to = ""

func initiate_social_chat(target_id: String, topic: String = "") -> bool:
	if _waiting_for_llm:
		return false
	if npc.current_state in ["dead", "combat"]:
		return false

	_responding_to = target_id
	memory.increment_turn(target_id)

	if _use_llm_chat:
		npc.change_state("thinking")
		_waiting_for_llm = true

		var target_name := _get_display_name(target_id)
		var target_node := WorldState.get_entity(target_id)
		var target_goal: String = "exploring" if not target_node else target_node.current_goal
		var target_activity := PromptBuilder.get_activity_description(target_goal)
		var activity := PromptBuilder.get_activity_description(npc.current_goal)

		var messages: Array = [
			PromptBuilder.build_chat_initiate_system_message(npc.npc_name, npc.personality, activity, target_name, topic),
			PromptBuilder.build_chat_initiate_user_message(npc.npc_name, npc.npc_id, target_name, target_id, target_activity, memory),
		]

		var req_id: String = "chat_" + npc.npc_id
		LLMClient.send_chat(req_id, messages)
		return true
	else:
		var target_name := _get_display_name(target_id)
		var greeting: String = _canned_greetings[randi() % _canned_greetings.size()] % target_name
		executor.execute("talk_to", target_id, greeting)
		_responding_to = ""
		return true

func _handle_chat_response(response: Dictionary) -> void:
	_waiting_for_llm = false
	var speaker_id := _responding_to
	var parsed := ResponseParser.parse_chat(response)
	if not parsed.valid:
		var greeting := "Well met, traveler!" if speaker_id == "player" else "Hello, %s." % _get_display_name(speaker_id)
		executor.execute("talk_to", speaker_id, greeting)
		_responding_to = ""
		_conversation_hold = CONVERSATION_HOLD_TIME
		return
	memory.add_observation("Replied to %s: '%s'" % [speaker_id, parsed.dialogue])
	executor.execute("talk_to", speaker_id, parsed.dialogue)
	_conversation_hold = CONVERSATION_HOLD_TIME

	# Only apply goal changes when the player is speaking (NPC-NPC chat stays behavior-driven)
	if speaker_id == "player" and not parsed.goal.is_empty():
		npc.set_goal(parsed.goal)
		memory.add_goal(parsed.goal)
		memory.add_observation("Changed goal to '%s' after talking with %s" % [parsed.goal, speaker_id])

func _get_display_name(entity_id: String) -> String:
	if entity_id == "player":
		return "Player"
	var data := WorldState.get_entity_data(entity_id)
	return data.get("name", entity_id)

func _on_action_completed(completed_npc_id: String, action: String, success: bool) -> void:
	if completed_npc_id == npc.npc_id:
		var status := "succeeded" if success else "failed"
		memory.add_observation("Action '%s' %s" % [action, status])

func _on_npc_spoke(speaker_id: String, dialogue: String, target_id: String) -> void:
	# If we just spoke (we're the speaker), clear the responding guard
	if speaker_id == npc.npc_id:
		_responding_to = ""
		_conversation_hold = CONVERSATION_HOLD_TIME
		memory.add_conversation(target_id, npc.npc_id, dialogue)
		return
	if target_id == npc.npc_id:
		if speaker_id != "player":
			# Queue with reading delay instead of responding immediately
			_reading_queue = {"speaker_id": speaker_id, "spoken_text": dialogue, "timer": READING_DELAY}
		else:
			pass  # Player chat handled via request_reactive_response directly
