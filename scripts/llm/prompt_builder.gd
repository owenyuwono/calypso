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
- Don't attack monsters much stronger than you
- At night, the field is more dangerous (monsters are more aggressive)
- If your stamina is low, consider resting at a rest spot (Town Well, Town Inn)
- You can rest to recover stamina"""

const USER_TEMPLATE := """STATS: Level {level}, HP {hp}/{max_hp}, ATK {atk} (effective {eff_atk}), DEF {def} (effective {eff_def})
EQUIPMENT: Weapon: {weapon}, Armor: {armor}
INVENTORY: {inventory_text}
GOLD: {gold}
TIME: {time_display} ({phase})
STAMINA: {stamina_text}

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
	var memory_summary: String = memory_node.get_summary() if memory_node else ""

	var stats = npc_node.get_node_or_null("StatsComponent")
	var inv_comp = npc_node.get_node_or_null("InventoryComponent")
	var equip_comp = npc_node.get_node_or_null("EquipmentComponent")
	var combat_comp = npc_node.get_node_or_null("CombatComponent")

	var level: int = stats.level if stats else 1
	var hp: int = stats.hp if stats else 50
	var max_hp: int = stats.max_hp if stats else 50
	var atk: int = stats.atk if stats else 10
	var def: int = stats.def if stats else 5
	var eff_atk: int = combat_comp.get_effective_atk() if combat_comp else atk
	var eff_def: int = combat_comp.get_effective_def() if combat_comp else def
	var gold: int = inv_comp.gold if inv_comp else 0

	var equipment: Dictionary = equip_comp.get_equipment() if equip_comp else {}
	var weapon_id: String = equipment.get("weapon", "")
	var armor_id: String = equipment.get("armor", "")
	var weapon_name := ItemDatabase.get_item_name(weapon_id) if not weapon_id.is_empty() else "(none)"
	var armor_name := ItemDatabase.get_item_name(armor_id) if not armor_id.is_empty() else "(none)"

	var inv: Dictionary = inv_comp.get_items() if inv_comp else {}
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
		"time_display": TimeManager.get_time_display(),
		"phase": TimeManager.get_phase(),
		"stamina_text": _get_stamina_text(npc_node),
	})
	return {"role": "user", "content": content}

const GOAL_INSTRUCTION := """
IMPORTANT: When the player asks you to do something, you MUST add a goal tag at the end of your reply.
Available goals: hunt_field, buy_potions, sell_loot, buy_weapon, buy_armor, follow_player, return_to_town, patrol, idle, rest
Format: Say your reply, then add [GOAL:goal_name] at the very end.
Examples:
- "follow me" → Sure, I'll follow you! [GOAL:follow_player]
- "go hunt" or "hunt monsters" → Time to hunt! [GOAL:hunt_field]
- "buy potions" → I'll stock up on potions. [GOAL:buy_potions]
- "sell your loot" → Good idea, time to sell. [GOAL:sell_loot]
- "stay here" or "wait" → I'll wait here. [GOAL:idle]
- "go back to town" → Heading back to town. [GOAL:return_to_town]
- "patrol" or "guard" → I'll keep watch. [GOAL:patrol]
- "rest" or "take a break" → I need to rest. [GOAL:rest]
If the player is just chatting and NOT asking you to do something, do NOT add a goal tag."""

const WORLD_FACTS := """WORLD FACTS:
- Places: City (shops, districts, training grounds), Field (slimes, wolves, goblins)
- Shops: Weapon Shop, Item Shop (potions, gear)
- Rest spots: Town Well, Town Inn
- The field is slightly more dangerous at night
- There are NO journals, scrolls, dragons, traps, camps, or magic spells. Do NOT invent things not listed above."""

