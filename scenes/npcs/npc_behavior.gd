extends Node
## Deterministic goal-driven behavior for adventurer NPCs.
## Ticks every 1s when NPC is idle. Drives actions via the existing executor.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

const VALID_GOALS: Array = [
	"hunt_field", "hunt_dungeon", "buy_potions", "sell_loot",
	"buy_weapon", "buy_armor", "follow_player", "return_to_town", "patrol", "idle"
]

const TICK_INTERVAL: float = 1.0

# Alternate hunt spots to roam when no monsters nearby
const FIELD_SPOTS: Array = ["FieldCenter", "FieldFar", "FieldNorth", "FieldSouth"]
const DUNGEON_SPOTS: Array = ["DungeonCenter", "DungeonDeep", "DungeonEntrance"]
const PATROL_SPOTS: Array = ["TownSquare", "TownNorth", "TownEast", "TownSouth"]

var default_goal: String = "hunt_field"

var npc: CharacterBody3D
var memory: Node
var executor: Node
var brain: Node

var _behavior_timer: float = 0.0
var _social_cooldown: float = 0.0
const SOCIAL_COOLDOWN_MIN: float = 45.0
const SOCIAL_COOLDOWN_MAX: float = 90.0
const SOCIAL_PROXIMITY: float = 12.0
var _action_in_progress: bool = false
var _hunt_spot_index: int = 0
var _patrol_index: int = 0

func _ready() -> void:
	npc = get_parent()
	memory = npc.get_node("NPCMemory")
	executor = npc.get_node("NPCActionExecutor")
	brain = npc.get_node("NPCBrain")
	_social_cooldown = randf_range(10.0, 30.0)
	GameEvents.npc_action_completed.connect(_on_action_completed)

func _process(delta: float) -> void:
	if _social_cooldown > 0.0:
		_social_cooldown -= delta
	if _action_in_progress:
		return
	if npc.current_state != "idle":
		return
	if not WorldState.is_alive(npc.npc_id):
		return

	_behavior_timer += delta
	if _behavior_timer >= TICK_INTERVAL:
		_behavior_timer = 0.0
		evaluate()

func evaluate() -> void:
	# Priority 0: Auto-equip any unequipped gear in inventory
	_auto_equip()
	# Priority 1: Survival checks
	if _check_survival():
		return
	# Priority 2: Goal completion transitions
	if _check_goal_completion():
		return
	# Priority 2.5: Social chat with nearby NPCs
	if _try_social_chat():
		return
	# Priority 3: Execute current goal
	_execute_goal()

# =============================================================================
# Survival Priorities
# =============================================================================

func _check_survival() -> bool:
	var data := WorldState.get_entity_data(npc.npc_id)
	var hp: int = data.get("hp", 0)
	var max_hp: int = data.get("max_hp", 1)
	var hp_pct: float = float(hp) / float(max_hp)
	var potion_count: int = WorldState.get_item_count(npc.npc_id, "healing_potion")
	var gold: int = WorldState.get_gold(npc.npc_id)

	# Use potion if HP < 30% and has one
	if hp_pct < 0.3 and potion_count > 0:
		_do_action("use_item", "healing_potion")
		return true

	# Retreat if HP < 40% and no potions and not in town
	if hp_pct < 0.4 and potion_count == 0 and not _is_in_town():
		npc.set_goal("return_to_town")
		_do_action("move_to", "TownSquare")
		return true

	# Buy potions if running low and can afford
	if potion_count < 2 and gold >= 40 and npc.current_goal != "buy_potions":
		npc.set_goal("buy_potions")
		return false  # Let _execute_goal handle it next tick

	# Sell loot if inventory has >3 materials
	var material_count := _get_total_material_count()
	if material_count > 3 and npc.current_goal != "sell_loot":
		npc.set_goal("sell_loot")
		return false

	return false

# =============================================================================
# Goal Completion Checks
# =============================================================================

