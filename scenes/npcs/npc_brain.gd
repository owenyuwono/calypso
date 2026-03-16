extends Node
## NPC brain — LLM decision loop for adventurer NPCs with combat awareness.

const CONVERSATION_HOLD_TIME: float = 10.0
const CHAT_RANGE: float = 8.0
const READING_DELAY: float = 3.0  # seconds to "read" before responding to NPC speech
const POST_SPEECH_COOLDOWN_MIN: float = 5.0
const POST_SPEECH_COOLDOWN_MAX: float = 10.0
const OVERHEARD_DELAY_MIN: float = 2.0
const OVERHEARD_DELAY_MAX: float = 5.0

const PromptBuilder = preload("res://scripts/llm/prompt_builder.gd")
const ResponseParser = preload("res://scripts/llm/response_parser.gd")
const ActionSchema = preload("res://scripts/llm/action_schema.gd")
const NpcTraitHelpers = preload("res://scripts/utils/npc_trait_helpers.gd")

var npc: CharacterBody3D  # NPCBase, duck-typed
var memory: Node  # NPCMemory
var executor: Node  # NPCActionExecutor
var _identity: Node  # NpcIdentity
var _relationship: Node  # RelationshipComponent
var _enabled: bool = true
var _waiting_for_llm: bool = false
var _use_llm: bool = false
var _use_llm_chat: bool = true  # LLM for reactive conversation only
var _responding_to: String = ""  # Guard against infinite talk_to recursion
var _pending_chat: Dictionary = {}  # {speaker_id, spoken_text} — buffered player chat when decision is in flight
var _conversation_hold: float = 0.0
var _reading_queue: Dictionary = {}  # {speaker_id, spoken_text, timer} — delayed NPC-NPC response
var _speech_cooldown: float = 0.0

# Event-driven LLM triggering
var _event_cooldowns: Dictionary = {}  # {event_type: last_trigger_time}
var _pending_events: Array = []  # Buffer events while LLM request is in-flight

const EVENT_COOLDOWNS: Dictionary = {
	"player_chat": 2.0,
	"npc_chat": 5.0,
	"goal_completed": 10.0,
	"significant_discovery": 15.0,
	"combat_outcome": 10.0,
	"low_resources": 30.0,
	"social_trigger": 20.0,
	"memory_extraction": 10.0,
	"idle_timeout": 60.0,
}

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
	_identity = npc.get_node_or_null("NpcIdentity")
	_relationship = npc.get_node_or_null("RelationshipComponent")

	# Pick initial mood
	if _identity:
		npc.current_mood = _identity.mood_emotion
	else:
		npc.current_mood = "neutral"

	GameEvents.npc_action_completed.connect(
		func(n_id: String, action: String, success: bool) -> void:
			if n_id == npc.npc_id:
				_on_action_completed(n_id, action, success)
	)
	GameEvents.npc_spoke.connect(_on_npc_spoke)
	LLMClient.request_completed.connect(_on_llm_response)
	LLMClient.request_failed.connect(_on_llm_failed)
	GameEvents.memory_added.connect(_on_memory_added)
	GameEvents.relationship_tier_changed.connect(_on_tier_changed)

func _process(delta: float) -> void:
	if not _enabled or _waiting_for_llm:
		return
	if _speech_cooldown > 0.0:
		_speech_cooldown -= delta
	if _conversation_hold > 0.0:
		_conversation_hold -= delta
		return
	# Tick reading delay for NPC-NPC responses
	if not _reading_queue.is_empty():
		_reading_queue["timer"] -= delta
		if _reading_queue["timer"] <= 0.0:
			var queued := _reading_queue
			_reading_queue = {}
			var is_overheard: bool = queued.get("overheard", false)
			var original_target: String = queued.get("original_target", "")
			request_reactive_response(queued["speaker_id"], queued["spoken_text"], is_overheard, original_target)
		return
	# Don't make decisions while in combat, dead, or already acting
	if npc.current_state in ["combat", "dead"]:
		return

## Called when a significant event happens that warrants LLM thinking.
func on_significant_event(event_type: String, context: Dictionary = {}) -> void:
	# Check cooldown
	var now: float = Time.get_unix_time_from_system()
	var cooldown: float = EVENT_COOLDOWNS.get(event_type, 10.0)
	var last_trigger: float = _event_cooldowns.get(event_type, 0.0)
	if now - last_trigger < cooldown:
		return

	# If already waiting for LLM, buffer the event
	if _waiting_for_llm:
		_pending_events.append({"type": event_type, "context": context})
		return

	# Refresh mood before triggering decision
	if _identity:
		npc.current_mood = _identity.mood_emotion
	else:
		npc.current_mood = "neutral"

	# Update cooldown and trigger LLM decision
	_event_cooldowns[event_type] = now
	if _use_llm and LLMClient.is_available():
		_request_llm_decision()
	else:
		_use_test_action()