const CHAT_SYSTEM_TEMPLATE := """You are {npc_name}, an adventurer in a medieval village.
Personality: {personality}
{trait_line}{backstory_line}You are currently {activity}.
{grounding_facts}
Reply in 1 short sentence (under 15 words).
You may reference YOUR FACTS but do NOT recite them directly. Do NOT invent events, items, or scenarios that are not listed.
{voice}
{mood}
Caps, abbreviations, symbols (??, ..., !), and swearing are all allowed.
Stay on topic. Reply to what was said.
{world_facts}
Do NOT use JSON. Just speak naturally as {npc_name}.
Do NOT narrate actions or emotes. No *asterisk actions*. Only output spoken words.
{goal_instruction}"""

const CHAT_USER_TEMPLATE := """You are level {level} with {hp}/{max_hp} HP and {gold} gold.
TIME: {time_display} ({phase}). STAMINA: {stamina_text}.
{key_memories}
{context}
{relationship_line}{speaker_name} says to you: "{spoken_text}"

Respond as {npc_name}:"""

const CHAT_INITIATE_SYSTEM_TEMPLATE := """You are {npc_name}, an adventurer in a medieval village.
Personality: {personality}
{trait_line}{backstory_line}You are currently {activity}.
{grounding_facts}
You see {target_name} nearby. {intent_cue} {topic}.

Say 1 short sentence (under 15 words).
You may reference YOUR FACTS but do NOT recite them directly. Do NOT invent events, items, or scenarios that are not listed.
{voice}
{mood}
Caps, abbreviations, symbols (??, ..., !), and swearing are all allowed.
{world_facts}
Do NOT use JSON. Just speak naturally as {npc_name}.
Do NOT narrate actions or emotes. No *asterisk actions*. Only output spoken words.
{goal_instruction}"""

const CHAT_INITIATE_USER_TEMPLATE := """You are level {level} with {hp}/{max_hp} HP and {gold} gold.
TIME: {time_display} ({phase}). STAMINA: {stamina_text}.
{key_memories}
{context}
{relationship_line}You see {target_name}, who is {target_activity}.

Say something to {target_name} as {npc_name}:"""

static func build_chat_initiate_system_message(npc_name: String, personality: String, activity: String, target_name: String, topic: String = "", trait_summary: String = "", intent_cue: String = "", backstory: String = "", voice_style: String = "", mood: String = "", grounding_facts: String = "") -> Dictionary:
	var effective_topic := topic if not topic.is_empty() else "whatever comes to mind"
	var effective_cue := intent_cue if not intent_cue.is_empty() else "Chat with %s about" % target_name
	var trait_line := "Traits: %s\n" % trait_summary if not trait_summary.is_empty() else ""
	var backstory_line := "Background: %s\n" % backstory if not backstory.is_empty() else ""
	var effective_voice := ("Your vibe: " + voice_style) if not voice_style.is_empty() else "Talk like a real MMO player. Casual and brief."
	var effective_mood := ("Current mood: " + mood) if not mood.is_empty() else ""
	var content := CHAT_INITIATE_SYSTEM_TEMPLATE.format({
		"npc_name": npc_name,
		"personality": personality,
		"trait_line": trait_line,
		"backstory_line": backstory_line,
		"activity": activity,
		"target_name": target_name,
		"intent_cue": effective_cue,
		"topic": effective_topic,
		"voice": effective_voice,
		"mood": effective_mood,
		"world_facts": WORLD_FACTS,
		"grounding_facts": grounding_facts,
		"goal_instruction": "",
	})
	return {"role": "system", "content": content}

static func build_chat_initiate_user_message(npc_name: String, npc_id: String, target_name: String, target_id: String, target_activity: String, memory_node: Node, relationship_label: String = "") -> Dictionary:
	var npc_node = WorldState.get_entity(npc_id)
	var level: int = 1
	var hp: int = 50
	var max_hp: int = 50
	var gold: int = 0
	if npc_node and is_instance_valid(npc_node):
		var stats = npc_node.get_node_or_null("StatsComponent")
		var inv = npc_node.get_node_or_null("InventoryComponent")
		if stats:
			level = stats.level
			hp = stats.hp
			max_hp = stats.max_hp
		if inv:
			gold = inv.gold

	var context := ""
	if memory_node and memory_node.has_method("get_area_chat_context"):
		context = memory_node.get_area_chat_context(5)

	var relationship_line := "Your relationship with %s: %s\n" % [target_name, relationship_label] if not relationship_label.is_empty() else ""

	var key_memories := ""
	if memory_node and memory_node.has_method("get_key_memories_summary"):
		key_memories = memory_node.get_key_memories_summary(2)

	var content := CHAT_INITIATE_USER_TEMPLATE.format({
		"npc_name": npc_name,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"key_memories": key_memories,
		"context": context,
		"relationship_line": relationship_line,
		"target_name": target_name,
		"target_activity": target_activity,
		"time_display": TimeManager.get_time_display(),
		"phase": TimeManager.get_phase(),
		"stamina_text": _get_stamina_text(npc_node) if npc_node else "N/A",
	})
	return {"role": "user", "content": content}

