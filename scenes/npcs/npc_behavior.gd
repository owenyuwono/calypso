extends Node
## Deterministic goal-driven behavior for adventurer NPCs.
## Ticks every 1s when NPC is idle. Drives actions via the existing executor.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const NpcTraits = preload("res://scripts/data/npc_traits.gd")

const VALID_GOALS: Array = [
	"hunt_field", "buy_potions", "sell_loot",
	"buy_weapon", "buy_armor", "follow_player", "return_to_town", "patrol", "idle", "rest",
	"vend", "buy_from_vendor", "tend_shop", "chop_wood"
]

const TICK_INTERVAL: float = 1.0

# Alternate hunt spots to roam when no monsters nearby
const FIELD_SPOTS: Array = ["FieldCenter", "FieldFar", "FieldNorth", "FieldSouth"]
const PATROL_SPOTS: Array = ["MarketDistrict", "NobleQuarter", "ParkGardens", "CityGate"]
const TOWN_DESTINATIONS: Array = ["MarketDistrict", "NobleQuarter", "ParkGardens", "CityGate"]
const REST_SPOTS: Array = ["MarketDistrict", "NobleQuarter", "ParkGardens"]

const POTION_STOCK_TARGET: int = 3
const POTION_RESTOCK_THRESHOLD: int = 2
const POTION_BUY_GOLD_MIN: int = 40

var default_goal: String = "patrol"

var npc: CharacterBody3D
var memory: Node
var executor: Node
var brain: Node
var _social: Node  # NpcSocial child node

var _behavior_timer: float = 0.0
var _action_in_progress: bool = false
var _hunt_spot_index: int = 0
var _patrol_index: int = 0
var _perception: Node

var _idle_timer: float = 0.0  # Tracks how long NPC has been idle with no activity
var _was_in_combat: bool = false  # Detects combat → non-combat transition
var _frame_skip: int = randi() % 2
var _last_equip_check_hash: int = -1

func _ready() -> void:
	npc = get_parent()
	memory = npc.get_node("NPCMemory")
	executor = npc.get_node("NPCActionExecutor")
	brain = npc.get_node("NPCBrain")
	# Stagger behavior ticks so 50+ NPCs don't all evaluate on the same frame
	_behavior_timer = randf_range(0.0, TICK_INTERVAL)
	_social = preload("res://scenes/npcs/npc_social.gd").new()
	_social.name = "NpcSocial"
	add_child(_social)
	_social.setup(npc, brain, memory)

	LLMClient.request_completed.connect(_on_shop_title_response)

	GameEvents.npc_action_completed.connect(
		func(n_id: String, action: String, success: bool) -> void:
			if n_id == npc.npc_id:
				_on_action_completed(n_id, action, success)
	)
	GameEvents.time_phase_changed.connect(_on_time_phase_changed)

