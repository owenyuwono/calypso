extends Node
## Deterministic goal-driven behavior for adventurer NPCs.
## Ticks every 1s when NPC is idle. Drives actions via the existing executor.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const NpcTraits = preload("res://scripts/data/npc_traits.gd")

const VALID_GOALS: Array = [
	"hunt_field", "buy_potions", "sell_loot",
	"buy_weapon", "buy_armor", "follow_player", "return_to_town", "patrol", "idle", "rest",
	"vend", "buy_from_vendor", "tend_shop"
]

const TICK_INTERVAL: float = 1.0
const IDLE_DRIFT_INTERVAL: float = 8.0
const IDLE_CLUSTER_RANGE: float = 4.0
const IDLE_DRIFT_CHANCE: float = 0.6

# Alternate hunt spots to roam when no monsters nearby
const FIELD_SPOTS: Array = ["FieldCenter", "FieldFar", "FieldNorth", "FieldSouth"]
const PATROL_SPOTS: Array = ["TownSquare", "MarketDistrict", "NobleQuarter", "ParkGardens", "CityGate"]

const POTION_STOCK_TARGET: int = 3
const POTION_RESTOCK_THRESHOLD: int = 2
const POTION_BUY_GOLD_MIN: int = 40

var default_goal: String = "idle"

var npc: CharacterBody3D
var memory: Node
var executor: Node
var brain: Node
var _social: Node  # NpcSocial child node

var _behavior_timer: float = 0.0
var _action_in_progress: bool = false
var _idle_drift_timer: float = 0.0
var _hunt_spot_index: int = 0
var _patrol_index: int = 0
var _perception: Node

func _ready() -> void:
	npc = get_parent()
	memory = npc.get_node("NPCMemory")
	executor = npc.get_node("NPCActionExecutor")
	brain = npc.get_node("NPCBrain")
	_social = preload("res://scenes/npcs/npc_social.gd").new()
	_social.name = "NpcSocial"
	add_child(_social)
	_social.setup(npc, brain, memory)

	GameEvents.npc_action_completed.connect(
		func(n_id: String, action: String, success: bool) -> void:
			if n_id == npc.npc_id:
				_on_action_completed(n_id, action, success)
	)
	GameEvents.time_phase_changed.connect(_on_time_phase_changed)

func _process(delta: float) -> void:
	_idle_drift_timer += delta
	if _action_in_progress:
		return
	if npc.current_state != "idle":
		return
	if not npc._stats.is_alive():
		return
	if brain and brain.is_busy():
		return

	_behavior_timer += delta
	if _behavior_timer >= TICK_INTERVAL:
		_behavior_timer = 0.0
		evaluate()

func evaluate() -> void:
	if not _perception:
		_perception = npc.get_node_or_null("PerceptionComponent")
	# Priority 0: Auto-equip any unequipped gear in inventory
	_auto_equip()
	# Priority 1: Survival checks
	if _check_survival():
		return
	# Priority 2: Goal completion transitions
	if _check_goal_completion():
		return
	# Priority 2.3: Night pressure — cautious NPCs return to town at night
	if TimeManager.is_night():
		var boldness: float = NpcTraits.get_trait(npc.trait_profile, "boldness", 0.5)
		if boldness < 0.4 and not _is_in_town() and npc.current_goal == "hunt_field":
			npc.set_goal("return_to_town")
			npc.last_thought = "It's getting dark, better head back"
			_do_action("move_to", "TownSquare")
			return
	# Priority 2.5: Schedule override for routine NPCs
	var identity = npc.get_node_or_null("NpcIdentity")
	if identity and identity.schedule_type == "routine":
		var sched_goal: Dictionary = identity.resolve_schedule_goal(int(TimeManager.get_game_hour()))
		if not sched_goal.is_empty() and sched_goal.get("goal", "") != npc.current_goal:
			npc.set_goal(sched_goal["goal"])
			npc.last_thought = "Following my routine"
			_do_action("move_to", sched_goal.get("location", ""))
			return
	# Priority 2.6: Social chat with nearby NPCs
	if _social.try_social_chat():
		return
	# Priority 3: Execute current goal
	_execute_goal()

