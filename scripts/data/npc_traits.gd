extends RefCounted
## Static NPC trait profiles — personality axes that drive behavior and LLM prompts.

# Trait axes (0.0–1.0):
# boldness: 0=cautious, 1=reckless — affects retreat HP%, aggro willingness
# sociability: 0=introverted, 1=extroverted — affects social chat cooldown
# generosity: 0=selfish, 1=generous — future use (trade willingness)
# curiosity: 0=focused, 1=exploratory — future use (goal switching)

const PROFILES: Dictionary = {
	"bold_warrior": {
		"boldness": 0.85, "sociability": 0.7, "generosity": 0.5, "curiosity": 0.3,
		"weapon_type": "sword",
		"starting_proficiencies": {"sword": 3, "constitution": 2, "agility": 1},
	},
	"cautious_mage": {
		"boldness": 0.2, "sociability": 0.4, "generosity": 0.6, "curiosity": 0.7,
		"weapon_type": "staff",
		"starting_proficiencies": {"staff": 3, "constitution": 1, "agility": 1},
	},
	"boisterous_brawler": {
		"boldness": 0.75, "sociability": 0.9, "generosity": 0.6, "curiosity": 0.4,
		"weapon_type": "sword",
		"starting_proficiencies": {"sword": 3, "constitution": 2, "agility": 1},
	},
	"sly_rogue": {
		"boldness": 0.5, "sociability": 0.8, "generosity": 0.2, "curiosity": 0.6,
		"weapon_type": "dagger",
		"starting_proficiencies": {"dagger": 3, "agility": 2, "constitution": 1},
	},
	"stoic_knight": {
		"boldness": 0.6, "sociability": 0.25, "generosity": 0.7, "curiosity": 0.2,
		"weapon_type": "sword",
		"starting_proficiencies": {"sword": 3, "constitution": 2, "agility": 1},
	},
	"cheerful_scholar": {
		"boldness": 0.4, "sociability": 0.85, "generosity": 0.8, "curiosity": 0.9,
		"weapon_type": "staff",
		"starting_proficiencies": {"staff": 3, "constitution": 1, "agility": 1},
	},
	"mysterious_loner": {
		"boldness": 0.55, "sociability": 0.15, "generosity": 0.3, "curiosity": 0.5,
		"weapon_type": "dagger",
		"starting_proficiencies": {"dagger": 3, "agility": 2, "constitution": 1},
	},
}

# Label mappings for compact LLM trait summaries
const BOLDNESS_LABELS: Array = [
	[0.3, "cautious"], [0.6, "steady"], [1.0, "bold"],
]
const SOCIABILITY_LABELS: Array = [
	[0.3, "quiet"], [0.6, "moderate"], [1.0, "talkative"],
]

static func get_profile(id: String) -> Dictionary:
	return PROFILES.get(id, {})

static func get_trait(id: String, trait_name: String, default: float = 0.5) -> float:
	var profile := PROFILES.get(id, {}) as Dictionary
	return profile.get(trait_name, default)

const BACKSTORIES: Dictionary = {
	"bold_warrior": "Kael grew up in a frontier village raided by bandits every spring. He picked up a sword at twelve and never put it down. He came to this town chasing rumors of a cursed dungeon that swallowed his older brother whole.",
	"cautious_mage": "Lyra was expelled from the Astral Academy for questioning her professors' methods. She believes true magic comes from understanding, not rote memorization. She funds her independent research by selling monster parts to alchemists.",
	"boisterous_brawler": "Bjorn once arm-wrestled a minotaur in a tavern bet and won — or so he claims. He left the northern clans after a blood feud and now fights anything that moves to forget the cold. He measures friendship by how many scars you share.",
	"sly_rogue": "Sera used to run cons in the capital before a mark turned out to be a royal spy. She fled here with nothing but quick hands and a fake name. She scouts the town looking for her next opportunity — old habits die hard.",
	"stoic_knight": "Thane served the Order of the Silver Wall for fifteen years before they disbanded in disgrace. He still follows their code: protect the weak, face the dark, never run. The dungeon is his penance for a failure he won't talk about.",
	"cheerful_scholar": "Mira left her family's library in the eastern isles to see the world firsthand. She keeps a journal of every monster, herb, and ruin she encounters. She believes every creature has a story worth documenting — even the slimes.",
	"mysterious_loner": "Dusk doesn't share where he came from, only that he can't go back. He fights in the dungeon alone because the last party he joined didn't come out alive. He keeps a tally of kills scratched into his blade's handle.",
}

