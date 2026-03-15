extends Node
## NPC memory — scored memory array, conversation history, key memories, and relationships.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

# ---------------------------------------------------------------------------
# Memory constants
# ---------------------------------------------------------------------------
const MAX_MEMORIES: int = 20
const IMPORTANCE_HIGH: String = "high"
const IMPORTANCE_MEDIUM: String = "medium"
const IMPORTANCE_LOW: String = "low"
const SOURCE_WITNESSED: String = "witnessed"
const MAX_CONVERSATION_HISTORY: int = 10
const MAX_AREA_CHAT_LOG: int = 15
const MAX_CONVERSATION_TURNS: int = 3
const CONVERSATION_WINDOW: float = 120.0  # Reset after this gap in seconds

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var memories: Array = []  # Array of memory dicts — see add_memory() for schema
var conversation_history: Dictionary = {}  # partner_id -> Array of {speaker, text}
var area_chat_log: Array = []  # [{speaker_name: String, text: String}]
var goals_history: Array = []
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
		var lowest_score: float = INF
		var lowest_idx: int = 0
		for i in memories.size():
			var s: float = score_memory(memories[i])
			if s < lowest_score:
				lowest_score = s
				lowest_idx = i
		memories.remove_at(lowest_idx)

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

func get_memories_for_prompt(limit: int = 10) -> String:
	if memories.is_empty():
		return ""
	var sorted: Array = memories.duplicate()
	sorted.sort_custom(func(a, b): return score_memory(a) > score_memory(b))
	var top: Array = sorted.slice(0, mini(limit, sorted.size()))
	var lines: Array = []
	for mem in top:
		var text: String = mem["fuzzy_text"] if mem["fuzzy"] and not mem["fuzzy_text"].is_empty() else mem["fact"]
		lines.append("[%s] %s" % [mem["importance"], text])
	return "\n".join(lines)

func get_facts_about(topic: String) -> Array:
	var result: Array = []
	for mem in memories:
		if mem["topic"] == topic:
			result.append(mem)
	return result

func get_unshared_facts(target_id: String) -> Array:
	var result: Array = []
	for mem in memories:
		if not (target_id in mem["shared_with"]):
			result.append(mem)
	return result

func mark_fact_shared(memory_id: String, target_id: String) -> void:
	for mem in memories:
		if mem["id"] == memory_id:
			if not (target_id in mem["shared_with"]):
				mem["shared_with"].append(target_id)
			return

# =============================================================================
# Deprecated memory stubs — Wave 2 migration
# =============================================================================

# DEPRECATED: Use add_memory() directly. Migrated in Wave 2.
func add_observation(text: String) -> void:
	add_memory(text, SOURCE_WITNESSED, IMPORTANCE_LOW)

# DEPRECATED: Use add_memory() directly. Migrated in Wave 2.
func add_key_memory(type: String, text: String) -> void:
	add_memory(text, SOURCE_WITNESSED, IMPORTANCE_HIGH, false, type)

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
# Chat Facts — structured data for grounded conversation
# =============================================================================