# =============================================================================
# Survival Priorities
# =============================================================================

func _check_survival() -> bool:
	var hp: int = npc._stats.hp
	var max_hp: int = npc._stats.max_hp
	var hp_pct: float = float(hp) / float(max_hp)
	var potion_count: int = npc._inventory.get_item_count("healing_potion")

	var boldness: float = NpcTraits.get_trait(npc.trait_profile, "boldness", 0.5)
	var potion_threshold: float = 0.45 - (boldness * 0.25)  # bold: 0.20, cautious: 0.45
	var retreat_threshold: float = 0.55 - (boldness * 0.25)  # bold: 0.30, cautious: 0.55

	# Use potion if HP low and has one
	if hp_pct < potion_threshold and potion_count > 0:
		_do_action("use_item", "healing_potion")
		return true

	# Retreat if HP low and no potions and not in town
	if hp_pct < retreat_threshold and potion_count == 0 and not _is_in_town():
		npc.set_goal("return_to_town")
		_do_action("move_to", "TownSquare")
		return true

	# Stamina check — return to town if exhausted
	var stamina_comp = npc.get_node_or_null("StaminaComponent")
	if stamina_comp:
		var stamina_pct: float = stamina_comp.get_stamina_percent()
		var rest_threshold: float = 0.25 - (boldness * 0.15)  # bold: 0.10, cautious: 0.25
		# Hard floor: force retreat at 5% regardless
		if (stamina_pct < rest_threshold or stamina_pct < 0.05) and not _is_in_town():
			npc.set_goal("return_to_town")
			npc.last_thought = "Getting tired, heading back"
			_do_action("move_to", "TownSquare")
			return true

	return false

# =============================================================================
# Goal Completion Checks
# =============================================================================

func _check_goal_completion() -> bool:
	match npc.current_goal:
		"buy_potions":
			var potion_count: int = npc._inventory.get_item_count("healing_potion")
			var gold: int = npc._inventory.gold
			if potion_count >= POTION_STOCK_TARGET or gold < 20:
				npc.set_goal(default_goal)
				return true
		"sell_loot":
			if NpcTradeHelper.get_first_material(npc._inventory).is_empty():
				# Check for weapon/armor upgrade opportunity
				var upgrade := NpcTradeHelper.get_best_upgrade("weapon", npc._equipment, npc._inventory)
				if not upgrade.is_empty():
					npc.set_goal("buy_weapon")
					return true
				upgrade = NpcTradeHelper.get_best_upgrade("armor", npc._equipment, npc._inventory)
				if not upgrade.is_empty():
					npc.set_goal("buy_armor")
					return true
				npc.set_goal(default_goal)
				return true
		"buy_weapon", "buy_armor":
			# These complete in _execute_goal when purchase done or can't afford
			pass
		"rest":
			var rest_stamina_comp = npc.get_node_or_null("StaminaComponent")
			if rest_stamina_comp and rest_stamina_comp.get_stamina_percent() >= 0.8:
				npc.set_goal(default_goal)
				return true
		"return_to_town":
			if _is_in_town():
				# Check if stamina is low — transition to rest goal
				var rtt_stamina_comp = npc.get_node_or_null("StaminaComponent")
				if rtt_stamina_comp and rtt_stamina_comp.get_stamina_percent() < 0.5:
					npc.set_goal("rest")
					return true
				var hp: int = npc._stats.hp
				var max_hp: int = npc._stats.max_hp
				if float(hp) / float(max_hp) >= 0.7:
					if _should_restock_potions() and _can_afford_potions():
						npc.set_goal("buy_potions")
					else:
						npc.set_goal(default_goal)
					return true
		"hunt_field":
			# Sell loot if inventory has enough materials
			if _get_total_material_count() >= 5:
				npc.set_goal("sell_loot")
				return true
			# Restock potions if out and can afford
			if npc._inventory.get_item_count("healing_potion") == 0 and _can_afford_potions():
				npc.set_goal("buy_potions")
				return true
		"vend":
			# Vending NPCs stay in vend goal — never complete
			# If VendingComponent stopped (e.g. sold out), restart it
			var vc: Node = npc.get_node_or_null("VendingComponent")
			if vc and not vc.is_vending():
				# Listings may be exhausted — stay on vend goal so _execute_vend rebuilds them
				pass
			return false
		"buy_from_vendor":
			# Completes in _execute_goal once purchase attempt is done
			pass
	return false

