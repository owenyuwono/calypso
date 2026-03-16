extends RefCounted
## Builds LLM prompts for adventurer NPCs — combat, economy, and social awareness.
## Uses compact formats to reduce token usage (~50% reduction for 50-100 NPC throughput).

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
- buy_item: Buy from a vendor. Target = vendor_id. Set action_data: {"item_id": "...", "count": 1}
- sell_item: Sell to a vendor. Target = vendor_id. Set action_data: {"item_id": "...", "count": 1}
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

const USER_TEMPLATE := """{stats}
{equipment}
{inventory}
{time}
{stamina}

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

static func build_user_message(npc_id: String, npc_node: Node3D, memory_node: Node, perception: Dictionary) -> Dictionary:
	var memory_summary: String = memory_node.get_summary() if memory_node else ""

	var stats = npc_node.get_node_or_null("StatsComponent")
	var inv_comp = npc_node.get_node_or_null("InventoryComponent")
	var equip_comp = npc_node.get_node_or_null("EquipmentComponent")
	var combat_comp = npc_node.get_node_or_null("CombatComponent")

	var level: int = stats.level if stats else 1
	var hp: int = stats.hp if stats else 50
	var max_hp: int = stats.max_hp if stats else 50
	var atk: int = stats.atk if stats else 10
	var def_val: int = stats.def if stats else 5
	var eff_atk: int = combat_comp.get_effective_atk() if combat_comp else atk
	var eff_def: int = combat_comp.get_effective_def() if combat_comp else def_val
	var gold: int = inv_comp.gold if inv_comp else 0

	var equipment: Dictionary = equip_comp.get_equipment() if equip_comp else {}
	var weapon_id: String = equipment.get("weapon", "")
	var armor_id: String = equipment.get("armor", "")

	var inv: Dictionary = inv_comp.get_items() if inv_comp else {}

	var perception_text := _format_perception(perception)

	var atk_bonus: int = eff_atk - atk
	var def_bonus: int = eff_def - def_val

	var content := USER_TEMPLATE.format({
		"stats": "lv%d hp:%d/%d atk:%d+%d def:%d+%d gold:%d" % [level, hp, max_hp, atk, atk_bonus, def_val, def_bonus, gold],
		"equipment": _format_equipment_compact(weapon_id, armor_id),
		"inventory": _format_inventory_compact(inv),
		"time": _format_time_compact(),
		"stamina": _format_stamina_compact(npc_node),
		"perception": perception_text,
		"memory": memory_summary,
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
No modern language, concepts, or technology. This is a medieval fantasy world.
Only reference items and equipment you actually have. Do not invent weapons or items.
{world_facts}
Do NOT use JSON. Just speak naturally as {npc_name}.
Do NOT narrate actions or emotes. No *asterisk actions*. Only output spoken words.
{goal_instruction}"""

const CHAT_USER_TEMPLATE := """lv{level} hp:{hp}/{max_hp} gold:{gold} | equip:{equipment} | inv:{inventory}
time:{time_display}({phase}) stamina:{stamina_text}
{key_memories}
{context}
{relationship_line}{speaker_line}

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
No modern language, concepts, or technology. This is a medieval fantasy world.
{world_facts}
Do NOT use JSON. Just speak naturally as {npc_name}.
Do NOT narrate actions or emotes. No *asterisk actions*. Only output spoken words.
{goal_instruction}"""

