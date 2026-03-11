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

const GOAL_INSTRUCTION := """
IMPORTANT: When the player asks you to do something, you MUST add a goal tag at the end of your reply.
Available goals: hunt_field, hunt_dungeon, buy_potions, sell_loot, buy_weapon, buy_armor, follow_player, return_to_town, patrol, idle
Format: Say your reply, then add [GOAL:goal_name] at the very end.
Examples:
- "follow me" → Sure, I'll follow you! [GOAL:follow_player]
- "go hunt" or "hunt monsters" → Time to hunt! [GOAL:hunt_field]
- "go to the dungeon" → Heading to the dungeon! [GOAL:hunt_dungeon]
- "buy potions" → I'll stock up on potions. [GOAL:buy_potions]
- "sell your loot" → Good idea, time to sell. [GOAL:sell_loot]
- "stay here" or "wait" → I'll wait here. [GOAL:idle]
- "go back to town" → Heading back to town. [GOAL:return_to_town]
- "patrol" or "guard" → I'll keep watch. [GOAL:patrol]
If the player is just chatting and NOT asking you to do something, do NOT add a goal tag."""

const CHAT_SYSTEM_TEMPLATE := """You are {npc_name}, an adventurer in a medieval village.
Personality: {personality}
You are currently {activity}.

Respond in character with ONE short sentence (under 10 words).
Do NOT use JSON. Just speak naturally as {npc_name}.
Do NOT narrate actions or emotes. No *asterisk actions*. Only output spoken words.
{goal_instruction}"""

const CHAT_USER_TEMPLATE := """You are level {level} with {hp}/{max_hp} HP and {gold} gold.
{context}
{speaker_name} says to you: "{spoken_text}"

Respond as {npc_name}:"""

const CHAT_INITIATE_SYSTEM_TEMPLATE := """You are {npc_name}, an adventurer in a medieval village.
Personality: {personality}
You are currently {activity}.

You see {target_name} nearby and want to chat briefly.
Talk to {target_name} about {topic}.

Say ONE short sentence (under 10 words) to start a conversation.
Do NOT use JSON. Just speak naturally as {npc_name}.
Do NOT narrate actions or emotes. No *asterisk actions*. Only output spoken words.
{goal_instruction}"""

const CHAT_INITIATE_USER_TEMPLATE := """You are level {level} with {hp}/{max_hp} HP and {gold} gold.
{context}
You see {target_name}, who is {target_activity}.

Say something to {target_name} as {npc_name}:"""

static func build_chat_initiate_system_message(npc_name: String, personality: String, activity: String, target_name: String, topic: String = "") -> Dictionary:
	var effective_topic := topic if not topic.is_empty() else "whatever comes to mind"
	var content := CHAT_INITIATE_SYSTEM_TEMPLATE.format({
		"npc_name": npc_name,
		"personality": personality,
		"activity": activity,
		"target_name": target_name,
		"topic": effective_topic,
		"goal_instruction": "",
	})
	return {"role": "system", "content": content}

static func build_chat_initiate_user_message(npc_name: String, npc_id: String, target_name: String, target_id: String, target_activity: String, memory_node: Node) -> Dictionary:
	var data := WorldState.get_entity_data(npc_id)
	var level: int = data.get("level", 1)
	var hp: int = data.get("hp", 50)
	var max_hp: int = data.get("max_hp", 50)
	var gold: int = data.get("gold", 0)

	var context := ""
	if memory_node:
		var history: Array = memory_node.get_conversation_with(target_id)
		if not history.is_empty():
			var recent := history.slice(maxi(0, history.size() - 3))
			var lines: Array = []
			for entry in recent:
				lines.append("%s: %s" % [entry["speaker"], entry["text"]])
			context = "Recent conversation:\n" + "\n".join(lines)

	var content := CHAT_INITIATE_USER_TEMPLATE.format({
		"npc_name": npc_name,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"context": context,
		"target_name": target_name,
		"target_activity": target_activity,
	})
	return {"role": "user", "content": content}

static func build_chat_system_message(npc_name: String, personality: String, activity: String, player_speaking: bool = false) -> Dictionary:
	var content := CHAT_SYSTEM_TEMPLATE.format({
		"npc_name": npc_name,
		"personality": personality,
		"activity": activity,
		"goal_instruction": GOAL_INSTRUCTION if player_speaking else "",
	})
	return {"role": "system", "content": content}

static func build_chat_user_message(npc_name: String, npc_id: String, speaker_name: String, spoken_text: String, memory_node: Node) -> Dictionary:
	var data := WorldState.get_entity_data(npc_id)
	var level: int = data.get("level", 1)
	var hp: int = data.get("hp", 50)
	var max_hp: int = data.get("max_hp", 50)
	var gold: int = data.get("gold", 0)

	# Build conversation context from last 3 entries
	var context := ""
	if memory_node:
		var speaker_id := "player" if speaker_name == "Player" else speaker_name.to_lower()
		var history: Array = memory_node.get_conversation_with(speaker_id)
		if not history.is_empty():
			var recent := history.slice(maxi(0, history.size() - 3))
			var lines: Array = []
			for entry in recent:
				lines.append("%s: %s" % [entry["speaker"], entry["text"]])
			context = "Recent conversation:\n" + "\n".join(lines)

	var content := CHAT_USER_TEMPLATE.format({
		"npc_name": npc_name,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"context": context,
		"speaker_name": speaker_name,
		"spoken_text": spoken_text,
	})
	return {"role": "user", "content": content}

static func get_activity_description(goal: String) -> String:
	match goal:
		"hunt_field":
			return "hunting monsters in the field"
		"hunt_dungeon":
			return "hunting monsters in the dungeon"
		"buy_potions":
			return "buying potions in town"
		"sell_loot":
			return "selling loot in town"
		"buy_weapon":
			return "shopping for a weapon upgrade"
		"buy_armor":
			return "shopping for armor"
		"follow_player":
			return "following the player"
		"return_to_town":
			return "retreating to town"
		"patrol":
			return "patrolling the town"
		"idle":
			return "resting in town"
		_:
			return "exploring the area"

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
