extends RefCounted
## Static device definitions for the base resource simulation.
## Each device has production/consumption rates (per game-hour) and optional storage capacity.

const DEVICES: Dictionary = {
	# --- Electricity producers ---
	"fuel_generator": {
		"name": "Fuel Generator",
		"category": "producer",
		"produces": {"electricity": 5.0},
		"consumes": {"fuel": 1.0},
		"time_modifier": false,
	},
	"solar_panel": {
		"name": "Solar Panel",
		"category": "producer",
		"produces": {"electricity": 2.0},
		"consumes": {},
		"time_modifier": true,
	},
	# --- Water producers ---
	"water_pump": {
		"name": "Electric Water Pump",
		"category": "producer",
		"produces": {"water": 5.0},
		"consumes": {"electricity": 0.5},
		"time_modifier": false,
	},
	"rainwater_collector": {
		"name": "Rainwater Collector",
		"category": "producer",
		"produces": {"water": 1.0},
		"consumes": {},
		"time_modifier": false,
		"illegal_pre_apocalypse": true,
	},
	"well": {
		"name": "Well",
		"category": "producer",
		"produces": {"water": 3.0},
		"consumes": {},
		"time_modifier": false,
	},
	# --- Farm plots (food producers) ---
	"soil_farm": {
		"name": "Soil Farm Plot",
		"category": "farm",
		"consumes": {"water": 1.0},
		"growth_time_hours": 6.0,
		"food_items": ["tomato", "carrot"],
		"time_modifier": false,
	},
	"vertical_farm": {
		"name": "Vertical Farm",
		"category": "farm",
		"consumes": {"water": 2.0, "electricity": 0.5},
		"growth_time_hours": 3.0,
		"food_items": ["lettuce", "herbs"],
		"time_modifier": false,
	},
	"aquaponics": {
		"name": "Aquaponics",
		"category": "farm",
		"consumes": {"water": 0.5, "electricity": 1.0},
		"growth_time_hours": 2.0,
		"food_items": ["fish", "herbs"],
		"time_modifier": false,
	},
	# --- Storage containers ---
	"battery_bank": {
		"name": "Battery Bank",
		"category": "storage",
		"resource_type": "electricity",
		"capacity": 50.0,
	},
	"water_tank_small": {
		"name": "Small Water Tank",
		"category": "storage",
		"resource_type": "water",
		"capacity": 30.0,
	},
	"water_tank_large": {
		"name": "Large Water Tank",
		"category": "storage",
		"resource_type": "water",
		"capacity": 100.0,
	},
	"jerry_can": {
		"name": "Jerry Can",
		"category": "storage",
		"resource_type": "fuel",
		"capacity": 20.0,
	},
	"fuel_drum": {
		"name": "Fuel Drum",
		"category": "storage",
		"resource_type": "fuel",
		"capacity": 200.0,
	},
	# --- Utility devices ---
	"fridge": {
		"name": "Fridge",
		"category": "utility",
		"consumes": {"electricity": 0.3},
		"effect": "prevent_spoilage",
		"time_modifier": false,
	},
}

static func get_device(device_type: String) -> Dictionary:
	return DEVICES.get(device_type, {})

static func get_devices_by_category(category: String) -> Array:
	var result: Array = []
	for key in DEVICES:
		if DEVICES[key].get("category", "") == category:
			result.append(key)
	return result