# =============================================================================
# Goal Execution
# =============================================================================

func _execute_goal() -> void:
	match npc.current_goal:
		"hunt_field":
			_execute_hunt()
		"buy_potions":
			_execute_buy_potions()
		"sell_loot":
			_execute_sell_loot()
		"buy_weapon":
			_execute_buy_equipment("weapon")
		"buy_armor":
			_execute_buy_equipment("armor")
		"follow_player":
			_execute_follow_player()
		"return_to_town":
			_execute_return_to_town()
		"patrol":
			_execute_patrol()
		"rest":
			_execute_rest()
		"idle":
			_execute_idle()
		"vend":
			_execute_vend()
		"buy_from_vendor":
			_execute_buy_from_vendor()
		"tend_shop":
			_execute_tend_shop()

func _execute_hunt() -> void:
	# Look for nearby alive monsters
	var perception: Dictionary = _perception.get_perception()
	var monsters: Array = perception.get("monsters", [])

	# Filter to alive monsters only
	var alive_monsters: Array = []
	for m in monsters:
		if WorldState.is_alive(m["id"]):
			alive_monsters.append(m)

	if alive_monsters.size() > 0:
		# Generosity-based target selection: generous NPCs avoid already-contested monsters
		var generosity: float = NpcTraits.get_trait(npc.trait_profile, "generosity", 0.5)
		var target: Dictionary = alive_monsters[0]
		if generosity >= 0.4:
			# Build set of monster IDs already targeted by other NPCs
			var contested: Dictionary = {}
			for eid in WorldState.entity_data:
				if eid == npc.npc_id:
					continue
				var edata: Dictionary = WorldState.entity_data[eid]
				if edata.get("type", "") == "npc":
					var ct: String = edata.get("combat_target", "")
					if not ct.is_empty():
						contested[ct] = true
			# Prefer uncontested monsters; fall back to any if all contested
			var preferred: Dictionary = {}
			for m in alive_monsters:
				if not contested.has(m["id"]):
					preferred = m
					break
			if not preferred.is_empty():
				target = preferred
		npc.last_thought = "Attacking %s" % target.get("name", target["id"])
		_do_action("attack", target["id"])
		return

	# No alive monsters — check for loot drops before roaming
	# Filter to only loot_drop type entities — item entities don't have pickup()
	var loot_drops: Array = []
	for item in perception.get("items", []):
		var item_data: Dictionary = WorldState.get_entity_data(item["id"])
		if item_data.get("type", "") == "loot_drop":
			loot_drops.append(item)
	if loot_drops.size() > 0:
		var loot: Dictionary = loot_drops[0]
		npc.last_thought = "Picking up %s" % loot.get("name", loot["id"])
		_do_action("pickup_loot", loot["id"])
		return

	# No monsters nearby — move to hunt zone
	var zone_center: String = "FieldCenter"
	var spots: Array = FIELD_SPOTS

	# Check if we're already in the zone
	if _is_near_location(zone_center, 20.0):
		# Already in zone but no monsters — try another spot
		_hunt_spot_index = (_hunt_spot_index + 1) % spots.size()
		var next_spot: String = spots[_hunt_spot_index]
		if WorldState.has_location(next_spot):
			npc.last_thought = "Roaming to %s looking for monsters" % next_spot
			_do_action("move_to", next_spot)
		else:
			_do_action("move_to", zone_center)
	else:
		npc.last_thought = "Heading to %s to hunt" % zone_center
		_do_action("move_to", zone_center)

