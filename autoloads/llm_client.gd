extends Node
## Async HTTP pool for Ollama API calls with timeout and rate-limiting.

const OLLAMA_BASE_URL: String = "http://localhost:11434"
const OLLAMA_MODEL: String = "qwen3.5:4b"
const LLM_TIMEOUT: float = 60.0
const LLM_TEMPERATURE: float = 0.7
const MAX_CONCURRENT_REQUESTS: int = 10

var _active_requests: int = 0
var _sequence: int = 0  # Monotonic counter for FIFO ordering within same priority tier
var _request_queue: Array = []  # Array of {id, body, priority, seq}
var _http_pool: Array = []  # Reusable HTTPRequest nodes
var _queue_dirty: bool = false  # True when queue has unsorted additions

signal request_completed(request_id: String, response: Dictionary)
signal request_failed(request_id: String, error: String)

func _ready() -> void:
	# Pre-create HTTP request nodes
	for i in MAX_CONCURRENT_REQUESTS:
		var http := HTTPRequest.new()
		http.timeout = LLM_TIMEOUT
		add_child(http)
		_http_pool.append({"node": http, "busy": false, "request_id": ""})

func _process(_delta: float) -> void:
	_process_queue()

func is_available() -> bool:
	return _active_requests < MAX_CONCURRENT_REQUESTS or not _request_queue.is_empty()

func get_active_request_count() -> int:
	return _active_requests

## Send a chat completion request to llama-server (OpenAI-compatible endpoint).
## Returns a request_id. Listen to request_completed/request_failed signals.
##
## Priority levels (lower = dispatched first):
##   1 — player-involved conversations (req_id prefix: conv_player_)
##   2 — NPC-to-NPC conversations      (req_id prefix: conv_)
##   3 — NPC decision-making           (default)
##   4 — memory extraction             (req_id prefix: extract_)
##   5 — background tasks              (req_id prefix: fuzzy_, opinion_, impression_)
func send_chat(request_id: String, messages: Array, format: Dictionary = {}, priority: int = 3) -> String:
	# Deduplication: drop new request if same type+entity already queued.
	# A "duplicate" shares the same request_id prefix (the part up to and including
	# the npc_id), identified by splitting on "_" and matching the first two tokens.
	if _is_duplicate_queued(request_id):
		print("[LLM] Dropping duplicate queued request '%s'" % request_id)
		return request_id

	var body := {
		"model": OLLAMA_MODEL,
		"messages": messages,
		"stream": false,
		"think": false,
		"options": {
			"temperature": LLM_TEMPERATURE,
		},
	}
	if not format.is_empty():
		body["format"] = format

	_sequence += 1
	_request_queue.append({
		"id": request_id,
		"body": body,
		"priority": priority,
		"seq": _sequence,
	})
	_queue_dirty = true
	return request_id

## Returns true if a queued request shares the same type prefix + entity id
## as the incoming request_id, making it a duplicate.
##
## Duplicate logic by request_id pattern:
##   chat_{npc_id}        → dedup key = "chat_{npc_id}"
##   extract_{npc_id}_*   → dedup key = "extract_{npc_id}"
##   conv_{npc_id}_*      → dedup key = "conv_{npc_id}"
##   fuzzy_{npc_id}_*     → dedup key = "fuzzy_{npc_id}"
##   opinion_{npc_id}_*   → dedup key = "opinion_{npc_id}"
##   impression_{npc_id}_ → dedup key = "impression_{npc_id}"
##   {npc_id}             → dedup key = "{npc_id}" (bare decision request)
func _is_duplicate_queued(request_id: String) -> bool:
	var dedup_key := _dedup_key(request_id)
	for queued in _request_queue:
		var queued_id: String = queued.id
		if _dedup_key(queued_id) == dedup_key:
			return true
	return false

## Extracts the deduplication key from a request_id.
## Returns "prefix_npcid" for prefixed ids or the full id for bare npc_id requests.
func _dedup_key(request_id: String) -> String:
	var prefixes: Array = ["conv_player_", "chat_", "extract_", "conv_", "fuzzy_", "opinion_", "impression_", "shop_title_"]
	for prefix in prefixes:
		if request_id.begins_with(prefix):
			return request_id
	# Bare npc_id decision request — use as-is
	return request_id

