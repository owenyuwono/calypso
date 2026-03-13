extends RefCounted
## JSON schema for Ollama's structured output — adventurer action set.

const VALID_ACTIONS: Array = ["move_to", "attack", "use_item", "buy_item", "sell_item", "talk_to", "wait", "rest"]

static func get_schema() -> Dictionary:
	return {
		"type": "object",
		"properties": {
			"thinking": {
				"type": "string",
				"description": "Brief internal reasoning about what to do next",
			},
			"action": {
				"type": "string",
				"enum": VALID_ACTIONS,
				"description": "The action to take",
			},
			"target": {
				"type": "string",
				"description": "Entity ID, location ID, or item ID to act on",
			},
			"dialogue": {
				"type": "string",
				"description": "What to say (only for talk_to action)",
			},
			"action_data": {
				"type": "object",
				"description": "Extra data for buy_item/sell_item: {item_id, count}",
				"properties": {
					"item_id": {"type": "string"},
					"count": {"type": "integer"},
				},
			},
			"goal_update": {
				"type": "string",
				"description": "New goal if the current goal should change, empty string to keep current",
			},
		},
		"required": ["thinking", "action", "target"],
	}
