extends Node
## Translates LLM action decisions into game mechanics.

var npc: CharacterBody3D  # NPCBase, duck-typed to avoid class_name load issues

func _ready() -> void:
	npc = get_parent()

func execute(action: String, target: String, dialogue: String = "") -> void:
	npc.current_action = action
	npc.current_target = target
	GameEvents.npc_action_started.emit(npc.npc_id, action, target)

	match action:
		"move_to":
			_do_move_to(target)
		"pick_up":
			_do_pick_up(target)
		"drop_item":
			_do_drop_item(target)
		"use_object":
			_do_use_object(target)
		"talk_to":
			_do_talk_to(target, dialogue)
		"wait":
			_do_wait()
		_:
			push_warning("NPCActionExecutor: Unknown action '%s'" % action)
			npc.change_state("failed")
			GameEvents.npc_action_completed.emit(npc.npc_id, action, false)

func _do_move_to(target: String) -> void:
	if WorldState.has_location(target):
		npc.navigate_to(WorldState.get_location(target))
	else:
		npc.navigate_to_entity(target)

## Navigate to an entity if too far. Returns true if close enough after approach.
func _approach_entity(entity_node: Node3D, max_dist: float = 3.0) -> bool:
	var dist: float = npc.global_position.distance_to(entity_node.global_position)
	if dist <= max_dist:
		return true
	npc._suppress_nav_complete = true
	npc.navigate_to(entity_node.global_position)
	await npc.nav_agent.navigation_finished
	dist = npc.global_position.distance_to(entity_node.global_position)
	return dist <= max_dist

func _do_pick_up(item_id: String) -> void:
	var item_node: Node3D = WorldState.get_entity(item_id)
	if not item_node:
		_fail("pick_up", "Item '%s' not found" % item_id)
		return

	var close_enough: bool = await _approach_entity(item_node)
	if not close_enough:
		_fail("pick_up", "Item '%s' unreachable" % item_id)
		return

	npc.change_state("interacting")
	WorldState.add_to_inventory(npc.npc_id, item_id)
	item_node.visible = false
	item_node.process_mode = Node.PROCESS_MODE_DISABLED
	GameEvents.item_picked_up.emit(item_id, npc.npc_id)
	GameEvents.npc_action_completed.emit(npc.npc_id, "pick_up", true)
	npc.change_state("idle")

func _do_drop_item(item_id: String) -> void:
	npc.change_state("interacting")
	if not WorldState.remove_from_inventory(npc.npc_id, item_id):
		_fail("drop_item", "Item '%s' not in inventory" % item_id)
		return

	var item_node: Node3D = WorldState.get_entity(item_id)
	if item_node:
		item_node.global_position = npc.global_position + Vector3(1, 0, 0)
		item_node.visible = true
		item_node.process_mode = Node.PROCESS_MODE_INHERIT
	GameEvents.item_dropped.emit(item_id, npc.npc_id, npc.global_position)
	GameEvents.npc_action_completed.emit(npc.npc_id, "drop_item", true)
	npc.change_state("idle")

func _do_use_object(object_id: String) -> void:
	var obj_node: Node3D = WorldState.get_entity(object_id)
	if not obj_node:
		_fail("use_object", "Object '%s' not found" % object_id)
		return

	var close_enough: bool = await _approach_entity(obj_node)
	if not close_enough:
		_fail("use_object", "Object '%s' unreachable" % object_id)
		return

	npc.change_state("interacting")
	GameEvents.object_used.emit(object_id, npc.npc_id)
	GameEvents.npc_action_completed.emit(npc.npc_id, "use_object", true)

	await get_tree().create_timer(1.5).timeout
	if npc.current_state == "interacting":
		npc.change_state("idle")

func _do_talk_to(target_id: String, dialogue: String) -> void:
	npc.change_state("talking")
	GameEvents.npc_spoke.emit(npc.npc_id, dialogue, target_id)
	GameEvents.npc_action_completed.emit(npc.npc_id, "talk_to", true)

	await get_tree().create_timer(2.0).timeout
	if npc.current_state == "talking":
		npc.change_state("idle")

func _do_wait() -> void:
	npc.change_state("idle")
	GameEvents.npc_action_completed.emit(npc.npc_id, "wait", true)

func _fail(action: String, reason: String) -> void:
	push_warning("NPC %s action '%s' failed: %s" % [npc.npc_id, action, reason])
	npc.change_state("failed")
	GameEvents.npc_action_completed.emit(npc.npc_id, action, false)
	await get_tree().create_timer(2.0).timeout
	if npc.current_state == "failed":
		npc.change_state("idle")
