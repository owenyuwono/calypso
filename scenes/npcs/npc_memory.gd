extends Node
## NPC memory — rolling observation window, conversation history, key memories, and relationships.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

const MAX_OBSERVATIONS: int = 20
const MAX_CONVERSATION_HISTORY: int = 10
const MAX_KEY_MEMORIES: int = 10
const MAX_AREA_CHAT_LOG: int = 15

var observations: Array = []
var conversation_history: Dictionary = {}  # partner_id -> Array of {speaker, text}
var area_chat_log: Array = []  # [{speaker_name: String, text: String}]
var goals_history: Array = []
var key_memories: Array = []  # [{type, text, time}]
var relationships: Dictionary = {}  # partner_id -> {affinity, shared_combat, conversations, last_interaction}
var _conversation_turns: Dictionary = {}  # partner_id -> {count: int, time: float}
const MAX_CONVERSATION_TURNS: int = 3
const CONVERSATION_WINDOW: float = 120.0  # Reset after this gap in seconds

var _recent_chat_topics: Array = []  # last N topic strings
const MAX_RECENT_TOPICS: int = 3

var _npc_id: String = ""

func _ready() -> void:
	_npc_id = get_parent().npc_id
	GameEvents.npc_spoke.connect(_on_npc_spoke_memory)
	GameEvents.entity_died.connect(_on_entity_died_memory)
	GameEvents.level_up.connect(_on_level_up_memory)

# =============================================================================
# Key Memories
# =============================================================================

func add_key_memory(type: String, text: String) -> void:
	# Deduplicate by type+text
	for km in key_memories:
		if km["type"] == type and km["text"] == text:
			return
	key_memories.append({"type": type, "text": text, "time": _timestamp()})
	if key_memories.size() > MAX_KEY_MEMORIES:
		# FIFO eviction — prefer keeping deaths
		var evict_idx := -1
		for i in key_memories.size():
			if key_memories[i]["type"] != "death":
				evict_idx = i
				break
		if evict_idx == -1:
			evict_idx = 0
		key_memories.remove_at(evict_idx)

func has_key_memory_type(type: String) -> bool:
	for km in key_memories:
		if km["type"] == type:
			return true
	return false

func get_key_memories_summary(max_count: int = 3) -> String:
	if key_memories.is_empty():
		return ""
	var start := maxi(0, key_memories.size() - max_count)
	var recent := key_memories.slice(start)
	var lines: Array = []
	for km in recent:
		lines.append("- %s" % km["text"])
	return "Key memories:\n" + "\n".join(lines)

# =============================================================================
# Relationships
# =============================================================================

func get_relationship(partner_id: String) -> Dictionary:
	if not relationships.has(partner_id):
		relationships[partner_id] = {
			"affinity": 0.0,
			"shared_combat": 0,
			"conversations": 0,
			"last_interaction": 0.0,
		}
	return relationships[partner_id]

func modify_affinity(partner_id: String, delta: float) -> void:
	var rel := get_relationship(partner_id)
	rel["affinity"] = clampf(rel["affinity"] + delta, -1.0, 1.0)
	rel["last_interaction"] = Time.get_ticks_msec() / 1000.0

func record_shared_combat(partner_id: String) -> void:
	var rel := get_relationship(partner_id)
	rel["shared_combat"] += 1
	modify_affinity(partner_id, 0.1)

func record_conversation(partner_id: String) -> void:
	var rel := get_relationship(partner_id)
	rel["conversations"] += 1
	modify_affinity(partner_id, 0.05)

func get_relationship_label(partner_id: String) -> String:
	if not relationships.has(partner_id):
		return "stranger"
	var affinity: float = relationships[partner_id]["affinity"]
	if affinity >= 0.6:
		return "close friend"
	elif affinity >= 0.3:
		return "friend"
	elif affinity >= 0.0:
		return "acquaintance"
	elif affinity >= -0.3:
		return "wary"
	else:
		return "distrustful"

