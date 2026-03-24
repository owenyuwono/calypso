extends RefCounted
## Static dialogue tree definitions for all named NPCs.
## Procedural NPCs fall back to get_generic_greeting().

class_name DialogueDatabase

const DIALOGUES: Dictionary = {
	"kael": {
		"greeting": {
			"text": "Hey! You look ready to fight. Good. The fields east of town are crawling with slimes and wolves — I've been out there all morning. You heading out?",
			"choices": [
				{"text": "Tell me about the fields.", "next": "fields_info"},
				{"text": "Hunt together?", "next": "hunt_together", "condition": "relationship >= friendly"},
				{"text": "Tell me about your adventures.", "next": "kael_adventures_prompt", "condition": "proficiency:charisma >= 3"},
				{"text": "About those wolves...", "next": "kael_quest_offer", "condition": "quest:field_patrol:not_started"},
				{"text": "Any progress on the wolves?", "next": "kael_quest_progress", "condition": "quest:field_patrol:active"},
				{"text": "I've dealt with the wolves.", "next": "kael_quest_complete", "condition": "quest:field_patrol:completable"},
				{"text": "Just passing through.", "next": null},
			],
		},
		"kael_quest_offer": {
			"text": "Wolves have been threatening travelers on the road east of town. I can't patrol everywhere at once. Help me deal with 2 of them and I'll make it worth your while.",
			"choices": [
				{"text": "I'll handle it.", "next": null, "action": "quest_accept:field_patrol"},
				{"text": "Not right now.", "next": null},
			],
		},
		"kael_quest_progress": {
			"text": "The wolves are still a problem. Travelers won't use that road until we clear them out. Two wolves — that's all I need.",
			"choices": [
				{"text": "I'm working on it.", "next": null},
			],
		},
		"kael_quest_complete": {
			"text": "The roads are safer now. Well done, friend. You've done the city a real service.",
			"choices": [
				{"text": "Happy to help.", "next": null, "action": "quest_complete:field_patrol"},
			],
		},
		"kael_quest_done": {
			"text": "Thanks to you, the east road is safe again. Travelers can pass without worry.",
			"choices": [
				{"text": "Good to hear. See you out there.", "next": null},
			],
		},
		"fields_info": {
			"text": "Slimes in the east — weak, but they drop good loot if you farm enough. Wolves are tougher, hit fast. Watch your stamina or they'll wear you down. I've seen people get overwhelmed trying to fight three at once.",
			"choices": [
				{"text": "Any rare drops?", "next": "rare_drops"},
				{"text": "Hunt together?", "next": "hunt_together", "condition": "relationship >= friendly"},
				{"text": "Thanks, I'll keep that in mind.", "next": null},
			],
		},
		"rare_drops": {
			"text": "Wolves drop wolf pelts — sell decent. Slimes drop slime cores, useful for crafting. Nothing crazy, but it adds up. The real score is when you stumble on a gold ore vein. That's where the money is.",
			"choices": [
				{"text": "Hunt together?", "next": "hunt_together", "condition": "relationship >= friendly"},
				{"text": "Good to know. See you out there.", "next": null},
			],
		},
		"hunt_together": {
			"text": "YEAH. Let's go. I've been waiting for someone worth hunting with. You handle the wolves, I'll take the slimes — no wait, let's bet on who gets more kills. Loser buys potions.",
			"choices": [
				{"text": "You're on. Let's go.", "next": null},
				{"text": "Maybe another time.", "next": null},
			],
		},
		"kael_adventures_prompt": {
			"text": "Ha! You actually want to hear it? Most people just nod and move on. Alright — pull up a wall, this one's worth telling.",
			"choices": [
				{"text": "I'm listening.", "next": "kael_adventures_story"},
				{"text": "Actually, never mind.", "next": null},
			],
		},
		"kael_adventures_story": {
			"text": "Three months back I was cornered in the west field — four wolves, low on potions, one skill charge left. Most people would've run. I used Cleave on the two closest, got lucky crits on both, and the other two broke off. Walked away with full wolf pelt drops.",
			"choices": [
				{"text": "You stayed and fought all four?", "next": "kael_adventures_ending"},
				{"text": "Bold move. Did it always work like that?", "next": "kael_adventures_ending"},
			],
		},
		"kael_adventures_ending": {
			"text": "That one time, yeah. Plenty of others I got flattened and had to limp back through the gate. That's the thing about the field — every run teaches you something, if you survive it. Keep that in mind when you head out.",
			"choices": [
				{"text": "I will. Thanks for telling me.", "next": null},
				{"text": "I'll aim to do better than surviving.", "next": null},
			],
		},
	},

	"lyra": {
		"greeting": {
			"text": "Oh. Hmm. I was in the middle of something, but... I suppose a brief conversation is fine. Are you familiar with the elemental compositions out in the field zones? They're quite interesting.",
			"choices": [
				{"text": "Tell me about magic.", "next": "magic_theory"},
				{"text": "Any dangers I should know about?", "next": "field_dangers"},
				{"text": "Could you teach me something?", "next": "lyra_teach_consider", "condition": "proficiency:persuasion >= 4"},
				{"text": "About your research...", "next": "lyra_quest_offer", "condition": "quest:arcane_study:not_started"},
				{"text": "How's the slime study going?", "next": "lyra_quest_progress", "condition": "quest:arcane_study:active"},
				{"text": "I have data from the slimes.", "next": "lyra_quest_complete", "condition": "quest:arcane_study:completable"},
				{"text": "Sorry to interrupt. Goodbye.", "next": null},
			],
		},
		"lyra_quest_offer": {
			"text": "I'm studying slime essence and its elemental properties. Could you defeat 3 slimes for my research? The combat data would be invaluable.",
			"choices": [
				{"text": "I'll help with your research.", "next": null, "action": "quest_accept:arcane_study"},
				{"text": "Not right now.", "next": null},
			],
		},
		"lyra_quest_progress": {
			"text": "How's the slime hunting going? I need data from 3 slimes. Take care to note any elemental reactions — that's the part that interests me.",
			"choices": [
				{"text": "Still working on it.", "next": null},
			],
		},
		"lyra_quest_complete": {
			"text": "Excellent research data! The sample size is sufficient. Let me reward you for your contribution to the study.",
			"choices": [
				{"text": "Glad I could help.", "next": null, "action": "quest_complete:arcane_study"},
			],
		},
		"lyra_quest_done": {
			"text": "The data you gathered confirmed my hypothesis about slime lightning affinity. Fascinating. Thank you.",
			"choices": [
				{"text": "Anytime. Goodbye, Lyra.", "next": null},
			],
		},
		"magic_theory": {
			"text": "Well, the staff proficiency is about channeling — you're not casting spells, exactly, you're... directing flows. The INT stat governs how cleanly the energy moves. More INT, more damage, but also more precision. It's subtle.",
			"choices": [
				{"text": "What about magical resistance?", "next": "resistances"},
				{"text": "Can you share your research notes?", "next": "research_notes", "condition": "relationship >= friendly"},
				{"text": "Interesting. Thank you.", "next": null},
			],
		},
		"field_dangers": {
			"text": "The wolves have higher evasion than they look. Probably. I've noticed misses happen more often against them than against slimes. I'd recommend accuracy-focused gear before heading into the west field — the dark mages there are genuinely dangerous.",
			"choices": [
				{"text": "What do the dark mages drop?", "next": "mage_drops"},
				{"text": "Thanks for the warning.", "next": null},
			],
		},
		"resistances": {
			"text": "Each monster type has elemental affinities. Some are weak to fire, some resist ice. The slimes, for example... I believe they're weak to lightning but resist water. I'd need to verify. The point is, element choice matters more than raw power.",
			"choices": [
				{"text": "Can you share your research notes?", "next": "research_notes", "condition": "relationship >= friendly"},
				{"text": "I'll experiment. Thanks, Lyra.", "next": null},
			],
		},
		"mage_drops": {
			"text": "Arcane dust, mostly. Some mana crystals if you're lucky. Useful for crafting if you have the recipe. I've been meaning to test synthesis ratios but... I keep getting interrupted.",
			"choices": [
				{"text": "I'll let you get back to it. Goodbye.", "next": null},
			],
		},
		"research_notes": {
			"text": "...You're actually interested? Hmm. Alright. The key insight is that magical damage bypasses physical armor — DEF does nothing. MDEF is what matters. Most people ignore that and wonder why their warrior takes full hits from a mage.",
			"choices": [
				{"text": "That's genuinely useful. Thank you.", "next": null},
				{"text": "Anything else?", "next": "research_bonus"},
			],
		},
		"research_bonus": {
			"text": "The WIS stat also governs cooldown reduction — up to a cap. People sleep on WIS. If you're using skills heavily, a few points there will pay off. Probably. That's my working hypothesis, anyway.",
			"choices": [
				{"text": "I'll keep that in mind. Thanks.", "next": null},
			],
		},
		"lyra_teach_consider": {
			"text": "...Teach you something. That's an unusual request. Most people just want to know which element does more damage. You're asking about knowledge, not numbers. Hmm.",
			"choices": [
				{"text": "I want to understand the theory, not just the output.", "next": "lyra_teach_lesson"},
				{"text": "I'll take whatever you're willing to share.", "next": "lyra_teach_lesson"},
			],
		},
		"lyra_teach_lesson": {
			"text": "Alright. Here's something worth knowing: the damage formula isn't linear. At low INT, each point of INT gains you very little. Past a threshold, returns improve. This is why mages who spread stats thin stay weak — the investment only pays off when you commit.",
			"choices": [
				{"text": "So single-stat focus is the right call.", "next": "lyra_teach_followup"},
				{"text": "When does the threshold kick in?", "next": "lyra_teach_followup"},
			],
		},
		"lyra_teach_followup": {
			"text": "Around INT 4 or 5, in my estimation. Below that, a staff is mostly just a stick you swing. Above it, the magical damage starts to compound noticeably. I haven't had a student in a long time. Don't make me regret this.",
			"choices": [
				{"text": "You won't. Thank you, Lyra.", "next": null, "action": "persuasion_attempt"},
				{"text": "I'll put it to use.", "next": null, "action": "persuasion_attempt"},
			],
		},
	},

	"bjorn": {
		"greeting": {
			"text": "HAHA! A new face! You got that look — hungry for a fight. Good! My shop's open if you need a blade worthy of your ambitions. I forge 'em myself between hunts. Well, mostly. I carry them, at least!",
			"choices": [
				{"text": "Let me see what you have.", "next": null, "action": "trade"},
				{"text": "Tell me about your weapons.", "next": "weapons_talk"},
				{"text": "About that ore...", "next": "bjorn_quest_offer", "condition": "quest:miners_request:not_started"},
				{"text": "I have the ore.", "next": "bjorn_quest_complete", "condition": "quest:miners_request:completable"},
				{"text": "About the ore...", "next": "bjorn_quest_progress", "condition": "quest:miners_request:active"},
				{"text": "Maybe later.", "next": null},
			],
		},
		"bjorn_quest_offer": {
			"text": "I need copper ore for my forge. My current supply ran dry and I've got blades to finish. Can you bring me 5 pieces? I'll pay well for it.",
			"choices": [
				{"text": "I'll get you the ore.", "next": null, "action": "quest_accept:miners_request"},
				{"text": "Not right now.", "next": null},
			],
		},
		"bjorn_quest_progress": {
			"text": "Still working on that ore? I need 5 copper pieces. The forge is cold without good material — don't leave me waiting too long!",
			"choices": [
				{"text": "I'm on it.", "next": null},
			],
		},
		"bjorn_quest_complete": {
			"text": "You have the ore! HAHA! Hand it over — my forge is hungry!",
			"choices": [
				{"text": "Here you go.", "next": null, "action": "quest_complete:miners_request"},
			],
		},
		"bjorn_quest_done": {
			"text": "Thanks for the ore. My forge is busy now! If you need a blade, you know where to find me.",
			"choices": [
				{"text": "Good luck with the forge.", "next": null},
			],
		},
		"weapons_talk": {
			"text": "Steel beats iron every time, no debate. But iron beats a fist! Hahaha! Basic swords are fine starting out. Once you can afford it, upgrade. The difference in ATK is worth every coin. I've split wolves clean in two with a good blade.",
			"choices": [
				{"text": "Browse the stock.", "next": null, "action": "trade"},
				{"text": "What weapon type do you recommend?", "next": "weapon_advice"},
				{"text": "Good advice. See you around.", "next": null},
			],
		},
		"weapon_advice": {
			"text": "Depends on your build! Sword is versatile — cleave hits multiple targets. Axe hits HARDER but slower. Mace is brutal against heavy armor. I use an axe personally. Nothing like the satisfying CRACK when it connects. You'll know your type when you find it.",
			"choices": [
				{"text": "I'll browse your wares.", "next": null, "action": "trade"},
				{"text": "Thanks for the advice.", "next": null},
			],
		},
	},

	"sera": {
		"greeting": {
			"text": "Well, well. You've got that look — either you want something, or you've got something worth trading. Either way, I'm interested. What'll it be?",
			"choices": [
				{"text": "What are you selling?", "next": null, "action": "trade"},
				{"text": "What can you tell me about rare drops?", "next": "rare_drops"},
				{"text": "Just looking around.", "next": null},
			],
		},
		"rare_drops": {
			"text": "Now we're talking. The west field — that's where the interesting stuff drops. Dark mages carry arcane dust. Skeletons drop bone fragments, useful for crafting. But the real tip? Fish. People overlook fishing. Deep water catches sell for solid gold.",
			"choices": [
				{"text": "Any harder-to-find items?", "next": "secret_drops", "condition": "relationship >= friendly"},
				{"text": "Good to know. Let me see your stock.", "next": null, "action": "trade"},
				{"text": "Thanks for the tip.", "next": null},
			],
		},
		"secret_drops": {
			"text": "Since you asked nicely... Gold ore. Sounds obvious, but most people mine copper and stop there. Gold ore is in the west field, and it sells for triple. The rocks are harder to spot — they're darker than iron. Look for the shimmer.",
			"choices": [
				{"text": "I owe you one. Let me see your stock.", "next": null, "action": "trade"},
				{"text": "Much appreciated.", "next": null},
			],
		},
	},

	"thane": {
		"greeting": {
			"text": "Adventurer. If you're planning to work the fields, know the rules: stay east if you're new, west only when you can handle a three-wolf pull. The city depends on capable people keeping those routes clear.",
			"choices": [
				{"text": "Tell me about the patrol routes.", "next": "patrol_routes"},
				{"text": "Any threat to the city itself?", "next": "city_threats"},
				{"text": "Understood. I'll be careful.", "next": null},
			],
		},
		"patrol_routes": {
			"text": "East gate, sweep the ridge, back through the south road — that's the clean path. Avoid the hollow near the west tree line at night. Wolves pack there. If you're going out after dusk, take potions. The cautious come back.",
			"choices": [
				{"text": "What about the west field?", "next": "west_field"},
				{"text": "Noted. I'll stick to the east road.", "next": null},
			],
		},
		"city_threats": {
			"text": "The walls hold. They always have. My concern is the west field — the skeleton numbers have been rising. Something drives them, but I haven't found the source yet. If you're strong enough, that's where I'd look.",
			"choices": [
				{"text": "I'll keep an eye out.", "next": "city_threats_followup"},
				{"text": "Not my concern. Goodbye.", "next": null},
			],
		},
		"city_threats_followup": {
			"text": "Good. Report back anything unusual — unusual spawn clusters, items that don't match the area, anything. The city doesn't need heroes. It needs observant people who pay attention.",
			"choices": [
				{"text": "I will. Count on it.", "next": null},
			],
		},
		"west_field": {
			"text": "High risk, high reward. Skeletons, wolves, dark mages — all in the same zone. Strong gear recommended. If you can clear that field consistently, the loot will fund your next upgrade. I've done it a few times myself.",
			"choices": [
				{"text": "Any tips for fighting skeletons?", "next": "skeleton_tips"},
				{"text": "Thanks, Thane.", "next": null},
			],
		},
		"skeleton_tips": {
			"text": "Blunt weapons. Maces shatter bone faster than blades. If you're using a sword, pierce-type works reasonably well. The mages are the real threat — close the distance fast before they stack ranged hits on you.",
			"choices": [
				{"text": "Good advice. I'll be ready.", "next": null},
			],
		},
	},

	"mira": {
		"greeting": {
			"text": "Oh, hello! I was just about to brew a restorative batch. Are you injured? Even if you're not, a few extra healing potions never hurt. I can walk you through crafting them if you'd like.",
			"choices": [
				{"text": "Tell me about healing and crafting.", "next": "healing_crafting"},
				{"text": "Any advice for staying alive out there?", "next": "survival_advice"},
				{"text": "You seem like you have a secret...", "next": "mira_secret_deflect", "condition": "proficiency:charisma >= 5"},
				{"text": "About those sardines...", "next": "mira_quest_offer", "condition": "quest:healers_herbs:not_started"},
				{"text": "I still need to get the sardines.", "next": "mira_quest_progress", "condition": "quest:healers_herbs:active"},
				{"text": "I have the cooked sardine.", "next": "mira_quest_complete", "condition": "quest:healers_herbs:completable"},
				{"text": "I'm fine, but thanks.", "next": null},
			],
		},
		"mira_quest_offer": {
			"text": "I need cooked sardines for my remedies — they have restorative properties when prepared correctly. Can you catch 3 sardines and cook one for me? The fishing spots near the field should have them.",
			"choices": [
				{"text": "I'll get them for you.", "next": null, "action": "quest_accept:healers_herbs"},
				{"text": "Not right now.", "next": null},
			],
		},
		"mira_quest_progress": {
			"text": "I still need those sardines. Catch 3 from a fishing spot and cook one at the cooking station. The remedy won't work without them.",
			"choices": [
				{"text": "I'll keep looking.", "next": null},
			],
		},
		"mira_quest_complete": {
			"text": "Perfect! These will make excellent medicine. Thank you so much — the people who need this remedy will be grateful.",
			"choices": [
				{"text": "Happy to help.", "next": null, "action": "quest_complete:healers_herbs"},
			],
		},
		"mira_quest_done": {
			"text": "The remedies are coming along wonderfully thanks to those sardines. Come back if you need any healing advice!",
			"choices": [
				{"text": "Take care, Mira.", "next": null},
			],
		},
		"healing_crafting": {
			"text": "The cooking station near the plaza is your friend for basic restoratives. Cooked fish heals a good chunk — trout especially. For proper potions, you'll need the crafting station and some gathered materials. WIS helps the crafting process, I've found.",
			"choices": [
				{"text": "What materials do I need?", "next": "crafting_materials"},
				{"text": "Where's the nearest crafting station?", "next": "station_location"},
				{"text": "Good to know. Thank you.", "next": null},
			],
		},
		"survival_advice": {
			"text": "Don't fight when your stamina is low. I've seen it go wrong too many times — when stamina drops, your ATK and move speed drop with it. Keep potions on your hotbar, not buried in inventory. And take rest spots seriously, they recover stamina fast.",
			"choices": [
				{"text": "What about healing between fights?", "next": "resting"},
				{"text": "Solid advice. Thanks, Mira.", "next": null},
			],
		},
		"crafting_materials": {
			"text": "For basic bandages: any cloth or leather scraps, from gathering or drops. For healing potions: herbs from the field and a flask — the item shop carries flasks. CON training helps too. Higher CON means more HP and natural regen between fights.",
			"choices": [
				{"text": "Good to know. I'll look into it.", "next": null},
			],
		},
		"station_location": {
			"text": "There are three stations near the central fountain in the plaza district — cooking, smithing, and crafting. You can't miss them. Each one opens a different recipe menu depending on your proficiency levels.",
			"choices": [
				{"text": "Perfect. Thank you, Mira.", "next": null},
			],
		},
		"resting": {
			"text": "Between fights, just stand still for a moment. HP regenerates on its own outside of combat — it's slow, but it adds up. If you've trained CON, the regen rate is noticeably faster. For longer rest, there are spots in the park district.",
			"choices": [
				{"text": "Thank you. That's really helpful.", "next": null},
			],
		},
		"mira_secret_deflect": {
			"text": "A secret? That's... a strange thing to say. What makes you think that?",
			"choices": [
				{"text": "You pause before answering. You measure your words carefully.", "next": "mira_secret_pause"},
				{"text": "Just a feeling. You don't have to say anything.", "next": "mira_secret_pause"},
			],
		},
		"mira_secret_pause": {
			"text": "...I used to be a field healer. Before I came here. There was an expedition — a large one, into the west caves before they were cleared. Someone I was responsible for didn't make it back. I couldn't help them in time.",
			"choices": [
				{"text": "That's why you're so focused on prevention.", "next": "mira_secret_resolve"},
				{"text": "That must have been hard to carry.", "next": "mira_secret_resolve"},
			],
		},
		"mira_secret_resolve": {
			"text": "The potions, the stamina advice, the rest spots — yes. I'd rather ten people not need emergency healing than save one person dramatically. Nobody talks about the ones who didn't need saving. But I know they're out there. That's enough.",
			"choices": [
				{"text": "Thank you for telling me.", "next": null},
				{"text": "I'll remember that. I'll be careful out there.", "next": null},
			],
		},
	},

	"dusk": {
		"greeting": {
			"text": "You caught me at a good time. Or maybe I let you catch me. Hard to say. What do you want?",
			"choices": [
				{"text": "What do you know about rare drops?", "next": "rare_knowledge"},
				{"text": "What are you doing out here?", "next": "dusk_business"},
				{"text": "Nothing. Sorry to bother you.", "next": null},
			],
		},
		"rare_knowledge": {
			"text": "The dark mages in the west field — they carry arcane dust. Most people know that. What they don't know is that the mages who spawn near the rocky clearing have a small chance to drop a staff fragment. Higher level drop, uncommon spot.",
			"choices": [
				{"text": "What's the staff fragment for?", "next": "staff_fragment"},
				{"text": "Any other hidden drops?", "next": "more_secrets", "condition": "relationship >= friendly"},
				{"text": "I'll look for that spot. Thanks.", "next": null},
			],
		},
		"staff_fragment": {
			"text": "Crafting. I've heard it combines with other materials into something worth more than the sum of its parts. I don't craft. I find things. Someone else can figure out the recipe.",
			"choices": [
				{"text": "Anything else worth knowing?", "next": "more_secrets", "condition": "relationship >= friendly"},
				{"text": "Useful. Thank you.", "next": null},
			],
		},
		"dusk_business": {
			"text": "Scouting. Information. The usual. This city has more going on beneath the surface than most people notice. The skeleton surge in the west field isn't natural — something is pushing them toward the gate. I'm trying to figure out what.",
			"choices": [
				{"text": "Should I be worried?", "next": "threat_assessment"},
				{"text": "Sounds dangerous.", "next": null},
			],
		},
		"threat_assessment": {
			"text": "Not yet. The walls are solid. But if the source isn't dealt with, eventually it becomes everyone's problem. I work better alone, so don't follow me — but keep an eye on the skeleton spawn rates when you're out there.",
			"choices": [
				{"text": "Noted. I'll watch for changes.", "next": null},
			],
		},
		"more_secrets": {
			"text": "Gold ore respawns faster if you mine all three nodes in the west field clearing — I think they share a timer. Might be coincidence. Also: wolves at night are faster than during the day. I wouldn't bet my life on either of those, but they're worth testing.",
			"choices": [
				{"text": "I'll test both. Good hunting, Dusk.", "next": null},
			],
		},
	},

	"garrick": {
		"greeting": {
			"text": "Welcome, welcome! Garrick's your man for weapons — swords, axes, maces, whatever suits your fighting style. Everything's quality stock, priced fairly. Take a look, no pressure.",
			"choices": [
				{"text": "Browse your wares.", "next": null, "action": "trade"},
				{"text": "What do you recommend for a beginner?", "next": "beginner_advice"},
				{"text": "Just browsing. Thanks.", "next": null},
			],
		},
		"beginner_advice": {
			"text": "A basic sword covers you well starting out — decent damage, versatile skills. Once you've leveled your sword proficiency to three or four, you'll want to upgrade. Iron sword is a solid step up. I've got both in stock.",
			"choices": [
				{"text": "Show me what you have.", "next": null, "action": "trade"},
				{"text": "Good advice. I'll keep it in mind.", "next": null},
			],
		},
	},

	"elara": {
		"greeting": {
			"text": "Hello there, traveler! Running low on potions? I keep a healthy supply — adventurers go through them faster than you'd think. Let me know what you need.",
			"choices": [
				{"text": "What do you have?", "next": null, "action": "trade"},
				{"text": "How's business?", "next": "business_talk"},
				{"text": "Just passing by. Thanks.", "next": null},
			],
		},
		"business_talk": {
			"text": "Steady! Adventurers need potions every day. I restock when I can — sometimes I run short if there's been heavy fighting in the fields. If I'm sold out, check back later. I always keep a few in reserve for regulars.",
			"choices": [
				{"text": "I'll stock up now then.", "next": null, "action": "trade"},
				{"text": "Good to know. Goodbye.", "next": null},
			],
		},
	},

	"celine": {
		"greeting": {
			"text": "Need something? I've got potions, bandages — all made fresh. What do you need?",
			"choices": [
				{"text": "What do you have?", "next": null, "action": "trade"},
				{"text": "How's business?", "next": "celine_business"},
				{"text": "Tell me about yourself.", "next": "celine_about"},
				{"text": "Never mind.", "next": null},
			],
		},
		"celine_business": {
			"text": "Could be better. Slime jelly's the base for most of my potions, and adventurers know it. They charge what they like. If you ever come across some, I'd pay fair for it.",
			"choices": [
				{"text": "I'll keep that in mind.", "next": null},
				{"text": "Let me see your stock.", "next": null, "action": "trade"},
			],
		},
		"celine_about": {
			"text": "Not much to tell. I'm from the coast. My mother was an apothecary — taught me everything I know. I came here three years ago to start fresh. The fountain's good for foot traffic, and adventurers always need potions.",
			"choices": [
				{"text": "What happened to your mother's shop?", "next": "celine_mother"},
				{"text": "Sounds like a good setup.", "next": null},
			],
		},
		"celine_mother": {
			"text": "Fire. A mislabelled solvent. Gone in an hour. She... didn't have it in her to start over. But I did.",
			"choices": [
				{"text": "I'm sorry.", "next": "celine_resolve"},
				{"text": "That's tough.", "next": "celine_resolve"},
			],
		},
		"celine_resolve": {
			"text": "Don't be. I'm here now, and my potions are better than hers ever were. Don't tell her I said that.",
			"choices": [
				{"text": "[Smile] Your secret's safe.", "next": null},
				{"text": "Let me buy something.", "next": null, "action": "trade"},
			],
		},
	},
}

