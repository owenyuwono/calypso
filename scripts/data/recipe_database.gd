extends RefCounted
## Static recipe definitions for cooking, smithing, and crafting skills.

class_name RecipeDatabase

const RECIPES: Dictionary = {
	# Cooking
	"cooked_sardine": {
		"name": "Cooked Sardine",
		"skill_id": "cooking",
		"required_level": 1,
		"inputs": {"sardine": 1},
		"outputs": {"cooked_sardine": 1},
		"xp": 8,
		"craft_time": 2.0,
	},
	"cooked_trout": {
		"name": "Cooked Trout",
		"skill_id": "cooking",
		"required_level": 3,
		"inputs": {"trout": 1},
		"outputs": {"cooked_trout": 1},
		"xp": 15,
		"craft_time": 3.0,
	},
	"cooked_salmon": {
		"name": "Cooked Salmon",
		"skill_id": "cooking",
		"required_level": 5,
		"inputs": {"salmon": 1},
		"outputs": {"cooked_salmon": 1},
		"xp": 25,
		"craft_time": 4.0,
	},
	"fish_stew": {
		"name": "Fish Stew",
		"skill_id": "cooking",
		"required_level": 4,
		"inputs": {"trout": 1, "log": 1},
		"outputs": {"fish_stew": 1},
		"xp": 20,
		"craft_time": 5.0,
	},
	"hearty_soup": {
		"name": "Hearty Soup",
		"skill_id": "cooking",
		"required_level": 7,
		"inputs": {"salmon": 1, "log": 1, "stone": 1},
		"outputs": {"hearty_soup": 1},
		"xp": 35,
		"craft_time": 6.0,
	},
	# Smithing
	"copper_ingot": {
		"name": "Copper Ingot",
		"skill_id": "smithing",
		"required_level": 1,
		"inputs": {"copper_ore": 2},
		"outputs": {"copper_ingot": 1},
		"xp": 10,
		"craft_time": 3.0,
	},
	"iron_ingot": {
		"name": "Iron Ingot",
		"skill_id": "smithing",
		"required_level": 3,
		"inputs": {"iron_ore": 2},
		"outputs": {"iron_ingot": 1},
		"xp": 20,
		"craft_time": 4.0,
	},
	"gold_ingot": {
		"name": "Gold Ingot",
		"skill_id": "smithing",
		"required_level": 6,
		"inputs": {"gold_ore": 2},
		"outputs": {"gold_ingot": 1},
		"xp": 35,
		"craft_time": 5.0,
	},
	"copper_sword": {
		"name": "Copper Sword",
		"skill_id": "smithing",
		"required_level": 2,
		"inputs": {"copper_ingot": 2, "log": 1},
		"outputs": {"copper_sword": 1},
		"xp": 15,
		"craft_time": 5.0,
	},
	"iron_mace": {
		"name": "Iron Mace",
		"skill_id": "smithing",
		"required_level": 5,
		"inputs": {"iron_ingot": 2, "oak_log": 1},
		"outputs": {"iron_mace": 1},
		"xp": 30,
		"craft_time": 6.0,
	},
	# Crafting
	"bandage": {
		"name": "Bandage",
		"skill_id": "crafting",
		"required_level": 1,
		"inputs": {"branch": 2, "jelly": 1},
		"outputs": {"bandage": 1},
		"xp": 8,
		"craft_time": 2.0,
	},
	"healing_potion_recipe": {
		"name": "Healing Potion",
		"skill_id": "crafting",
		"required_level": 3,
		"inputs": {"jelly": 2, "stone": 1},
		"outputs": {"healing_potion": 1},
		"xp": 15,
		"craft_time": 3.0,
	},
	"leather_armor": {
		"name": "Leather Armor",
		"skill_id": "crafting",
		"required_level": 4,
		"inputs": {"fur": 3},
		"outputs": {"leather_armor": 1},
		"xp": 25,
		"craft_time": 5.0,
	},
	"bone_dagger": {
		"name": "Bone Dagger",
		"skill_id": "crafting",
		"required_level": 5,
		"inputs": {"bone": 2, "branch": 1},
		"outputs": {"bone_dagger": 1},
		"xp": 30,
		"craft_time": 4.0,
	},
}

static func get_recipe(id: String) -> Dictionary:
	return RECIPES.get(id, {})

static func get_recipes_for_skill(skill_id: String) -> Array:
	var result: Array = []
	for recipe_id in RECIPES:
		var recipe: Dictionary = RECIPES[recipe_id]
		if recipe.get("skill_id", "") == skill_id:
			result.append(recipe_id)
	return result
