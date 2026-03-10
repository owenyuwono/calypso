extends RefCounted
## Static item definitions.

const ITEMS: Dictionary = {
	# Consumables
	"healing_potion": {"name": "Healing Potion", "type": "consumable", "value": 20, "heal": 30},
	# Weapons
	"basic_sword": {"name": "Basic Sword", "type": "weapon", "value": 50, "atk_bonus": 5},
	"iron_sword": {"name": "Iron Sword", "type": "weapon", "value": 150, "atk_bonus": 10},
	# Armor
	"basic_shield": {"name": "Basic Shield", "type": "armor", "value": 40, "def_bonus": 3},
	"iron_shield": {"name": "Iron Shield", "type": "armor", "value": 120, "def_bonus": 5},
	# Monster drops (sell only)
	"jelly": {"name": "Jelly", "type": "material", "value": 8},
	"fur": {"name": "Fur", "type": "material", "value": 15},
	"goblin_tooth": {"name": "Goblin Tooth", "type": "material", "value": 25},
	"bone": {"name": "Bone", "type": "material", "value": 20},
	"dark_crystal": {"name": "Dark Crystal", "type": "material", "value": 50},
}

static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

static func get_item_name(item_id: String) -> String:
	var item := get_item(item_id)
	return item.get("name", item_id)