func _execute_buy_potions() -> void:
	var vendor_id := NpcTradeHelper.find_vendor(npc.npc_id, npc.global_position, "healing_potion")
	if vendor_id.is_empty():
		npc.last_thought = "No vendor selling potions nearby"
		_do_action("wait", "")
		return
	if _is_near_entity(vendor_id, 4.0):
		_do_action_with_data("buy_item", vendor_id, {"item_id": "healing_potion", "count": 1})
	else:
		npc.last_thought = "Going to %s for potions" % vendor_id
		_do_action("move_to", vendor_id)

func _execute_sell_loot() -> void:
	var material_id := NpcTradeHelper.get_first_material(npc._inventory)
	if material_id.is_empty():
		# Nothing to sell, transition handled by _check_goal_completion
		npc.set_goal(default_goal)
		return

	# Sell to any vending NPC (they accept gold in return for items)
	var vendor_id := NpcTradeHelper.find_vendor(npc.npc_id, npc.global_position)
	if vendor_id.is_empty():
		npc.last_thought = "No vendor to sell loot to"
		_do_action("wait", "")
		return
	if _is_near_entity(vendor_id, 4.0):
		var count: int = npc._inventory.get_item_count(material_id)
		_do_action_with_data("sell_item", vendor_id, {"item_id": material_id, "count": count})
	else:
		npc.last_thought = "Going to vendor to sell loot"
		_do_action("move_to", vendor_id)

func _execute_buy_equipment(slot: String) -> void:
	var upgrade_id := NpcTradeHelper.get_best_upgrade(slot, npc._equipment, npc._inventory)
	if upgrade_id.is_empty():
		npc.set_goal(default_goal)
		return

	var vendor_id := NpcTradeHelper.find_vendor(npc.npc_id, npc.global_position, upgrade_id)
	if vendor_id.is_empty():
		npc.last_thought = "No vendor selling %s upgrade" % slot
		npc.set_goal(default_goal)
		return
	if _is_near_entity(vendor_id, 4.0):
		_do_action_with_data("buy_item", vendor_id, {"item_id": upgrade_id, "count": 1})
		# After buying, equip it — the action_completed callback will handle transition
		npc.set_goal(default_goal)
	else:
		npc.last_thought = "Going to %s for %s upgrade" % [vendor_id, slot]
		_do_action("move_to", vendor_id)

func _execute_vend() -> void:
	var vending_comp: Node = npc.get_node_or_null("VendingComponent")
	if not vending_comp:
		# No VendingComponent — just idle
		_do_action("wait", "")
		return
	if vending_comp.is_vending():
		# Already vending — nothing to do this tick
		_do_action("wait", "")
		return
	# Build listings from non-equipped inventory items at 80% of base value
	var listings := NpcTradeHelper.build_vend_listings(npc._inventory, npc._equipment)
	if listings.is_empty():
		npc.last_thought = "Nothing to sell"
		_do_action("wait", "")
		return
	var npc_name: String = WorldState.get_entity_data(npc.npc_id).get("name", npc.npc_id)
	var shop_title: String = "%s's Shop" % npc_name
	vending_comp.start_vending(shop_title, listings)
	npc.last_thought = "Opening shop: %s" % shop_title
	_do_action("wait", "")

func _execute_buy_from_vendor() -> void:
	# Fallback: buy healing potions if affordable, otherwise look for weapon upgrades
	var target_item: String = ""
	var gold: int = npc._inventory.gold
	var potion_count: int = npc._inventory.get_item_count("healing_potion")
	if potion_count < 2 and gold >= 20:
		target_item = "healing_potion"
	else:
		var upgrade_w := NpcTradeHelper.get_best_upgrade("weapon", npc._equipment, npc._inventory)
		var upgrade_a := NpcTradeHelper.get_best_upgrade("armor", npc._equipment, npc._inventory)
		if not upgrade_w.is_empty():
			target_item = upgrade_w
		elif not upgrade_a.is_empty():
			target_item = upgrade_a

	if target_item.is_empty():
		npc.set_goal(default_goal)
		return

	var vendor_id := NpcTradeHelper.find_vendor(npc.npc_id, npc.global_position, target_item)
	if vendor_id.is_empty():
		npc.last_thought = "No vendor selling %s" % target_item
		npc.set_goal(default_goal)
		return

	if _is_near_entity(vendor_id, 4.0):
		_do_action_with_data("buy_item", vendor_id, {"item_id": target_item, "count": 1})
		npc.set_goal(default_goal)
	else:
		npc.last_thought = "Going to %s to buy %s" % [vendor_id, target_item]
		_do_action("move_to", vendor_id)