func gather_chat_facts(target_id: String) -> Array:
	var facts: Array = []

	# High-importance memories (replaces old key_memories loop)
	for mem in memories:
		if mem["importance"] == IMPORTANCE_HIGH:
			facts.append({"topic": mem["fact"].to_lower(), "fact": mem["fact"], "weight": 2.0})
		elif mem["importance"] == IMPORTANCE_MEDIUM:
			facts.append({"topic": mem["fact"].to_lower(), "fact": mem["fact"], "weight": 1.0})

	# Own state
	var npc_node := get_parent()
	var hp: int = npc_node._stats.hp
	var max_hp: int = npc_node._stats.max_hp
	var hp_pct: float = float(hp) / float(max_hp)
	var gold: int = npc_node._inventory.gold
	var level: int = npc_node._stats.level
	var equipment: Dictionary = npc_node._equipment.get_equipment()
	var weapon_id: String = equipment.get("weapon", "")
	var armor_id: String = equipment.get("armor", "")
	var potion_count: int = npc_node._inventory.get_item_count("healing_potion")

	if hp_pct < 0.5:
		facts.append({"topic": "being injured", "fact": "You are at %d/%d HP" % [hp, max_hp], "weight": 2.5})
	if weapon_id.is_empty():
		facts.append({"topic": "needing a weapon", "fact": "You have no weapon equipped", "weight": 2.0})
	else:
		var wname := ItemDatabase.get_item_name(weapon_id)
		facts.append({"topic": "your %s" % wname.to_lower(), "fact": "You have a %s equipped" % wname, "weight": 1.0})
	if not armor_id.is_empty():
		var aname := ItemDatabase.get_item_name(armor_id)
		facts.append({"topic": "your %s" % aname.to_lower(), "fact": "You have %s equipped" % aname, "weight": 0.8})
	if potion_count > 0:
		facts.append({"topic": "your healing potions", "fact": "You have %d healing potion%s" % [potion_count, "s" if potion_count != 1 else ""], "weight": 1.0})
	else:
		facts.append({"topic": "running out of potions", "fact": "You have no healing potions left", "weight": 1.5})

	var goal: String = npc_node.current_goal if npc_node else "idle"
	var activity := _goal_to_fact(goal, gold)
	if not activity.is_empty():
		facts.append(activity)

	# Target state
	if not target_id.is_empty():
		var target_node = WorldState.get_entity(target_id)
		if target_node and is_instance_valid(target_node):
			var tstats = target_node.get_node_or_null("StatsComponent")
			var tequip = target_node.get_node_or_null("EquipmentComponent")
			var tname: String = target_node.npc_name if "npc_name" in target_node else target_id
			if tstats:
				var tlevel: int = tstats.level
				var thp: int = tstats.hp
				var tmax_hp: int = tstats.max_hp
				var thp_pct: float = float(thp) / float(tmax_hp)
				if thp_pct < 0.5:
					facts.append({"topic": "%s looking rough" % tname, "fact": "%s is at %d/%d HP" % [tname, thp, tmax_hp], "weight": 2.0})
				if tlevel > level:
					facts.append({"topic": "%s's level" % tname, "fact": "%s is level %d (higher than you)" % [tname, tlevel], "weight": 1.5})
			if tequip:
				var tweapon: String = tequip.get_equipment().get("weapon", "")
				if not tweapon.is_empty():
					var twname := ItemDatabase.get_item_name(tweapon)
					facts.append({"topic": "%s's %s" % [tname, twname.to_lower()], "fact": "%s is using a %s" % [tname, twname], "weight": 1.0})

	# Relationship with target (via RelationshipComponent)
	var rel_comp_facts = get_parent().get_node_or_null("RelationshipComponent")
	if rel_comp_facts and not target_id.is_empty():
		var shared_combat_count: int = rel_comp_facts.get_event_count(target_id, "shared_combat")
		if shared_combat_count > 0:
			var partner_node = WorldState.get_entity(target_id)
			var tname: String = partner_node.npc_name if partner_node and "npc_name" in partner_node else target_id
			facts.append({"topic": "fighting alongside %s" % tname, "fact": "You fought together %d time%s" % [shared_combat_count, "s" if shared_combat_count != 1 else ""], "weight": 1.5})

	# Stamina awareness
	var stamina_comp = get_parent().get_node_or_null("StaminaComponent")
	if stamina_comp:
		var sta_pct: float = stamina_comp.get_stamina_percent()
		if sta_pct < 0.3:
			facts.append({"topic": "being tired", "fact": "You are exhausted (stamina at %d%%)" % int(sta_pct * 100), "weight": 2.5})
		elif sta_pct < 0.5:
			facts.append({"topic": "getting tired", "fact": "You are getting tired (stamina at %d%%)" % int(sta_pct * 100), "weight": 1.5})

	# Time-of-day awareness
	if TimeManager.is_night():
		facts.append({"topic": "nighttime", "fact": "It is nighttime and the field is more dangerous", "weight": 1.5})

	# Nearby monsters
	var perception := WorldState.get_npc_perception(_npc_id)
	var monsters: Array = perception.get("monsters", [])
	if not monsters.is_empty():
		var mname: String = monsters[0].get("name", "a monster")
		facts.append({"topic": "the %s nearby" % mname.to_lower(), "fact": "There is a %s nearby" % mname, "weight": 1.5})

	return facts

