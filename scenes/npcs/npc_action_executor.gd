extends Node
## Translates LLM action decisions into game mechanics for adventurer NPCs.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const RecipeDatabase = preload("res://scripts/data/recipe_database.gd")

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
		"pickup_loot":
			_do_pickup_loot(target)
		"chop_tree":
			_do_chop_tree(target)
		"craft_at_station":
			_do_craft_at_station(target, action_data)
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
	npc.set_suppress_nav_complete(true)
	npc.navigate_to(entity_node.global_position)
	var timeout := get_tree().create_timer(8.0)
	await signal_race([npc.nav_agent.navigation_finished, timeout.timeout])
	dist = npc.global_position.distance_to(entity_node.global_position)
	return dist <= max_dist

## Navigate to a specific position near an entity. Used when the entity center is a NavMesh obstacle.
func _approach_position(entity_node: Node3D, nav_pos: Vector3, max_dist: float = 3.0) -> bool:
	var dist: float = npc.global_position.distance_to(entity_node.global_position)
	if dist <= max_dist:
		return true
	npc.set_suppress_nav_complete(true)
	npc.navigate_to(nav_pos)
	var timeout := get_tree().create_timer(8.0)
	await signal_race([npc.nav_agent.navigation_finished, timeout.timeout])
	dist = npc.global_position.distance_to(entity_node.global_position)
	return dist <= max_dist

## Get a position offset from target, approaching from the source direction.
func _get_approach_pos(source: Vector3, target: Vector3, standoff: float) -> Vector3:
	var offset: Vector3 = source - target
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		offset = Vector3(1.0, 0.0, 0.0)
	return target + offset.normalized() * standoff

## Wait for whichever signal fires first. Returns the index of the signal that fired.
func signal_race(signals: Array) -> int:
	var fired_index: int = -1
	var done: bool = false
	var callbacks: Array = []
	for i in signals.size():
		var idx := i
		var cb := func() -> void:
			if not done:
				done = true
				fired_index = idx
		callbacks.append(cb)
		signals[i].connect(cb, CONNECT_ONE_SHOT)
	while not done:
		await get_tree().process_frame
	# Disconnect any remaining listeners
	for i in signals.size():
		if signals[i].is_connected(callbacks[i]):
			signals[i].disconnect(callbacks[i])
	return fired_index

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
				_add_npc_memory("Used %s, healed %d HP" % [item.get("name", item_id), healed])
			npc._inventory.remove_item(item_id)
		"weapon", "armor":
			npc._equipment.equip(item_id)
			_add_npc_memory("Equipped %s" % item.get("name", item_id))

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

	var cost: int = 0
	var vending_comp: Node = vendor_node.get_node_or_null("VendingComponent")
	if vending_comp and vending_comp.get_listings().size() > 0:
		# Buy via VendingComponent — handles gold transfer and inventory on both sides
		var success: bool = vending_comp.buy_from(npc, item_id, count)
		if not success:
			_fail("buy_item", "VendingComponent refused purchase of %s from %s" % [item_id, vendor_id])
			return
	else:
		# Vendor has no active vending — fall back to direct purchase at base value
		var fallback_item: Dictionary = ItemDatabase.get_item(item_id)
		cost = fallback_item.get("value", 0) * count
		if not npc._inventory.remove_gold_amount(cost):
			_fail("buy_item", "Not enough gold for %s (need %d)" % [item_id, cost])
			return
		npc._inventory.add_item(item_id, count)
		GameEvents.item_purchased.emit(npc.npc_id, item_id, cost)

	var item: Dictionary = ItemDatabase.get_item(item_id)
	_add_npc_memory("Bought %dx %s for %d gold" % [count, item.get("name", item_id), cost])
	if item.get("type", "") in ["weapon", "armor"]:
		_add_npc_memory("Bought %s for %d gold" % [item.get("name", item_id), cost], "medium", false, "big_purchase")

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

	_add_npc_memory("Sold %dx %s for %d gold" % [count, item.get("name", item_id), revenue])

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

