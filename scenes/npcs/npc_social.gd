extends Node
## Social chat subsystem for adventurer NPCs.
## Handles NPC-to-NPC social chat initiation, candidate selection, and cooldown.

const NpcTraits = preload("res://scripts/data/npc_traits.gd")

const SOCIAL_PROXIMITY: float = 12.0
const SOCIAL_CHANCE: float = 1.0  # Always attempt when cooldown expires; filtering done by facts gate
const SOCIAL_COOLDOWN_MIN: float = 15.0
const SOCIAL_COOLDOWN_MAX: float = 45.0

const CHAT_INTENTS: Array = [
	{"intent": "ask_question", "cue": "Ask {target_name} a question about"},
	{"intent": "share_story", "cue": "Tell {target_name} about your experience with"},
	{"intent": "brag", "cue": "Boast to {target_name} about"},
	{"intent": "complain", "cue": "Complain to {target_name} about"},
	{"intent": "warn", "cue": "Warn {target_name} about"},
	{"intent": "gossip", "cue": "Tell {target_name} what you noticed about"},
	{"intent": "joke", "cue": "Say something funny to {target_name} about"},
	{"intent": "ask_advice", "cue": "Ask {target_name} for advice about"},
]

const FALLBACK_TOPICS: Array = [
	"how the hunting is going", "life in town", "the monsters around here",
]

const SOCIAL_GOALS: Array = ["idle", "patrol", "rest", "vend", "tend_shop"]

var _npc: CharacterBody3D
var _brain: Node
var _memory: Node
var _rel_comp: Node  # RelationshipComponent, duck-typed
var _perception: Node

var _social_cooldown: float = 0.0

func setup(npc: CharacterBody3D, brain: Node, memory: Node) -> void:
	_npc = npc
	_brain = brain
	_memory = memory
	_rel_comp = npc.get_node_or_null("RelationshipComponent")
	_social_cooldown = randf_range(10.0, 20.0)

func _process(delta: float) -> void:
	if _social_cooldown > 0.0:
		_social_cooldown -= delta

## Returns true if a social chat was initiated, false otherwise.
## Called from NpcBehavior.evaluate() as priority 2.5.
func try_social_chat() -> bool:
	if _social_cooldown > 0.0:
		return false
	if not _brain or _brain.is_busy():
		return false
	if _npc.current_goal not in SOCIAL_GOALS:
		return false

	if not _perception:
		_perception = _npc.get_node_or_null("PerceptionComponent")
	if not _perception:
		return false
	var perception: Dictionary = _perception.get_perception(SOCIAL_PROXIMITY)
	var npcs: Array = perception.get("npcs", [])

	# Build candidate list and sort by tier (highest first)
	var candidates: Array = []
	for n in npcs:
		var nid: String = n["id"]
		if nid == "player":
			continue
		if not WorldState.is_alive(nid):
			continue
		var state: String = n.get("state", "idle")
		if state in ["combat", "dead", "thinking"]:
			continue
		if not _memory.can_continue_conversation(nid):
			continue
		var tier_index: int = 0
		if _rel_comp:
			var tier: String = _rel_comp.get_tier(nid)
			tier_index = RelationshipComponent.TIER_LADDER.find(tier)
			if tier_index == -1:
				tier_index = 0
		candidates.append({"id": nid, "tier_index": tier_index})

	# Sort by tier_index descending — prefer closer relationships
	candidates.sort_custom(func(a, b): return a["tier_index"] > b["tier_index"])

	for c in candidates:
		var facts: Array = _memory.gather_chat_facts(c["id"])
		# Gate: only chat if there's something interesting to say (weight >= 1.5)
		var interesting := facts.filter(func(f): return f.get("weight", 0.0) >= 1.5)
		if interesting.is_empty():
			continue  # nothing worth chatting about
		# Filter out recently discussed topics
		var fresh_facts := facts.filter(func(f): return not _memory.is_recent_topic(f.get("topic", "")))
		if fresh_facts.is_empty():
			fresh_facts = facts  # fallback: allow repeats if everything was used
		var picked := _pick_weighted_fact(fresh_facts)
		var subject: String = picked.get("topic", FALLBACK_TOPICS[randi() % FALLBACK_TOPICS.size()])
		var intent_data: Dictionary = _pick_chat_intent()
		var target_name: String = WorldState.get_entity_data(c["id"]).get("name", c["id"])
		var intent_cue: String = intent_data["cue"].format({"target_name": target_name})
		if _brain.initiate_social_chat(c["id"], subject, intent_cue, facts):
			_memory.add_recent_topic(subject)
			var sociability: float = NpcTraits.get_trait(_npc.trait_profile, "sociability", 0.5)
			var min_cd: float = SOCIAL_COOLDOWN_MIN + (1.0 - sociability) * 40.0
			var max_cd: float = SOCIAL_COOLDOWN_MAX + (1.0 - sociability) * 60.0
			_social_cooldown = randf_range(min_cd, max_cd)
			return true
	return false

func _pick_weighted_fact(facts: Array) -> Dictionary:
	if facts.is_empty():
		return {}
	var total: float = 0.0
	for f in facts:
		total += f.get("weight", 1.0)
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for f in facts:
		cumulative += f.get("weight", 1.0)
		if roll <= cumulative:
			return f
	return facts[0]

func _pick_chat_intent() -> Dictionary:
	var boldness: float = NpcTraits.get_trait(_npc.trait_profile, "boldness", 0.5)
	var curiosity: float = NpcTraits.get_trait(_npc.trait_profile, "curiosity", 0.5)
	var sociability: float = NpcTraits.get_trait(_npc.trait_profile, "sociability", 0.5)

	# Build weighted pool based on personality
	var weights: Dictionary = {
		"ask_question": 1.0 + curiosity * 2.0,
		"share_story": 1.0 + sociability * 1.5,
		"brag": 0.5 + boldness * 2.0,
		"complain": 1.0 + (1.0 - boldness) * 1.5,
		"warn": 0.5 + boldness * 1.5,
		"gossip": 0.5 + curiosity * 1.5,
		"joke": 0.5 + sociability * 2.0,
		"ask_advice": 1.0 + (1.0 - boldness) * 1.5,
	}

	var total_weight: float = 0.0
	for w in weights.values():
		total_weight += w

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for intent_data in CHAT_INTENTS:
		cumulative += weights.get(intent_data["intent"], 1.0)
		if roll <= cumulative:
			return intent_data

	return CHAT_INTENTS[0]
