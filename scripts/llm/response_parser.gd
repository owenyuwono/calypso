extends RefCounted
## Parses and validates LLM JSON responses into action dictionaries.

const VALID_ACTIONS: Array = ["move_to", "attack", "use_item", "buy_item", "sell_item", "talk_to", "wait"]

static func parse(ollama_response: Dictionary) -> Dictionary:
	var result := _empty_result()

	var message: Dictionary = ollama_response.get("message", {})
	var content: String = message.get("content", "")

	if content.is_empty():
		result.error = "Empty response content"
		return result

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

static func validate(data: Dictionary) -> Dictionary:
	var result := _empty_result()

	result.thinking = str(data.get("thinking", ""))
	result.action = str(data.get("action", "wait"))
	result.target = str(data.get("target", ""))
	result.dialogue = str(data.get("dialogue", ""))
	result.goal_update = str(data.get("goal_update", ""))

	# Parse action_data for buy/sell
	var action_data = data.get("action_data", {})
	if action_data is Dictionary:
		result["action_data"] = action_data
	else:
		result["action_data"] = {}

	# Validate action
	if result.action not in VALID_ACTIONS:
		result.error = "Invalid action: '%s'" % result.action
		result.action = "wait"
		return result

	# Validate target for actions that need one
	if result.action in ["move_to", "attack", "use_item", "buy_item", "sell_item", "talk_to"]:
		if result.target.is_empty():
			result.error = "Action '%s' requires a target" % result.action
			result.action = "wait"
			return result

	# Validate dialogue for talk_to
	if result.action == "talk_to" and result.dialogue.is_empty():
		result.dialogue = "..."

	# Ensure action_data has defaults for buy/sell
	if result.action in ["buy_item", "sell_item"]:
		if not result["action_data"].has("count"):
			result["action_data"]["count"] = 1

	result.valid = true
	return result

static func _empty_result() -> Dictionary:
	return {
		"valid": false,
		"action": "wait",
		"target": "",
		"dialogue": "",
		"thinking": "",
		"goal_update": "",
		"action_data": {},
		"error": "",
	}
