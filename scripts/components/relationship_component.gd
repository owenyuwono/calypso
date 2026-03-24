class_name RelationshipComponent
extends BaseComponent
## Component that owns relationship state for an entity.
## Bridge: _sync() writes back to WorldState.entity_data on every mutation.

var relationships: Dictionary = {}

const TIER_LADDER: Array = ["stranger", "recognized", "acquaintance", "friendly", "close", "bonded"]
const MAX_HISTORY: int = 10


# --- Core Data ---

func get_or_create(entity_id: String) -> Dictionary:
	if not relationships.has(entity_id):
		relationships[entity_id] = {
			"tier": "stranger",
			"impression": "",
			"tension": 0.0,
			"history": [],
		}
	return relationships[entity_id]


# --- Event Recording ---

func record_event(entity_id: String, event: String, game_day: int, charisma_level: int = 0) -> void:
	var rel: Dictionary = get_or_create(entity_id)
	if entity_id == "player" and charisma_level > 0:
		rel["charisma_level"] = charisma_level
	rel["history"].append({
		"event": event,
		"timestamp": Time.get_unix_time_from_system(),
		"game_day": game_day,
		"high_tension": rel["tension"] > 0.7,
	})
	if rel["history"].size() > MAX_HISTORY:
		rel["history"] = rel["history"].slice(rel["history"].size() - MAX_HISTORY)
	_evaluate_tier(entity_id)
	_sync()


# --- Tier Evaluation ---

func _evaluate_tier(entity_id: String) -> void:
	var rel: Dictionary = get_or_create(entity_id)
	var history: Array = rel["history"]

	var conversation_count: int = 0
	var shared_combat_count: int = 0
	var helped_count: int = 0
	var saved_count: int = 0
	var shared_secret_count: int = 0

	for entry in history:
		match entry["event"]:
			"conversation":
				conversation_count += 1
			"shared_combat":
				shared_combat_count += 1
			"helped":
				helped_count += 1
			"saved_from_death":
				saved_count += 1
			"shared_secret":
				shared_secret_count += 1

	# Demotion: "attacked" drops to recognized immediately
	for entry in history:
		if entry["event"] == "attacked":
			var old_tier: String = rel["tier"]
			rel["tier"] = "recognized"
			if old_tier != "recognized":
				GameEvents.relationship_tier_changed.emit(_get_entity_id(), entity_id, old_tier, "recognized")
			_check_tension_demotion(entity_id, rel)
			return

	# Demotion: high tension for 3+ consecutive interactions
	_check_tension_demotion(entity_id, rel)

	# Promotion (one tier at a time, no cascading)
	var current_tier: String = rel["tier"]
	var next_tier: String = _get_next_tier(current_tier)
	var charisma: int = rel.get("charisma_level", 0)
	if not next_tier.is_empty():
		if _can_promote(current_tier, next_tier, conversation_count, shared_combat_count, helped_count, saved_count, shared_secret_count, rel["tension"], charisma):
			rel["tier"] = next_tier
			GameEvents.relationship_tier_changed.emit(_get_entity_id(), entity_id, current_tier, next_tier)


func _get_next_tier(current: String) -> String:
	var idx: int = TIER_LADDER.find(current)
	if idx < 0 or idx >= TIER_LADDER.size() - 1:
		return ""
	return TIER_LADDER[idx + 1]


func _get_prev_tier(current: String) -> String:
	var idx: int = TIER_LADDER.find(current)
	if idx <= 0:
		return ""
	return TIER_LADDER[idx - 1]


func _can_promote(from: String, to: String, conv: int, combat: int, helped: int, saved: int, secret: int, tension: float, charisma_level: int = 0) -> bool:
	# Reduce conversation thresholds based on charisma (not combat/helped/saved/secret)
	var conv_reduction: int = 0
	if charisma_level >= 7:
		conv_reduction = 2
	elif charisma_level >= 4:
		conv_reduction = 1

	match to:
		"recognized":
			return conv >= max(1, 1 - conv_reduction) or combat >= 1
		"acquaintance":
			return conv >= max(1, 3 - conv_reduction) or combat >= 2
		"friendly":
			return (conv >= max(1, 5 - conv_reduction) and combat >= 1) or helped >= 1
		"close":
			return conv >= max(1, 10 - conv_reduction) and combat >= 3 and tension < 0.7
		"bonded":
			return saved >= 1 or secret >= 1
	return false


func _check_tension_demotion(entity_id: String, rel: Dictionary) -> void:
	if rel["tension"] <= 0.7:
		return
	var history: Array = rel["history"]
	var consecutive_high_tension: int = 0
	for i in range(history.size() - 1, -1, -1):
		var entry: Dictionary = history[i]
		if entry.get("high_tension", false):
			consecutive_high_tension += 1
		else:
			break
	if consecutive_high_tension >= 3:
		var old_tier: String = rel["tier"]
		var prev_tier: String = _get_prev_tier(old_tier)
		if not prev_tier.is_empty():
			rel["tier"] = prev_tier
			GameEvents.relationship_tier_changed.emit(_get_entity_id(), entity_id, old_tier, prev_tier)


# --- Impression API ---

func set_impression(entity_id: String, text: String) -> void:
	var rel: Dictionary = get_or_create(entity_id)
	rel["impression"] = text
	_sync()


func get_impression(entity_id: String) -> String:
	var rel: Dictionary = relationships.get(entity_id, {})
	var impression: String = rel.get("impression", "")
	if impression.is_empty():
		return "No impression"
	return impression


# --- Tier API ---

func get_tier(entity_id: String) -> String:
	var rel: Dictionary = relationships.get(entity_id, {})
	return rel.get("tier", "stranger")


# --- Tension API ---

func get_tension(entity_id: String) -> float:
	var rel: Dictionary = relationships.get(entity_id, {})
	return rel.get("tension", 0.0)


func set_tension(entity_id: String, value: float) -> void:
	var rel: Dictionary = get_or_create(entity_id)
	rel["tension"] = clampf(value, 0.0, 1.0)
	_sync()


# --- Event Count ---

func get_event_count(entity_id: String, event_type: String) -> int:
	var rel: Dictionary = relationships.get(entity_id, {})
	var count: int = 0
	for entry in rel.get("history", []):
		if entry.get("event", "") == event_type:
			count += 1
	return count


# --- Summary ---

func get_relationships_summary() -> Dictionary:
	var summary: Dictionary = {}
	for entity_id in relationships:
		var rel: Dictionary = relationships[entity_id]
		summary[entity_id] = {
			"tier": rel.get("tier", "stranger"),
			"impression": rel.get("impression", ""),
			"tension": rel.get("tension", 0.0),
		}
	return summary


# --- Bridge ---

func _sync() -> void:
	var eid := _get_entity_id()
	if eid.is_empty():
		return
	WorldState.set_entity_data(eid, "relationships", relationships.duplicate(true))