## Generic greeting pools per archetype and mood.
const GENERIC_GREETINGS: Dictionary = {
	"warrior": {
		"happy": [
			"Good day! The hunt's been kind lately. You heading out to the fields?",
			"Hey there! Fine weather for fighting. Anything I can help with?",
			"Well met! I'm in a great mood today — had a good run in the east field.",
		],
		"sad": [
			"...",
			"Not a great day. What do you need?",
			"Yeah. Hi. What is it.",
		],
		"angry": [
			"What.",
			"Make it quick.",
			"I'm not in the mood for small talk.",
		],
		"neutral": [
			"Hey. You look like you're heading to the fields. Any luck out there?",
			"Adventurer. Keeping busy?",
			"Seen you around. You hold your own in a fight?",
		],
	},
	"mage": {
		"happy": [
			"Oh! Hello. I just had a breakthrough with my research — good timing on your part.",
			"What a pleasant afternoon. Can I help you with something?",
			"Hmm. You caught me in a good mood. What is it?",
		],
		"sad": [
			"Not now. Please.",
			"...",
			"If you need something, say it quickly.",
		],
		"angry": [
			"This is not a good time.",
			"What do you want.",
			"I am trying to concentrate.",
		],
		"neutral": [
			"Hmm. Hello. Something on your mind?",
			"Ah, a visitor. What brings you over?",
			"Yes? Can I help you with something?",
		],
	},
	"rogue": {
		"happy": [
			"Well, well. Lucky you — I'm in a generous mood. What do you need?",
			"Hey there. Good timing. I just got back from a profitable run.",
			"You again? Or is it the first time? Either way — what's up?",
		],
		"sad": [
			"Not a great day. Don't ask.",
			"Yeah?",
			"What.",
		],
		"angry": [
			"I'm busy.",
			"Not interested.",
			"Say what you have to say.",
		],
		"neutral": [
			"Eyes sharp today. Something caught your attention?",
			"Well. Here we are. What do you want?",
			"Hmm. You're looking for something.",
		],
	},
	"ranger": {
		"happy": [
			"Hey! Beautiful day out. You heading to the fields?",
			"Good timing — I just got back with a full pack. Nice haul.",
			"Hey! You look like someone who knows their way around a bow.",
		],
		"sad": [
			"Hey. Yeah. What do you need?",
			"...",
			"Not really in the talking mood, but go ahead.",
		],
		"angry": [
			"Say your piece.",
			"What.",
			"I'm watching the treeline. What is it?",
		],
		"neutral": [
			"Hey. Passing through, or looking for something?",
			"You scout the fields much? Good XP out there.",
			"Traveler. You look prepared. What's your build?",
		],
	},
	"merchant": {
		"happy": [
			"Welcome! Great day for shopping, don't you think?",
			"Hello there! Business has been wonderful — can I interest you in anything?",
			"Come in, come in! Today is a fine day to spend some gold.",
		],
		"sad": [
			"Oh. Hello.",
			"Yes? Can I help you?",
			"Welcome... I suppose.",
		],
		"angry": [
			"What do you want.",
			"Make it quick, I'm busy.",
			"Yes. Can I help you.",
		],
		"neutral": [
			"Welcome! Looking for anything in particular?",
			"Hello! Can I help you find something?",
			"Good to see you. What do you need?",
		],
	},
}


