extends Node
## Social chat subsystem for adventurer NPCs.
## Handles NPC-to-NPC social chat initiation, candidate selection, and cooldown.

const NpcTraits = preload("res://scripts/data/npc_traits.gd")

const SOCIAL_PROXIMITY: float = 12.0
const SOCIAL_COOLDOWN_MIN: float = 15.0
const SOCIAL_COOLDOWN_MAX: float = 45.0

const FALLBACK_TOPICS: Array = [
	"how the hunting is going", "life in town", "the monsters around here",
]

const SOCIAL_GOALS: Array = ["idle", "patrol", "rest", "vend"]

var _npc: CharacterBody3D
var _memory: Node
var _rel_comp: Node  # RelationshipComponent, duck-typed
var _perception: Node

var _social_cooldown: float = 0.0
var _process_timer: float = 0.0
const PROCESS_INTERVAL: float = 1.0

func setup(npc: CharacterBody3D, memory: Node) -> void:
	_npc = npc
	_memory = memory
	_rel_comp = npc.get_node_or_null("RelationshipComponent")
	_social_cooldown = randf_range(10.0, 20.0)

func _process(delta: float) -> void:
	_process_timer += delta
	if _process_timer < PROCESS_INTERVAL:
		return
	var elapsed: float = _process_timer
	_process_timer = 0.0

	if _social_cooldown > 0.0:
		_social_cooldown -= elapsed

## Returns true if a social chat was initiated, false otherwise.
## Called from NpcBehavior.evaluate() as priority 2.5.
func try_social_chat() -> bool:
	if _social_cooldown > 0.0:
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
		var subject: String = FALLBACK_TOPICS[randi() % FALLBACK_TOPICS.size()]
		var target_name: String = WorldState.get_entity_data(c["id"]).get("name", c["id"])
		var canned_lines: Array = [
			"Hey %s, how's it going?" % target_name,
			"Good to see you, %s." % target_name,
			"Stay safe out there, %s." % target_name,
			"Have you heard anything about %s?" % subject,
			"I was just thinking about %s." % subject,
		]
		var line: String = canned_lines[randi() % canned_lines.size()]
		GameEvents.npc_spoke.emit(_npc.npc_id, line, c["id"])
		var sociability: float = NpcTraits.get_trait(_npc.trait_profile, "sociability", 0.5)
		var min_cd: float = SOCIAL_COOLDOWN_MIN + (1.0 - sociability) * 40.0
		var max_cd: float = SOCIAL_COOLDOWN_MAX + (1.0 - sociability) * 60.0
		_social_cooldown = randf_range(min_cd, max_cd)
		return true
	return false