func _request_llm_decision() -> void:
	npc.change_state("thinking")
	_waiting_for_llm = true

	var perception_comp: Node = get_parent().get_node("PerceptionComponent")
	var perception: Dictionary = perception_comp.get_perception()
	var messages: Array = [
		PromptBuilder.build_system_message(npc.npc_name, npc.personality, npc.current_goal),
		PromptBuilder.build_user_message(npc.npc_id, npc, memory, perception),
	]

	var schema := ActionSchema.get_schema()
	var req_id: String = npc.npc_id
	LLMClient.send_chat(req_id, messages, schema)

func _on_llm_response(req_id: String, response: Dictionary) -> void:
	# Route by prefix to specialized handlers
	if req_id.begins_with("extract_"):
		if not req_id.substr(8).begins_with(npc.npc_id):
			return
		_handle_extract_response(response)
		return
	elif req_id.begins_with("fuzzy_"):
		if not req_id.substr(6).begins_with(npc.npc_id):
			return
		_handle_fuzzy_response(response)
		return
	elif req_id.begins_with("opinion_"):
		if not req_id.substr(8).begins_with(npc.npc_id):
			return
		_handle_opinion_response(response)
		return
	elif req_id.begins_with("impression_"):
		if not req_id.substr(11).begins_with(npc.npc_id):
			return
		_handle_impression_response(response)
		return
	elif req_id.begins_with("conv_"):
		# conv_{npc_id}_{conversation_id} — strip "conv_{npc_id}_" prefix
		var after_prefix: String = req_id.substr(5)  # strip "conv_"
		if not after_prefix.begins_with(npc.npc_id):
			return
		var conversation_id: String = after_prefix.substr(npc.npc_id.length() + 1)  # strip "{npc_id}_"
		_handle_conversation_response(conversation_id, response)
		return
	# Route chat responses separately
	elif req_id.begins_with("chat_"):
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
		memory.add_memory("Had a confused thought (LLM parse error)", "witnessed", "low")
		npc.change_state("idle")
		return

	npc.last_thought = parsed.thinking
	memory.add_memory("Thinking: %s -> %s %s" % [parsed.thinking, parsed.action, parsed.target], "witnessed", "low")

	# Update goal if requested
	if not parsed.goal_update.is_empty():
		npc.set_goal(parsed.goal_update)
		memory.add_goal(parsed.goal_update)

	executor.execute(parsed.action, parsed.target, parsed.dialogue, parsed.get("action_data", {}))

	# After processing decision, check for buffered player chat
	if not _pending_chat.is_empty():
		var pending := _pending_chat
		_pending_chat = {}
		request_reactive_response(pending["speaker_id"], pending["spoken_text"], pending.get("overheard", false), pending.get("original_target_id", ""))
		return

	# Check for buffered significant events
	if _pending_events.size() > 0:
		var next_event: Dictionary = _pending_events.pop_front()
		on_significant_event(next_event.get("type", ""), next_event.get("context", {}))

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
	memory.add_memory("Couldn't think clearly (LLM error: %s)" % error, "witnessed", "low")

	npc.change_state("idle")
	if not _test_actions.is_empty():
		_use_test_action()

	# After processing failure, check for buffered player chat
	if not _pending_chat.is_empty():
		var pending := _pending_chat
		_pending_chat = {}
		request_reactive_response(pending["speaker_id"], pending["spoken_text"], pending.get("overheard", false), pending.get("original_target_id", ""))

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
	memory.add_memory("Decided to %s %s" % [action, target], "witnessed", "low")

	executor.execute(action, target, dialogue)

func set_test_actions(actions: Array) -> void:
	_test_actions = actions
	_test_action_index = 0

func set_use_llm(enabled: bool) -> void:
	_use_llm = enabled

func set_use_llm_chat(enabled: bool) -> void:
	_use_llm_chat = enabled

func is_busy() -> bool:
	return _waiting_for_llm or not _responding_to.is_empty() or _conversation_hold > 0.0 or not _reading_queue.is_empty() or _speech_cooldown > 0.0