func _process(delta: float) -> void:
	_frame_skip += 1
	if _frame_skip % 2 != 0:
		return
	var effective_delta: float = delta * 2.0

	# Detect combat → non-combat transition to emit combat_outcome
	if not "current_state" in npc:
		return
	var in_combat: bool = npc.current_state == "combat"
	if _was_in_combat and not in_combat and npc.current_state != "dead":
		_was_in_combat = false
		var outcome: String = "fled" if npc.current_goal == "return_to_town" else "won"
		_emit_npc_event("combat_outcome", {"result": outcome})
	elif in_combat:
		_was_in_combat = true

	if _action_in_progress:
		_idle_timer = 0.0
		return
	if npc.current_state != "idle":
		_idle_timer = 0.0
		return
	if not npc._stats.is_alive():
		return
	if brain and brain.is_busy():
		return

	# Track idle time and fire idle_timeout event
	_idle_timer += effective_delta
	if _idle_timer >= 60.0:
		_idle_timer = 0.0
		_emit_npc_event("idle_timeout", {})

	_behavior_timer += effective_delta
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
			_do_action("move_to", TOWN_DESTINATIONS.pick_random())
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

	# Mid-combat threat assessment: are we losing this fight?
	if npc.current_state == "combat":
		var tracker: Dictionary = npc.get_combat_tracker()
		if tracker["hits_taken"] >= 3:
			var losing: bool = tracker["damage_taken"] > tracker["damage_dealt"] * 1.5
			if losing:
				var flee_threshold: float = 0.5  # default
				if boldness < 0.4:
					flee_threshold = 0.6  # cautious flee earlier
				elif boldness > 0.7:
					flee_threshold = 0.35  # bold stay longer
				if hp_pct < flee_threshold:
					npc.last_thought = "This fight is going badly, retreating!"
					npc.set_goal("return_to_town")
					return true

	# Retreat if HP low and no potions and not in town
	if hp_pct < retreat_threshold and potion_count == 0 and not _is_in_town():
		# Notify LLM if critically low — HP < 30%
		if hp_pct < 0.30:
			_emit_npc_event("low_resources", {"hp_percent": hp_pct})
		npc.set_goal("return_to_town")
		_do_action("move_to", TOWN_DESTINATIONS.pick_random())
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
			_do_action("move_to", TOWN_DESTINATIONS.pick_random())
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
				var completed: String = npc.current_goal
				npc.set_goal(default_goal)
				_emit_npc_event("goal_completed", {"completed_goal": completed})
				return true
		"sell_loot":
			if NpcTradeHelper.get_first_material(npc._inventory).is_empty():
				var completed: String = npc.current_goal
				# Check for weapon/armor upgrade opportunity
				var upgrade := NpcTradeHelper.get_best_upgrade("weapon", npc._equipment, npc._inventory)
				if not upgrade.is_empty():
					npc.set_goal("buy_weapon")
					_emit_npc_event("goal_completed", {"completed_goal": completed})
					return true
				upgrade = NpcTradeHelper.get_best_upgrade("armor", npc._equipment, npc._inventory)
				if not upgrade.is_empty():
					npc.set_goal("buy_armor")
					_emit_npc_event("goal_completed", {"completed_goal": completed})
					return true
				npc.set_goal(default_goal)
				_emit_npc_event("goal_completed", {"completed_goal": completed})
				return true
		"buy_weapon", "buy_armor":
			# These complete in _execute_goal when purchase done or can't afford
			pass
		"rest":
			var rest_stamina_comp = npc.get_node_or_null("StaminaComponent")
			if rest_stamina_comp and rest_stamina_comp.get_stamina_percent() >= 0.8:
				var completed: String = npc.current_goal
				npc.set_goal(default_goal)
				_emit_npc_event("goal_completed", {"completed_goal": completed})
				return true
		"return_to_town":
			if _is_in_town():
				var completed: String = npc.current_goal
				# Check if stamina is low — transition to rest goal
				var rtt_stamina_comp = npc.get_node_or_null("StaminaComponent")
				if rtt_stamina_comp and rtt_stamina_comp.get_stamina_percent() < 0.5:
					npc.set_goal("rest")
					_emit_npc_event("goal_completed", {"completed_goal": completed})
					return true
				var hp: int = npc._stats.hp
				var max_hp: int = npc._stats.max_hp
				if float(hp) / float(max_hp) >= 0.7:
					if _should_restock_potions() and _can_afford_potions():
						npc.set_goal("buy_potions")
					else:
						npc.set_goal(default_goal)
					_emit_npc_event("goal_completed", {"completed_goal": completed})
					return true
		"hunt_field":
			# Sell loot if inventory has enough materials
			if _get_total_material_count() >= 5:
				var completed: String = npc.current_goal
				npc.set_goal("sell_loot")
				_emit_npc_event("goal_completed", {"completed_goal": completed})
				return true
			# Restock potions if out and can afford
			if npc._inventory.get_item_count("healing_potion") == 0 and _can_afford_potions():
				var completed: String = npc.current_goal
				npc.set_goal("buy_potions")
				_emit_npc_event("goal_completed", {"completed_goal": completed})
				return true
		"chop_wood":
			# Sell logs if carrying enough (any wood material type)
			var wood_count: int = npc._inventory.get_item_count("log") + npc._inventory.get_item_count("oak_log") + npc._inventory.get_item_count("ancient_log")
			if wood_count >= 5:
				var completed: String = npc.current_goal
				npc.set_goal("sell_loot")
				_emit_npc_event("goal_completed", {"completed_goal": completed})
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
		"chop_wood":
			_execute_chop_wood()

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
		var target: Dictionary = _select_hunt_target(alive_monsters)
		if not target.is_empty():
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

