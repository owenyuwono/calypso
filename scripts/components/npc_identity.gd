extends BaseComponent
class_name NpcIdentity
## Owns identity, personality, mood, opinions, schedule, and secrets for an NPC.
## Loaded from NpcIdentityDatabase. Syncs mood/opinions back to WorldState.entity_data.

# --- Identity fields ---
var npc_id: String = ""
var npc_name: String = ""
var age: String = ""
var occupation: String = ""
var traits: Dictionary = {}
var speech_style: String = ""
var backstory: String = ""
var likes: Array = []
var dislikes: Array = []
var desires: Array = []
var opinions: Array = []
var secrets: Array = []
var tendencies: Dictionary = {}

# --- Mood ---
var mood_emotion: String = "content"
var mood_energy: String = "normal"
var baseline_emotion: String = "content"
var baseline_energy: String = "normal"

# --- Schedule ---
var schedule_type: String = "goal"
var routine: Array = []
var periodic_pattern: Array = []

# Emotion decay chain: each key steps toward value
const _EMOTION_STEPS: Dictionary = {
	"angry": "content",
	"worried": "content",
	"afraid": "worried",
	"sad": "content",
	"excited": "content",
}

# Energy decay chain: each key steps toward value
const _ENERGY_STEPS: Dictionary = {
	"tired": "normal",
	"energetic": "normal",
}

func _ready() -> void:
	npc_id = _get_entity_id()
	GameEvents.game_hour_changed.connect(_on_game_hour_changed)
	GameEvents.entity_damaged.connect(_on_entity_damaged)
	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_respawned.connect(_on_entity_respawned)
	GameEvents.proficiency_level_up.connect(_on_proficiency_level_up)


func setup(data: Dictionary) -> void:
	npc_name = data.get("name", "")
	age = data.get("age", "")
	occupation = data.get("occupation", "")
	traits = data.get("traits", {}).duplicate()
	speech_style = data.get("speech_style", "")
	backstory = data.get("backstory", "")
	likes = data.get("likes", []).duplicate()
	dislikes = data.get("dislikes", []).duplicate()
	desires = data.get("desires", []).duplicate()
	opinions = data.get("opinions", []).duplicate()
	secrets = data.get("secrets", []).duplicate()
	tendencies = data.get("tendencies", {}).duplicate()
	baseline_emotion = data.get("baseline_emotion", "content")
	baseline_energy = data.get("baseline_energy", "normal")
	mood_emotion = baseline_emotion
	mood_energy = baseline_energy
	schedule_type = data.get("schedule_type", "goal")
	routine = data.get("routine", []).duplicate()
	periodic_pattern = data.get("periodic_pattern", []).duplicate()


# --- Mood system ---

func shift_mood(emotion: String, energy: String = "") -> void:
	mood_emotion = emotion
	if not energy.is_empty():
		mood_energy = energy
	GameEvents.mood_changed.emit(_get_entity_id(), mood_emotion, mood_energy)
	_sync_mood()


func _on_game_hour_changed(_hour: int) -> void:
	var changed := false

	if mood_emotion != baseline_emotion:
		if _EMOTION_STEPS.has(mood_emotion):
			mood_emotion = _EMOTION_STEPS[mood_emotion]
		else:
			# No further step defined; jump directly to baseline (e.g. content → excited)
			mood_emotion = baseline_emotion
		changed = true

	if mood_energy != baseline_energy:
		if _ENERGY_STEPS.has(mood_energy):
			mood_energy = _ENERGY_STEPS[mood_energy]
		else:
			# No further step defined; jump directly to baseline
			mood_energy = baseline_energy
		changed = true

	if changed:
		GameEvents.mood_changed.emit(_get_entity_id(), mood_emotion, mood_energy)
		_sync_mood()


func _on_entity_damaged(target_id: String, _attacker_id: String, _damage: int, remaining_hp: int) -> void:
	if target_id != _get_entity_id():
		return
	var stats = get_parent().get_node_or_null("StatsComponent")
	if not stats:
		return
	var max_hp: int = stats.max_hp
	if max_hp <= 0:
		return
	var ratio: float = float(remaining_hp) / float(max_hp)
	# afraid: below 20% HP; worried: lost at least 20% of max HP (ratio < 0.8)
	if ratio < 0.2:
		shift_mood("afraid", "")
	elif ratio < 0.8:
		shift_mood("worried", "")