func get_relationships_summary() -> String:
	if relationships.is_empty():
		return ""
	# Sort by affinity descending, take top 3
	var sorted_ids: Array = relationships.keys()
	sorted_ids.sort_custom(func(a, b): return relationships[b]["affinity"] < relationships[a]["affinity"])
	var parts: Array = []
	var count := 0
	for pid in sorted_ids:
		if count >= 3:
			break
		var label := get_relationship_label(pid)
		var entity_node = WorldState.get_entity(pid)
		var name: String = entity_node.npc_name if entity_node and "npc_name" in entity_node else pid
		parts.append("%s: %s" % [name, label])
		count += 1
	return "Relationships: " + ", ".join(parts)

# =============================================================================
# Chat Facts — structured data for grounded conversation
# =============================================================================

func gather_chat_facts(target_id: String) -> Array:
	var facts: Array = []

	# Key memories (weighted by importance)
	var mem_weights: Dictionary = {"death": 3.0, "first_kill": 2.0, "level_up": 2.0, "big_purchase": 1.5, "notable_conversation": 1.0}
	for km in key_memories:
		var w: float = mem_weights.get(km["type"], 1.0)
		facts.append({"topic": km["text"].to_lower(), "fact": km["text"], "weight": w})

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

	# Relationship with target
	if relationships.has(target_id):
		var rel: Dictionary = relationships[target_id]
		var shared: int = rel.get("shared_combat", 0)
		if shared > 0:
			var partner_node = WorldState.get_entity(target_id)
			var tname: String = partner_node.npc_name if partner_node and "npc_name" in partner_node else target_id
			facts.append({"topic": "fighting alongside %s" % tname, "fact": "You fought together %d time%s" % [shared, "s" if shared != 1 else ""], "weight": 1.5})

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
		"hunt_dungeon":
			return {"topic": "the dungeon", "fact": "You are hunting in the dungeon", "weight": 1.0}
		"buy_potions":
			return {"topic": "stocking up on potions", "fact": "You are buying potions", "weight": 1.0}
		"sell_loot":
			return {"topic": "selling your loot", "fact": "You are selling loot at the shop", "weight": 1.0}
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
	if speaker_id == _npc_id and target_id != _npc_id:
		record_conversation(target_id)
	elif target_id == _npc_id and speaker_id != _npc_id:
		record_conversation(speaker_id)

func _on_entity_died_memory(entity_id: String, killer_id: String) -> void:
	# Skip if this NPC died
	if entity_id == _npc_id:
		return
	# Only track shared combat when a monster dies
	# Check entity type - monsters have monster_type property
	var entity_node := WorldState.get_entity(entity_id)
	if not entity_node or not is_instance_valid(entity_node):
		return
	if not ("monster_type" in entity_node):
		return
	# Check killer is an NPC - NPCs have npc_id property
	var killer_node := WorldState.get_entity(killer_id)
	if not killer_node or not ("npc_id" in killer_node):
		return
	var my_node := get_parent()
	if not is_instance_valid(my_node):
		return
	var dist: float = my_node.global_position.distance_to(entity_node.global_position)
	if dist >= 15.0:
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
				record_shared_combat(eid)
	else:
		# This NPC is a bystander — record shared combat with the killer
		record_shared_combat(killer_id)

func _on_level_up_memory(entity_id: String, new_level: int) -> void:
	if entity_id == _npc_id:
		add_key_memory("level_up", "Reached level %d" % new_level)

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
# Observations & Conversations
# =============================================================================

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

func add_area_chat(speaker_name: String, text: String) -> void:
	area_chat_log.append({"speaker_name": speaker_name, "text": text})
	if area_chat_log.size() > MAX_AREA_CHAT_LOG:
		area_chat_log.pop_front()

func get_area_chat_context(max_count: int = 5) -> String:
	if area_chat_log.is_empty():
		return ""
	var start := maxi(0, area_chat_log.size() - max_count)
	var recent := area_chat_log.slice(start)
	var lines: Array = []
	for entry: Dictionary in recent:
		lines.append("%s: %s" % [entry["speaker_name"], entry["text"]])
	return "Recent nearby chat:\n" + "\n".join(lines)

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
	var km_summary := get_key_memories_summary(3)
	if not km_summary.is_empty():
		parts.append(km_summary)
	var rel_summary := get_relationships_summary()
	if not rel_summary.is_empty():
		parts.append(rel_summary)
	return "\n".join(parts)

func _timestamp() -> String:
	var ticks := Time.get_ticks_msec()
	var secs := ticks / 1000
	var mins := secs / 60
	return "%d:%02d" % [mins, secs % 60]
