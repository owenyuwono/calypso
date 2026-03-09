extends Node
## NPC brain — LLM decision loop with fallback to hardcoded test actions.

const NPC_DECISION_INTERVAL: float = 5.0

# Preload LLM helper scripts
const PromptBuilder = preload("res://scripts/llm/prompt_builder.gd")
const ResponseParser = preload("res://scripts/llm/response_parser.gd")
const ActionSchema = preload("res://scripts/llm/action_schema.gd")

var npc: CharacterBody3D  # NPCBase, duck-typed
var memory: Node  # NPCMemory
var executor: Node  # NPCActionExecutor
var _decision_timer: float = 0.0
var _enabled: bool = true
var _waiting_for_llm: bool = false
var _use_llm: bool = true  # Set false to use test actions only

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
	GameEvents.llm_request_sent.emit(npc.npc_id)

func _on_llm_response(req_id: String, response: Dictionary) -> void:
	if req_id != npc.npc_id:
		return
	_waiting_for_llm = false

	var parsed := ResponseParser.parse(response)

	if not parsed.valid:
		push_warning("NPC %s: Invalid LLM response: %s" % [npc.npc_id, parsed.error])
		memory.add_observation("Had a confused thought (LLM parse error)")
		npc.change_state("idle")
		return

	npc.last_thought = parsed.thinking
	memory.add_observation("Thinking: %s → %s %s" % [parsed.thinking, parsed.action, parsed.target])

	# Update goal if requested
	if not parsed.goal_update.is_empty():
		npc.set_goal(parsed.goal_update)
		memory.add_goal(parsed.goal_update)

	executor.execute(parsed.action, parsed.target, parsed.dialogue)

func _on_llm_failed(req_id: String, error: String) -> void:
	if req_id != npc.npc_id:
		return
	_waiting_for_llm = false

	push_warning("NPC %s: LLM request failed: %s" % [npc.npc_id, error])
	memory.add_observation("Couldn't think clearly (LLM error: %s)" % error)

	# Fallback to test action
	npc.change_state("idle")
	if not _test_actions.is_empty():
		_use_test_action()

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

## Reactive conversation — triggered when another entity speaks to this NPC.
## Bypasses the normal tick timer for immediate response.
func request_reactive_response(speaker_id: String, spoken_text: String) -> void:
	if _waiting_for_llm:
		return  # Already processing

	memory.add_observation("%s spoke to me: '%s'" % [speaker_id, spoken_text])
	memory.add_conversation(speaker_id, speaker_id, spoken_text)

	if _use_llm and LLMClient.is_available():
		# Build a conversation-focused prompt
		npc.change_state("thinking")
		_waiting_for_llm = true
		_decision_timer = 0.0  # Reset tick timer

		var messages: Array = [
			PromptBuilder.build_system_message(npc.npc_name, npc.personality, npc.current_goal),
			PromptBuilder.build_user_message(npc.npc_id, npc, memory),
			{"role": "user", "content": "%s just said to you: \"%s\"\nRespond naturally using the talk_to action." % [speaker_id, spoken_text]},
		]

		var schema := ActionSchema.get_schema()
		LLMClient.send_chat(npc.npc_id, messages, schema)
		GameEvents.llm_request_sent.emit(npc.npc_id)
	else:
		# Fallback: generic greeting response
		var greeting := "Well met, traveler!" if speaker_id == "player" else "Hello, %s." % speaker_id
		executor.execute("talk_to", speaker_id, greeting)

func _on_action_completed(completed_npc_id: String, action: String, success: bool) -> void:
	if completed_npc_id == npc.npc_id:
		var status := "succeeded" if success else "failed"
		memory.add_observation("Action '%s' %s" % [action, status])

func _on_npc_spoke(speaker_id: String, dialogue: String, target_id: String) -> void:
	if target_id == npc.npc_id:
		# Auto-respond to create natural back-and-forth conversations.
		# request_reactive_response() handles memory, so skip it here to avoid duplicates.
		if speaker_id != "player":
			request_reactive_response(speaker_id, dialogue)
		else:
			memory.add_conversation(speaker_id, speaker_id, dialogue)
			memory.add_observation("%s said to me: '%s'" % [speaker_id, dialogue])
	elif speaker_id == npc.npc_id:
		memory.add_conversation(target_id, npc.npc_id, dialogue)
