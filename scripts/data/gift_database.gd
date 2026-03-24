extends RefCounted
## Static NPC gift preference definitions. Per-NPC loved/liked/disliked lists for named NPCs,
## archetype fallback lists for procedural NPCs, and canned reaction lines per tier.

class_name GiftDatabase

# Named NPC preferences keyed by npc_id.
# Each entry has "loved", "liked", "disliked" arrays of item IDs.
# Items not listed in any array are treated as "neutral".
const NPC_PREFERENCES: Dictionary = {
	"kael": {
		"loved": ["iron_sword", "steel_sword", "iron_axe", "iron_spear", "iron_mace"],
		"liked": ["iron_chest", "iron_helm", "iron_legs", "healing_potion", "bandage"],
		"disliked": ["sardine", "trout", "salmon", "fish_stew"],
	},
	"lyra": {
		"loved": ["iron_staff", "gold_ore", "gold_ingot", "iron_ore"],
		"liked": ["copper_ore", "copper_ingot", "iron_ingot", "healing_potion", "hearty_soup"],
		"disliked": ["iron_axe", "iron_mace", "bone_dagger", "fur"],
	},
	"bjorn": {
		"loved": ["iron_ore", "copper_ore", "gold_ore", "iron_axe", "iron_ingot"],
		"liked": ["copper_ingot", "gold_ingot", "iron_mace", "iron_chest", "stone"],
		"disliked": ["healing_potion", "bandage", "cooked_sardine"],
	},
	"sera": {
		"loved": ["iron_dagger", "bone_dagger", "healing_potion", "bandage"],
		"liked": ["leather_armor", "fur", "iron_bow", "cooked_trout"],
		"disliked": ["iron_mace", "iron_spear", "stone"],
	},
	"thane": {
		"loved": ["iron_mace", "iron_chest", "iron_helm", "iron_legs"],
		"liked": ["iron_sword", "iron_axe", "iron_spear", "healing_potion"],
		"disliked": ["iron_staff", "iron_dagger", "sardine", "fish_stew"],
	},
	"mira": {
		"loved": ["cooked_salmon", "cooked_trout", "fish_stew", "hearty_soup", "healing_potion"],
		"liked": ["cooked_sardine", "bandage", "iron_staff"],
		"disliked": ["iron_axe", "iron_mace", "bone", "fur"],
	},
	"dusk": {
		"loved": ["iron_bow", "leather_armor", "fur"],
		"liked": ["iron_dagger", "bone_dagger", "healing_potion", "cooked_trout", "oak_log"],
		"disliked": ["iron_mace", "iron_chest", "stone"],
	},
	"greta": {
		"loved": ["iron_sword", "iron_axe", "iron_mace", "iron_dagger", "iron_staff", "iron_bow", "iron_spear", "steel_sword"],
		"liked": ["bone_dagger", "copper_ingot", "iron_ingot", "gold_ingot"],
		"disliked": ["cooked_sardine", "fish_stew", "stone"],
	},
	"pip": {
		"loved": ["healing_potion", "bandage", "cooked_salmon", "hearty_soup", "fish_stew"],
		"liked": ["cooked_trout", "cooked_sardine", "copper_ore", "iron_ore", "fur", "bone"],
		"disliked": ["iron_sword", "iron_axe", "iron_mace", "iron_spear"],
	},
}

# Archetype fallback preferences for procedural NPCs keyed by archetype.
# Only "liked" and "disliked" lists — no "loved" at archetype level.
const ARCHETYPE_PREFERENCES: Dictionary = {
	"warrior": {
		"liked": ["iron_sword", "iron_axe", "iron_mace", "iron_spear", "steel_sword", "iron_chest", "iron_helm", "iron_legs", "healing_potion", "bandage"],
		"disliked": ["iron_staff", "sardine", "trout", "salmon"],
	},
	"mage": {
		"liked": ["iron_staff", "copper_ore", "iron_ore", "gold_ore", "copper_ingot", "iron_ingot", "gold_ingot", "healing_potion"],
		"disliked": ["iron_axe", "iron_mace", "iron_spear", "bone_dagger"],
	},
	"rogue": {
		"liked": ["iron_dagger", "bone_dagger", "iron_bow", "healing_potion", "bandage", "leather_armor"],
		"disliked": ["iron_mace", "iron_spear", "stone"],
	},
	"ranger": {
		"liked": ["iron_bow", "cooked_salmon", "cooked_trout", "cooked_sardine", "fish_stew", "oak_log", "pine_log", "birch_log", "fur"],
		"disliked": ["iron_mace", "iron_chest", "stone"],
	},
	"merchant": {
		"liked": ["copper_ore", "iron_ore", "gold_ore", "copper_ingot", "iron_ingot", "gold_ingot", "fur", "bone", "healing_potion", "bandage", "cooked_salmon"],
		"disliked": [],
	},
}

const REACTIONS: Dictionary = {
	"loved": [
		"This is exactly what I needed!",
		"You know me well. Thank you!",
		"I can't believe you found one of these!",
	],
	"liked": [
		"Oh, that's nice of you. Thanks!",
		"I appreciate this.",
		"How thoughtful!",
	],
	"neutral": [
		"Hmm, thanks I guess.",
		"I'll find a use for this.",
		"That's... something.",
	],
	"disliked": [
		"I don't really need this...",
		"Not sure what I'd do with that.",
		"Uh... thanks.",
	],
}


static func get_preference(npc_id: String, archetype: String, item_id: String) -> String:
	# Check named NPC table first.
	if NPC_PREFERENCES.has(npc_id):
		var prefs: Dictionary = NPC_PREFERENCES[npc_id]
		if item_id in prefs.get("loved", []):
			return "loved"
		if item_id in prefs.get("liked", []):
			return "liked"
		if item_id in prefs.get("disliked", []):
			return "disliked"
		return "neutral"

	# Fall back to archetype table for procedural NPCs.
	if ARCHETYPE_PREFERENCES.has(archetype):
		var prefs: Dictionary = ARCHETYPE_PREFERENCES[archetype]
		if item_id in prefs.get("liked", []):
			return "liked"
		if item_id in prefs.get("disliked", []):
			return "disliked"

	return "neutral"


static func get_reaction(preference: String) -> String:
	var lines: Array = REACTIONS.get(preference, REACTIONS["neutral"])
	return lines[randi() % lines.size()]
