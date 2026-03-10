extends Node
## NPC memory — rolling observation window and conversation history.

const MAX_OBSERVATIONS: int = 20
const MAX_CONVERSATION_HISTORY: int = 10

var observations: Array = []
var conversation_history: Dictionary = {}  # partner_id -> Array of {speaker, text}
var goals_history: Array = []
var _conversation_turns: Dictionary = {}  # partner_id -> {count: int, time: float}
const MAX_CONVERSATION_TURNS: int = 2
const CONVERSATION_WINDOW: float = 60.0  # Reset after this gap in seconds

func can_continue_conversation(partner_id: String) -> bool:
	if _conversation_turns.has(partner_id):
		var entry: Dictionary = _conversation_turns[partner_id]
		if Time.get_ticks_msec() / 1000.0 - entry["time"] > CONVERSATION_WINDOW:
			_conversation_turns.erase(partner_id)
			return true
		return entry["count"] < MAX_CONVERSATION_TURNS
	return true

func increment_turn(partner_id: String) -> void:
	if _conversation_turns.has(partner_id):
		var entry: Dictionary = _conversation_turns[partner_id]
		if Time.get_ticks_msec() / 1000.0 - entry["time"] > CONVERSATION_WINDOW:
			_conversation_turns[partner_id] = {"count": 1, "time": Time.get_ticks_msec() / 1000.0}
		else:
			entry["count"] += 1
			entry["time"] = Time.get_ticks_msec() / 1000.0
	else:
		_conversation_turns[partner_id] = {"count": 1, "time": Time.get_ticks_msec() / 1000.0}

func reset_conversation_turns(partner_id: String) -> void:
	_conversation_turns.erase(partner_id)

func add_observation(text: String) -> void:
	var entry := "[%s] %s" % [_timestamp(), text]
	observations.append(entry)
	if observations.size() > MAX_OBSERVATIONS:
		observations.pop_front()

func add_conversation(partner_id: String, speaker_id: String, text: String) -> void:
	if not conversation_history.has(partner_id):
		conversation_history[partner_id] = []
	conversation_history[partner_id].append({
		"speaker": speaker_id,
		"text": text,
	})
	if conversation_history[partner_id].size() > MAX_CONVERSATION_HISTORY:
		conversation_history[partner_id].pop_front()

func get_conversation_with(partner_id: String) -> Array:
	return conversation_history.get(partner_id, [])

func add_goal(goal: String) -> void:
	goals_history.append(goal)

func get_recent_observations(count: int = 10) -> Array:
	var start := maxi(0, observations.size() - count)
	return observations.slice(start)

func get_summary() -> String:
	var parts: Array = []
	if not observations.is_empty():
		parts.append("Recent observations:\n" + "\n".join(get_recent_observations(5)))
	if not goals_history.is_empty():
		parts.append("Goal history: " + ", ".join(goals_history.slice(-3)))
	return "\n".join(parts)

func _timestamp() -> String:
	var ticks := Time.get_ticks_msec()
	var secs := ticks / 1000
	var mins := secs / 60
	return "%d:%02d" % [mins, secs % 60]