func _execute_chop_wood() -> void:
	var perception: Dictionary = _perception.get_perception()
	var trees: Array = perception.get("trees", [])

	# Find nearest harvestable tree
	var target_tree: Dictionary = {}
	for t in trees:
		if t.get("harvestable", false):
			target_tree = t
			break

	if target_tree.is_empty():
		# No harvestable trees nearby — move to field zone
		npc.last_thought = "Looking for trees to chop"
		_do_action("move_to", "FieldCenter")
		return

	npc.last_thought = "Chopping %s" % target_tree.get("name", target_tree["id"])
	_do_action("chop_tree", target_tree["id"])

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

var _cached_shop_title: String = ""
var _shop_title_pending: bool = false

func _execute_vend() -> void:
	var vending_comp: Node = npc.get_node_or_null("VendingComponent")
	if not vending_comp:
		_do_action("wait", "")
		return
	if vending_comp.is_vending():
		_do_action("wait", "")
		return
	if _shop_title_pending:
		# Waiting for LLM to name the shop — don't open yet
		npc.last_thought = "Thinking of a shop name..."
		_do_action("wait", "")
		return
	var listings := NpcTradeHelper.build_vend_listings(npc._inventory, npc._equipment)
	if listings.is_empty():
		npc.last_thought = "Nothing to sell"
		_do_action("wait", "")
		return
	if _cached_shop_title != "":
		# Already have a name — open immediately
		vending_comp.start_vending(_cached_shop_title, listings)
		npc.last_thought = "Opening shop: %s" % _cached_shop_title
		_do_action("wait", "")
		return
	# First time — request creative name from LLM, don't open yet
	var npc_name: String = WorldState.get_entity_data(npc.npc_id).get("name", npc.npc_id)
	var item_names: Array = []
	for item_id in listings:
		var item_data: Dictionary = ItemDatabase.ITEMS.get(item_id, {})
		item_names.append(item_data.get("name", item_id))
	var personality: String = WorldState.get_entity_data(npc.npc_id).get("personality", "")
	var prompt_text: String = "You are %s, a shopkeeper in a medieval fantasy town. %s\nYou sell: %s\nInvent a short, creative shop name (2-4 words max). Reply with ONLY the shop name, nothing else." % [npc_name, personality, ", ".join(item_names)]
	var messages: Array = [{"role": "user", "content": prompt_text}]
	var req_id: String = "shop_title_%s" % npc.npc_id
	_shop_title_pending = true
	npc.last_thought = "Thinking of a shop name..."
	LLMClient.send_chat(req_id, messages, {}, 5)
	_do_action("wait", "")

func _on_shop_title_response(req_id: String, response: Dictionary) -> void:
	if not req_id.begins_with("shop_title_"):
		return
	var target_npc_id: String = req_id.substr(11)
	if target_npc_id != npc.npc_id:
		return
	_shop_title_pending = false
	var content: String = response.get("message", {}).get("content", "").strip_edges()
	# Clean up quotes
	content = content.trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
	if content.is_empty() or content.length() > 40:
		# Fallback if LLM gave bad output
		var npc_name: String = WorldState.get_entity_data(npc.npc_id).get("name", npc.npc_id)
		content = "%s's Shop" % npc_name
	_cached_shop_title = content

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
		_do_action("move_to", TOWN_DESTINATIONS.pick_random())

