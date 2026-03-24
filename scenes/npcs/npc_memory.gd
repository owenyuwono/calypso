extends Node
## NPC memory — scored memory array, conversation history, key memories, and relationships.

# ---------------------------------------------------------------------------
# Memory constants
# ---------------------------------------------------------------------------
const MAX_MEMORIES: int = 20
const IMPORTANCE_HIGH: String = "high"
const IMPORTANCE_MEDIUM: String = "medium"
const IMPORTANCE_LOW: String = "low"
const SOURCE_WITNESSED: String = "witnessed"
const MAX_CONVERSATION_TURNS: int = 3
const CONVERSATION_WINDOW: float = 120.0  # Reset after this gap in seconds

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var memories: Array = []  # Array of memory dicts — see add_memory() for schema
var _conversation_turns: Dictionary = {}  # partner_id -> {count: int, time: float}

var _recent_chat_topics: Array = []  # last N topic strings
const MAX_RECENT_TOPICS: int = 3

var _npc_id: String = ""
var _memory_counter: int = 0

func _ready() -> void:
	_npc_id = get_parent().npc_id
	GameEvents.npc_spoke.connect(_on_npc_spoke_memory)
	GameEvents.entity_died.connect(_on_entity_died_memory)
	GameEvents.proficiency_level_up.connect(_on_proficiency_level_up_memory)
	GameEvents.game_hour_changed.connect(_on_game_hour_changed)

# =============================================================================
# Memory System
# =============================================================================

func _get_entity_id() -> String:
	return _npc_id

func add_memory(fact: String, source: String = SOURCE_WITNESSED, importance: String = IMPORTANCE_LOW, emotional: bool = false, topic: String = "") -> Dictionary:
	# Deduplicate: exact match or contains
	for mem in memories:
		if mem["fact"] == fact:
			mem["times_reinforced"] += 1
			return mem

	var confidence: float = 1.0
	if source == SOURCE_WITNESSED:
		confidence = 1.0
	elif source.begins_with("heard_from"):
		confidence = 0.7
	else:
		confidence = 0.4

	var game_day: int = 0
	if TimeManager:
		game_day = TimeManager.get_day()

	var new_memory: Dictionary = {
		"id": "%s_%d_%d" % [_get_entity_id(), Time.get_ticks_msec(), _memory_counter],
		"fact": fact,
		"source": source,
		"importance": importance,
		"emotional": emotional,
		"times_reinforced": 0,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"game_day": game_day,
		"fuzzy": false,
		"fuzzy_text": "",
		"confidence": confidence,
		"topic": topic,
		"shared_with": [],
	}

	_memory_counter += 1
	memories.append(new_memory)

	# Evict lowest-scored memory if over cap
	if memories.size() > MAX_MEMORIES:
		memories.sort_custom(func(a, b): return score_memory(a) < score_memory(b))
		memories.remove_at(0)

	GameEvents.memory_added.emit(_get_entity_id(), fact, importance)
	return new_memory

func score_memory(memory: Dictionary) -> float:
	var importance_weight: float = {IMPORTANCE_HIGH: 10.0, IMPORTANCE_MEDIUM: 5.0, IMPORTANCE_LOW: 2.0}.get(memory.get("importance", IMPORTANCE_LOW), 2.0)

	var current_day: int = 0
	if TimeManager:
		current_day = TimeManager.get_day()
	var day_delta: int = current_day - memory.get("game_day", current_day)
	var recency_bonus: float = 0.0
	if day_delta == 0:
		recency_bonus = 10.0
	elif day_delta == 1:
		recency_bonus = 6.0
	elif day_delta <= 3:
		recency_bonus = 3.0
	elif day_delta <= 7:
		recency_bonus = 1.0
	else:
		recency_bonus = 0.0

	var emotional_bonus: float = 5.0 if memory.get("emotional", false) else 0.0
	var reinforced: int = memory.get("times_reinforced", 0)
	var confidence: float = memory.get("confidence", 1.0)

	return (importance_weight + recency_bonus + reinforced * 3.0 + emotional_bonus) * confidence

func run_garbage_collection(current_game_day: int) -> void:
	if memories.is_empty():
		return

	# Sort ascending by score (lowest first)
	memories.sort_custom(func(a, b): return score_memory(a) < score_memory(b))

	var cutoff: int = memories.size() / 4  # bottom 25%
	var to_remove: Array = []
	for i in cutoff:
		if memories[i]["fuzzy"]:
			to_remove.append(memories[i])
		else:
			memories[i]["fuzzy"] = true
			memories[i]["fuzzy_text"] = _make_fuzzy(memories[i]["fact"])

	for mem in to_remove:
		memories.erase(mem)

	# Enforce hard cap
	while memories.size() > MAX_MEMORIES:
		memories.remove_at(0)

func _make_fuzzy(fact: String) -> String:
	# Simple degradation: truncate and add ellipsis
	var words: Array = fact.split(" ")
	if words.size() <= 3:
		return "something about " + fact.substr(0, mini(20, fact.length())) + "..."
	var half: int = words.size() / 2
	return " ".join(words.slice(0, half)) + "... (faded memory)"

func has_key_memory_type(type: String) -> bool:
	for mem in memories:
		if mem["topic"] == type:
			return true
	return false