## Conversation turn — called by ConversationManager during structured multi-party conversations.
func generate_conversation_turn(conversation_id: String) -> void:
	var conv_manager = get_tree().get_first_node_in_group("conversation_manager")
	if not conv_manager:
		return
	var state = conv_manager.active_conversations.get(conversation_id)
	if not state:
		return

	# Build conversation prompts
	var system_msg: String = PromptBuilder.build_conversation_system_message(npc, state.participant_ids)
	var user_msg: String = PromptBuilder.build_conversation_user_message(npc, state)

	var req_id: String = "conv_%s_%s" % [npc.npc_id, conversation_id]
	var messages: Array = [
		{"role": "system", "content": system_msg},
		{"role": "user", "content": user_msg}
	]
	LLMClient.send_chat(req_id, messages, {}, 2)  # priority 2 for NPC conversations


## Reactive conversation — triggered when another entity speaks to this NPC.
func request_reactive_response(speaker_id: String, spoken_text: String, overheard: bool = false, original_target_id: String = "") -> void:
	if _waiting_for_llm:
		# Buffer the chat — process after current LLM response completes
		_pending_chat = {"speaker_id": speaker_id, "spoken_text": spoken_text, "overheard": overheard, "original_target_id": original_target_id}
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
	memory.add_memory("%s spoke to me: '%s'" % [speaker_id, spoken_text], "witnessed", "low")
	memory.add_conversation(speaker_id, speaker_id, spoken_text)
	print("[CHAT] %s: reactive response to %s — '%s'" % [npc.npc_id, speaker_id, spoken_text])

	if _use_llm_chat:
		npc.change_state("thinking")
		_waiting_for_llm = true

		var speaker_name := _get_display_name(speaker_id)
		var activity := PromptBuilder.get_activity_description(npc.current_goal)
		var is_player := speaker_id == "player"
		var trait_summary: String = NpcTraitHelpers.get_trait_summary(npc.trait_profile)
		var ctx := _get_identity_context()
		var rel_label: String = ""
		if speaker_id != "player":
			rel_label = _relationship.get_tier(speaker_id) if _relationship else "stranger"
		var reactive_facts: Array = memory.gather_chat_facts(speaker_id)
		var grounding := _format_grounding_facts(reactive_facts, 3)
		var original_target_name: String = ""
		if overheard and not original_target_id.is_empty():
			original_target_name = _get_display_name(original_target_id)
		var messages: Array = [
			PromptBuilder.build_chat_system_message(npc.npc_name, npc.personality, activity, is_player, trait_summary, ctx.backstory, ctx.voice_style, ctx.mood_prompt, grounding),
			PromptBuilder.build_chat_user_message(npc.npc_name, npc.npc_id, speaker_name, spoken_text, memory, rel_label, overheard, original_target_name),
		]

		var req_id: String = "chat_" + npc.npc_id
		LLMClient.send_chat(req_id, messages)
	else:
		var greeting := "Well met, traveler!" if speaker_id == "player" else "Hello, %s." % _get_display_name(speaker_id)
		executor.execute("talk_to", speaker_id, greeting)
		_responding_to = ""

