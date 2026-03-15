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
		"speech_style": "Direct, competitive, impatient. Talks like a tryhard MMO player. Uses CAPS when fired up. Swears casually (damn, hell yeah). Short punchy sentences. Never flowery or polite.",
		"backstory": "Kael grew up in a frontier village raided by bandits every spring. He picked up a sword at twelve and never put it down. He came to this town chasing rumors of a cursed dungeon that swallowed his older brother whole.",
		"likes": ["combat", "glory", "strong opponents", "proving himself"],
		"dislikes": ["cowardice", "excuses", "people who talk but don't act"],
		"desires": [
			{"want": "become the strongest fighter in the region", "intensity": "high"},
			{"want": "find out what happened to his brother", "intensity": "high"},
		],
		"opinions": [],
		"secrets": [
			{"fact": "He blames himself for not being home when the bandits took his brother.", "known_by": [], "reveal_condition": "trusts the listener deeply"},
		],
		"tendencies": {
			"exaggerates": true,
			"withholds_from_strangers": false,
			"lies_when": "never",
			"avoids_topics": [],
		},
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
		"speech_style": "Thoughtful and measured. Uses '...' pauses and 'hmm' or 'well' when thinking. Slightly nerdy. Calm tone, rarely raises voice. Qualifies statements ('I think', 'probably').",
		"backstory": "Lyra was expelled from the Astral Academy for questioning her professors' methods. She believes true magic comes from understanding, not rote memorization. She funds her independent research by selling monster parts to alchemists.",
		"likes": ["knowledge", "magic theory", "quiet study", "solving puzzles"],
		"dislikes": ["recklessness", "willful ignorance", "people who rush into danger"],
		"desires": [
			{"want": "understand the true nature of ancient magic", "intensity": "high"},
			{"want": "prove the Astral Academy's methods are flawed", "intensity": "medium"},
		],
		"opinions": [],
		"secrets": [
			{"fact": "She was offered reinstatement but turned it down — pride would not let her accept.", "known_by": [], "reveal_condition": "conversation about the Academy arises"},
		],
		"tendencies": {
			"exaggerates": false,
			"withholds_from_strangers": true,
			"lies_when": "never",
			"avoids_topics": ["her expulsion", "personal failures"],
		},
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
		"speech_style": "LOUD and rowdy. Caps frequently. Finds everything hilarious or exciting. Swears enthusiastically (holy shit, hell yeah). Uses !!! liberally. Laughs a lot (hahaha, lmao). Zero filter.",
		"backstory": "Bjorn once arm-wrestled a minotaur in a tavern bet and won — or so he claims. He left the northern clans after a blood feud and now fights anything that moves to forget the cold. He measures friendship by how many scars you share.",
		"likes": ["fighting", "ale", "tall tales", "finding worthy opponents"],
		"dislikes": ["weakness", "cowards", "boring conversations", "silence"],
		"desires": [
			{"want": "find a truly worthy opponent to test his strength", "intensity": "high"},
			{"want": "build a reputation that reaches back to his northern clan", "intensity": "medium"},
		],
		"opinions": [],
		"secrets": [
			{"fact": "He started the blood feud that exiled him, not the other clan.", "known_by": [], "reveal_condition": "completely drunk and among trusted friends"},
		],
		"tendencies": {
			"exaggerates": true,
			"withholds_from_strangers": false,
			"lies_when": "telling stories for effect",
			"avoids_topics": ["the blood feud details"],
		},
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
		"speech_style": "Lazy and sarcastic. Lowercase preferred. Uses abbreviations (idk, ngl, tbh, lol). Dry deadpan humor. Acts like nothing impresses her. Swears for comedic effect.",
		"backstory": "Sera used to run cons in the capital before a mark turned out to be a royal spy. She fled here with nothing but quick hands and a fake name. She scouts the town looking for her next opportunity — old habits die hard.",
		"likes": ["treasure", "stealth", "easy marks", "watching plans come together"],
		"dislikes": ["authority", "guards", "predictability", "people who ask too many questions"],
		"desires": [
			{"want": "accumulate enough wealth to disappear somewhere safe", "intensity": "high"},
			{"want": "freedom from anyone who might be looking for her", "intensity": "high"},
		],
		"opinions": [],
		"secrets": [
			{"fact": "Her real name is not Sera. She lifted it from a gravestone when she fled the capital.", "known_by": [], "reveal_condition": "never, unless forced"},
		],
		"tendencies": {
			"exaggerates": false,
			"withholds_from_strangers": true,
			"lies_when": "protecting self-interest or hiding her past",
			"avoids_topics": ["her real name", "the capital", "the royal spy incident"],
		},
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
		"speech_style": "Minimal. Few words. Formal but not wordy. Prefers one-word acknowledgments. Rarely shows emotion. Can respond with just a word or two. Never swears.",
		"backstory": "Thane served the Order of the Silver Wall for fifteen years before they disbanded in disgrace. He still follows their code: protect the weak, face the dark, never run. The dungeon is his penance for a failure he won't talk about.",
		"likes": ["justice", "order", "protecting the innocent", "clear duties"],
		"dislikes": ["dishonesty", "betrayal", "chaos", "people who abuse their power"],
		"desires": [
			{"want": "protect those who cannot protect themselves", "intensity": "high"},
			{"want": "atone for the failure that brought down his Order", "intensity": "high"},
		],
		"opinions": [],
		"secrets": [
			{"fact": "He gave false testimony that exonerated a corrupt commander — the act that ultimately destroyed the Order.", "known_by": [], "reveal_condition": "asked directly about the Order's disbanding after deep trust is established"},
		],
		"tendencies": {
			"exaggerates": false,
			"withholds_from_strangers": true,
			"lies_when": "never",
			"avoids_topics": ["his past failure", "the Order of the Silver Wall's disbanding"],
		},
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
		"speech_style": "Warm and excitable. Uses !! and ?? freely. Gets genuinely hyped about discoveries. Friendly energy, asks lots of questions. Speaks with breathless enthusiasm. Rarely swears.",
		"backstory": "Mira left her family's library in the eastern isles to see the world firsthand. She keeps a journal of every monster, herb, and ruin she encounters. She believes every creature has a story worth documenting — even the slimes.",
		"likes": ["experiments", "new creatures", "discoveries", "her journal", "asking questions"],
		"dislikes": ["boredom", "closed-mindedness", "people who destroy things without studying them first"],
		"desires": [
			{"want": "discover something no scholar has documented before", "intensity": "high"},
			{"want": "fill her journal with enough entries to publish a compendium", "intensity": "medium"},
		],
		"opinions": [],
		"secrets": [
			{"fact": "She accidentally burned down a section of her family's library chasing a spark sprite — the guilt still haunts her.", "known_by": [], "reveal_condition": "topic of the family library or fire comes up"},
		],
		"tendencies": {
			"exaggerates": true,
			"withholds_from_strangers": false,
			"lies_when": "downplaying her mistakes",
			"avoids_topics": ["the library fire"],
		},
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
		"speech_style": "Extremely terse. Cryptic. Uses '...' and fragments. Prefers silence, speaks only when necessary. Single words or short phrases. Cold, guarded. Swears only when frustrated.",
		"backstory": "Dusk doesn't share where he came from, only that he can't go back. He fights in the dungeon alone because the last party he joined didn't come out alive. He keeps a tally of kills scratched into his blade's handle.",
		"likes": ["shadows", "secrets", "solitude", "uncovering hidden things"],
		"dislikes": ["loud people", "crowds", "being watched", "questions about his past"],
		"desires": [
			{"want": "uncover the truth behind what happened to his last party", "intensity": "high"},
			{"want": "find a way to return to wherever he came from", "intensity": "medium"},
		],
		"opinions": [],
		"secrets": [
			{"fact": "He was the only survivor of his last party because he fled — something he has never admitted to anyone.", "known_by": [], "reveal_condition": "impossible under normal circumstances"},
		],
		"tendencies": {
			"exaggerates": false,
			"withholds_from_strangers": true,
			"lies_when": "cornered or questioned about his past",
			"avoids_topics": ["his origin", "his last party", "where he came from"],
		},
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
		"speech_style": "Gruff and practical. Short sentences. Talks about craft with quiet pride. Not unfriendly but not chatty.",
		"backstory": "Garret has run this forge for twenty years. He has seen adventurers come and go. He respects quality work — in blades and in the people who use them.",
		"likes": ["well-made weapons", "customers who know what they want", "hard work"],
		"dislikes": ["haggling", "people who treat weapons carelessly", "idle chatter"],
		"desires": [
			{"want": "craft a truly legendary blade before he retires", "intensity": "medium"},
		],
		"opinions": [],
		"secrets": [],
		"tendencies": {
			"exaggerates": false,
			"withholds_from_strangers": false,
			"lies_when": "never",
			"avoids_topics": [],
		},
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
		"speech_style": "Cheerful and welcoming. Warm sales patter. Slightly sing-song. Eager to make a deal.",
		"backstory": "Vela traveled as a caravan merchant for years before settling here. She has a sharp eye for what people need before they know they need it. Her shop is small but she keeps it well stocked.",
		"likes": ["good trades", "repeat customers", "finding rare goods", "friendly conversation"],
		"dislikes": ["theft", "dishonest customers", "slow days"],
		"desires": [
			{"want": "expand the shop into the larger building next door", "intensity": "medium"},
		],
		"opinions": [],
		"secrets": [],
		"tendencies": {
			"exaggerates": false,
			"withholds_from_strangers": false,
			"lies_when": "never",
			"avoids_topics": [],
		},
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
