class_name NpcGenerator
## Procedural NPC loadout generator.
## Generates loadout dictionaries compatible with NpcLoadouts.LOADOUTS format.

const ARCHETYPES: Dictionary = {
	"warrior": {
		"weight": 30,
		"weapon_pref": "sword",
		"boldness_range": [0.6, 1.0],
		"generosity_range": [0.2, 0.8],
		"sociability_range": [0.3, 0.7],
		"curiosity_range": [0.2, 0.6],
		"default_goal": "hunt",
		"models": ["Knight", "Barbarian"],
	},
	"mage": {
		"weight": 25,
		"weapon_pref": "staff",
		"boldness_range": [0.3, 0.7],
		"generosity_range": [0.3, 0.9],
		"sociability_range": [0.4, 0.8],
		"curiosity_range": [0.5, 0.9],
		"default_goal": "hunt",
		"models": ["Mage"],
	},
	"rogue": {
		"weight": 20,
		"weapon_pref": "dagger",
		"boldness_range": [0.5, 0.9],
		"generosity_range": [0.1, 0.5],
		"sociability_range": [0.2, 0.6],
		"curiosity_range": [0.4, 0.8],
		"default_goal": "hunt",
		"models": ["Rogue"],
	},
	"ranger": {
		"weight": 15,
		"weapon_pref": "axe",
		"boldness_range": [0.4, 0.8],
		"generosity_range": [0.3, 0.7],
		"sociability_range": [0.3, 0.6],
		"curiosity_range": [0.6, 1.0],
		"default_goal": "hunt",
		"models": ["Knight", "Barbarian"],
	},
	"merchant": {
		"weight": 10,
		"weapon_pref": "mace",
		"boldness_range": [0.2, 0.5],
		"generosity_range": [0.4, 0.9],
		"sociability_range": [0.6, 1.0],
		"curiosity_range": [0.3, 0.6],
		"default_goal": "vend",
		"models": ["Rogue", "Mage"],
	},
}

# ~200 fantasy names, excluding existing NPCs (Kael, Lyra, Bjorn, Sera, Thane, Mira, Dusk)
const NAME_POOL: Array = [
	# Nordic
	"Aldric", "Astrid", "Bjolv", "Brandulf", "Dagny", "Eirik", "Eldrun", "Fenrir",
	"Freya", "Gunnar", "Halvar", "Helga", "Ingvar", "Ivar", "Jorvik", "Ketil",
	"Leif", "Lofn", "Magnus", "Njord", "Olaf", "Ragna", "Sigrid", "Sigurd",
	"Skald", "Solveig", "Sven", "Torben", "Torsten", "Ulfric", "Valdis", "Vigdis",
	# Celtic
	"Aelwyn", "Ailish", "Bran", "Brynn", "Cael", "Caoimhe", "Ciaran", "Dara",
	"Deirdre", "Elowen", "Emer", "Fenn", "Fionn", "Gareth", "Gwion", "Isolde",
	"Keir", "Lachlan", "Maeve", "Merrick", "Niamh", "Oisin", "Orla", "Riona",
	"Rowan", "Saoirse", "Siobhan", "Tadhg", "Tara", "Tristan",
	# Generic fantasy
	"Adan", "Alara", "Alden", "Aldwyn", "Alek", "Alina", "Alric", "Amber",
	"Ansel", "Ardan", "Arlan", "Arlen", "Arvin", "Asher", "Ashton", "Aspen",
	"Avery", "Axel", "Ayla", "Azra", "Bael", "Barek", "Beren", "Blaine",
	"Blake", "Bram", "Brant", "Bren", "Briar", "Brice", "Brin", "Brix",
	"Brock", "Cade", "Cael", "Calder", "Calla", "Calyx", "Caren", "Carys",
	"Cass", "Cassia", "Cedar", "Celn", "Cera", "Cerin", "Ceth", "Cian",
	"Cira", "Circe", "Ciro", "Cith", "Clair", "Clover", "Corin", "Cress",
	"Crispin", "Crow", "Cullen", "Cyan", "Dael", "Dain", "Dale", "Damek",
	"Daven", "Daveth", "Dawn", "Dax", "Dean", "Deln", "Dena", "Deryn",
	"Deven", "Dirk", "Dorin", "Drake", "Drew", "Drin", "Durin", "Dwyn",
	"Eadric", "Edain", "Edric", "Egan", "Elara", "Eldan", "Eldin", "Eldon",
	"Elian", "Elira", "Elith", "Elke", "Ellorin", "Elric", "Elrin", "Elsin",
	"Elvan", "Ember", "Emeth", "Emrys", "Enan", "Enid", "Ennis", "Enora",
	"Eran", "Erith", "Erlan", "Eryn", "Ethan", "Evan", "Evara", "Evren",
	"Faen", "Faelan", "Falen", "Fallon", "Farren", "Faye", "Feran", "Ferin",
	"Feryn", "Finnian", "Fira", "Firen", "Firth", "Flan", "Flint", "Flynn",
	"Forin", "Frath", "Frith", "Frost", "Fyren", "Gale", "Galen", "Garan",
	"Garet", "Garin", "Garyn", "Gavin", "Geth", "Gildan", "Gilrin", "Giran",
	"Girth", "Glen", "Glyn", "Goran", "Grath", "Grend", "Grent", "Grim",
	"Grith", "Gwen", "Gwyn", "Hadwin", "Hael", "Haelin", "Hagen", "Halen",
	"Haleth", "Halia", "Halin", "Halon", "Haran", "Haren", "Hareth", "Harlin",
	"Harrin", "Harwin", "Hask", "Haven", "Hawn", "Heldrin", "Helin", "Helrin",
	"Heron", "Heth", "Hildan", "Hiran", "Hirin", "Horin", "Hrath", "Hrin",
	"Hyrin", "Idris", "Ildan", "Ileth", "Ilin", "Ilrin", "Ilvan", "Imara",
	"Imren", "Inara", "Ineth", "Innis", "Iris", "Irith", "Irvan", "Iryn",
]