static func get_backstory(profile_name: String) -> String:
	return BACKSTORIES.get(profile_name, "")

const VOICE_STYLES: Dictionary = {
	"bold_warrior": "Direct, competitive, impatient. Talks like a tryhard MMO player. Uses CAPS when fired up. Swears casually (damn, hell yeah). Short punchy sentences. Never flowery or polite.",
	"cautious_mage": "Thoughtful and measured. Uses '...' pauses and 'hmm' or 'well' when thinking. Slightly nerdy. Calm tone, rarely raises voice. Qualifies statements ('I think', 'probably').",
	"boisterous_brawler": "LOUD and rowdy. Caps frequently. Finds everything hilarious or exciting. Swears enthusiastically (holy shit, hell yeah). Uses !!! liberally. Laughs a lot (hahaha, lmao). Zero filter.",
	"sly_rogue": "Lazy and sarcastic. Lowercase preferred. Uses abbreviations (idk, ngl, tbh, lol). Dry deadpan humor. Acts like nothing impresses her. Swears for comedic effect.",
	"stoic_knight": "Minimal. Few words. Formal but not wordy. Prefers one-word acknowledgments. Rarely shows emotion. Can respond with just a word or two. Never swears.",
	"cheerful_scholar": "Warm and excitable. Uses !! and ?? freely. Gets genuinely hyped about discoveries. Friendly energy, asks lots of questions. Speaks with breathless enthusiasm. Rarely swears.",
	"mysterious_loner": "Extremely terse. Cryptic. Uses '...' and fragments. Prefers silence, speaks only when necessary. Single words or short phrases. Cold, guarded. Swears only when frustrated.",
}

static func get_voice_style(profile_name: String) -> String:
	return VOICE_STYLES.get(profile_name, "")

const MOODS: Array = [
	{"name": "neutral", "prompt": "", "weights": {}},
	{"name": "pumped", "prompt": "You're fired up and full of energy right now.", "weights": {"boldness": 1.5, "sociability": 0.5}},
	{"name": "thoughtful", "prompt": "You're in a reflective, contemplative mood.", "weights": {"curiosity": 1.5, "boldness": -0.5}},
	{"name": "irritated", "prompt": "You're mildly annoyed about something.", "weights": {"boldness": 0.8, "sociability": -0.5}},
	{"name": "relaxed", "prompt": "You're calm and easygoing right now.", "weights": {"generosity": 0.5, "sociability": 0.3, "boldness": -0.3}},
	{"name": "curious", "prompt": "Something has caught your attention. You're intrigued.", "weights": {"curiosity": 1.5, "sociability": 0.3}},
	{"name": "cocky", "prompt": "You're feeling confident, maybe a bit too confident.", "weights": {"boldness": 1.5, "sociability": 0.8}},
	{"name": "tired", "prompt": "You're a bit worn out and low-energy right now.", "weights": {"boldness": -0.5, "sociability": -0.5}},
]

static func pick_mood(profile_name: String) -> Dictionary:
	var profile := get_profile(profile_name)
	if profile.is_empty():
		return MOODS[0]
	var weighted: Array = []
	for mood in MOODS:
		var score: float = 1.0
		var w: Dictionary = mood["weights"]
		for trait_name in w:
			score += profile.get(trait_name, 0.5) * w[trait_name]
		weighted.append({"mood": mood, "score": maxf(score, 0.1)})
	var total: float = 0.0
	for entry in weighted:
		total += entry["score"]
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for entry in weighted:
		cumulative += entry["score"]
		if roll <= cumulative:
			return entry["mood"]
	return MOODS[0]

static func get_trait_summary(id: String) -> String:
	var profile := PROFILES.get(id, {}) as Dictionary
	if profile.is_empty():
		return ""
	var labels: Array = []
	var boldness: float = profile.get("boldness", 0.5)
	for entry in BOLDNESS_LABELS:
		if boldness <= entry[0]:
			labels.append(entry[1])
			break
	var sociability: float = profile.get("sociability", 0.5)
	for entry in SOCIABILITY_LABELS:
		if sociability <= entry[0]:
			labels.append(entry[1])
			break
	return ", ".join(labels)
