extends RefCounted
## Pure data class representing a conversation between two or more entities.
## No game logic, no signals, no references to other systems.
class_name ConversationState

const ACTION_SPEAK: String = "speak"
const ACTION_SILENCE: String = "silence"
const ACTION_TOPIC_CHANGE: String = "topic_change"
const ACTION_WALK_AWAY: String = "walk_away"
const ACTION_JOIN: String = "join"

var conversation_id: String = ""
var participant_ids: Array = []
var location: String = ""
var topic: String = ""
var turns: Array = []  # Array of ConversationTurn dicts
var nearby_listeners: Array = []
var mood: String = "friendly"  # friendly/tense/casual/heated/quiet
var started_at: float = 0.0
var max_turns: int = 20


## Factory: build a ConversationState with required fields pre-filled.
## start_time: pass Time.get_unix_time_from_system() or a game clock value — used by timeout logic.
static func create(id: String, participants: Array, loc: String, t: String, start_time: float) -> ConversationState:
	var state := ConversationState.new()
	state.conversation_id = id
	state.participant_ids = participants.duplicate()
	state.location = loc
	state.topic = t
	state.started_at = start_time
	return state


## Build a ConversationTurn dictionary.
## action must be one of: "speak", "silence", "topic_change", "walk_away", "join"
static func make_turn(speaker_id: String, text: String, action: String, ts: float, t: String = "") -> Dictionary:
	return {
		"speaker_id": speaker_id,
		"text": text,
		"action": action,
		"timestamp": ts,
		"topic": t,
	}


## Append a turn dict to the turns array.
func add_turn(turn: Dictionary) -> void:
	turns.append(turn)


## Return the number of participants in this conversation.
func get_participant_count() -> int:
	return participant_ids.size()


## Return the speaker_id from the most recent turn, or "" if no turns exist.
func get_last_speaker() -> String:
	if turns.is_empty():
		return ""
	return turns.back().get("speaker_id", "")


## Return the total number of turns recorded.
func get_turn_count() -> int:
	return turns.size()
