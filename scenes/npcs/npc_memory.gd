extends Node
## NPC memory — rolling observation window and conversation history.

const MAX_OBSERVATIONS: int = 20
const MAX_CONVERSATION_HISTORY: int = 10

var observations: Array = []
var conversation_history: Dictionary = {}  # partner_id -> Array of {speaker, text}
var goals_history: Array = []

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
