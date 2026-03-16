class_name ConversationManager
extends Node
## Manages active multi-party conversations: lifecycle, turn selection, timeout.

const SILENCE_TIMEOUT: float = 30.0
const MAX_TURNS: int = 20
const EARSHOT_RANGE: float = 15.0
const TURN_COOLDOWN: float = 3.0
const MAX_CONSECUTIVE_SILENCE: int = 3
const SPEAK_THRESHOLD: float = 2.0

var active_conversations: Dictionary = {}  # conversation_id -> ConversationState
var entity_to_conversation: Dictionary = {}  # entity_id -> conversation_id
var _conversation_counter: int = 0

var _turn_timers: Dictionary = {}   # conversation_id -> float
var _silence_counts: Dictionary = {}  # conversation_id -> {entity_id: int}


func _ready() -> void:
	add_to_group("conversation_manager")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func start_conversation(initiator_id: String, target_ids: Array, topic: String) -> String:
	# Reject if initiator already in a conversation
	if is_in_conversation(initiator_id):
		return ""

	# Reject if any target is already in a conversation
	for tid in target_ids:
		if is_in_conversation(tid):
			return ""

	var conversation_id: String = "conv_%d" % _conversation_counter
	_conversation_counter += 1

	var all_ids: Array = [initiator_id] + target_ids
	var state: ConversationState = ConversationState.create(
		conversation_id,
		all_ids,
		"",
		topic,
		Time.get_unix_time_from_system()
	)

	active_conversations[conversation_id] = state
	_silence_counts[conversation_id] = {}

	for pid in all_ids:
		entity_to_conversation[pid] = conversation_id
		_silence_counts[conversation_id][pid] = 0

	GameEvents.conversation_started.emit(conversation_id, all_ids)
	return conversation_id


func end_conversation(conversation_id: String) -> void:
	if not active_conversations.has(conversation_id):
		return

	var state: ConversationState = active_conversations[conversation_id]
	if not state:
		active_conversations.erase(conversation_id)
		return

	# Build transcript BEFORE erasing state so brains receive complete text
	var transcript: String = _build_transcript(state)

	# Trigger memory extraction BEFORE cleanup
	for pid in state.participant_ids:
		if pid == "player":
			continue
		var entity: Node = WorldState.get_entity(pid)
		if entity and is_instance_valid(entity):
			var brain: Node = entity.get_node_or_null("NPCBrain")
			if brain and brain.has_method("request_memory_extraction"):
				brain.request_memory_extraction(conversation_id, transcript)

	# Cleanup participant map
	for pid in state.participant_ids:
		entity_to_conversation.erase(pid)

	# Cleanup timers and silence counts
	_turn_timers.erase(conversation_id)
	_silence_counts.erase(conversation_id)

	active_conversations.erase(conversation_id)
	GameEvents.conversation_ended.emit(conversation_id)


func join_conversation(conversation_id: String, entity_id: String) -> void:
	if not active_conversations.has(conversation_id):
		return

	var state: ConversationState = active_conversations[conversation_id]
	if entity_id in state.participant_ids:
		return

	state.participant_ids.append(entity_id)
	entity_to_conversation[entity_id] = conversation_id

	if not _silence_counts.has(conversation_id):
		_silence_counts[conversation_id] = {}
	_silence_counts[conversation_id][entity_id] = 0

	var turn: Dictionary = ConversationState.make_turn(
		entity_id, "", ConversationState.ACTION_JOIN, Time.get_unix_time_from_system()
	)
	state.add_turn(turn)

	GameEvents.conversation_participant_joined.emit(conversation_id, entity_id)


func leave_conversation(conversation_id: String, entity_id: String, reason: String = "walked away") -> void:
	if not active_conversations.has(conversation_id):
		return

	var state: ConversationState = active_conversations[conversation_id]
	state.participant_ids.erase(entity_id)
	entity_to_conversation.erase(entity_id)

	if _silence_counts.has(conversation_id):
		_silence_counts[conversation_id].erase(entity_id)

	var turn: Dictionary = ConversationState.make_turn(
		entity_id, reason, ConversationState.ACTION_WALK_AWAY, Time.get_unix_time_from_system()
	)
	state.add_turn(turn)

	GameEvents.conversation_participant_left.emit(conversation_id, entity_id)

	if state.participant_ids.size() < 2:
		end_conversation(conversation_id)


