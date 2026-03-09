extends RefCounted
## Parses and validates LLM JSON responses into action dictionaries.

const VALID_ACTIONS: Array = ["move_to", "pick_up", "drop_item", "use_object", "talk_to", "wait"]

## Parse the Ollama API response and extract the action.
## Returns {"valid": true/false, "action": str, "target": str, "dialogue": str, "thinking": str, "goal_update": str, "error": str}
static func parse(ollama_response: Dictionary) -> Dictionary:
	var result := {
		"valid": false,
		"action": "wait",
		"target": "",
		"dialogue": "",
		"thinking": "",
		"goal_update": "",
		"error": "",
	}

	# Extract message content from Ollama response
	var message: Dictionary = ollama_response.get("message", {})
	var content: String = message.get("content", "")

	if content.is_empty():
		result.error = "Empty response content"
		return result

	# Parse JSON from content
	var json := JSON.new()
	var parse_err := json.parse(content)
	if parse_err != OK:
		result.error = "JSON parse error: %s" % json.get_error_message()
		return result

	if not json.data is Dictionary:
		result.error = "Response is not a JSON object"
		return result

	var data: Dictionary = json.data
	return validate(data)

## Validate an already-parsed action dictionary.
static func validate(data: Dictionary) -> Dictionary:
	var result := {
		"valid": false,
		"action": "wait",
		"target": "",
		"dialogue": "",
		"thinking": "",
		"goal_update": "",
		"error": "",
	}

	# Extract fields
	result.thinking = str(data.get("thinking", ""))
	result.action = str(data.get("action", "wait"))
	result.target = str(data.get("target", ""))
	result.dialogue = str(data.get("dialogue", ""))
	result.goal_update = str(data.get("goal_update", ""))

	# Validate action
	if result.action not in VALID_ACTIONS:
		result.error = "Invalid action: '%s'" % result.action
		result.action = "wait"
		return result

	# Validate target for actions that need one
	if result.action in ["move_to", "pick_up", "drop_item", "use_object", "talk_to"]:
		if result.target.is_empty():
			result.error = "Action '%s' requires a target" % result.action
			result.action = "wait"
			return result

	# Validate dialogue for talk_to
	if result.action == "talk_to" and result.dialogue.is_empty():
		result.dialogue = "..."

	result.valid = true
	return result
