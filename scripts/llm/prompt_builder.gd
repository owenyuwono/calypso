extends RefCounted
## Builds LLM prompts from NPC state, personality, memory, and perception.

const SYSTEM_TEMPLATE := """You are {npc_name}, a character in a medieval village.

PERSONALITY: {personality}

CURRENT GOAL: {goal}

You must respond with a JSON object choosing your next action. Available actions:
- move_to: Walk to a location or entity. Target = location_id or entity_id
- pick_up: Pick up a nearby item. Target = item_id (must be within 3 meters)
- drop_item: Drop an item from your inventory. Target = item_id
- use_object: Interact with a nearby object. Target = object_id (must be within 3 meters)
- talk_to: Say something to a nearby NPC. Target = npc_id, include dialogue
- wait: Do nothing for now

IMPORTANT RULES:
- Stay in character as {npc_name} at all times
- Choose actions that make sense for your personality and goals
- You can only pick up items or use objects within 3 meters
- When talking, speak naturally as your character would
- Keep dialogue to ONE short sentence (under 15 words)
- Don't try to cover multiple topics — the conversation will continue naturally
- If you've been talking back and forth, consider ending with a wait action
- Update your goal if you've completed it or circumstances changed"""

const USER_TEMPLATE := """CURRENT SITUATION:
Location: {location}
{inventory_info}

NEARBY:
{perception}

{memory}

What do you do next? Respond with a JSON action."""

static func build_system_message(npc_name: String, personality: String, goal: String) -> Dictionary:
	var content := SYSTEM_TEMPLATE.format({
		"npc_name": npc_name,
		"personality": personality,
		"goal": goal,
	})
	return {"role": "system", "content": content}

static func build_user_message(npc_id: String, npc_node: Node3D, memory_node: Node) -> Dictionary:
	var perception := WorldState.get_npc_perception(npc_id)
	var location := _get_nearest_location(npc_node)
	var inventory := WorldState.get_inventory(npc_id)
	var memory_summary: String = memory_node.get_summary() if memory_node else ""

	var inventory_info := "Inventory: (empty)"
	if not inventory.is_empty():
		var item_names: Array = []
		for item_id in inventory:
			var data := WorldState.get_entity_data(item_id)
			item_names.append(data.get("name", item_id))
		inventory_info = "Inventory: " + ", ".join(item_names)

	var perception_text := _format_perception(perception)

	var content := USER_TEMPLATE.format({
		"location": location,
		"inventory_info": inventory_info,
		"perception": perception_text,
		"memory": memory_summary,
	})
	return {"role": "user", "content": content}

static func _format_perception(perception: Dictionary) -> String:
	var lines: Array = []

	var npcs: Array = perception.get("npcs", [])
	if npcs.is_empty():
		lines.append("NPCs: none nearby")
	else:
		for npc_info in npcs:
			var data := WorldState.get_entity_data(npc_info.id)
			var name: String = data.get("name", npc_info.id)
			var state: String = npc_info.get("state", "idle")
			lines.append("NPC: %s (%s) - %.1fm away, %s" % [name, npc_info.id, npc_info.distance, state])

	var items: Array = perception.get("items", [])
	if items.is_empty():
		lines.append("Items: none nearby")
	else:
		for item_info in items:
			lines.append("Item: %s (%s) - %.1fm away" % [item_info.name, item_info.id, item_info.distance])

	var objects: Array = perception.get("objects", [])
	if not objects.is_empty():
		for obj_info in objects:
			lines.append("Object: %s (%s) - %.1fm away" % [obj_info.name, obj_info.id, obj_info.distance])

	var locations: Array = perception.get("locations", [])
	if not locations.is_empty():
		for loc_info in locations:
			lines.append("Location: %s - %.1fm away" % [loc_info.id, loc_info.distance])

	return "\n".join(lines)

static func _get_nearest_location(npc_node: Node3D) -> String:
	var locations := WorldState.get_all_locations()
	var nearest_id := "unknown"
	var nearest_dist := 999.0

	for loc_id in locations:
		var dist: float = npc_node.global_position.distance_to(locations[loc_id])
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = loc_id

	return "%s (%.1fm)" % [nearest_id, nearest_dist]
