extends Node
## Translates LLM action decisions into game mechanics for adventurer NPCs.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

const SELL_PRICE_RATIO: float = 0.5

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
	var target_stats = target_node.get_node_or_null("StatsComponent")
	if target_stats and not target_stats.is_alive():
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
	if not npc._inventory.has_item(item_id):
		_fail("use_item", "Don't have item '%s'" % item_id)
		return

	npc.change_state("interacting")

	match item.get("type", ""):
		"consumable":
			var heal: int = item.get("heal", 0)
			if heal > 0:
				var healed: int = npc._combat.heal(heal)
				var memory_node = npc.get_node_or_null("NPCMemory")
				if memory_node:
					memory_node.add_observation("Used %s, healed %d HP" % [item.get("name", item_id), healed])
			npc._inventory.remove_item(item_id)
		"weapon", "armor":
			npc._equipment.equip(item_id)
			var memory_node = npc.get_node_or_null("NPCMemory")
			if memory_node:
				memory_node.add_observation("Equipped %s" % item.get("name", item_id))

	GameEvents.npc_action_completed.emit(npc.npc_id, "use_item", true)
	npc.change_state("idle")

func _do_buy_item(vendor_id: String, action_data: Dictionary = {}) -> void:
	var vendor_node := WorldState.get_entity(vendor_id)
	if not vendor_node:
		_fail("buy_item", "Vendor '%s' not found" % vendor_id)
		return

	var close_enough: bool = await _approach_entity(vendor_node)
	if not close_enough:
		_fail("buy_item", "Vendor '%s' unreachable" % vendor_id)
		return

	var item_id: String = action_data.get("item_id", "")
	var count: int = action_data.get("count", 1)
	if item_id.is_empty():
		_fail("buy_item", "No item_id specified")
		return

	var vending_comp: Node = vendor_node.get_node_or_null("VendingComponent")
	if vending_comp and vending_comp.is_vending():
		# Buy via VendingComponent — handles gold transfer and inventory on both sides
		var success: bool = vending_comp.buy_from(npc, item_id, count)
		if not success:
			_fail("buy_item", "VendingComponent refused purchase of %s from %s" % [item_id, vendor_id])
			return
	else:
		# Vendor has no active vending — fall back to direct purchase at base value
		var fallback_item: Dictionary = ItemDatabase.get_item(item_id)
		var cost: int = fallback_item.get("value", 0) * count
		if not npc._inventory.remove_gold_amount(cost):
			_fail("buy_item", "Not enough gold for %s (need %d)" % [item_id, cost])
			return
		npc._inventory.add_item(item_id, count)
		GameEvents.item_purchased.emit(npc.npc_id, item_id, cost)

	var item: Dictionary = ItemDatabase.get_item(item_id)
	var memory_node = npc.get_node_or_null("NPCMemory")
	if memory_node:
		memory_node.add_observation("Bought %dx %s" % [count, item.get("name", item_id)])
		if item.get("type", "") in ["weapon", "armor"] and memory_node.has_method("add_key_memory"):
			memory_node.add_key_memory("big_purchase", "Bought %s" % item.get("name", item_id))

	GameEvents.npc_action_completed.emit(npc.npc_id, "buy_item", true)
	npc.change_state("idle")

func _do_sell_item(vendor_id: String, action_data: Dictionary = {}) -> void:
	var vendor_node := WorldState.get_entity(vendor_id)
	if not vendor_node:
		_fail("sell_item", "Vendor '%s' not found" % vendor_id)
		return

	var close_enough: bool = await _approach_entity(vendor_node)
	if not close_enough:
		_fail("sell_item", "Vendor '%s' unreachable" % vendor_id)
		return

	var item_id: String = action_data.get("item_id", "")
	var count: int = action_data.get("count", 1)
	if item_id.is_empty():
		_fail("sell_item", "No item_id specified")
		return

	if not npc._inventory.remove_item(item_id, count):
		_fail("sell_item", "Don't have %dx %s" % [count, item_id])
		return

	var item := ItemDatabase.get_item(item_id)
	# Pay the selling NPC 50% of base value (vendor absorbs the item)
	var revenue: int = int(item.get("value", 0) * SELL_PRICE_RATIO) * count
	npc._inventory.add_gold_amount(revenue)
	GameEvents.item_sold.emit(npc.npc_id, item_id, revenue)

	# Vendor gains the item in their inventory (they can re-list it)
	var vendor_inv: Node = vendor_node.get_node_or_null("InventoryComponent")
	if vendor_inv:
		vendor_inv.remove_gold_amount(revenue)
		vendor_inv.add_item(item_id, count)

	var memory_node = npc.get_node_or_null("NPCMemory")
	if memory_node:
		memory_node.add_observation("Sold %dx %s for %d gold" % [count, item.get("name", item_id), revenue])

	GameEvents.npc_action_completed.emit(npc.npc_id, "sell_item", true)
	npc.change_state("idle")

func _do_talk_to(target_id: String, dialogue: String) -> void:
	npc.change_state("talking")
	# Face the target
	var target_node := WorldState.get_entity(target_id)
	if target_node and is_instance_valid(target_node):
		var dir := (target_node.global_position - npc.global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			npc._visuals.face_direction(dir.normalized())
	GameEvents.npc_spoke.emit(npc.npc_id, dialogue, target_id)
	GameEvents.npc_action_completed.emit(npc.npc_id, "talk_to", true)

	await get_tree().create_timer(5.0).timeout
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