func _check_goal_completion() -> bool:
	match npc.current_goal:
		"buy_potions":
			var potion_count := WorldState.get_item_count(npc.npc_id, "healing_potion")
			var gold := WorldState.get_gold(npc.npc_id)
			if potion_count >= 3 or gold < 20:
				npc.set_goal(default_goal)
				return true
		"sell_loot":
			if _get_first_material().is_empty():
				# Check for weapon/armor upgrade opportunity
				var upgrade := _get_best_upgrade("weapon")
				if not upgrade.is_empty():
					npc.set_goal("buy_weapon")
					return true
				upgrade = _get_best_upgrade("armor")
				if not upgrade.is_empty():
					npc.set_goal("buy_armor")
					return true
				npc.set_goal(default_goal)
				return true
		"buy_weapon", "buy_armor":
			# These complete in _execute_goal when purchase done or can't afford
			pass
		"return_to_town":
			if _is_in_town():
				var data := WorldState.get_entity_data(npc.npc_id)
				var hp: int = data.get("hp", 0)
				var max_hp: int = data.get("max_hp", 1)
				if float(hp) / float(max_hp) >= 0.7:
					var potion_count := WorldState.get_item_count(npc.npc_id, "healing_potion")
					if potion_count < 2 and WorldState.get_gold(npc.npc_id) >= 40:
						npc.set_goal("buy_potions")
					else:
						npc.set_goal(default_goal)
					return true
	return false

# =============================================================================
# Goal Execution
# =============================================================================

func _execute_goal() -> void:
	match npc.current_goal:
		"hunt_field":
			_execute_hunt("field")
		"hunt_dungeon":
			_execute_hunt("dungeon")
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
		"idle":
			pass  # Do nothing

func _execute_hunt(zone: String) -> void:
	# Look for nearby alive monsters
	var perception := WorldState.get_npc_perception(npc.npc_id)
	var monsters: Array = perception.get("monsters", [])

	# Filter to alive monsters only
	var alive_monsters: Array = []
	for m in monsters:
		if WorldState.is_alive(m["id"]):
			alive_monsters.append(m)

	if alive_monsters.size() > 0:
		# Attack nearest alive monster
		var target: Dictionary = alive_monsters[0]
		npc.last_thought = "Attacking %s" % target.get("name", target["id"])
		_do_action("attack", target["id"])
		return

	# No monsters nearby — move to hunt zone
	var zone_center: String = "FieldCenter" if zone == "field" else "DungeonCenter"
	var spots: Array = FIELD_SPOTS if zone == "field" else DUNGEON_SPOTS

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
	if _is_near_entity("item_shop_npc", 4.0):
		_do_action_with_data("buy_item", "item_shop_npc", {"item_id": "healing_potion", "count": 1})
	else:
		npc.last_thought = "Going to item shop for potions"
		_do_action("move_to", "item_shop_npc")

func _execute_sell_loot() -> void:
	var material_id := _get_first_material()
	if material_id.is_empty():
		# Nothing to sell, transition handled by _check_goal_completion
		npc.set_goal(default_goal)
		return

	if _is_near_entity("weapon_shop_npc", 4.0):
		var count := WorldState.get_item_count(npc.npc_id, material_id)
		_do_action_with_data("sell_item", "weapon_shop_npc", {"item_id": material_id, "count": count})
	else:
		npc.last_thought = "Going to weapon shop to sell loot"
		_do_action("move_to", "weapon_shop_npc")

func _execute_buy_equipment(slot: String) -> void:
	var upgrade_id := _get_best_upgrade(slot)
	if upgrade_id.is_empty():
		npc.set_goal(default_goal)
		return

	var shop_id: String = "weapon_shop_npc" if slot == "weapon" else "item_shop_npc"
	if _is_near_entity(shop_id, 4.0):
		_do_action_with_data("buy_item", shop_id, {"item_id": upgrade_id, "count": 1})
		# After buying, equip it
		# The action_completed callback will handle transition
		npc.set_goal(default_goal)
	else:
		npc.last_thought = "Going to shop for %s upgrade" % slot
		_do_action("move_to", shop_id)

func _execute_follow_player() -> void:
	var player_node := WorldState.get_entity("player")
	if not player_node:
		npc.set_goal(default_goal)
		return

	var dist := npc.global_position.distance_to(player_node.global_position)
	if dist > 5.0:
		_do_action("move_to", "player")
		return

	# Check if player is fighting and help
	var perception := WorldState.get_npc_perception(npc.npc_id)
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
		var data := WorldState.get_entity_data(npc.npc_id)
		var hp: int = data.get("hp", 0)
		var max_hp: int = data.get("max_hp", 1)
		if float(hp) / float(max_hp) < 0.7:
			var potion_count := WorldState.get_item_count(npc.npc_id, "healing_potion")
			if potion_count > 0:
				_do_action("use_item", "healing_potion")
				return
		# If we're here, HP is fine or no potions — completion check will handle
		_do_action("wait", "")
	else:
		npc.last_thought = "Retreating to town"
		_do_action("move_to", "TownSquare")

