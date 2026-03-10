extends RefCounted
## Builds LLM prompts for adventurer NPCs — combat, economy, and social awareness.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

const SYSTEM_TEMPLATE := """You are {npc_name}, an adventurer in a medieval village.

PERSONALITY: {personality}

CURRENT GOAL: {goal}

You explore, fight monsters, buy supplies, and interact with other adventurers.
Make decisions like a real player would in an MMO.

Available actions:
- move_to: Move to a location or entity. Target = location_id or entity_id.
- attack: Attack a monster. Target = monster entity_id. You will approach and auto-attack.
- use_item: Use an item from inventory. Target = item_type_id (e.g. "healing_potion").
- buy_item: Buy from a shop. Target = shop_npc_id. Set action_data: {"item_id": "...", "count": 1}
- sell_item: Sell to a shop. Target = shop_npc_id. Set action_data: {"item_id": "...", "count": 1}
- talk_to: Talk to another adventurer or the player. Target = entity_id. Include dialogue.
- wait: Do nothing for a moment. Rest and observe.

RULES:
- Stay in character as {npc_name}
- Choose actions that make sense for your situation and goals
- When talking, keep dialogue to ONE short sentence (under 15 words)
- If your HP is low, consider using a healing potion or retreating to town
- If you have monster drops, consider selling them at a shop
- If you can afford better equipment, consider buying upgrades
- Update your goal when circumstances change
- Don't attack monsters much stronger than you"""

const USER_TEMPLATE := """STATS: Level {level}, HP {hp}/{max_hp}, ATK {atk} (effective {eff_atk}), DEF {def} (effective {eff_def})
EQUIPMENT: Weapon: {weapon}, Armor: {armor}
INVENTORY: {inventory_text}
GOLD: {gold}

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
	var data := WorldState.get_entity_data(npc_id)
	var perception := WorldState.get_npc_perception(npc_id)
	var memory_summary: String = memory_node.get_summary() if memory_node else ""

	# Stats
	var level: int = data.get("level", 1)
	var hp: int = data.get("hp", 50)
	var max_hp: int = data.get("max_hp", 50)
	var atk: int = data.get("atk", 10)
	var def: int = data.get("def", 5)
	var eff_atk: int = WorldState.get_effective_atk(npc_id)
	var eff_def: int = WorldState.get_effective_def(npc_id)
	var gold: int = data.get("gold", 0)

	# Equipment
	var equipment: Dictionary = data.get("equipment", {})
	var weapon_id: String = equipment.get("weapon", "")
	var armor_id: String = equipment.get("armor", "")
	var weapon_name := ItemDatabase.get_item_name(weapon_id) if not weapon_id.is_empty() else "(none)"
	var armor_name := ItemDatabase.get_item_name(armor_id) if not armor_id.is_empty() else "(none)"

	# Inventory
	var inv: Dictionary = WorldState.get_inventory(npc_id)
	var inventory_text := "(empty)"
	if not inv.is_empty():
		var parts: Array = []
		for item_id in inv:
			var count: int = inv[item_id]
			var item_name := ItemDatabase.get_item_name(item_id)
			parts.append("%s x%d" % [item_name, count])
		inventory_text = ", ".join(parts)

	var perception_text := _format_perception(perception)

	var content := USER_TEMPLATE.format({
		"level": level, "hp": hp, "max_hp": max_hp,
		"atk": atk, "def": def, "eff_atk": eff_atk, "eff_def": eff_def,
		"weapon": weapon_name, "armor": armor_name,
		"inventory_text": inventory_text, "gold": gold,
		"perception": perception_text,
		"memory": memory_summary,
	})
	return {"role": "user", "content": content}

static func _format_perception(perception: Dictionary) -> String:
	var lines: Array = []

	# Monsters
	var monsters: Array = perception.get("monsters", [])
	if not monsters.is_empty():
		for m in monsters:
			lines.append("Monster: %s (%s) - HP %d/%d, %.1fm away" % [m.name, m.id, m.hp, m.max_hp, m.distance])
	else:
		lines.append("Monsters: none nearby")

	# NPCs / Players
	var npcs: Array = perception.get("npcs", [])
	if not npcs.is_empty():
		for n in npcs:
			var state_info: String = n.get("state", "idle")
			lines.append("Adventurer: %s (%s) - Lv.%d, HP %d/%d, %.1fm away, %s" % [
				n.name, n.id, n.get("level", 1), n.get("hp", 0), n.get("max_hp", 0), n.distance, state_info])
	else:
		lines.append("Adventurers: none nearby")

	# Shop NPCs
	var shops: Array = perception.get("shop_npcs", [])
	for s in shops:
		lines.append("Shop: %s (%s) - %.1fm away [%s]" % [s.name, s.id, s.distance, s.get("shop_type", "")])

	# Locations
	var locations: Array = perception.get("locations", [])
	if not locations.is_empty():
		for loc in locations:
			lines.append("Location: %s - %.1fm away" % [loc.id, loc.distance])

	return "\n".join(lines)