const CHAT_INITIATE_USER_TEMPLATE := """lv{level} hp:{hp}/{max_hp} gold:{gold}
time:{time_display}({phase}) stamina:{stamina_text}
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

	var relationship_line := "rel:%s=%s\n" % [target_name, relationship_label] if not relationship_label.is_empty() else ""

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

static func build_chat_user_message(npc_name: String, npc_id: String, speaker_name: String, spoken_text: String, memory_node: Node, relationship_label: String = "", overheard: bool = false, original_target_name: String = "") -> Dictionary:
	var npc_node = WorldState.get_entity(npc_id)
	var level: int = 1
	var hp: int = 50
	var max_hp: int = 50
	var gold: int = 0
	var equipment_text := "none"
	var inventory_text := "empty"
	if npc_node and is_instance_valid(npc_node):
		var stats = npc_node.get_node_or_null("StatsComponent")
		var inv_comp = npc_node.get_node_or_null("InventoryComponent")
		var equip_comp = npc_node.get_node_or_null("EquipmentComponent")
		if stats:
			level = stats.level
			hp = stats.hp
			max_hp = stats.max_hp
		if inv_comp:
			gold = inv_comp.gold
			var inv: Dictionary = inv_comp.get_items()
			inventory_text = _format_inventory_compact(inv)
		if equip_comp:
			var equipment: Dictionary = equip_comp.get_equipment()
			var weapon_id: String = equipment.get("weapon", "")
			var armor_id: String = equipment.get("armor", "")
			equipment_text = _format_equipment_compact(weapon_id, armor_id)

	# Build conversation context from area chat log
	var context := ""
	if memory_node and memory_node.has_method("get_area_chat_context"):
		context = memory_node.get_area_chat_context(5)

	var relationship_line := "rel:%s=%s\n" % [speaker_name, relationship_label] if not relationship_label.is_empty() else ""

	var key_memories := ""
	if memory_node and memory_node.has_method("get_key_memories_summary"):
		key_memories = memory_node.get_key_memories_summary(2)

	var speaker_line: String
	if overheard and not original_target_name.is_empty():
		speaker_line = "You overhear %s say to %s: \"%s\"\nYou were NOT addressed directly. Only respond if you have something relevant to add." % [speaker_name, original_target_name, spoken_text]
	else:
		speaker_line = "%s says to you: \"%s\"" % [speaker_name, spoken_text]

	var content := CHAT_USER_TEMPLATE.format({
		"npc_name": npc_name,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"equipment": equipment_text,
		"inventory": inventory_text,
		"key_memories": key_memories,
		"context": context,
		"relationship_line": relationship_line,
		"speaker_line": speaker_line,
		"time_display": TimeManager.get_time_display(),
		"phase": TimeManager.get_phase(),
		"stamina_text": _get_stamina_text(npc_node) if npc_node else "N/A",
	})
	return {"role": "user", "content": content}

const WORLD_BLOCK: String = "You are an NPC in Arcadia, a medieval fantasy world. The town has shops, a tavern, and surrounding fields with monsters. Technology is medieval — no modern concepts. Magic exists but is rare."


static func build_conversation_system_message(npc_node: Node, partner_ids: Array) -> String:
	# Block 1: World
	var blocks: Array = [WORLD_BLOCK]

	var identity: Node = npc_node.get_node_or_null("NpcIdentity")
	var rel_comp: Node = npc_node.get_node_or_null("RelationshipComponent")

	# Block 2: Character
	if identity:
		var char_parts: Array = []
		char_parts.append(identity.get_personality_prompt())
		var mood_text: String = identity.get_mood_prompt()
		if not mood_text.is_empty():
			char_parts.append(mood_text)
		var tendency_text: String = identity.get_tendency_prompt()
		if not tendency_text.is_empty():
			char_parts.append(tendency_text)
		var desires_text: String = identity.get_desires_prompt()
		if not desires_text.is_empty():
			char_parts.append("Desires:\n" + desires_text)

		# Secrets gated by the most restrictive tier across all partners
		var min_tier: String = "bonded"
		if rel_comp and not partner_ids.is_empty():
			for pid in partner_ids:
				var t: String = rel_comp.get_tier(pid)
				if RelationshipComponent.TIER_LADDER.find(t) < RelationshipComponent.TIER_LADDER.find(min_tier):
					min_tier = t
		else:
			min_tier = "stranger"
		var secrets: Array = identity.get_secrets_for_tier(min_tier)
		if not secrets.is_empty():
			var secret_lines: Array = []
			for s in secrets:
				secret_lines.append("- " + str(s))
			char_parts.append("Secrets (do not reveal unless pressed):\n" + "\n".join(secret_lines))

		blocks.append("\n".join(char_parts))

	# Block 3: Context — relationships and opinions
	if rel_comp and not partner_ids.is_empty():
		var context_parts: Array = []
		for partner_id in partner_ids:
			var tier: String = rel_comp.get_tier(partner_id)
			var impression: String = rel_comp.get_impression(partner_id)
			var tension: float = rel_comp.get_tension(partner_id)
			var partner_node = WorldState.get_entity(partner_id)
			var partner_name: String = partner_node.npc_name if partner_node and "npc_name" in partner_node else partner_id
			context_parts.append("%s — tier: %s, impression: %s, tension: %.1f" % [partner_name, tier, impression, tension])

			# Include opinions gated by tier
			if identity:
				var ops: Array = identity.get_opinions_for("", tier)
				for op in ops:
					var opinion_text: String = op.get("take", "")
					var op_topic: String = op.get("topic", "")
					if not opinion_text.is_empty():
						context_parts.append("Opinion on %s: %s" % [op_topic, opinion_text])

		blocks.append("Relationships:\n" + "\n".join(context_parts))

	# Instruction
	var npc_name: String = ""
	if identity:
		npc_name = identity.npc_name
	elif "npc_name" in npc_node:
		npc_name = npc_node.npc_name
	blocks.append("Respond with 1-2 sentences as %s. You may also: stay silent [SILENCE], change topic [TOPIC:new topic], or leave [LEAVE]. Stay in character. No narration. No modern language. Only reference known memories. Can exaggerate, withhold, or lie per tendencies." % npc_name)

	return "\n\n".join(blocks)


static func build_conversation_user_message(npc_node: Node, conversation: ConversationState) -> String:
	var parts: Array = []

	# Conversation history
	if not conversation.turns.is_empty():
		var history_lines: Array = []
		for turn: Dictionary in conversation.turns:
			var speaker_id: String = turn.get("speaker_id", "")
			var action: String = turn.get("action", ConversationState.ACTION_SPEAK)
			var text: String = turn.get("text", "")

			var speaker_node = WorldState.get_entity(speaker_id)
			var speaker_name: String = speaker_node.npc_name if speaker_node and "npc_name" in speaker_node else speaker_id

			match action:
				ConversationState.ACTION_SILENCE:
					history_lines.append("%s: [silence]" % speaker_name)
				ConversationState.ACTION_WALK_AWAY:
					history_lines.append("%s: [left]" % speaker_name)
				ConversationState.ACTION_TOPIC_CHANGE:
					var new_topic: String = turn.get("topic", "")
					if not new_topic.is_empty():
						history_lines.append("%s: [changed topic to: %s]" % [speaker_name, new_topic])
					else:
						history_lines.append("%s: [changed topic]" % speaker_name)
				ConversationState.ACTION_JOIN:
					history_lines.append("%s: [joined conversation]" % speaker_name)
				_:
					# speak or unknown — show text
					if not text.is_empty():
						history_lines.append("%s: %s" % [speaker_name, text])
		parts.append("Conversation so far:\n" + "\n".join(history_lines))

	# Recent memories
	var memory_node: Node = npc_node.get_node_or_null("NPCMemory")
	if memory_node:
		var mem_text: String = memory_node.get_memories_for_prompt(5)
		if not mem_text.is_empty():
			parts.append("Recent memories:\n" + mem_text)

	# Current opinions on conversation topic
	var identity: Node = npc_node.get_node_or_null("NpcIdentity")
	var rel_comp: Node = npc_node.get_node_or_null("RelationshipComponent")
	if identity and not conversation.topic.is_empty():
		var tier: String = "stranger"
		if rel_comp and not conversation.participant_ids.is_empty():
			for pid in conversation.participant_ids:
				if pid != npc_node.get("entity_id"):
					tier = rel_comp.get_tier(pid)
					break
		var topic_opinions: Array = identity.get_opinions_for(conversation.topic, tier)
		if not topic_opinions.is_empty():
			var op_lines: Array = []
			for op in topic_opinions:
				var op_text: String = op.get("take", "")
				if not op_text.is_empty():
					op_lines.append("- " + op_text)
			if not op_lines.is_empty():
				parts.append("Your opinions on \"%s\":\n" % conversation.topic + "\n".join(op_lines))

	return "\n\n".join(parts)


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
		"vend":
			return "running a shop"
		"buy_from_vendor":
			return "shopping at a vendor"
		_:
			return "exploring the area"

static func _format_perception(perception: Dictionary) -> String:
	var lines: Array = []

	# Monsters — compact: Name(type,hp:status,Xm)
	var monsters: Array = perception.get("monsters", [])
	if not monsters.is_empty():
		for m in monsters:
			var hp_status := _hp_status(m.hp, m.max_hp)
			var dist: int = int(round(m.distance))
			lines.append("%s(%s,hp:%s,%dm)" % [m.name, m.id, hp_status, dist])
	else:
		lines.append("monsters:none")

	# NPCs / Players — compact: Name(class,hp:status,activity,Xm)
	var npcs: Array = perception.get("npcs", [])
	if not npcs.is_empty():
		for n in npcs:
			var hp_status := _hp_status(n.get("hp", 0), n.get("max_hp", 1))
			var activity := _state_to_activity(n.get("state", "idle"))
			var dist: int = int(round(n.distance))
			lines.append("%s(adventurer,hp:%s,%s,%dm)" % [n.name, hp_status, activity, dist])
	else:
		lines.append("adventurers:none")

	# Vendors — compact: Name(vendor,shop_title,Xm)
	var vendors: Array = perception.get("vendors", [])
	for v in vendors:
		var title: String = v.get("shop_title", "")
		var dist: int = int(round(v.distance))
		if not title.is_empty():
			lines.append("%s(vendor,%s,%dm)" % [v.name, title, dist])
		else:
			lines.append("%s(vendor,%dm)" % [v.name, dist])

	# Locations — compact: loc_id(Xm)
	var locations: Array = perception.get("locations", [])
	if not locations.is_empty():
		var loc_parts: Array = []
		for loc in locations:
			var dist: int = int(round(loc.distance))
			loc_parts.append("%s(%dm)" % [loc.id, dist])
		lines.append("locs:" + ",".join(loc_parts))

	return "\n".join(lines)

## Returns a compact HP status label from current and max HP values.
static func _hp_status(hp: int, max_hp: int) -> String:
	if max_hp <= 0:
		return "unknown"
	var pct: float = float(hp) / float(max_hp)
	if pct >= 0.95:
		return "full"
	elif pct >= 0.65:
		return "high"
	elif pct >= 0.35:
		return "mid"
	elif pct >= 0.15:
		return "low"
	else:
		return "critical"

## Maps NPC state string to compact activity label.
static func _state_to_activity(state: String) -> String:
	match state:
		"combat":
			return "fighting"
		"moving":
			return "moving"
		"thinking":
			return "idle"
		"dead":
			return "dead"
		"vend", "vending":
			return "vending"
		_:
			return "idle"

## Returns compact equipment string: equip:weapon_id,armor_id
static func _format_equipment_compact(weapon_id: String, armor_id: String) -> String:
	var parts: Array = []
	if not weapon_id.is_empty():
		parts.append(weapon_id)
	if not armor_id.is_empty():
		parts.append(armor_id)
	if parts.is_empty():
		return "equip:none"
	return "equip:" + ",".join(parts)

## Returns compact inventory string: inv:item_id*count,...
static func _format_inventory_compact(inv: Dictionary) -> String:
	if inv.is_empty():
		return "inv:empty"
	var parts: Array = []
	for item_id in inv:
		var count: int = inv[item_id]
		parts.append("%s*%d" % [item_id, count])
	return "inv:" + ",".join(parts)

## Returns compact time string: time:14h(day)
static func _format_time_compact() -> String:
	return "time:%s(%s)" % [TimeManager.get_time_display(), TimeManager.get_phase()]

## Returns compact stamina string: stamina:80/100
static func _format_stamina_compact(npc_node: Node) -> String:
	return "stamina:" + _get_stamina_text(npc_node)

static func _get_stamina_text(npc_node: Node) -> String:
	var comp = npc_node.get_node_or_null("StaminaComponent")
	if not comp:
		return "N/A"
	return "%d/%d" % [int(comp.get_stamina()), int(comp.get_max_stamina())]