func get_key_memories_summary(max_count: int = 3) -> String:
	var high_mems: Array = []
	for mem in memories:
		if mem["importance"] == IMPORTANCE_HIGH:
			high_mems.append(mem)
	if high_mems.is_empty():
		return ""
	high_mems.sort_custom(func(a, b): return score_memory(a) > score_memory(b))
	var top: Array = high_mems.slice(0, mini(max_count, high_mems.size()))
	var lines: Array = []
	for mem in top:
		lines.append("- %s" % mem["fact"])
	return "Key memories:\n" + "\n".join(lines)

# =============================================================================
# Signal Handlers
# =============================================================================

func _on_npc_spoke_memory(speaker_id: String, _dialogue: String, target_id: String) -> void:
	# Record conversation relationship for any interaction involving this NPC, including player
	var rel_comp: Node = get_parent().get_node_or_null("RelationshipComponent")
	if rel_comp:
		if speaker_id == _npc_id and target_id != _npc_id:
			rel_comp.record_event(target_id, "conversation", TimeManager.get_day())
		elif target_id == _npc_id and speaker_id != _npc_id:
			rel_comp.record_event(speaker_id, "conversation", TimeManager.get_day())
	# Skip NPC memory/LLM context building for player interactions
	if speaker_id == "player" or target_id == "player":
		return

func _on_entity_died_memory(entity_id: String, killer_id: String) -> void:
	# Skip if this NPC died
	if entity_id == _npc_id:
		return
	# Only track shared combat when a monster dies
	var entity_node := WorldState.get_entity(entity_id)
	if not entity_node or not is_instance_valid(entity_node):
		return
	if not ("monster_type" in entity_node):
		return
	# Killer must be an NPC or the player
	var killer_node := WorldState.get_entity(killer_id)
	var killer_is_npc: bool = killer_node != null and is_instance_valid(killer_node) and ("npc_id" in killer_node)
	var killer_is_player: bool = killer_id == "player"
	if not killer_is_npc and not killer_is_player:
		return
	var my_node := get_parent()
	if not is_instance_valid(my_node):
		return
	var dist: float = my_node.global_position.distance_to(entity_node.global_position)
	if dist >= 15.0:
		return
	var rel_comp: Node = get_parent().get_node_or_null("RelationshipComponent")
	if not rel_comp:
		return
	if killer_id == _npc_id:
		# This NPC is the killer — find nearby ally NPCs and player who were also fighting
		for eid in WorldState.entities:
			if eid == _npc_id or eid == entity_id:
				continue
			var ally_node := WorldState.get_entity(eid)
			if not ally_node or not is_instance_valid(ally_node):
				continue
			var ally_is_npc: bool = "npc_id" in ally_node
			var ally_is_player: bool = eid == "player"
			if not ally_is_npc and not ally_is_player:
				continue
			var ally_dist: float = ally_node.global_position.distance_to(entity_node.global_position)
			if ally_dist < 15.0:
				rel_comp.record_event(eid, "shared_combat", TimeManager.get_day())
	else:
		# This NPC is a bystander — record shared combat with the killer (NPC or player)
		rel_comp.record_event(killer_id, "shared_combat", TimeManager.get_day())

func _on_proficiency_level_up_memory(entity_id: String, skill_id: String, new_level: int) -> void:
	if entity_id == _npc_id:
		var ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")
		var skill_data: Dictionary = ProficiencyDatabase.get_skill(skill_id)
		var skill_name: String = skill_data.get("name", skill_id)
		add_memory("Reached %s level %d" % [skill_name, new_level], SOURCE_WITNESSED, IMPORTANCE_HIGH, false, "level_up")

func _on_game_hour_changed(hour: int) -> void:
	# Stagger GC across NPCs by hashing entity ID to a specific hour
	if hour == _get_entity_id().hash() % 24:
		run_garbage_collection(TimeManager.get_day())

# =============================================================================
# Conversation Turns
# =============================================================================

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

func add_recent_topic(topic: String) -> void:
	_recent_chat_topics.append(topic)
	if _recent_chat_topics.size() > MAX_RECENT_TOPICS:
		_recent_chat_topics.pop_front()

func is_recent_topic(topic: String) -> bool:
	return topic in _recent_chat_topics

func get_recent_observations(count: int = 10) -> Array:
	# DEPRECATED: Returns most recent memories as plain text strings for backward compat.
	var sorted: Array = memories.duplicate()
	sorted.sort_custom(func(a, b): return score_memory(a) > score_memory(b))
	var top: Array = sorted.slice(0, mini(count, sorted.size()))
	var result: Array = []
	for mem in top:
		result.append("[%s] %s" % [_timestamp(), mem["fact"]])
	return result

func get_summary() -> String:
	var parts: Array = []
	var km_summary: String = get_key_memories_summary(3)
	if not km_summary.is_empty():
		parts.append(km_summary)
	return "\n".join(parts)

# =============================================================================
# Sync to WorldState
# =============================================================================

func _sync() -> void:
	if _npc_id.is_empty():
		return
	WorldState.set_entity_data(_npc_id, "memories", memories)

# =============================================================================
# Internal helpers
# =============================================================================

func _timestamp() -> String:
	var ticks := Time.get_ticks_msec()
	var secs := ticks / 1000
	var mins := secs / 60
	return "%d:%02d" % [mins, secs % 60]