static func build_chat_system_message(npc_name: String, personality: String, activity: String, player_speaking: bool = false, trait_summary: String = "", backstory: String = "", voice_style: String = "", mood: String = "", grounding_facts: String = "") -> Dictionary:
	var trait_line := "Traits: %s\n" % trait_summary if not trait_summary.is_empty() else ""
	var backstory_line := "Background: %s\n" % backstory if not backstory.is_empty() else ""
	var effective_voice := ("Your vibe: " + voice_style) if not voice_style.is_empty() else "Talk like a real MMO player. Casual and brief."
	var effective_mood := ("Current mood: " + mood) if not mood.is_empty() else ""
	var content := CHAT_SYSTEM_TEMPLATE.format({
		"npc_name": npc_name,
		"personality": personality,
		"trait_line": trait_line,
		"backstory_line": backstory_line,
		"activity": activity,
		"voice": effective_voice,
		"mood": effective_mood,
		"world_facts": WORLD_FACTS,
		"grounding_facts": grounding_facts,
		"goal_instruction": GOAL_INSTRUCTION if player_speaking else "",
	})
	return {"role": "system", "content": content}

static func build_chat_user_message(npc_name: String, npc_id: String, speaker_name: String, spoken_text: String, memory_node: Node, relationship_label: String = "") -> Dictionary:
	var npc_node = WorldState.get_entity(npc_id)
	var level: int = 1
	var hp: int = 50
	var max_hp: int = 50
	var gold: int = 0
	if npc_node and is_instance_valid(npc_node):
		var stats = npc_node.get_node_or_null("StatsComponent")
		var inv = npc_node.get_node_or_null("InventoryComponent")
		if stats:
			level = stats.level
			hp = stats.hp
			max_hp = stats.max_hp
		if inv:
			gold = inv.gold

	# Build conversation context from area chat log
	var context := ""
	if memory_node and memory_node.has_method("get_area_chat_context"):
		context = memory_node.get_area_chat_context(5)

	var relationship_line := "Your relationship with %s: %s\n" % [speaker_name, relationship_label] if not relationship_label.is_empty() else ""

	var key_memories := ""
	if memory_node and memory_node.has_method("get_key_memories_summary"):
		key_memories = memory_node.get_key_memories_summary(2)

	var content := CHAT_USER_TEMPLATE.format({
		"npc_name": npc_name,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"key_memories": key_memories,
		"context": context,
		"relationship_line": relationship_line,
		"speaker_name": speaker_name,
		"spoken_text": spoken_text,
		"time_display": TimeManager.get_time_display(),
		"phase": TimeManager.get_phase(),
		"stamina_text": _get_stamina_text(npc_node) if npc_node else "N/A",
	})
	return {"role": "user", "content": content}

static func get_activity_description(goal: String) -> String:
	match goal:
		"hunt_field":
			return "hunting monsters in the field"
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
			return "patrolling the city"
		"rest":
			return "resting to recover stamina"
		"idle":
			return "resting in the city"
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

static func _get_stamina_text(npc_node: Node) -> String:
	var comp = npc_node.get_node_or_null("StaminaComponent")
	if not comp:
		return "N/A"
	return "%d/%d" % [int(comp.get_stamina()), int(comp.get_max_stamina())]
