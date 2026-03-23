extends RefCounted
## Static quest definitions.

class_name QuestDatabase

const QUESTS: Dictionary = {
	"miners_request": {
		"name": "Miner's Request",
		"description": "Bjorn needs copper ore for his smithing work. Head into the field and mine some copper, then bring it back to him.",
		"giver": "bjorn",
		"objectives": [
			{"type": "gather", "item": "copper_ore", "count": 5, "description": "Gather 5 copper ore"},
			{"type": "deliver", "npc": "bjorn", "item": "copper_ore", "count": 5, "description": "Deliver the ore to Bjorn"},
		],
		"rewards": {
			"gold": 100,
			"items": {"iron_sword": 1},
			"proficiency_xp": {"mining": 50},
			"relationship": {},
		},
		"prerequisite_quests": [],
		"prerequisite_flags": [],
		"repeatable": false,
	},
	"arcane_study": {
		"name": "Arcane Study",
		"description": "Lyra is researching the slimes that have been appearing in the east field. She needs firsthand combat data — go fight some slimes and report back.",
		"giver": "lyra",
		"objectives": [
			{"type": "kill", "monster_type": "slime", "count": 3, "description": "Defeat 3 slimes in the east field"},
			{"type": "talk_to", "npc": "lyra", "description": "Report your findings to Lyra"},
		],
		"rewards": {
			"gold": 80,
			"items": {},
			"proficiency_xp": {"staff": 40},
			"relationship": {},
		},
		"prerequisite_quests": [],
		"prerequisite_flags": [],
		"repeatable": false,
	},
	"field_patrol": {
		"name": "Field Patrol",
		"description": "Kael has spotted wolf tracks near the city gates. Clear out a few wolves from the field and let him know when it's done.",
		"giver": "kael",
		"objectives": [
			{"type": "kill", "monster_type": "wolf", "count": 2, "description": "Defeat 2 wolves"},
			{"type": "talk_to", "npc": "kael", "description": "Return to Kael"},
		],
		"rewards": {
			"gold": 120,
			"items": {},
			"proficiency_xp": {"sword": 30},
			"relationship": {},
		},
		"prerequisite_quests": [],
		"prerequisite_flags": [],
		"repeatable": false,
	},
	"healers_herbs": {
		"name": "Healer's Herbs",
		"description": "Mira is running low on healing supplies and needs cooked fish to treat the injured. Catch some sardines, cook them at the crafting station, and bring them to her.",
		"giver": "mira",
		"objectives": [
			{"type": "gather", "item": "sardine", "count": 3, "description": "Catch 3 sardines"},
			{"type": "craft", "item": "cooked_sardine", "count": 1, "description": "Cook 1 cooked sardine"},
			{"type": "deliver", "npc": "mira", "item": "cooked_sardine", "count": 1, "description": "Deliver the cooked sardine to Mira"},
		],
		"rewards": {
			"gold": 60,
			"items": {"healing_potion": 3},
			"proficiency_xp": {"cooking": 30},
			"relationship": {},
		},
		"prerequisite_quests": [],
		"prerequisite_flags": [],
		"repeatable": false,
	},
}

static func get_quest(quest_id: String) -> Dictionary:
	return QUESTS.get(quest_id, {})

static func has_quest(quest_id: String) -> bool:
	return QUESTS.has(quest_id)

static func get_quests_for_giver(npc_id: String) -> Array:
	var result: Array = []
	for quest_id in QUESTS:
		if QUESTS[quest_id].get("giver", "") == npc_id:
			result.append(quest_id)
	return result

static func get_all_quest_ids() -> Array:
	return QUESTS.keys()
