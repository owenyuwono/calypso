extends RefCounted
## Parses and validates LLM JSON responses into action dictionaries.

const ActionSchema = preload("res://scripts/llm/action_schema.gd")

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
	if result.action not in ActionSchema.VALID_ACTIONS:
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

static func parse_chat(ollama_response: Dictionary) -> Dictionary:
	var result := {"valid": false, "dialogue": "", "error": ""}

	var message: Dictionary = ollama_response.get("message", {})
	var content: String = message.get("content", "")

	if content.is_empty():
		result.error = "Empty response content"
		return result

	var cleaned := _clean_chat_response(content)
	if cleaned.is_empty():
		result.error = "Empty after cleaning"
		return result

	# Truncate to first sentence if too long
	if cleaned.length() > 200:
		var period_pos := cleaned.find(".")
		if period_pos > 0 and period_pos < 200:
			cleaned = cleaned.substr(0, period_pos + 1)
		else:
			cleaned = cleaned.substr(0, 200) + "..."

	result.valid = true
	result.dialogue = cleaned
	return result

static func _clean_chat_response(text: String) -> String:
	var cleaned := text.strip_edges()

	# Strip JSON wrapping — if it looks like {"response": "..."} or {"dialogue": "..."}
	if cleaned.begins_with("{") and cleaned.ends_with("}"):
		var json := JSON.new()
		if json.parse(cleaned) == OK and json.data is Dictionary:
			var data: Dictionary = json.data
			for key in ["response", "dialogue", "text", "content", "message"]:
				if data.has(key) and data[key] is String:
					cleaned = data[key].strip_edges()
					break

	# Strip surrounding quotes
	if cleaned.length() >= 2:
		if (cleaned.begins_with("\"") and cleaned.ends_with("\"")) or \
		   (cleaned.begins_with("'") and cleaned.ends_with("'")):
			cleaned = cleaned.substr(1, cleaned.length() - 2).strip_edges()

	# Strip common LLM prefixes
	for prefix in ["Response:", "Reply:", "Answer:", "Output:"]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length()).strip_edges()
			break

	# Strip NPC name prefixes like "Kael:" or "Lyra:"
	var colon_pos := cleaned.find(":")
	if colon_pos > 0 and colon_pos < 20:
		var before_colon := cleaned.substr(0, colon_pos).strip_edges()
		# If the part before colon is a single word (likely a name), strip it
		if " " not in before_colon and before_colon[0] == before_colon[0].to_upper():
			cleaned = cleaned.substr(colon_pos + 1).strip_edges()

	return cleaned

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
