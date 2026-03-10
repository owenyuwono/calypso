extends Node
## Translates LLM action decisions into game mechanics for adventurer NPCs.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

var npc: CharacterBody3D  # NPCBase, duck-typed

func _ready() -> void:
	npc = get_parent()

func execute(action: String, target: String, dialogue: String = "", action_data: Dictionary = {}) -> void:
	npc.current_action = action
	npc.current_target = target

	match action:
		"move_to":
			_do_move_to(target)
		"attack":
			_do_attack(target)
		"use_item":
			_do_use_item(target)
		"buy_item":
			_do_buy_item(target, action_data)
		"sell_item":
			_do_sell_item(target, action_data)
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

func _do_attack(target_id: String) -> void:
	var target_node := WorldState.get_entity(target_id)
	if not target_node or not is_instance_valid(target_node):
		_fail("attack", "Target '%s' not found" % target_id)
		return
	if not WorldState.is_alive(target_id):
		_fail("attack", "Target '%s' is already dead" % target_id)
		return

	# Enter combat state — npc_base handles the auto-attack loop
	npc.enter_combat(target_id)
	GameEvents.npc_action_completed.emit(npc.npc_id, "attack", true)

func _do_use_item(item_id: String) -> void:
	var item := ItemDatabase.get_item(item_id)
	if item.is_empty():
		_fail("use_item", "Unknown item '%s'" % item_id)
		return
	if not WorldState.has_item(npc.npc_id, item_id):
		_fail("use_item", "Don't have item '%s'" % item_id)
		return

	npc.change_state("interacting")

	match item.get("type", ""):
		"consumable":
			var heal: int = item.get("heal", 0)
			if heal > 0:
				var healed := WorldState.heal_entity(npc.npc_id, heal)
				var memory_node = npc.get_node_or_null("NPCMemory")
				if memory_node:
					memory_node.add_observation("Used %s, healed %d HP" % [item.get("name", item_id), healed])
			WorldState.remove_from_inventory(npc.npc_id, item_id)
		"weapon", "armor":
			WorldState.equip_item(npc.npc_id, item_id)
			var memory_node = npc.get_node_or_null("NPCMemory")
			if memory_node:
				memory_node.add_observation("Equipped %s" % item.get("name", item_id))

	GameEvents.npc_action_completed.emit(npc.npc_id, "use_item", true)
	npc.change_state("idle")

func _do_buy_item(shop_id: String, action_data: Dictionary = {}) -> void:
	var shop_node := WorldState.get_entity(shop_id)
	if not shop_node:
		_fail("buy_item", "Shop '%s' not found" % shop_id)
		return

	var close_enough: bool = await _approach_entity(shop_node)
	if not close_enough:
		_fail("buy_item", "Shop '%s' unreachable" % shop_id)
		return

	var item_id: String = action_data.get("item_id", "")
	var count: int = action_data.get("count", 1)
	if item_id.is_empty():
		_fail("buy_item", "No item_id specified")
		return

	var item := ItemDatabase.get_item(item_id)
	var cost: int = item.get("value", 0) * count
	if not WorldState.remove_gold(npc.npc_id, cost):
		_fail("buy_item", "Not enough gold for %s (need %d)" % [item_id, cost])
		return

	WorldState.add_to_inventory(npc.npc_id, item_id, count)
	GameEvents.item_purchased.emit(npc.npc_id, item_id, cost)

	var memory_node = npc.get_node_or_null("NPCMemory")
	if memory_node:
		memory_node.add_observation("Bought %dx %s for %d gold" % [count, item.get("name", item_id), cost])

	GameEvents.npc_action_completed.emit(npc.npc_id, "buy_item", true)
	npc.change_state("idle")

func _do_sell_item(shop_id: String, action_data: Dictionary = {}) -> void:
	var shop_node := WorldState.get_entity(shop_id)
	if not shop_node:
		_fail("sell_item", "Shop '%s' not found" % shop_id)
		return

	var close_enough: bool = await _approach_entity(shop_node)
	if not close_enough:
		_fail("sell_item", "Shop '%s' unreachable" % shop_id)
		return

	var item_id: String = action_data.get("item_id", "")
	var count: int = action_data.get("count", 1)
	if item_id.is_empty():
		_fail("sell_item", "No item_id specified")
		return

	if not WorldState.remove_from_inventory(npc.npc_id, item_id, count):
		_fail("sell_item", "Don't have %dx %s" % [count, item_id])
		return

	var item := ItemDatabase.get_item(item_id)
	var revenue: int = int(item.get("value", 0) * 0.5) * count
	WorldState.add_gold(npc.npc_id, revenue)
	GameEvents.item_sold.emit(npc.npc_id, item_id, revenue)

	var memory_node = npc.get_node_or_null("NPCMemory")
	if memory_node:
		memory_node.add_observation("Sold %dx %s for %d gold" % [count, item.get("name", item_id), revenue])

	GameEvents.npc_action_completed.emit(npc.npc_id, "sell_item", true)
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