# Weapon item IDs indexed by weapon type and tier
const WEAPON_TIERS: Dictionary = {
	"sword": {
		"poor": "basic_sword",
		"average": "iron_sword",
		"wealthy": "steel_sword",
	},
	"axe": {
		"poor": "basic_axe",
		"average": "iron_axe",
		"wealthy": "steel_axe",
	},
	"mace": {
		"poor": "basic_mace",
		"average": "iron_mace",
		"wealthy": "steel_mace",
	},
	"dagger": {
		"poor": "basic_dagger",
		"average": "iron_dagger",
		"wealthy": "steel_dagger",
	},
	"staff": {
		"poor": "basic_staff",
		"average": "iron_staff",
		"wealthy": "steel_staff",
	},
}

# Shield item IDs by tier
const SHIELD_TIERS: Dictionary = {
	"poor": "basic_shield",
	"average": "iron_shield",
	"wealthy": "steel_shield",
}

# Gold ranges by tier
const GOLD_RANGES: Dictionary = {
	"poor":    [20,  50],
	"average": [50,  150],
	"wealthy": [150, 300],
}

# Potions by tier
const POTION_COUNTS: Dictionary = {
	"poor":    [1, 2],
	"average": [2, 4],
	"wealthy": [4, 6],
}


## Generate a single NPC loadout dictionary.
## used_names: names already taken — chosen name will not appear in this list.
static func generate_npc(used_names: Array) -> Dictionary:
	var archetype_id: String = _pick_archetype()
	var archetype: Dictionary = ARCHETYPES[archetype_id]
	var tier: String = _pick_tier()
	var name: String = _pick_name(used_names)
	var loadout: Dictionary = _generate_loadout(archetype_id, tier)

	return {
		"name": name,
		"archetype": archetype_id,
		"model": archetype["models"][randi() % archetype["models"].size()],
		"trait": archetype_id,
		"boldness": _rand_range(archetype["boldness_range"][0], archetype["boldness_range"][1]),
		"generosity": _rand_range(archetype["generosity_range"][0], archetype["generosity_range"][1]),
		"sociability": _rand_range(archetype["sociability_range"][0], archetype["sociability_range"][1]),
		"curiosity": _rand_range(archetype["curiosity_range"][0], archetype["curiosity_range"][1]),
		"default_goal": archetype["default_goal"],
		"items": loadout["items"],
		"equip": loadout["equip"],
		"gold": loadout["gold"],
	}