static func get_dialogue_entry(npc_id: String) -> String:
	if not has_dialogue(npc_id):
		return ""
	return "greeting"


static func has_dialogue(npc_id: String) -> bool:
	return DIALOGUES.has(npc_id)


static func get_node(npc_id: String, node_id: String) -> Dictionary:
	var tree: Dictionary = DIALOGUES.get(npc_id, {})
	return tree.get(node_id, {})


static func get_generic_greeting(archetype: String, mood: String) -> Dictionary:
	var arch_key: String = archetype if GENERIC_GREETINGS.has(archetype) else "warrior"
	var mood_key: String = mood
	var arch_pool: Dictionary = GENERIC_GREETINGS[arch_key]
	if not arch_pool.has(mood_key):
		mood_key = "neutral"
	var lines: Array = arch_pool[mood_key]
	var text: String = lines[randi() % lines.size()]
	return {
		"text": text,
		"choices": [
			{"text": "Goodbye.", "next": null},
		],
	}


static func evaluate_condition(condition: String, player: Node, npc: Node) -> bool:
	if condition.is_empty():
		return true

	# relationship >= tier
	if condition.begins_with("relationship >= "):
		var required_tier: String = condition.substr(16).strip_edges()
		var rel_comp: Node = npc.get_node_or_null("RelationshipComponent")
		if not rel_comp:
			return false
		var player_id: String = WorldState.get_entity_id_for_node(player)
		if player_id.is_empty():
			return false
		var current_tier: String = rel_comp.get_tier(player_id)
		const TIERS: Array = ["stranger", "recognized", "acquaintance", "friendly", "close", "bonded"]
		var current_idx: int = TIERS.find(current_tier)
		var required_idx: int = TIERS.find(required_tier)
		if required_idx < 0:
			return false
		return current_idx >= required_idx

	# time == phase
	if condition.begins_with("time == "):
		var required_phase: String = condition.substr(8).strip_edges()
		return TimeManager.get_phase() == required_phase

	# has_item:item_id
	if condition.begins_with("has_item:"):
		var item_id: String = condition.substr(9).strip_edges()
		var inv: Node = player.get_node_or_null("InventoryComponent")
		if not inv:
			return false
		return inv.has_item(item_id)

	# quest:quest_id:state — check quest progress
	# States: not_started, active, completed, completable
	if condition.begins_with("quest:"):
		var parts: Array = condition.split(":")
		if parts.size() >= 3:
			var quest_id: String = parts[1]
			var state: String = parts[2]
			var quest_comp: Node = player.get_node_or_null("QuestComponent")
			if not quest_comp:
				return false
			match state:
				"not_started": return not quest_comp.is_quest_active(quest_id) and not quest_comp.is_quest_completed(quest_id)
				"active": return quest_comp.is_quest_active(quest_id)
				"completed": return quest_comp.is_quest_completed(quest_id)
				"completable": return quest_comp.is_quest_completable(quest_id)
		return false

	# flag:flag_name — check boolean flag
	if condition.begins_with("flag:"):
		var flag_name: String = condition.substr(5)
		var quest_comp: Node = player.get_node_or_null("QuestComponent")
		return quest_comp and quest_comp.has_flag(flag_name)

	# proficiency:skill_id >= level — check player proficiency level
	if condition.begins_with("proficiency:"):
		var remainder: String = condition.substr(12)
		var parts: Array = remainder.split(" >= ")
		if parts.size() != 2:
			return false
		var skill_id: String = parts[0].strip_edges()
		var required_level: int = int(parts[1].strip_edges())
		var prog: Node = player.get_node_or_null("ProgressionComponent")
		if not prog:
			return false
		var level: int = prog.get_proficiency_level(skill_id)
		return level >= required_level

	return true