func _on_entity_died(entity_id: String, killer_id: String) -> void:
	if entity_id == _get_entity_id():
		shift_mood("sad", "tired")
		return
	# Nearby enemy died — check if they were close to us
	var dead_entity: Node = WorldState.get_entity(entity_id)
	var self_node: Node = WorldState.get_entity(_get_entity_id())
	if not dead_entity or not self_node:
		return
	if self_node.global_position.distance_to(dead_entity.global_position) > 15.0:
		return
	shift_mood("content", "energetic")


func _on_entity_respawned(entity_id: String) -> void:
	if entity_id != _get_entity_id():
		return
	shift_mood("content", "tired")


func _on_proficiency_level_up(entity_id: String, _skill_id: String, _new_level: int) -> void:
	if entity_id != _get_entity_id():
		return
	shift_mood("excited", "energetic")


# --- Trait API ---

func get_trait(trait_name: String, default: float = 0.5) -> float:
	return float(traits.get(trait_name, default))


# --- Prompt accessors ---

func get_personality_prompt() -> String:
	var parts: Array = []
	parts.append("Name: %s" % npc_name)
	parts.append("Age: %s" % age)
	parts.append("Occupation: %s" % occupation)
	parts.append("Speech style: %s" % speech_style)
	parts.append("Backstory: %s" % backstory)
	if not likes.is_empty():
		parts.append("Likes: %s" % ", ".join(likes))
	if not dislikes.is_empty():
		parts.append("Dislikes: %s" % ", ".join(dislikes))
	return "\n".join(parts)


func get_mood_prompt() -> String:
	return "Mood: %s, Energy: %s" % [mood_emotion, mood_energy]


func get_tendency_prompt() -> String:
	var lines: Array = []
	if tendencies.get("exaggerates", false):
		lines.append("You tend to exaggerate.")
	if tendencies.get("withholds_from_strangers", false):
		lines.append("You withhold information from strangers.")
	var lies_when: String = tendencies.get("lies_when", "never")
	if lies_when != "never" and not lies_when.is_empty():
		lines.append("You lie when %s." % lies_when)
	var avoids: Array = tendencies.get("avoids_topics", [])
	if not avoids.is_empty():
		lines.append("You avoid talking about: %s." % ", ".join(avoids))
	return "\n".join(lines)


func get_desires_prompt() -> String:
	if desires.is_empty():
		return ""
	var lines: Array = []
	for d in desires:
		lines.append("- %s (intensity: %s)" % [d.get("want", ""), d.get("intensity", "")])
	return "\n".join(lines)


# --- Secret API ---

func get_secrets_for_tier(tier: String) -> Array:
	if tier in ["close", "bonded"]:
		return secrets.duplicate()
	return []


# --- Opinion API ---

func add_opinion(opinion: Dictionary) -> void:
	opinions.append(opinion)
	_sync_opinions()


func get_opinions() -> Array:
	return opinions.duplicate()


func get_opinions_for(topic: String, tier: String) -> Array:
	var result: Array = []
	for op in opinions:
		if not topic.is_empty() and op.get("topic", "") != topic:
			continue
		var share: String = op.get("will_share_with", "anyone")
		match share:
			"anyone":
				result.append(op)
			"close only":
				if tier in ["close", "bonded"]:
					result.append(op)
			"keeps to self":
				pass  # never share
	return result


# --- Schedule API ---

func resolve_schedule_goal(hour: int) -> Dictionary:
	if schedule_type == "routine":
		for slot in routine:
			var start: int = slot.get("start_hour", 0)
			var end: int = slot.get("end_hour", 0)
			# Handle overnight slots (end_hour < start_hour means wraps midnight)
			if start <= end:
				if hour >= start and hour < end:
					return {"goal": slot.get("goal", ""), "location": slot.get("location", "")}
			else:
				if hour >= start or hour < end:
					return {"goal": slot.get("goal", ""), "location": slot.get("location", "")}
		return {}
	# periodic and goal types: caller handles
	return {}


# --- Sync ---

func _sync_mood() -> void:
	var eid := _get_entity_id()
	if eid.is_empty() or not WorldState.entity_data.has(eid):
		return
	WorldState.set_entity_data(eid, "mood_emotion", mood_emotion)
	WorldState.set_entity_data(eid, "mood_energy", mood_energy)


func _sync_opinions() -> void:
	var eid := _get_entity_id()
	if eid.is_empty() or not WorldState.entity_data.has(eid):
		return
	WorldState.set_entity_data(eid, "opinions", opinions.duplicate())