## Generate N NPC loadouts with unique names.
static func generate_npcs(count: int) -> Array:
	var result: Array = []
	var used_names: Array = []
	for i: int in range(count):
		var loadout: Dictionary = generate_npc(used_names)
		used_names.append(loadout["name"])
		result.append(loadout)
	return result


## Pick a random archetype based on weights.
static func _pick_archetype() -> String:
	var total_weight: int = 0
	for key: String in ARCHETYPES:
		total_weight += ARCHETYPES[key]["weight"]

	var roll: int = randi() % total_weight
	var accumulated: int = 0
	for key: String in ARCHETYPES:
		accumulated += ARCHETYPES[key]["weight"]
		if roll < accumulated:
			return key

	# Fallback — should never reach here
	return "warrior"


## Pick a random name not in used_names.
static func _pick_name(used_names: Array) -> String:
	var available: Array = []
	for candidate: String in NAME_POOL:
		if not used_names.has(candidate):
			available.append(candidate)

	if available.is_empty():
		# Pool exhausted — generate a fallback with numeric suffix
		return "Adventurer_%d" % randi_range(1000, 9999)

	return available[randi() % available.size()]


## Pick a wealth tier using configured probabilities.
static func _pick_tier() -> String:
	var roll: int = randi() % 100
	if roll < 40:
		return "poor"
	elif roll < 80:
		return "average"
	else:
		return "wealthy"


## Generate items and equipment for a given archetype and wealth tier.
static func _generate_loadout(archetype: String, tier: String) -> Dictionary:
	var archetype_data: Dictionary = ARCHETYPES[archetype]
	var weapon_pref: String = archetype_data["weapon_pref"]
	var weapon_id: String = WEAPON_TIERS[weapon_pref][tier]

	var gold_range: Array = GOLD_RANGES[tier]
	var gold: int = randi_range(gold_range[0], gold_range[1])

	var potion_range: Array = POTION_COUNTS[tier]
	var potion_count: int = randi_range(potion_range[0], potion_range[1])

	var items: Dictionary = {}
	items[weapon_id] = 1
	if potion_count > 0:
		items["healing_potion"] = potion_count

	var equip: Array = [weapon_id]

	# Warriors and rangers get a shield at average+ tier
	if (archetype == "warrior" or archetype == "ranger") and tier != "poor":
		var shield_id: String = SHIELD_TIERS[tier]
		items[shield_id] = 1
		equip.append(shield_id)

	# Merchants stock extra sell inventory instead of a shield
	if archetype == "merchant":
		items = _generate_merchant_inventory(tier, weapon_id, potion_count)
		equip = [weapon_id]

	return {
		"items": items,
		"equip": equip,
		"gold": gold,
	}


## Generate a merchant's sell inventory (weapons + potions for resale).
static func _generate_merchant_inventory(tier: String, own_weapon: String, potion_count: int) -> Dictionary:
	var inv: Dictionary = {}

	# Personal weapon
	inv[own_weapon] = 1

	# Potions to sell
	var sell_potions: int = potion_count + randi_range(2, 5)
	inv["healing_potion"] = sell_potions

	# Stock a selection of basic weapons to sell
	var stock_weapons: Array = ["basic_sword", "basic_axe", "basic_mace", "basic_dagger", "basic_staff"]
	for weapon_id: String in stock_weapons:
		inv[weapon_id] = randi_range(1, 3)

	# Wealthier merchants stock mid-tier weapons too
	if tier == "average" or tier == "wealthy":
		var mid_weapons: Array = ["iron_sword", "iron_axe", "iron_mace", "iron_dagger", "iron_staff"]
		for weapon_id: String in mid_weapons:
			inv[weapon_id] = randi_range(1, 2)

	if tier == "wealthy":
		var high_weapons: Array = ["steel_sword", "steel_axe", "steel_mace"]
		for weapon_id: String in high_weapons:
			inv[weapon_id] = 1

	return inv


## Return a random float in [low, high].
static func _rand_range(low: float, high: float) -> float:
	return low + randf() * (high - low)