func _do_pickup_loot(loot_id: String) -> void:
	var loot_node := WorldState.get_entity(loot_id)
	if not loot_node or not is_instance_valid(loot_node):
		_fail("pickup_loot", "Loot '%s' not found" % loot_id)
		return

	var close_enough: bool = await _approach_entity(loot_node)
	if not close_enough:
		_fail("pickup_loot", "Loot '%s' unreachable" % loot_id)
		return

	# Guard: another NPC may have picked it up while we were walking
	if not is_instance_valid(loot_node):
		_fail("pickup_loot", "Loot '%s' already taken" % loot_id)
		return

	loot_node.pickup(npc.npc_id)
	GameEvents.npc_action_completed.emit(npc.npc_id, "pickup_loot", true)
	npc.change_state("idle")

const CHOP_INTERVAL: float = 2.0
const CHOP_RANGE: float = 3.0

func _do_chop_tree(tree_id: String) -> void:
	var tree_node: Node3D = WorldState.get_entity(tree_id)
	if not tree_node or not is_instance_valid(tree_node):
		_fail("chop_tree", "Tree '%s' not found" % tree_id)
		return

	# Check tree is still harvestable
	var tree_data: Dictionary = WorldState.get_entity_data(tree_id)
	if not tree_data.get("harvestable", false):
		_fail("chop_tree", "Tree '%s' is depleted" % tree_id)
		return

	# Navigate to tree (offset from center to avoid NavMesh obstacle)
	var approach_pos: Vector3 = _get_approach_pos(npc.global_position, tree_node.global_position, 2.5)
	var close_enough: bool = await _approach_position(tree_node, approach_pos, CHOP_RANGE)
	if not close_enough:
		_fail("chop_tree", "Tree '%s' unreachable" % tree_id)
		return

	# Verify still valid after approach
	if not is_instance_valid(tree_node):
		_fail("chop_tree", "Tree '%s' freed during approach" % tree_id)
		return

	# Check if NPC meets level requirements for this tree
	var harvestable: Node = tree_node.get_node_or_null("HarvestableComponent")
	if harvestable and not harvestable.can_harvest(npc.npc_id):
		npc.set_goal("idle")
		GameEvents.npc_action_completed.emit(npc.npc_id, "chop_tree", false)
		return

	npc.change_state("interacting")

	# Chop loop
	while true:
		# Stop if interrupted by combat, death, or external goal change
		if npc.current_state == "combat" or npc.current_state == "dead" or npc.current_goal != "chop_wood":
			break

		# Stop if tree no longer harvestable (may have been depleted by another NPC)
		if not harvestable or harvestable.is_depleted():
			# Tree depleted by another NPC — mark done and let behavior re-evaluate
			npc.set_goal("idle")
			break

		# Re-check close enough (tree doesn't move, but just in case)
		if not is_instance_valid(tree_node):
			break
		var dist: float = npc.global_position.distance_to(tree_node.global_position)
		if dist > CHOP_RANGE:
			# Drifted away — re-approach with offset to avoid NavMesh obstacle
			npc.set_suppress_nav_complete(true)
			var reapproach_pos: Vector3 = _get_approach_pos(npc.global_position, tree_node.global_position, 2.5)
			npc.navigate_to(reapproach_pos)
			var timeout_timer := get_tree().create_timer(5.0)
			await signal_race([npc.nav_agent.navigation_finished, timeout_timer.timeout])
			npc.change_state("interacting")

		# Play chop animation
		var anim_name: String = "1H_Melee_Attack_Chop"
		npc._visuals.play_anim(anim_name)

		# Wait for hit delay before applying chop
		var hit_delay: float = npc._visuals.get_hit_delay(anim_name)
		if hit_delay > 0.0:
			await get_tree().create_timer(hit_delay).timeout

		# Check again after delay — combat, death, or goal change may have happened
		if npc.current_state == "combat" or npc.current_state == "dead" or npc.current_goal != "chop_wood":
			break
		if not is_instance_valid(tree_node) or not harvestable or harvestable.is_depleted():
			npc.set_goal("idle")
			break

		# Shake tree for feedback
		tree_node.last_chopper_pos = npc.global_position
		if tree_node.has_method("shake"):
			tree_node.shake()

		# Apply chop and get result
		var result: Dictionary = harvestable.process_chop(npc.npc_id)
		if npc._audio:
			npc._audio.play_oneshot("gather_tree_chop")

		# Grant woodcutting XP
		npc._progression.grant_proficiency_xp("woodcutting", result.get("xp", 0))

		# Tree depleted — spawn loot and mark goal complete
		if result.get("depleted", false):
			if is_instance_valid(tree_node):
				tree_node.spawn_loot(result.get("item_id", ""), result.get("bonus_item", ""))
			npc.set_goal("idle")
			break

		# Wait remainder of chop interval
		var wait_time: float = CHOP_INTERVAL - hit_delay
		if wait_time > 0.0:
			await get_tree().create_timer(wait_time).timeout

	GameEvents.npc_action_completed.emit(npc.npc_id, "chop_tree", true)
	if npc.current_state == "interacting":
		npc.change_state("idle")