func add_turn(conversation_id: String, turn: Dictionary) -> void:
	if not active_conversations.has(conversation_id):
		return

	var state: ConversationState = active_conversations[conversation_id]
	state.add_turn(turn)

	GameEvents.conversation_turn_added.emit(
		conversation_id,
		turn.get("speaker_id", ""),
		turn.get("text", ""),
		turn.get("action", ConversationState.ACTION_SPEAK)
	)

	if state.get_turn_count() >= MAX_TURNS:
		end_conversation(conversation_id)


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func get_conversation(entity_id: String) -> ConversationState:
	var conv_id: String = entity_to_conversation.get(entity_id, "")
	if conv_id.is_empty():
		return null
	return active_conversations.get(conv_id)


func is_in_conversation(entity_id: String) -> bool:
	return entity_id in entity_to_conversation


func update_nearby_listeners(conversation_id: String) -> void:
	if not active_conversations.has(conversation_id):
		return

	var state: ConversationState = active_conversations[conversation_id]
	if state.participant_ids.is_empty():
		return

	# Use first participant's position as conversation location
	var first_id: String = state.participant_ids[0]
	var first_entity: Node = WorldState.get_entity(first_id)
	if not first_entity or not is_instance_valid(first_entity):
		return

	var perception_comp: Node = first_entity.get_node_or_null("PerceptionComponent")
	var nearby: Array = perception_comp.get_nearby(EARSHOT_RANGE) if perception_comp else []
	var listeners: Array[String] = []
	for entry in nearby:
		var eid: String = entry.get("id", "")
		if eid.is_empty():
			continue
		if eid in state.participant_ids:
			continue
		listeners.append(eid)

	state.nearby_listeners = listeners


# ---------------------------------------------------------------------------
# Turn Selection
# ---------------------------------------------------------------------------

func select_next_speaker(conversation_id: String) -> String:
	if not active_conversations.has(conversation_id):
		return ""

	var state: ConversationState = active_conversations[conversation_id]
	var last_speaker: String = state.get_last_speaker()

	var silence_data: Dictionary = _silence_counts.get(conversation_id, {})

	var best_id: String = ""
	var best_score: float = -INF

	for pid in state.participant_ids:
		if pid == "player":
			continue

		var entity: Node = WorldState.get_entity(pid)
		if not entity or not is_instance_valid(entity):
			continue

		# Skip dead entities
		if not WorldState.is_alive(pid):
			continue

		# Skip entities currently in combat or dead state
		if "current_state" in entity and entity.current_state in ["combat", "dead"]:
			continue

		var score: float = 1.0

		# topic_relevance: check NpcIdentity likes/dislikes
		var identity: Node = entity.get_node_or_null("NpcIdentity")
		if identity:
			var topic: String = state.topic.to_lower()
			var likes: Array = identity.likes if "likes" in identity else []
			var dislikes: Array = identity.dislikes if "dislikes" in identity else []
			var found_like: bool = false
			var found_dislike: bool = false
			for like in likes:
				if like.to_lower().contains(topic) or topic.contains(like.to_lower()):
					found_like = true
					break
			for dislike in dislikes:
				if dislike.to_lower().contains(topic) or topic.contains(dislike.to_lower()):
					found_dislike = true
					break
			if found_like:
				score += 2.0
			elif found_dislike:
				score += 1.0  # they have something to say

		# relationship_bonus: tier with last speaker
		if not last_speaker.is_empty() and last_speaker != pid:
			var rel_comp: Node = entity.get_node_or_null("RelationshipComponent")
			if rel_comp:
				var tier: String = rel_comp.get_tier(last_speaker)
				match tier:
					"recognized":
						score += 0.5
					"acquaintance":
						score += 0.75
					"friendly":
						score += 1.0
					"close":
						score += 1.25
					"bonded":
						score += 1.5

		# personality_drive: sociability trait * 2.0
		if identity:
			score += identity.get_trait("sociability", 0.5) * 2.0

		# recency_penalty
		if pid == last_speaker:
			score -= 2.0

		# silence_streak_bonus
		var streak: int = silence_data.get(pid, 0)
		score += streak * 0.5

		# random jitter
		score += randf_range(-0.3, 0.3)

		if score > best_score:
			best_score = score
			best_id = pid

	if best_score < SPEAK_THRESHOLD:
		# No one wants to speak — update silence streaks
		_update_silence_streaks(conversation_id, state, "")
		return ""

	# Reset silence count for selected speaker, increment others
	_update_silence_streaks(conversation_id, state, best_id)

	return best_id


