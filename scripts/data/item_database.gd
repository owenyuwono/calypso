extends RefCounted
## Static item definitions. Minimal placeholder set for zombie survival pivot.

const ITEMS: Dictionary = {
	# Weapons
	"fists": {"name": "Fists", "description": "Bare knuckles — better than nothing.", "icon": "", "mesh": "", "type": "weapon", "slot_type": "main_hand", "weapon_type": "blunt", "phys_type": "blunt", "value": 0, "atk_bonus": 0, "attack_speed": 1.5},
	"wooden_plank": {"name": "Wooden Plank", "description": "A heavy plank pried from a fence. Crushes skulls in a pinch.", "icon": "", "mesh": "", "type": "weapon", "slot_type": "main_hand", "weapon_type": "blunt", "phys_type": "blunt", "value": 5, "atk_bonus": 4, "attack_speed": 0.9},
	# Consumables
	"bandage": {"name": "Bandage", "description": "Strips of cloth that staunch bleeding wounds.", "icon": "", "mesh": "", "type": "consumable", "heal": 20, "value": 8},
}

static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

static func get_item_name(item_id: String) -> String:
	var item := get_item(item_id)
	return item.get("name", item_id)