func initiate_social_chat(target_id: String, topic: String = "", intent_cue: String = "", facts: Array = []) -> bool:
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
		var trait_summary: String = NpcTraitHelpers.get_trait_summary(npc.trait_profile)
		var ctx := _get_identity_context()
		var rel_label: String = _relationship.get_tier(target_id) if _relationship else "stranger"
		var grounding := _format_grounding_facts(facts, 4)
		var messages: Array = [
			PromptBuilder.build_chat_initiate_system_message(npc.npc_name, npc.personality, activity, target_name, topic, trait_summary, intent_cue, ctx.backstory, ctx.voice_style, ctx.mood_prompt, grounding),
			PromptBuilder.build_chat_initiate_user_message(npc.npc_name, npc.npc_id, target_name, target_id, target_activity, memory, rel_label),
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

func _get_identity_context() -> Dictionary:
	if _identity:
		npc.current_mood = _identity.mood_emotion
		return {
			"backstory": _identity.backstory,
			"voice_style": _identity.speech_style,
			"mood_prompt": _identity.get_mood_prompt(),
		}
	npc.current_mood = "neutral"
	return {"backstory": "", "voice_style": "", "mood_prompt": ""}


func _format_grounding_facts(facts: Array, max_count: int = 4) -> String:
	if facts.is_empty():
		return ""
	# Sort by weight descending, take top N
	var sorted_facts := facts.duplicate()
	sorted_facts.sort_custom(func(a, b): return a.get("weight", 1.0) > b.get("weight", 1.0))
	var lines: Array = []
	var count := 0
	for f in sorted_facts:
		if count >= max_count:
			break
		lines.append("- %s" % f.get("fact", ""))
		count += 1
	return "YOUR FACTS:\n" + "\n".join(lines)

func _handle_chat_response(response: Dictionary) -> void:
	_waiting_for_llm = false
	var speaker_id := _responding_to
	var parsed := ResponseParser.parse_chat(response)
	if not parsed.valid:
		print("[CHAT] %s: parse failed for reply to %s — fallback greeting" % [npc.npc_id, speaker_id])
		var greeting := "Well met, traveler!" if speaker_id == "player" else "Hello, %s." % _get_display_name(speaker_id)
		executor.execute("talk_to", speaker_id, greeting)
		_responding_to = ""
		_conversation_hold = CONVERSATION_HOLD_TIME
		return
	print("[CHAT] %s → %s: '%s'" % [npc.npc_id, speaker_id, parsed.dialogue])
	memory.add_memory("Replied to %s: '%s'" % [speaker_id, parsed.dialogue], "witnessed", "low")
	executor.execute("talk_to", speaker_id, parsed.dialogue)
	_conversation_hold = CONVERSATION_HOLD_TIME
	_speech_cooldown = randf_range(POST_SPEECH_COOLDOWN_MIN, POST_SPEECH_COOLDOWN_MAX)

	# Only apply goal changes when the player is speaking (NPC-NPC chat stays behavior-driven)
	if speaker_id == "player" and not parsed.goal.is_empty():
		npc.set_goal(parsed.goal)
		memory.add_goal(parsed.goal)
		memory.add_memory("Changed goal to '%s' after talking with %s" % [parsed.goal, speaker_id], "witnessed", "medium")
		memory.add_memory("Player asked me to %s" % parsed.goal, "witnessed", "high", false, "notable_conversation")

func _get_display_name(entity_id: String) -> String:
	if entity_id == "player":
		return "Player"
	var data := WorldState.get_entity_data(entity_id)
	return data.get("name", entity_id)

func _on_action_completed(completed_npc_id: String, action: String, success: bool) -> void:
	if completed_npc_id == npc.npc_id:
		var status := "succeeded" if success else "failed"
		memory.add_memory("Action '%s' %s" % [action, status], "witnessed", "low")

func _on_npc_spoke(speaker_id: String, dialogue: String, target_id: String) -> void:
	# We just spoke — clear responding guard, set cooldowns
	if speaker_id == npc.npc_id:
		_responding_to = ""
		_conversation_hold = CONVERSATION_HOLD_TIME
		_speech_cooldown = randf_range(POST_SPEECH_COOLDOWN_MIN, POST_SPEECH_COOLDOWN_MAX)
		memory.add_conversation(target_id, npc.npc_id, dialogue)
		memory.add_area_chat(npc.npc_name, dialogue)
		return

	# Range check — can we hear the speaker?
	var speaker_node := WorldState.get_entity(speaker_id)
	if not speaker_node or not is_instance_valid(speaker_node):
		return
	if npc.global_position.distance_to(speaker_node.global_position) > CHAT_RANGE:
		return

	# Record to area chat log (everyone nearby hears it)
	var speaker_name := _get_display_name(speaker_id)
	memory.add_area_chat(speaker_name, dialogue)
	memory.add_conversation(speaker_id, speaker_id, dialogue)

	# Can we respond? Skip if busy/dead/combat/on cooldown
	if _speech_cooldown > 0.0 or is_busy():
		return
	if npc.current_state in ["dead", "combat"]:
		return
	if not memory.can_continue_conversation(speaker_id):
		return

	# Direct target: shorter delay. Overheard: longer random delay.
	if target_id == npc.npc_id:
		print("[CHAT] %s: heard %s say '%s' — queuing response" % [npc.npc_id, speaker_id, dialogue])
		if speaker_id != "player":
			_reading_queue = {"speaker_id": speaker_id, "spoken_text": dialogue, "timer": READING_DELAY, "overheard": false}
		else:
			pass  # Player chat handled via request_reactive_response directly
	else:
		# Overheard — free-for-all with staggered delay
		if speaker_id != "player":
			print("[CHAT] %s: overheard %s say '%s' — may chime in" % [npc.npc_id, speaker_id, dialogue])
			_reading_queue = {"speaker_id": speaker_id, "spoken_text": dialogue, "timer": randf_range(OVERHEARD_DELAY_MIN, OVERHEARD_DELAY_MAX), "overheard": true, "original_target": target_id}

# --- LLM response handlers (specialized) ---

func _handle_extract_response(response: Dictionary) -> void:
	var content: String = response.get("message", {}).get("content", "")
	if content.is_empty():
		return
	var facts: Array = content.split("\n")
	for fact in facts:
		fact = fact.strip_edges()
		if fact.is_empty() or fact.length() < 3:
			continue
		# Remove numbering like "1. " or "- "
		if fact.length() > 2 and fact[1] == "." and fact[0].is_valid_int():
			fact = fact.substr(2).strip_edges()
		elif fact.begins_with("- "):
			fact = fact.substr(2).strip_edges()
		memory.add_memory(fact, "heard_from:conversation", "medium")
		GameEvents.fact_learned.emit(npc.npc_id, fact, "conversation")

func _handle_fuzzy_response(response: Dictionary) -> void:
	pass  # Future: update memory's fuzzy_text field

func _handle_opinion_response(response: Dictionary) -> void:
	if not _identity:
		return
	var content: String = response.get("message", {}).get("content", "")
	if content.is_empty():
		return

	var topic: String = ""
	var stance: String = "neutral"
	var opinion_text: String = content

	for line in content.split("\n"):
		line = line.strip_edges()
		if line.begins_with("TOPIC:"):
			topic = line.substr(6).strip_edges()
		elif line.begins_with("STANCE:"):
			stance = line.substr(7).strip_edges().to_lower()
		elif line.begins_with("OPINION:"):
			opinion_text = line.substr(8).strip_edges()

	if topic.is_empty():
		topic = "general"

	var opinion: Dictionary = {
		"topic": topic,
		"take": opinion_text,
		"strength": "moderate",
		"will_share_with": "anyone",
		"stance": stance,
		"reasoning": opinion_text,
		"source": "experience",
		"formed_at": Time.get_unix_time_from_system()
	}

	_identity.add_opinion(opinion)
	GameEvents.opinion_formed.emit(npc.npc_id, topic, stance)

func _handle_impression_response(response: Dictionary) -> void:
	pass  # Future: parse impression, store via relationship.set_impression()

func _handle_conversation_response(conversation_id: String, response: Dictionary) -> void:
	var conv_manager = get_tree().get_first_node_in_group("conversation_manager")
	if not conv_manager:
		return

	var parsed: Dictionary = ResponseParser.parse_conversation_response(response)
	var turn: Dictionary = ConversationState.make_turn(
		npc.npc_id,
		parsed.dialogue,
		parsed.action,
		Time.get_unix_time_from_system(),
		parsed.get("new_topic", "")
	)
	conv_manager.add_turn(conversation_id, turn)

# --- LLM trigger methods ---

func request_memory_extraction(conversation_id: String, transcript: String = "") -> void:
	if transcript.is_empty():
		return

	var npc_name: String = npc.npc_name if "npc_name" in npc else npc.npc_id
	var prompt: String = "You are %s. You just had this conversation:\n%s\nWhat 1-3 facts would you remember? List each fact on its own line. Be brief." % [npc_name, transcript]

	var req_id: String = "extract_%s_%s" % [npc.npc_id, conversation_id]
	var messages: Array = [{"role": "user", "content": prompt}]
	LLMClient.send_chat(req_id, messages, {}, 4)

func _request_impression_update(entity_id: String) -> void:
	pass  # Future: send impression prompt with priority 5

func _maybe_form_opinion(entity_id: String, fact: String, importance: String) -> void:
	if importance != "high":
		return
	if not _identity:
		return

	var npc_name: String = _identity.npc_name if _identity.npc_name else npc.npc_id
	var personality: String = _identity.get_personality_prompt()
	var prompt: String = "You are %s, %s. You just learned: '%s'. In one sentence, what is your opinion about this? Respond with exactly this format:\nTOPIC: <topic>\nSTANCE: <positive/negative/neutral/curious/fearful>\nOPINION: <your take>" % [npc_name, personality, fact]

	var req_id: String = "opinion_%s_%d" % [npc.npc_id, Time.get_ticks_msec()]
	var messages: Array = [{"role": "user", "content": prompt}]
	LLMClient.send_chat(req_id, messages, {}, 5)

# --- Signal handlers ---

func _on_memory_added(entity_id: String, fact: String, importance: String) -> void:
	if entity_id != npc.npc_id:
		return
	_maybe_form_opinion(entity_id, fact, importance)

func _on_tier_changed(entity_id: String, partner_id: String, old_tier: String, new_tier: String) -> void:
	if entity_id != npc.npc_id:
		return
	_request_impression_update(partner_id)