func _process_queue() -> void:
	if _request_queue.is_empty():
		return

	# Sort by priority ascending (1 = highest), then by seq ascending (lower = earlier).
	# Godot's sort_custom uses introsort (not stable), so seq is required to
	# preserve FIFO order within the same priority tier.
	# Only re-sort when new entries were added since the last sort.
	if _queue_dirty:
		_request_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.priority != b.priority:
				return a.priority < b.priority
			return a.seq < b.seq
		)
		_queue_dirty = false

	for pool_entry in _http_pool:
		if pool_entry.busy:
			continue
		if _request_queue.is_empty():
			break

		# Pop and skip stale entries until we find a live one or exhaust the queue.
		var queued: Dictionary = {}
		while not _request_queue.is_empty():
			var candidate: Dictionary = _request_queue.pop_front()
			if _is_stale(candidate.id):
				print("[LLM] Dropping stale request '%s' (entity gone or dead)" % candidate.id)
				continue
			queued = candidate
			break

		if queued.is_empty():
			break

		_send_request(pool_entry, queued.id, queued.body)

## Returns true if the request is for a specific NPC that no longer exists or is dead.
## Bare npc_id and prefixed "prefix_npcid" requests are checked.
## Requests without a recognisable entity (e.g. player requests) are never stale.
func _is_stale(request_id: String) -> bool:
	var entity_id := _extract_entity_id(request_id)
	if entity_id.is_empty():
		return false
	var entity_node: Node = WorldState.get_entity(entity_id)
	if not entity_node:
		return true
	var stats: Node = entity_node.get_node_or_null("StatsComponent")
	if stats and not stats.is_alive():
		return true
	return false

## Extracts the entity (NPC) id embedded in a request_id.
## Returns "" if the entity cannot be determined (e.g. player conversations).
func _extract_entity_id(request_id: String) -> String:
	var prefixes: Array = ["conv_player_", "chat_", "extract_", "conv_", "fuzzy_", "opinion_", "impression_", "shop_title_"]
	for prefix in prefixes:
		if request_id.begins_with(prefix):
			var entity_id: String = request_id.substr(prefix.length())
			# Skip player-involved conversations — player is not in NPC entity registry
			if entity_id == "player" or entity_id.begins_with("player_"):
				return ""
			return entity_id
	# Bare request_id is the npc_id itself
	return request_id

func _send_request(pool_entry: Dictionary, req_id: String, body: Dictionary) -> void:
	pool_entry.busy = true
	pool_entry.request_id = req_id
	_active_requests += 1

	var http: HTTPRequest = pool_entry.node
	var json_body := JSON.stringify(body)
	var url := OLLAMA_BASE_URL + "/api/chat"
	var headers := ["Content-Type: application/json"]
	print("[LLM] Sending request '%s' to %s (model: %s)" % [req_id, url, body.get("model", "?")])

	# Disconnect any previous signal connections
	if http.request_completed.is_connected(_on_http_completed):
		http.request_completed.disconnect(_on_http_completed)
	http.request_completed.connect(_on_http_completed.bind(pool_entry), CONNECT_ONE_SHOT)

	var err := http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		push_warning("[LLM] HTTP request '%s' failed to start: error %d" % [req_id, err])
		_finish_request(pool_entry, req_id, {}, "HTTP request failed with error %d" % err)

func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, pool_entry: Dictionary) -> void:
	var req_id: String = pool_entry.request_id

	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg := "HTTP result error: %d" % result
		if result == HTTPRequest.RESULT_TIMEOUT:
			error_msg = "Request timed out after %.0fs" % LLM_TIMEOUT
		_finish_request(pool_entry, req_id, {}, error_msg)
		return

	if response_code != 200:
		_finish_request(pool_entry, req_id, {}, "HTTP %d response" % response_code)
		return

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		_finish_request(pool_entry, req_id, {}, "Failed to parse JSON response")
		return

	if not json.data is Dictionary:
		_finish_request(pool_entry, req_id, {}, "Response is not a JSON object")
		return

	var ollama_response: Dictionary = json.data
	var content: String = _extract_content(ollama_response)
	if content.is_empty():
		_finish_request(pool_entry, req_id, {}, "No content in response")
		return

	var response: Dictionary = {"message": {"content": content}}
	print("[LLM] Request '%s' completed successfully" % req_id)
	_finish_request(pool_entry, req_id, response, "")

## Extract the text content from an Ollama chat response.
func _extract_content(ollama_response: Dictionary) -> String:
	var message = ollama_response.get("message", {})
	if not message is Dictionary:
		return ""
	return str(message.get("content", ""))

func _finish_request(pool_entry: Dictionary, req_id: String, response: Dictionary, error: String) -> void:
	pool_entry.busy = false
	pool_entry.request_id = ""
	_active_requests -= 1

	if error.is_empty():
		request_completed.emit(req_id, response)
	else:
		push_warning("[LLM] Request '%s' failed: %s" % [req_id, error])
		request_failed.emit(req_id, error)
