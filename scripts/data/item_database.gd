extends RefCounted
## Static item definitions.

const ITEMS: Dictionary = {
	# Consumables
	"healing_potion": {"name": "Healing Potion", "type": "consumable", "value": 20, "heal": 30},
	# Swords (required_skill: "sword")
	"basic_sword":   {"name": "Basic Sword",   "type": "weapon", "slot_type": "main_hand", "weapon_type": "sword", "value": 50,   "atk_bonus": 5,  "required_skill": "sword", "required_level": 1},
	"iron_sword":    {"name": "Iron Sword",    "type": "weapon", "slot_type": "main_hand", "weapon_type": "sword", "value": 150,  "atk_bonus": 10, "required_skill": "sword", "required_level": 3},
	"steel_sword":   {"name": "Steel Sword",   "type": "weapon", "slot_type": "main_hand", "weapon_type": "sword", "value": 400,  "atk_bonus": 15, "required_skill": "sword", "required_level": 5},
	"mithril_sword": {"name": "Mithril Sword", "type": "weapon", "slot_type": "main_hand", "weapon_type": "sword", "value": 800,  "atk_bonus": 20, "required_skill": "sword", "required_level": 7},
	"dragon_sword":  {"name": "Dragon Sword",  "type": "weapon", "slot_type": "main_hand", "weapon_type": "sword", "value": 1500, "atk_bonus": 25, "required_skill": "sword", "required_level": 9},
	# Axes (required_skill: "axe")
	"basic_axe":     {"name": "Basic Axe",     "type": "weapon", "slot_type": "main_hand", "weapon_type": "axe", "value": 50,   "atk_bonus": 5,  "required_skill": "axe", "required_level": 1},
	"iron_axe":      {"name": "Iron Axe",      "type": "weapon", "slot_type": "main_hand", "weapon_type": "axe", "value": 150,  "atk_bonus": 10, "required_skill": "axe", "required_level": 3},
	"steel_axe":     {"name": "Steel Axe",     "type": "weapon", "slot_type": "main_hand", "weapon_type": "axe", "value": 400,  "atk_bonus": 15, "required_skill": "axe", "required_level": 5},
	"mithril_axe":   {"name": "Mithril Axe",   "type": "weapon", "slot_type": "main_hand", "weapon_type": "axe", "value": 800,  "atk_bonus": 20, "required_skill": "axe", "required_level": 7},
	"dragon_axe":    {"name": "Dragon Axe",    "type": "weapon", "slot_type": "main_hand", "weapon_type": "axe", "value": 1500, "atk_bonus": 25, "required_skill": "axe", "required_level": 9},
	# Maces (required_skill: "mace")
	"basic_mace":    {"name": "Basic Mace",    "type": "weapon", "slot_type": "main_hand", "weapon_type": "mace", "value": 50,   "atk_bonus": 5,  "required_skill": "mace", "required_level": 1},
	"iron_mace":     {"name": "Iron Mace",     "type": "weapon", "slot_type": "main_hand", "weapon_type": "mace", "value": 150,  "atk_bonus": 10, "required_skill": "mace", "required_level": 3},
	"steel_mace":    {"name": "Steel Mace",    "type": "weapon", "slot_type": "main_hand", "weapon_type": "mace", "value": 400,  "atk_bonus": 15, "required_skill": "mace", "required_level": 5},
	"mithril_mace":  {"name": "Mithril Mace",  "type": "weapon", "slot_type": "main_hand", "weapon_type": "mace", "value": 800,  "atk_bonus": 20, "required_skill": "mace", "required_level": 7},
	"dragon_mace":   {"name": "Dragon Mace",   "type": "weapon", "slot_type": "main_hand", "weapon_type": "mace", "value": 1500, "atk_bonus": 25, "required_skill": "mace", "required_level": 9},
	# Daggers (required_skill: "dagger", attack_speed: 0.7, lower atk_bonus)
	"basic_dagger":   {"name": "Basic Dagger",   "type": "weapon", "slot_type": "main_hand", "weapon_type": "dagger", "value": 50,   "atk_bonus": 4,  "attack_speed": 0.7, "required_skill": "dagger", "required_level": 1},
	"iron_dagger":    {"name": "Iron Dagger",    "type": "weapon", "slot_type": "main_hand", "weapon_type": "dagger", "value": 150,  "atk_bonus": 8,  "attack_speed": 0.7, "required_skill": "dagger", "required_level": 3},
	"steel_dagger":   {"name": "Steel Dagger",   "type": "weapon", "slot_type": "main_hand", "weapon_type": "dagger", "value": 400,  "atk_bonus": 12, "attack_speed": 0.7, "required_skill": "dagger", "required_level": 5},
	"mithril_dagger": {"name": "Mithril Dagger", "type": "weapon", "slot_type": "main_hand", "weapon_type": "dagger", "value": 800,  "atk_bonus": 16, "attack_speed": 0.7, "required_skill": "dagger", "required_level": 7},
	"dragon_dagger":  {"name": "Dragon Dagger",  "type": "weapon", "slot_type": "main_hand", "weapon_type": "dagger", "value": 1500, "atk_bonus": 20, "attack_speed": 0.7, "required_skill": "dagger", "required_level": 9},
	# Staves (required_skill: "staff")
	"basic_staff":    {"name": "Basic Staff",    "type": "weapon", "slot_type": "main_hand", "weapon_type": "staff", "value": 50,   "atk_bonus": 5,  "required_skill": "staff", "required_level": 1},
	"iron_staff":     {"name": "Iron Staff",     "type": "weapon", "slot_type": "main_hand", "weapon_type": "staff", "value": 150,  "atk_bonus": 10, "required_skill": "staff", "required_level": 3},
	"steel_staff":    {"name": "Steel Staff",    "type": "weapon", "slot_type": "main_hand", "weapon_type": "staff", "value": 400,  "atk_bonus": 15, "required_skill": "staff", "required_level": 5},
	"mithril_staff":  {"name": "Mithril Staff",  "type": "weapon", "slot_type": "main_hand", "weapon_type": "staff", "value": 800,  "atk_bonus": 20, "required_skill": "staff", "required_level": 7},
	"dragon_staff":   {"name": "Dragon Staff",   "type": "weapon", "slot_type": "main_hand", "weapon_type": "staff", "value": 1500, "atk_bonus": 25, "required_skill": "staff", "required_level": 9},
	# Shields (type: "armor", required_skill: "constitution")
	"basic_shield":   {"name": "Basic Shield",   "type": "armor", "slot_type": "off_hand", "value": 50,   "def_bonus": 3,  "required_skill": "constitution", "required_level": 1},
	"iron_shield":    {"name": "Iron Shield",    "type": "armor", "slot_type": "off_hand", "value": 150,  "def_bonus": 6,  "required_skill": "constitution", "required_level": 3},
	"steel_shield":   {"name": "Steel Shield",   "type": "armor", "slot_type": "off_hand", "value": 400,  "def_bonus": 9,  "required_skill": "constitution", "required_level": 5},
	"mithril_shield": {"name": "Mithril Shield", "type": "armor", "slot_type": "off_hand", "value": 800,  "def_bonus": 12, "required_skill": "constitution", "required_level": 7},
	"dragon_shield":  {"name": "Dragon Shield",  "type": "armor", "slot_type": "off_hand", "value": 1500, "def_bonus": 15, "required_skill": "constitution", "required_level": 9},
	# Wood (woodcutting drops)
	"log":          {"name": "Log",          "type": "material", "value": 5},
	"oak_log":      {"name": "Oak Log",      "type": "material", "value": 15},
	"ancient_log":  {"name": "Ancient Log",  "type": "material", "value": 40},
	"branch":       {"name": "Branch",       "type": "material", "value": 2},
	# Ore and stone (mining drops)
	"copper_ore":   {"name": "Copper Ore",   "type": "material", "value": 8},
	"iron_ore":     {"name": "Iron Ore",     "type": "material", "value": 20},
	"gold_ore":     {"name": "Gold Ore",     "type": "material", "value": 50},
	"stone":        {"name": "Stone",        "type": "material", "value": 3},
	# Monster drops (sell only)
	"jelly": {"name": "Jelly", "type": "material", "value": 8},
	"fur": {"name": "Fur", "type": "material", "value": 15},
	"goblin_tooth": {"name": "Goblin Tooth", "type": "material", "value": 25},
	"bone": {"name": "Bone", "type": "material", "value": 20},
	"dark_crystal": {"name": "Dark Crystal", "type": "material", "value": 50},
	# Fish (fishing drops)
	"sardine": {"name": "Sardine", "type": "material", "value": 5},
	"trout":   {"name": "Trout",   "type": "material", "value": 12},
	"salmon":  {"name": "Salmon",  "type": "material", "value": 25},
	# Ingots (smithing intermediate)
	"copper_ingot": {"name": "Copper Ingot", "type": "material", "value": 15},
	"iron_ingot":   {"name": "Iron Ingot",   "type": "material", "value": 30},
	"gold_ingot":   {"name": "Gold Ingot",   "type": "material", "value": 60},
	# Cooked food (cooking outputs)
	"cooked_sardine": {"name": "Cooked Sardine", "type": "consumable", "heal": 15, "value": 10},
	"cooked_trout":   {"name": "Cooked Trout",   "type": "consumable", "heal": 30, "value": 25},
	"cooked_salmon":  {"name": "Cooked Salmon",  "type": "consumable", "heal": 50, "value": 45},
	"fish_stew":      {"name": "Fish Stew",      "type": "consumable", "heal": 40, "value": 35},
	"hearty_soup":    {"name": "Hearty Soup",    "type": "consumable", "heal": 70, "value": 60},
	# Crafted goods (crafting + smithing outputs)
	"bandage":      {"name": "Bandage",      "type": "consumable", "heal": 20, "value": 8},
	"leather_armor": {"name": "Leather Armor", "type": "armor",  "slot_type": "torso",     "def_bonus": 3, "value": 40},
	"bone_dagger":   {"name": "Bone Dagger",   "type": "weapon", "slot_type": "main_hand", "weapon_type": "dagger", "atk_bonus": 6, "value": 25},
	"copper_sword":  {"name": "Copper Sword",  "type": "weapon", "slot_type": "main_hand", "weapon_type": "sword",  "atk_bonus": 7, "value": 60},
}

static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

static func get_item_name(item_id: String) -> String:
	var item := get_item(item_id)
	return item.get("name", item_id)