func _goal_to_fact(goal: String, gold: int) -> Dictionary:
	match goal:
		"hunt_field":
			return {"topic": "how the hunting is going", "fact": "You are hunting in the field", "weight": 1.0}
		"buy_potions":
			return {"topic": "stocking up on potions", "fact": "You are buying potions", "weight": 1.0}
		"sell_loot":
			return {"topic": "selling your loot", "fact": "You are selling loot at the shop", "weight": 1.0}
		"rest":
			return {"topic": "resting", "fact": "You are resting to recover stamina", "weight": 1.0}
		"idle":
			return {"topic": "how things are going", "fact": "You are resting in town with %d gold" % gold, "weight": 0.5}
		_:
			return {}

# =============================================================================
# Signal Handlers
# =============================================================================

func _on_npc_spoke_memory(speaker_id: String, _dialogue: String, target_id: String) -> void:
	# Record conversation relationship when this NPC is speaker or target (exclude player)
	if speaker_id == "player" or target_id == "player":
		return
	var rel_comp = get_parent().get_node_or_null("RelationshipComponent")
	if not rel_comp:
		return
	if speaker_id == _npc_id and target_id != _npc_id:
		rel_comp.record_event(target_id, "conversation", TimeManager.get_day())
	elif target_id == _npc_id and speaker_id != _npc_id:
		rel_comp.record_event(speaker_id, "conversation", TimeManager.get_day())

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
	# Check killer is an NPC
	var killer_node := WorldState.get_entity(killer_id)
	if not killer_node or not ("npc_id" in killer_node):
		return
	var my_node := get_parent()
	if not is_instance_valid(my_node):
		return
	var dist: float = my_node.global_position.distance_to(entity_node.global_position)
	if dist >= 15.0:
		return
	var rel_comp = get_parent().get_node_or_null("RelationshipComponent")
	if not rel_comp:
		return
	if killer_id == _npc_id:
		# This NPC is the killer — find nearby ally NPCs who were also fighting
		for eid in WorldState.entities:
			if eid == _npc_id or eid == entity_id:
				continue
			var ally_node := WorldState.get_entity(eid)
			if not ally_node or not is_instance_valid(ally_node):
				continue
			if not ("npc_id" in ally_node):
				continue
			var ally_dist: float = ally_node.global_position.distance_to(entity_node.global_position)
			if ally_dist < 15.0:
				rel_comp.record_event(eid, "shared_combat", TimeManager.get_day())
	else:
		# This NPC is a bystander — record shared combat with the killer
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

# =============================================================================
# Conversations & Area Chat
# =============================================================================

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

func add_area_chat(speaker_name: String, text: String) -> void:
	area_chat_log.append({"speaker_name": speaker_name, "text": text})
	if area_chat_log.size() > MAX_AREA_CHAT_LOG:
		area_chat_log.pop_front()

func get_area_chat_context(max_count: int = 5) -> String:
	if area_chat_log.is_empty():
		return ""
	var start: int = maxi(0, area_chat_log.size() - max_count)
	var recent: Array = area_chat_log.slice(start)
	var lines: Array = []
	for entry: Dictionary in recent:
		lines.append("%s: %s" % [entry["speaker_name"], entry["text"]])
	return "Recent nearby chat:\n" + "\n".join(lines)

func add_goal(goal: String) -> void:
	goals_history.append(goal)

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
	var mem_text: String = get_memories_for_prompt(5)
	if not mem_text.is_empty():
		parts.append("Recent memories:\n" + mem_text)
	if not goals_history.is_empty():
		parts.append("Goal history: " + ", ".join(goals_history.slice(-3)))
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