func _execute_rest() -> void:
	var stamina_comp = npc.get_node_or_null("StaminaComponent")
	if stamina_comp and stamina_comp.get_stamina_percent() >= 0.8:
		npc.set_goal(default_goal)
		return
	# Find nearest rest spot and move to it
	var nearest_spot: String = ""
	var nearest_dist: float = INF
	for spot_id in REST_SPOTS:
		if WorldState.has_location(spot_id):
			var spot_pos := WorldState.get_location(spot_id)
			var dist := npc.global_position.distance_to(spot_pos)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_spot = spot_id
	if nearest_spot.is_empty():
		_do_action("wait", "")
		return
	if nearest_dist > 15.0:
		npc.last_thought = "Going to %s to rest" % nearest_spot
		_do_action("move_to", nearest_spot)
	else:
		npc.last_thought = "Resting at %s" % nearest_spot
		_do_action("wait", "")

func _execute_patrol() -> void:
	var spot: String = PATROL_SPOTS[_patrol_index]
	if _is_near_location(spot, 15.0):
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
	# NPCs with idle goal should find something purposeful to do
	var inv: Node = npc.get_node_or_null("InventoryComponent")
	var stats: Node = npc.get_node_or_null("StatsComponent")

	# Low HP → return to town
	if stats:
		var hp_pct: float = float(stats.hp) / float(stats.max_hp) if stats.max_hp > 0 else 1.0
		if hp_pct < 0.7:
			npc.set_goal("return_to_town")
			return

	# Has materials → sell them
	if _get_total_material_count() > 0:
		npc.set_goal("sell_loot")
		return

	# Needs potions and has gold → buy potions
	if inv:
		var potion_count: int = inv.get_items().get("healing_potion", 0)
		var gold: int = inv.get_gold_amount()
		if potion_count < 2 and gold >= 20:
			npc.set_goal("buy_potions")
			return

	# In the field zone with woodcutting proficiency → chop wood (lower priority than combat/trade)
	var in_field: bool = absf(npc.global_position.x) > 70.0
	if in_field and npc._progression.get_proficiency_level("woodcutting") > 0:
		var perception: Dictionary = _perception.get_perception() if _perception else {}
		var trees: Array = perception.get("trees", [])
		var has_harvestable_tree: bool = false
		for t in trees:
			if t.get("harvestable", false):
				has_harvestable_tree = true
				break
		if has_harvestable_tree:
			npc.set_goal("chop_wood")
			return

	# Fallback → patrol town
	npc.set_goal("patrol")

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
		# Evaluate next action immediately instead of waiting for next tick
		_behavior_timer = TICK_INTERVAL

func _on_time_phase_changed(_old_phase: String, new_phase: String) -> void:
	if new_phase == "night" or new_phase == "dawn":
		evaluate()

# =============================================================================
# Hunt Target Selection
# =============================================================================

func _is_monster_contested(monster_id: String, nearby_entities: Array) -> Dictionary:
	# Uses the pre-fetched nearby list — avoids calling get_nearby() once per monster.
	for entry in nearby_entities:
		var eid: String = entry.id
		if eid == npc.npc_id:
			continue
		var edata: Dictionary = WorldState.get_entity_data(eid)
		if edata.get("type", "") != "npc":
			continue
		if edata.get("combat_target", "") != monster_id:
			continue
		# Found a fighter — check their status
		var fighter_hp: int = edata.get("hp", 0)
		var fighter_max_hp: int = edata.get("max_hp", 1)
		var fighter_hp_pct: float = float(fighter_hp) / float(fighter_max_hp)
		var fighter_goal: String = edata.get("goal", "")
		var fighter_retreating: bool = fighter_goal == "return_to_town" or fighter_hp_pct < 0.3
		return {"contested": true, "fighter_id": eid, "fighter_hp_pct": fighter_hp_pct, "fighter_retreating": fighter_retreating}
	return {"contested": false, "fighter_id": "", "fighter_hp_pct": 1.0, "fighter_retreating": false}

