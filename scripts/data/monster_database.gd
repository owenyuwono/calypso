extends RefCounted
## Static monster type definitions with 3D model paths.

const MONSTERS: Dictionary = {
	"slime": {
		"name": "Slime",
		"hp": 20, "atk": 3, "def": 1,
		"xp": 15, "gold": 5,
		"proficiency_xp": 3,
		"drops": [{"item": "jelly", "chance": 0.5}],
		"aggro_range": 6.0, "attack_range": 2.0, "attack_speed": 1.2,
		"color": Color(0.2, 0.8, 0.2),
		"wander_radius": 5.0,
		"model_scene": "res://assets/models/characters/Slime.glb",
		"model_scale": 0.7,
	},
	"wolf": {
		"name": "Wolf",
		"hp": 40, "atk": 7, "def": 3,
		"xp": 30, "gold": 10,
		"proficiency_xp": 6,
		"drops": [{"item": "fur", "chance": 0.4}],
		"aggro_range": 10.0, "attack_range": 2.0, "attack_speed": 1.0,
		"color": Color(0.5, 0.5, 0.5),
		"wander_radius": 8.0,
		# Wolf uses Rogue model with gray tint (no wolf model available)
		"model_scene": "res://assets/models/characters/Rogue_Hooded.glb",
		"model_scale": 0.5,
		"model_tint": Color(0.4, 0.35, 0.3, 0.2),
	},
	"goblin": {
		"name": "Goblin",
		"hp": 60, "atk": 10, "def": 5,
		"xp": 50, "gold": 20,
		"proficiency_xp": 10,
		"drops": [{"item": "goblin_tooth", "chance": 0.3}],
		"aggro_range": 8.0, "attack_range": 2.5, "attack_speed": 0.8,
		"color": Color(0.2, 0.4, 0.1),
		"wander_radius": 6.0,
		# Goblin uses small Skeleton_Minion with green tint
		"model_scene": "res://assets/models/characters/Skeleton_Minion.glb",
		"model_scale": 0.5,
		"model_tint": Color(0.1, 0.3, 0.05, 0.25),
	},
	"skeleton": {
		"name": "Skeleton",
		"hp": 80, "atk": 14, "def": 8,
		"xp": 80, "gold": 30,
		"proficiency_xp": 16,
		"drops": [{"item": "bone", "chance": 0.4}],
		"aggro_range": 10.0, "attack_range": 2.5, "attack_speed": 0.8,
		"color": Color(0.9, 0.9, 0.85),
		"wander_radius": 5.0,
		"model_scene": "res://assets/models/characters/Skeleton_Warrior.glb",
		"model_scale": 0.7,
	},
	"dark_mage": {
		"name": "Dark Mage",
		"hp": 60, "atk": 18, "def": 4,
		"xp": 100, "gold": 40,
		"proficiency_xp": 20,
		"drops": [{"item": "dark_crystal", "chance": 0.25}],
		"aggro_range": 12.0, "attack_range": 3.0, "attack_speed": 1.6,
		"color": Color(0.3, 0.1, 0.4),
		"wander_radius": 4.0,
		"model_scene": "res://assets/models/characters/Skeleton_Mage.glb",
		"model_scale": 0.7,
		"model_tint": Color(0.2, 0.05, 0.3, 0.15),
	},
}

static func get_monster(type_id: String) -> Dictionary:
	return MONSTERS.get(type_id, {})
