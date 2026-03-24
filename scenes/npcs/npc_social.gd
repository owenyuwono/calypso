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

const RICH_GREETINGS: Array = [
	"It's always a pleasure to see you, %s!",
	"Ah, %s! I was hoping I'd run into you today.",
	"%s! Come, let me tell you about %s.",
	"You brighten my day, %s. How have you been?",
	"My friend %s! Have you been keeping well?",
	"%s, you're just the person I wanted to talk to about %s.",
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

	# Check if a charisma 5+ player is within social range
	var player_charisma: int = _get_nearby_player_charisma(perception)

	for c in candidates:
		var subject: String = FALLBACK_TOPICS[randi() % FALLBACK_TOPICS.size()]
		var target_name: String = WorldState.get_entity_data(c["id"]).get("name", c["id"])
		var line: String
		if player_charisma >= 5:
			# Use richer greeting pool when a high-charisma player is nearby
			var rich_line: String = RICH_GREETINGS[randi() % RICH_GREETINGS.size()]
			if "%s" in rich_line:
				var placeholders: int = rich_line.count("%s")
				if placeholders == 1:
					line = rich_line % target_name
				else:
					line = rich_line % [target_name, subject]
			else:
				line = rich_line
		else:
			var canned_lines: Array = [
				"Hey %s, how's it going?" % target_name,
				"Good to see you, %s." % target_name,
				"Stay safe out there, %s." % target_name,
				"Have you heard anything about %s?" % subject,
				"I was just thinking about %s." % subject,
			]
			line = canned_lines[randi() % canned_lines.size()]
		GameEvents.npc_spoke.emit(_npc.npc_id, line, c["id"])
		var sociability: float = NpcTraits.get_trait(_npc.trait_profile, "sociability", 0.5)
		var min_cd: float = SOCIAL_COOLDOWN_MIN + (1.0 - sociability) * 40.0
		var max_cd: float = SOCIAL_COOLDOWN_MAX + (1.0 - sociability) * 60.0
		_social_cooldown = randf_range(min_cd, max_cd)
		return true
	return false


func _get_nearby_player_charisma(perception: Dictionary) -> int:
	# The player entity is included in the "npcs" array with id "player"
	var npcs: Array = perception.get("npcs", [])
	for n in npcs:
		var nid: String = n.get("id", "")
		if nid != "player":
			continue
		var player_node: Node = WorldState.get_entity(nid)
		if not player_node:
			return 0
		var prog: Node = player_node.get_node_or_null("ProgressionComponent")
		if not prog:
			return 0
		var charisma_level: int = prog.get_proficiency_level("charisma")
		return charisma_level
	return 0