func _can_handle_monster(monster_data: Dictionary) -> bool:
	# Compare NPC stats vs monster stats — can we handle this fight?
	var combat: Node = npc.get_node_or_null("CombatComponent")
	if not combat:
		return true  # no combat component = no way to evaluate, assume yes
	var npc_atk: int = combat.get_effective_atk()
	var npc_def: int = combat.get_effective_def()
	var monster_atk: int = monster_data.get("atk", 5)
	var monster_def: int = monster_data.get("def", 0)
	var monster_hp: int = monster_data.get("hp", 10)

	# Can we deal meaningful damage?
	var our_damage: int = maxi(npc_atk - monster_def, 1)
	# How much damage will we take?
	var their_damage: int = maxi(monster_atk - npc_def, 1)

	# If we'd die before killing it (rough estimate), it's too strong
	var stats: Node = npc.get_node_or_null("StatsComponent")
	if stats:
		var our_hp: int = stats.hp
		var hits_to_kill: int = ceili(float(monster_hp) / float(our_damage))
		var hits_to_die: int = ceili(float(our_hp) / float(their_damage))
		if hits_to_die < hits_to_kill:
			return false  # we'd die first
	return true

func _select_hunt_target(alive_monsters: Array) -> Dictionary:
	var generosity: float = NpcTraits.get_trait(npc.trait_profile, "generosity", 0.5)
	var boldness: float = NpcTraits.get_trait(npc.trait_profile, "boldness", 0.5)

	var uncontested: Array = []
	var help_targets: Array = []  # contested where fighter is retreating
	var contested: Array = []

	# Fetch nearby entities once — passed to _is_monster_contested to avoid O(M×T) calls
	var nearby: Array = _perception.get_nearby() if _perception else []

	for m in alive_monsters:
		var contest_info: Dictionary = _is_monster_contested(m["id"], nearby)
		var monster_data: Dictionary = WorldState.get_entity_data(m["id"])

		# Skip monsters we can't handle (unless bold)
		if boldness <= 0.7 and not _can_handle_monster(monster_data):
			continue

		if not contest_info["contested"]:
			uncontested.append(m)
		elif contest_info["fighter_retreating"]:
			help_targets.append(m)
		else:
			contested.append(m)

	# Priority 1: Uncontested monsters (always preferred)
	if uncontested.size() > 0:
		return uncontested[0]

	# Priority 2: Help retreating ally (generous NPCs only)
	if help_targets.size() > 0 and generosity >= 0.6:
		npc.last_thought = "Helping a friend in trouble!"
		return help_targets[0]

	# Priority 3: Steal contested (selfish + aggressive NPCs only)
	if contested.size() > 0 and generosity < 0.3 and boldness > 0.5:
		return contested[0]

	# Priority 4: All-contested fallback — attack nearest anyway
	if contested.size() > 0:
		return contested[0]
	if help_targets.size() > 0:
		return help_targets[0]

	# Priority 5: Monsters we skipped as too strong — pick weakest
	if alive_monsters.size() > 0:
		return alive_monsters[alive_monsters.size() - 1]  # last = weakest (sorted by distance, but better than nothing)

	return {}  # no monsters at all

# =============================================================================
# Helpers
# =============================================================================

func _auto_equip() -> void:
	var inv: Dictionary = npc._inventory.get_items()
	var check_hash: int = inv.size()
	if check_hash == _last_equip_check_hash:
		return
	_last_equip_check_hash = check_hash
	var equipment: Dictionary = npc._equipment.get_equipment()
	for item_id in inv:
		var item := ItemDatabase.get_item(item_id)
		var item_type: String = item.get("type", "")
		if item_type == "weapon":
			var current_id: String = equipment.get("main_hand", "")
			var current := ItemDatabase.get_item(current_id)
			if item.get("atk_bonus", 0) > current.get("atk_bonus", 0):
				npc._equipment.equip(item_id)
		elif item_type == "armor":
			var current_id: String = equipment.get("off_hand", "")
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

## Emit a significant NPC event to both the brain and the GameEvents signal bus.
func _emit_npc_event(event_type: String, context: Dictionary) -> void:
	if brain:
		brain.on_significant_event(event_type, context)
	GameEvents.npc_event_triggered.emit(npc.npc_id, event_type, context)
