extends Node
## Deterministic goal-driven behavior for adventurer NPCs.
## Ticks every 1s when NPC is idle. Drives actions via the existing executor.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const NpcTraits = preload("res://scripts/data/npc_traits.gd")

const VALID_GOALS: Array = [
	"hunt_field", "hunt_dungeon", "buy_potions", "sell_loot",
	"buy_weapon", "buy_armor", "follow_player", "return_to_town", "patrol", "idle", "rest"
]

const TICK_INTERVAL: float = 1.0
const IDLE_DRIFT_INTERVAL: float = 8.0
const IDLE_CLUSTER_RANGE: float = 4.0
const IDLE_DRIFT_CHANCE: float = 0.6

# Alternate hunt spots to roam when no monsters nearby
const FIELD_SPOTS: Array = ["FieldCenter", "FieldFar", "FieldNorth", "FieldSouth"]
const DUNGEON_SPOTS: Array = ["DungeonCenter", "DungeonDeep", "DungeonEntrance"]
const PATROL_SPOTS: Array = ["TownSquare", "TownNorth", "TownEast", "TownSouth"]

var default_goal: String = "idle"

var npc: CharacterBody3D
var memory: Node
var executor: Node
var brain: Node

var _behavior_timer: float = 0.0
var _social_cooldown: float = 0.0
const SOCIAL_COOLDOWN_MIN: float = 15.0
const SOCIAL_COOLDOWN_MAX: float = 45.0
const SOCIAL_PROXIMITY: float = 12.0
var _action_in_progress: bool = false
var _idle_drift_timer: float = 0.0
var _hunt_spot_index: int = 0
var _patrol_index: int = 0

func _ready() -> void:
	npc = get_parent()
	memory = npc.get_node("NPCMemory")
	executor = npc.get_node("NPCActionExecutor")
	brain = npc.get_node("NPCBrain")
	_social_cooldown = randf_range(10.0, 20.0)
	GameEvents.npc_action_completed.connect(_on_action_completed)

func _process(delta: float) -> void:
	if _social_cooldown > 0.0:
		_social_cooldown -= delta
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
	# Priority 2.5: Social chat with nearby NPCs
	if _try_social_chat():
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
	var gold: int = npc._inventory.gold

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
					var potion_count: int = npc._inventory.get_item_count("healing_potion")
					if potion_count < 2 and npc._inventory.gold >= 40:
						npc.set_goal("buy_potions")
					else:
						npc.set_goal(default_goal)
					return true
		"hunt_field", "hunt_dungeon":
			# Sell loot if inventory has enough materials
			if _get_total_material_count() >= 5:
				npc.set_goal("sell_loot")
				return true
			# Restock potions if out and can afford
			var potion_count: int = npc._inventory.get_item_count("healing_potion")
			if potion_count == 0 and npc._inventory.gold >= 40:
				npc.set_goal("buy_potions")
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
		"rest":
			_execute_rest()
		"idle":
			_execute_idle()

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
		var count: int = npc._inventory.get_item_count(material_id)
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

func _execute_idle() -> void:
	if _idle_drift_timer < IDLE_DRIFT_INTERVAL:
		return
	_idle_drift_timer = 0.0
	if randf() > IDLE_DRIFT_CHANCE:
		return

	var perception := WorldState.get_npc_perception(npc.npc_id, 25.0)
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
	var inv: Dictionary = npc._inventory.get_items()
	for item_id in inv:
		var item := ItemDatabase.get_item(item_id)
		if item.get("type", "") == "material":
			return item_id
	return ""

func _get_total_material_count() -> int:
	var inv: Dictionary = npc._inventory.get_items()
	var total := 0
	for item_id in inv:
		var item := ItemDatabase.get_item(item_id)
		if item.get("type", "") == "material":
			total += inv[item_id]
	return total

func _get_best_upgrade(slot: String) -> String:
	var equipment: Dictionary = npc._equipment.get_equipment()
	var current_id: String = equipment.get(slot, "")
	var current_item := ItemDatabase.get_item(current_id)
	var gold: int = npc._inventory.gold

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

const SOCIAL_GOALS: Array = ["idle", "patrol", "rest"]

func _try_social_chat() -> bool:
	if _social_cooldown > 0.0:
		return false
	if not brain or brain.is_busy():
		print("[CHAT] %s: skip social — brain busy (llm=%s responding=%s hold=%.1f reading=%s)" % [npc.npc_id, brain._waiting_for_llm, brain._responding_to, brain._conversation_hold, not brain._reading_queue.is_empty()])
		return false
	if npc.current_goal not in SOCIAL_GOALS:
		return false

	var perception := WorldState.get_npc_perception(npc.npc_id, SOCIAL_PROXIMITY)
	var npcs: Array = perception.get("npcs", [])

	# Build candidate list and sort by affinity (highest first)
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
		if not memory.can_continue_conversation(nid):
			continue
		var affinity: float = memory.get_relationship(nid)["affinity"]
		candidates.append({"id": nid, "affinity": affinity})

	if candidates.is_empty():
		print("[CHAT] %s: no candidates (saw %d npcs within %.0f)" % [npc.npc_id, npcs.size(), SOCIAL_PROXIMITY])

	# Sort by affinity descending — prefer friends
	candidates.sort_custom(func(a, b): return a["affinity"] > b["affinity"])

	for c in candidates:
		var facts: Array = memory.gather_chat_facts(c["id"])
		# Gate: only chat if there's something interesting to say (weight >= 1.5)
		var interesting := facts.filter(func(f): return f.get("weight", 0.0) >= 1.5)
		if interesting.is_empty():
			continue  # nothing worth chatting about
		# Filter out recently discussed topics
		var fresh_facts := facts.filter(func(f): return not memory.is_recent_topic(f.get("topic", "")))
		if fresh_facts.is_empty():
			fresh_facts = facts  # fallback: allow repeats if everything was used
		var picked := _pick_weighted_fact(fresh_facts)
		var subject: String = picked.get("topic", FALLBACK_TOPICS[randi() % FALLBACK_TOPICS.size()])
		var intent_data: Dictionary = _pick_chat_intent()
		var target_name: String = WorldState.get_entity_data(c["id"]).get("name", c["id"])
		var intent_cue: String = intent_data["cue"].format({"target_name": target_name})
		print("[CHAT] %s: initiating chat with %s — %s %s" % [npc.npc_id, c["id"], intent_data["intent"], subject])
		if brain.initiate_social_chat(c["id"], subject, intent_cue, facts):
			memory.add_recent_topic(subject)
			var sociability: float = NpcTraits.get_trait(npc.trait_profile, "sociability", 0.5)
			var min_cd: float = SOCIAL_COOLDOWN_MIN + (1.0 - sociability) * 40.0
			var max_cd: float = SOCIAL_COOLDOWN_MAX + (1.0 - sociability) * 60.0
			_social_cooldown = randf_range(min_cd, max_cd)
			print("[CHAT] %s: next social in %.0fs" % [npc.npc_id, _social_cooldown])
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
	var boldness: float = NpcTraits.get_trait(npc.trait_profile, "boldness", 0.5)
	var curiosity: float = NpcTraits.get_trait(npc.trait_profile, "curiosity", 0.5)
	var sociability: float = NpcTraits.get_trait(npc.trait_profile, "sociability", 0.5)

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