func _update_silence_streaks(conversation_id: String, state: ConversationState, speaker_id: String) -> void:
	if not _silence_counts.has(conversation_id):
		return

	var silence_data: Dictionary = _silence_counts[conversation_id]
	var all_silent: bool = true

	for pid in state.participant_ids:
		if pid == "player":
			continue
		if pid == speaker_id:
			silence_data[pid] = 0
			all_silent = false
		else:
			if not silence_data.has(pid):
				silence_data[pid] = 0
			silence_data[pid] += 1

			# Auto-leave if silence streak is too long
			if silence_data[pid] >= MAX_CONSECUTIVE_SILENCE:
				# Schedule via deferred to avoid mutating participant_ids during iteration
				call_deferred("leave_conversation", conversation_id, pid, "lost interest")

	# End if all NPC participants have been silent a full round
	if all_silent:
		call_deferred("end_conversation", conversation_id)


# ---------------------------------------------------------------------------
# Turn Loop
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	var to_end: Array = []
	var now := Time.get_unix_time_from_system()

	for conv_id in active_conversations:
		var state: ConversationState = active_conversations[conv_id]
		if not state:
			to_end.append(conv_id)
			continue

		# Initialize timer
		if conv_id not in _turn_timers:
			_turn_timers[conv_id] = 0.0

		_turn_timers[conv_id] += delta

		# Check silence timeout
		if state.get_turn_count() > 0:
			var last_turn: Dictionary = state.turns.back()
			var elapsed: float = now - last_turn.get("timestamp", state.started_at)
			if elapsed > SILENCE_TIMEOUT:
				to_end.append(conv_id)
				continue
		elif now - state.started_at > SILENCE_TIMEOUT:
			to_end.append(conv_id)
			continue

		# Turn cooldown
		if _turn_timers[conv_id] < TURN_COOLDOWN:
			continue
		_turn_timers[conv_id] = 0.0

		# Update nearby listeners
		update_nearby_listeners(conv_id)

		# Select speaker
		var speaker_id: String = select_next_speaker(conv_id)
		if speaker_id.is_empty():
			continue

		# Get brain and request turn
		var entity: Node = WorldState.get_entity(speaker_id)
		if entity and is_instance_valid(entity):
			var brain: Node = entity.get_node_or_null("NPCBrain")
			if brain and brain.has_method("generate_conversation_turn"):
				brain.generate_conversation_turn(conv_id)
			elif brain:
				_generate_fallback_turn(conv_id, speaker_id, state)

	# End timed-out conversations
	for conv_id in to_end:
		if conv_id in active_conversations:
			end_conversation(conv_id)


func _generate_fallback_turn(conv_id: String, speaker_id: String, _state: ConversationState) -> void:
	var turn: Dictionary = ConversationState.make_turn(
		speaker_id, "...", ConversationState.ACTION_SILENCE, Time.get_unix_time_from_system()
	)
	add_turn(conv_id, turn)


func _build_transcript(state: ConversationState) -> String:
	if not state:
		return ""
	var lines: Array = []
	for turn in state.turns:
		var speaker_id: String = turn.get("speaker_id", "unknown")
		var speaker_name: String = speaker_id
		var entity: Node = WorldState.get_entity(speaker_id)
		if entity and "npc_name" in entity:
			speaker_name = entity.npc_name
		elif speaker_id == "player":
			speaker_name = "Player"
		var text: String = turn.get("text", "[silence]")
		lines.append("%s: %s" % [speaker_name, text])
	return "\n".join(lines)
