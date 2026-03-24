extends RefCounted
class_name NpcIdentityDatabase
## Unified identity profiles for all NPCs.
## Identity fields are defined here. Starting loadout (items, gold, goal, equip) and traits are
## composed at runtime from NpcLoadouts and NpcTraits in get_identity().

const NpcLoadouts = preload("res://scripts/data/npc_loadouts.gd")
const NpcTraits = preload("res://scripts/data/npc_traits.gd")

const IDENTITIES: Dictionary = {
	"kael": {
		"name": "Kael",
		"age": "young",
		"occupation": "adventurer",
		"baseline_emotion": "excited",
		"baseline_energy": "energetic",
		"schedule_type": "goal",
		"routine": [],
		"periodic_pattern": [],
		"shop_type": "",
		"shop_items": [],
	},

	"lyra": {
		"name": "Lyra",
		"age": "adult",
		"occupation": "mage",
		"baseline_emotion": "content",
		"baseline_energy": "normal",
		"schedule_type": "goal",
		"routine": [],
		"periodic_pattern": [],
		"shop_type": "",
		"shop_items": [],
	},

	"bjorn": {
		"name": "Bjorn",
		"age": "adult",
		"occupation": "warrior",
		"baseline_emotion": "excited",
		"baseline_energy": "energetic",
		"schedule_type": "goal",
		"routine": [],
		"periodic_pattern": [],
		"shop_type": "",
		"shop_items": [],
	},

	"sera": {
		"name": "Sera",
		"age": "young",
		"occupation": "rogue",
		"baseline_emotion": "content",
		"baseline_energy": "normal",
		"schedule_type": "goal",
		"routine": [],
		"periodic_pattern": [],
		"shop_type": "",
		"shop_items": [],
	},

	"thane": {
		"name": "Thane",
		"age": "adult",
		"occupation": "knight",
		"baseline_emotion": "content",
		"baseline_energy": "normal",
		"schedule_type": "goal",
		"routine": [],
		"periodic_pattern": [],
		"shop_type": "",
		"shop_items": [],
	},

	"mira": {
		"name": "Mira",
		"age": "young",
		"occupation": "scholar",
		"baseline_emotion": "excited",
		"baseline_energy": "energetic",
		"schedule_type": "goal",
		"routine": [],
		"periodic_pattern": [],
		"shop_type": "",
		"shop_items": [],
	},

	"dusk": {
		"name": "Dusk",
		"age": "adult",
		"occupation": "rogue",
		"baseline_emotion": "content",
		"baseline_energy": "normal",
		"schedule_type": "goal",
		"routine": [],
		"periodic_pattern": [],
		"shop_type": "",
		"shop_items": [],
	},

	"weapon_shop_npc": {
		"name": "Garret",
		"age": "adult",
		"occupation": "blacksmith",
		"traits": {"boldness": 0.5, "sociability": 0.6, "generosity": 0.4, "curiosity": 0.2},
		"baseline_emotion": "content",
		"baseline_energy": "normal",
		"schedule_type": "routine",
		"routine": [
			{"start_hour": 6, "end_hour": 20, "goal": "tend_shop", "location": "weapon_shop"},
			{"start_hour": 20, "end_hour": 6, "goal": "rest", "location": "weapon_shop"},
		],
		"periodic_pattern": [],
		"starting_items": {},
		"starting_gold": 500,
		"starting_goal": "tend_shop",
		"starting_equip": {},
		"shop_type": "weapon",
		"shop_items": [
			"basic_sword", "iron_sword", "steel_sword", "mithril_sword", "dragon_sword",
			"basic_axe", "iron_axe", "steel_axe", "mithril_axe", "dragon_axe",
			"basic_mace", "iron_mace", "steel_mace", "mithril_mace", "dragon_mace",
			"basic_dagger", "iron_dagger", "steel_dagger", "mithril_dagger", "dragon_dagger",
			"basic_staff", "iron_staff", "steel_staff", "mithril_staff", "dragon_staff",
			"basic_shield", "iron_shield", "steel_shield", "mithril_shield", "dragon_shield",
		],
	},

	"item_shop_npc": {
		"name": "Vela",
		"age": "adult",
		"occupation": "merchant",
		"traits": {"boldness": 0.4, "sociability": 0.8, "generosity": 0.5, "curiosity": 0.5},
		"baseline_emotion": "content",
		"baseline_energy": "normal",
		"schedule_type": "routine",
		"routine": [
			{"start_hour": 7, "end_hour": 21, "goal": "tend_shop", "location": "item_shop"},
			{"start_hour": 21, "end_hour": 7, "goal": "rest", "location": "item_shop"},
		],
		"periodic_pattern": [],
		"starting_items": {},
		"starting_gold": 500,
		"starting_goal": "tend_shop",
		"starting_equip": {},
		"shop_type": "item",
		"shop_items": ["healing_potion"],
	},
}


static func get_identity(npc_id: String) -> Dictionary:
	var data: Dictionary = IDENTITIES.get(npc_id, {})
	if data.is_empty():
		return {}
	data = data.duplicate(true)
	# Compose starting loadout and traits from authoritative sources
	var loadout: Dictionary = NpcLoadouts.LOADOUTS.get(npc_id, {})
	if not loadout.is_empty():
		data["starting_items"] = loadout.get("items", {})
		data["starting_gold"] = loadout.get("gold", -1)
		data["starting_goal"] = loadout.get("default_goal", "idle")
		var equip_list: Array = loadout.get("equip", [])
		var equip_dict: Dictionary = {}
		if not equip_list.is_empty():
			equip_dict["weapon"] = equip_list[0]
		data["starting_equip"] = equip_dict
		var profile: Dictionary = NpcTraits.PROFILES.get(loadout.get("trait_profile", ""), {})
		if not profile.is_empty():
			data["traits"] = profile
	return data


static func get_all_ids() -> Array:
	return IDENTITIES.keys()
