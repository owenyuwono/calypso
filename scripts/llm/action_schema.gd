extends RefCounted
## JSON schema for Ollama's structured output (format parameter).

const VALID_ACTIONS: Array = ["move_to", "pick_up", "drop_item", "use_object", "talk_to", "wait"]

## Returns the JSON schema dict for Ollama's `format` parameter.
## This enforces grammar-constrained decoding for guaranteed valid JSON.
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
				"description": "What to say (only used with talk_to action)",
			},
			"goal_update": {
				"type": "string",
				"description": "New goal if the current goal should change, empty string to keep current goal",
			},
		},
		"required": ["thinking", "action", "target"],
	}