func _execute_patrol() -> void:
	var spot: String = PATROL_SPOTS[_patrol_index]
	if _is_near_location(spot, 3.0):
		_patrol_index = (_patrol_index + 1) % PATROL_SPOTS.size()
		spot = PATROL_SPOTS[_patrol_index]
	npc.last_thought = "Patrolling to %s" % spot
	_do_action("move_to", spot)

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

# =============================================================================
# Helpers
# =============================================================================

func _auto_equip() -> void:
	var data := WorldState.get_entity_data(npc.npc_id)
	var equipment: Dictionary = data.get("equipment", {})
	var inv := WorldState.get_inventory(npc.npc_id)
	for item_id in inv:
		var item := ItemDatabase.get_item(item_id)
		var item_type: String = item.get("type", "")
		if item_type == "weapon":
			var current_id: String = equipment.get("weapon", "")
			var current := ItemDatabase.get_item(current_id)
			if item.get("atk_bonus", 0) > current.get("atk_bonus", 0):
				WorldState.equip_item(npc.npc_id, item_id)
		elif item_type == "armor":
			var current_id: String = equipment.get("armor", "")
			var current := ItemDatabase.get_item(current_id)
			if item.get("def_bonus", 0) > current.get("def_bonus", 0):
				WorldState.equip_item(npc.npc_id, item_id)

func _is_in_town() -> bool:
	return _is_near_location("TownSquare", 25.0)

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

func _get_first_material() -> String:
	var inv := WorldState.get_inventory(npc.npc_id)
	for item_id in inv:
		var item := ItemDatabase.get_item(item_id)
		if item.get("type", "") == "material":
			return item_id
	return ""

func _get_total_material_count() -> int:
	var inv := WorldState.get_inventory(npc.npc_id)
	var total := 0
	for item_id in inv:
		var item := ItemDatabase.get_item(item_id)
		if item.get("type", "") == "material":
			total += inv[item_id]
	return total

func _get_best_upgrade(slot: String) -> String:
	var data := WorldState.get_entity_data(npc.npc_id)
	var equipment: Dictionary = data.get("equipment", {})
	var current_id: String = equipment.get(slot, "")
	var current_item := ItemDatabase.get_item(current_id)
	var gold := WorldState.get_gold(npc.npc_id)

	var bonus_key: String = "atk_bonus" if slot == "weapon" else "def_bonus"
	var current_bonus: int = current_item.get(bonus_key, 0)
	var item_type: String = slot  # "weapon" or "armor"

	var best_id: String = ""
	var best_bonus: int = current_bonus

	for item_id in ItemDatabase.ITEMS:
		var item: Dictionary = ItemDatabase.ITEMS[item_id]
		if item.get("type", "") != item_type:
			continue
		var item_bonus: int = item.get(bonus_key, 0)
		var cost: int = item.get("value", 0)
		if item_bonus > best_bonus and cost <= gold and item_id != current_id:
			best_bonus = item_bonus
			best_id = item_id

	return best_id

# =============================================================================
# Social Chat
# =============================================================================

const URGENT_GOALS: Array = ["buy_potions", "return_to_town", "sell_loot", "buy_weapon", "buy_armor"]

func _try_social_chat() -> bool:
	if _social_cooldown > 0.0:
		return false
	if not brain or brain.is_busy():
		return false
	if npc.current_goal in URGENT_GOALS:
		return false

	var perception := WorldState.get_npc_perception(npc.npc_id, SOCIAL_PROXIMITY)
	var npcs: Array = perception.get("npcs", [])
	for n in npcs:
		var nid: String = n["id"]
		if nid == "player":
			continue
		if not WorldState.is_alive(nid):
			continue
		var state: String = n.get("state", "idle")
		if state in ["combat", "dead", "thinking"]:
			continue
		if not memory.can_continue_conversation(nid):
			continue
		if brain.initiate_social_chat(nid):
			_social_cooldown = randf_range(SOCIAL_COOLDOWN_MIN, SOCIAL_COOLDOWN_MAX)
			return true
	return false
