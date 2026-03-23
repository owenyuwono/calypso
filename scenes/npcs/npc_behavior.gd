extends Node
## Deterministic goal-driven behavior for adventurer NPCs.
## Ticks every 1s when NPC is idle. Drives actions via the existing executor.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const NpcTraits = preload("res://scripts/data/npc_traits.gd")
const RecipeDatabase = preload("res://scripts/data/recipe_database.gd")

const VALID_GOALS: Array = [
	"hunt_field", "follow_player", "return_to_town", "patrol", "idle", "rest",
	"chop_wood", "craft_items"
]

const TICK_INTERVAL: float = 1.0

# Alternate hunt spots to roam when no monsters nearby
const FIELD_SPOTS: Array = ["FieldCenter", "FieldFar", "FieldNorth", "FieldSouth"]
const PATROL_SPOTS: Array = ["MarketDistrict", "NobleQuarter", "ParkGardens", "CityGate"]
const TOWN_DESTINATIONS: Array = ["MarketDistrict", "NobleQuarter", "ParkGardens", "CityGate"]
const REST_SPOTS: Array = ["MarketDistrict", "NobleQuarter", "ParkGardens"]

var default_goal: String = "patrol"

var npc: CharacterBody3D
var memory: Node
var executor: Node
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
	# Stagger behavior ticks so 50+ NPCs don't all evaluate on the same frame
	_behavior_timer = randf_range(0.0, TICK_INTERVAL)
	_social = preload("res://scenes/npcs/npc_social.gd").new()
	_social.name = "NpcSocial"
	add_child(_social)
	_social.setup(npc, memory)

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

	# Detect combat → non-combat transition
	if not "current_state" in npc:
		return
	var in_combat: bool = npc.current_state == "combat"
	if _was_in_combat and not in_combat and npc.current_state != "dead":
		_was_in_combat = false
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

	_idle_timer += effective_delta

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
					npc.set_goal(default_goal)
					return true
		"hunt_field":
			# No materials-to-sell transition — just keep hunting
			pass
		"chop_wood":
			# Sell logs removed — just keep chopping
			pass
		"craft_items":
			# Complete when no more craftable recipes — simplified without NpcEconomyHelper
			var progression: Node = npc.get_node_or_null("ProgressionComponent")
			if not progression:
				npc.set_goal(default_goal)
				return true
			# Check if inventory has crafting inputs for any recipe
			var found_recipe: bool = false
			for skill_id in ["cooking", "smithing", "crafting"]:
				for recipe_id in RecipeDatabase.get_recipes_for_skill(skill_id):
					var recipe: Dictionary = RecipeDatabase.get_recipe(recipe_id)
					var can_craft: bool = true
					for input_id in recipe.get("inputs", {}):
						if npc._inventory.get_item_count(input_id) < recipe["inputs"][input_id]:
							can_craft = false
							break
					if can_craft:
						found_recipe = true
						break
				if found_recipe:
					break
			if not found_recipe:
				npc.set_goal(default_goal)
				return true
	return false

# =============================================================================
# Goal Execution
# =============================================================================

func _execute_goal() -> void:
	match npc.current_goal:
		"hunt_field":
			_execute_hunt()
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
		"chop_wood":
			_execute_chop_wood()
		"craft_items":
			_execute_craft()

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

func _execute_idle() -> void:
	# Idle NPCs stay put — do nothing
	pass

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

func _is_near_position(pos: Vector3, range: float) -> bool:
	return npc.global_position.distance_to(pos) <= range

func _execute_craft() -> void:
	var progression: Node = npc.get_node_or_null("ProgressionComponent")
	if not progression:
		npc.set_goal(default_goal)
		return

	# Find best craftable recipe across all craft skills
	var best_recipe_id: String = ""
	var best_skill: String = ""
	for skill_id in ["cooking", "smithing", "crafting"]:
		for recipe_id in RecipeDatabase.get_recipes_for_skill(skill_id):
			var recipe: Dictionary = RecipeDatabase.get_recipe(recipe_id)
			var req_level: int = recipe.get("required_level", 1)
			if progression.get_proficiency_level(skill_id) < req_level:
				continue
			var can_craft: bool = true
			for input_id in recipe.get("inputs", {}):
				if npc._inventory.get_item_count(input_id) < recipe["inputs"][input_id]:
					can_craft = false
					break
			if can_craft:
				best_recipe_id = recipe_id
				best_skill = skill_id
				break
		if not best_recipe_id.is_empty():
			break

	if best_recipe_id.is_empty():
		npc.set_goal(default_goal)
		return

	# Find nearest crafting station of the right type
	var station: Node = _find_nearest_crafting_station(best_skill)
	if not station:
		npc.last_thought = "No crafting station nearby"
		npc.set_goal(default_goal)
		return

	# Dispatch craft action — executor handles navigation internally
	var recipe: Dictionary = RecipeDatabase.get_recipe(best_recipe_id)
	npc.last_thought = "Going to craft %s" % recipe.get("name", best_recipe_id)
	_do_action_with_data("craft_at_station", station._entity_id, {"recipe_id": best_recipe_id})

func _find_nearest_crafting_station(skill_id: String) -> Node:
	var best: Node = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("crafting_stations"):
		if node.get("station_type") == skill_id:
			var dist: float = npc.global_position.distance_to(node.global_position)
			if dist < best_dist:
				best_dist = dist
				best = node
	return best