var _follow_timer: float = 0.0
const FOLLOW_TIMEOUT: float = 120.0  # Stop following after 2 minutes
const FOLLOW_MAX_DISTANCE: float = 30.0  # Stop if player gets too far

func _execute_follow_player() -> void:
	var player_node := WorldState.get_entity("player")
	if not player_node:
		npc.set_goal(default_goal)
		_follow_timer = 0.0
		return

	# Timeout — stop following after FOLLOW_TIMEOUT seconds
	_follow_timer += TICK_INTERVAL
	if _follow_timer >= FOLLOW_TIMEOUT:
		npc.set_goal(default_goal)
		npc.last_thought = "I should get back to my own business"
		_follow_timer = 0.0
		return

	var dist := npc.global_position.distance_to(player_node.global_position)

	# Too far — give up following
	if dist > FOLLOW_MAX_DISTANCE:
		npc.set_goal(default_goal)
		npc.last_thought = "Lost sight of the player"
		_follow_timer = 0.0
		return

	if dist > 5.0:
		_do_action("move_to", "player")
		return

	# Check if player is fighting and help
	var perception: Dictionary = _perception.get_perception()
	var monsters: Array = perception.get("monsters", [])
	for m in monsters:
		if WorldState.is_alive(m["id"]) and m["distance"] < 8.0:
			_do_action("attack", m["id"])
			return

	# Close to player, nothing to do
	_do_action("wait", "")

func _execute_return_to_town() -> void:
	if _is_in_town():
		# HP check will be handled by _check_goal_completion
		# Use potion if we have one and HP not full
		var hp: int = npc._stats.hp
		var max_hp: int = npc._stats.max_hp
		if float(hp) / float(max_hp) < 0.7:
			var potion_count: int = npc._inventory.get_item_count("healing_potion")
			if potion_count > 0:
				_do_action("use_item", "healing_potion")
				return
		# If we're here, HP is fine or no potions — completion check will handle
		_do_action("wait", "")
	else:
		npc.last_thought = "Retreating to town"
		_do_action("move_to", "TownSquare")

func _execute_rest() -> void:
	var stamina_comp = npc.get_node_or_null("StaminaComponent")
	if stamina_comp and stamina_comp.get_stamina_percent() >= 0.8:
		npc.set_goal(default_goal)
		return
	# Find nearest rest spot and move to it
	var nearest_spot: String = ""
	var nearest_dist: float = INF
	for spot_id in ["TownWell", "TownInn"]:
		if WorldState.has_location(spot_id):
			var spot_pos := WorldState.get_location(spot_id)
			var dist := npc.global_position.distance_to(spot_pos)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_spot = spot_id
	if nearest_spot.is_empty():
		_do_action("wait", "")
		return
	if nearest_dist > 4.0:
		npc.last_thought = "Going to %s to rest" % nearest_spot
		_do_action("move_to", nearest_spot)
	else:
		npc.last_thought = "Resting at %s" % nearest_spot
		_do_action("wait", "")

func _execute_patrol() -> void:
	var spot: String = PATROL_SPOTS[_patrol_index]
	if _is_near_location(spot, 3.0):
		_patrol_index = (_patrol_index + 1) % PATROL_SPOTS.size()
		spot = PATROL_SPOTS[_patrol_index]
	npc.last_thought = "Patrolling to %s" % spot
	_do_action("move_to", spot)

