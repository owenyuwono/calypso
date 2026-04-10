extends RefCounted
## Static item definitions. Minimal placeholder set for zombie survival pivot.

const ITEMS: Dictionary = {
	# Weapons
	"fists": {"name": "Fists", "description": "Bare knuckles — better than nothing.", "icon": "", "mesh": "", "type": "weapon", "slot_type": "main_hand", "weapon_type": "blunt", "phys_type": "blunt", "value": 0, "atk_bonus": 0, "attack_speed": 1.5},
	"wooden_plank": {"name": "Wooden Plank", "description": "A heavy plank pried from a fence. Crushes skulls in a pinch.", "icon": "", "mesh": "", "type": "weapon", "slot_type": "main_hand", "weapon_type": "blunt", "phys_type": "blunt", "value": 5, "atk_bonus": 4, "attack_speed": 0.9},
	# Ranged weapons
	"pistol": {"name": "Pistol", "description": "A worn 9mm semi-auto. Reliable enough.", "icon": "", "mesh": "", "type": "weapon", "slot_type": "main_hand", "weapon_type": "pistol", "phys_type": "pierce", "value": 0, "atk_bonus": 3, "attack_speed": 0.12, "is_ranged": true, "magazine_size": 12, "reload_time": 1.5, "ammo_type": "bullet"},
	# Consumables
	"bandage": {"name": "Bandage", "description": "Strips of cloth that staunch bleeding wounds.", "icon": "", "mesh": "", "type": "consumable", "heal": 20, "value": 8},
	# Ammo
	"ammo_bullet": {"name": "Bullets", "description": "Standard 9mm rounds.", "icon": "", "mesh": "", "type": "ammo", "ammo_type": "bullet", "count": 12, "value": 3},
}

# Armor/phys-type resistance tables — single source of truth for damage pipeline
const RESISTANCE_MULTIPLIERS: Dictionary = {
	"fatal": 2.0, "weak": 1.5, "neutral": 1.0, "resist": 0.5, "immune": 0.0
}
const ARMOR_PHYS_TYPE_TABLE: Dictionary = {
	"heavy":  {"slash": "resist", "pierce": "neutral", "blunt": "weak"},
	"medium": {"slash": "neutral", "pierce": "weak",   "blunt": "neutral"},
	"light":  {"slash": "weak",   "pierce": "neutral", "blunt": "neutral"},
}

static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})
