class_name GossipSystem
## Static utility — gossip fact propagation between NPCs.
## Called from npc_brain.gd after NPC-to-NPC chat resolves.

const IMPORTANCE_THRESHOLD_DEFAULT: float = 1.5
const IMPORTANCE_THRESHOLD_SOCIABLE: float = 1.0
const SOCIABLE_CUTOFF: float = 0.7
const MAX_SHAREABLE_FACTS: int = 2
const DISTORTION_CHANCE: float = 0.15
const RUMOR_HOP_THRESHOLD: int = 4
const IMPORTANCE_DECAY: float = 0.8

const _POSITIVE_WORDS: Array = ["helped", "saved", "gave", "protected"]
const _NEGATIVE_WORDS: Array = ["stole", "attacked", "killed", "betrayed"]

const _EXAGGERATIONS: Array = ["apparently", "supposedly"]

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Return up to MAX_SHAREABLE_FACTS entries from memory suitable for sharing.
## - Filters by importance score threshold (lowered for sociable NPCs)
## - Excludes facts told BY the partner (prevent echo)
## - Excludes facts about the partner themselves (they already know)
## - Returns top facts sorted by importance score descending
static func get_shareable_facts(memory: Node, sociability: float, partner_id: String) -> Array:
	var threshold: float = IMPORTANCE_THRESHOLD_SOCIABLE if sociability > SOCIABLE_CUTOFF else IMPORTANCE_THRESHOLD_DEFAULT

	var candidates: Array = []
	for mem in memory.memories:
		# Skip entries that aren't interesting enough
		var score: float = _importance_to_float(mem.get("importance", "low"))
		if score < threshold:
			continue
		# Skip facts originally told by the partner (echo prevention)
		var told_by: String = mem.get("told_by", "")
		if told_by == partner_id:
			continue
		# Skip facts whose original source is the partner (they know already)
		var original_source: String = mem.get("original_source", "")
		if original_source == partner_id:
			continue
		candidates.append(mem)

	# Sort descending by importance score
	candidates.sort_custom(func(a, b): return _importance_to_float(a.get("importance", "low")) > _importance_to_float(b.get("importance", "low")))

	return candidates.slice(0, MAX_SHAREABLE_FACTS)

## Build a gossip-received memory entry when an NPC hears a fact.
static func receive_gossip(fact: String, importance: float, source_npc: String, spread_count: int, original_source: String) -> Dictionary:
	var new_count: int = spread_count + 1
	var new_source: String = "told_by" if new_count < RUMOR_HOP_THRESHOLD else "rumor"
	var distorted_fact: String = _maybe_distort(fact)
	return {
		"fact": distorted_fact,
		"importance": importance * IMPORTANCE_DECAY,
		"source": new_source,
		"told_by": source_npc,
		"spread_count": new_count,
		"original_source": original_source,
	}

## Check if hearing a fact should affect this NPC's relationship with the subject.
## Returns {"entity_id": about_entity, "delta": float}
static func get_relationship_effect(fact: String, about_entity: String) -> Dictionary:
	if about_entity.is_empty():
		return {"entity_id": about_entity, "delta": 0.0}
	var lower: String = fact.to_lower()
	for word in _POSITIVE_WORDS:
		if lower.contains(word):
			return {"entity_id": about_entity, "delta": 0.1}
	for word in _NEGATIVE_WORDS:
		if lower.contains(word):
			return {"entity_id": about_entity, "delta": -0.1}
	return {"entity_id": about_entity, "delta": 0.0}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## 15% chance to distort a fact via exaggeration or truncation.
static func _maybe_distort(fact: String) -> String:
	if randf() >= DISTORTION_CHANCE:
		return fact
	# Pick distortion type: 50% exaggeration, 50% detail loss
	if randf() < 0.5:
		var prefix: String = _EXAGGERATIONS[randi() % _EXAGGERATIONS.size()]
		return "%s, %s" % [prefix, fact]
	# Detail loss: keep first half of words
	var words: Array = fact.split(" ")
	if words.size() <= 3:
		return fact
	var half: int = maxi(3, words.size() / 2)
	return " ".join(words.slice(0, half)) + "..."

## Convert importance string label to a comparable float for threshold checks.
static func _importance_to_float(importance: String) -> float:
	match importance:
		"high":
			return 3.0
		"medium":
			return 2.0
		_:
			return 1.0