func _execute_tend_shop() -> void:
	var identity: Node = npc.get_node_or_null("NpcIdentity")
	if not identity:
		_do_action("wait", "")
		return

	var current_hour: int = int(TimeManager.get_game_hour())
	var sched_goal: Dictionary = identity.resolve_schedule_goal(current_hour)
	var shop_location: String = sched_goal.get("location", "")

	if shop_location.is_empty() or _is_near_location(shop_location, 3.0):
		npc.last_thought = "Tending my shop"
		_do_action("wait", "")
	else:
		npc.last_thought = "Heading to shop"
		_do_action("move_to", shop_location)


func _execute_idle() -> void:
	if _idle_drift_timer < IDLE_DRIFT_INTERVAL:
		return
	_idle_drift_timer = 0.0
	if randf() > IDLE_DRIFT_CHANCE:
		return

	var perception: Dictionary = _perception.get_perception(25.0)
	var npcs_nearby: Array = perception.get("npcs", [])

	var nearest_id: String = ""
	var nearest_dist: float = INF
	for n in npcs_nearby:
		var nid: String = n["id"]
		if nid == "player":
			continue
		if not WorldState.is_alive(nid):
			continue
		var entity_data := WorldState.get_entity_data(nid)
		if entity_data.get("type", "") != "npc":
			continue
		var dist: float = n["distance"]
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = nid

	if nearest_id.is_empty():
		return
	if nearest_dist <= IDLE_CLUSTER_RANGE:
		return

	npc.last_thought = "Drifting toward %s" % nearest_id
	_do_action("move_to", nearest_id)

# =============================================================================
# Action Dispatchers
# =============================================================================

func _do_action(action: String, target: String) -> void:
	_action_in_progress = true
	executor.execute(action, target)

func _do_action_with_data(action: String, target: String, data: Dictionary) -> void:
	_action_in_progress = true
	executor.execute(action, target, "", data)

func _on_action_completed(completed_npc_id: String, _action: String, _success: bool) -> void:
	if completed_npc_id == npc.npc_id:
		_action_in_progress = false

func _on_time_phase_changed(_old_phase: String, new_phase: String) -> void:
	if new_phase == "night" or new_phase == "dawn":
		evaluate()

# =============================================================================
# Helpers
# =============================================================================

func _auto_equip() -> void:
	var equipment: Dictionary = npc._equipment.get_equipment()
	var inv: Dictionary = npc._inventory.get_items()
	for item_id in inv:
		var item := ItemDatabase.get_item(item_id)
		var item_type: String = item.get("type", "")
		if item_type == "weapon":
			var current_id: String = equipment.get("weapon", "")
			var current := ItemDatabase.get_item(current_id)
			if item.get("atk_bonus", 0) > current.get("atk_bonus", 0):
				npc._equipment.equip(item_id)
		elif item_type == "armor":
			var current_id: String = equipment.get("armor", "")
			var current := ItemDatabase.get_item(current_id)
			if item.get("def_bonus", 0) > current.get("def_bonus", 0):
				npc._equipment.equip(item_id)

func _is_in_town() -> bool:
	return _is_near_location("TownSquare", 60.0)

func _is_near_location(location_id: String, range: float) -> bool:
	if not WorldState.has_location(location_id):
		return false
	var loc_pos := WorldState.get_location(location_id)
	return npc.global_position.distance_to(loc_pos) < range

func _is_near_entity(entity_id: String, range: float) -> bool:
	var entity_node := WorldState.get_entity(entity_id)
	if not entity_node or not is_instance_valid(entity_node):
		return false
	return npc.global_position.distance_to(entity_node.global_position) < range

func _get_total_material_count() -> int:
	var inv: Dictionary = npc._inventory.get_items()
	var total := 0
	for item_id in inv:
		var item := ItemDatabase.get_item(item_id)
		if item.get("type", "") == "material":
			total += inv[item_id]
	return total

func _should_restock_potions() -> bool:
	return npc._inventory.get_item_count("healing_potion") < POTION_RESTOCK_THRESHOLD

func _can_afford_potions() -> bool:
	return npc._inventory.gold >= POTION_BUY_GOLD_MIN