const CRAFT_RANGE: float = 3.0

func _do_craft_at_station(station_id: String, action_data: Dictionary) -> void:
	var station_node: Node3D = WorldState.get_entity(station_id)
	if not station_node or not is_instance_valid(station_node):
		_fail("craft_at_station", "Station '%s' not found" % station_id)
		return

	var recipe_id: String = action_data.get("recipe_id", "")
	if recipe_id.is_empty():
		_fail("craft_at_station", "No recipe_id in action_data")
		return

	var recipe: Dictionary = RecipeDatabase.get_recipe(recipe_id)
	if recipe.is_empty():
		_fail("craft_at_station", "Unknown recipe '%s'" % recipe_id)
		return

	# Navigate to station (offset from center to avoid NavMesh obstacle)
	var approach_pos: Vector3 = _get_approach_pos(npc.global_position, station_node.global_position, 2.0)
	var close_enough: bool = await _approach_position(station_node, approach_pos, CRAFT_RANGE)
	if not close_enough:
		_fail("craft_at_station", "Station '%s' unreachable" % station_id)
		return

	# Verify still valid after approach
	if not is_instance_valid(station_node):
		_fail("craft_at_station", "Station '%s' freed during approach" % station_id)
		return

	# Verify NPC has all required inputs before starting
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id in inputs:
		var needed: int = inputs[item_id]
		if not npc._inventory.has_item(item_id, needed):
			_fail("craft_at_station", "Missing input '%s' x%d for recipe '%s'" % [item_id, needed, recipe_id])
			return

	npc.change_state("interacting")
	npc._visuals.play_anim("Idle")

	# Wait for craft_time
	var craft_time: float = recipe.get("craft_time", 2.0)
	await get_tree().create_timer(craft_time).timeout

	# Guard: NPC may have been interrupted (combat, death, goal change)
	if npc.current_state == "dead":
		GameEvents.npc_action_completed.emit(npc.npc_id, "craft_at_station", false)
		return

	# Re-verify inputs after the wait — may have been consumed elsewhere
	for item_id in inputs:
		var needed: int = inputs[item_id]
		if not npc._inventory.has_item(item_id, needed):
			_fail("craft_at_station", "Inputs lost during craft wait for recipe '%s'" % recipe_id)
			return

	# Consume inputs
	for item_id in inputs:
		npc._inventory.remove_item(item_id, inputs[item_id])

	# Add outputs
	var outputs: Dictionary = recipe.get("outputs", {})
	for item_id in outputs:
		npc._inventory.add_item(item_id, outputs[item_id])

	# Grant proficiency XP
	var progression: Node = npc.get_node_or_null("ProgressionComponent")
	if progression:
		progression.grant_proficiency_xp(recipe.get("skill_id", ""), recipe.get("xp", 0))

	# Play craft SFX
	if npc._audio:
		npc._audio.play_oneshot("ui_craft_complete")

	var recipe_name: String = recipe.get("name", recipe_id)
	npc.last_thought = "Crafted %s" % recipe_name
	_add_npc_memory("Crafted %s at station" % recipe_name)

	GameEvents.npc_action_completed.emit(npc.npc_id, "craft_at_station", true)
	if npc.current_state == "interacting":
		npc.change_state("idle")


func _add_npc_memory(fact: String, importance: String = "medium", emotional: bool = false, topic: String = "") -> void:
	var memory_node: Node = npc.get_node_or_null("NPCMemory")
	if memory_node:
		memory_node.add_memory(fact, memory_node.SOURCE_WITNESSED, importance, emotional, topic)

func _fail(action: String, reason: String) -> void:
	push_warning("NPC %s action '%s' failed: %s" % [npc.npc_id, action, reason])
	npc.change_state("failed")
	GameEvents.npc_action_completed.emit(npc.npc_id, action, false)
	await get_tree().create_timer(2.0).timeout
	if npc.current_state == "failed":
		npc.change_state("idle")
