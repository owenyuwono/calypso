extends Node
## Async HTTP pool for Ollama API calls with timeout and rate-limiting.

const OLLAMA_BASE_URL: String = "http://localhost:11434"
const OLLAMA_MODEL: String = "qwen3.5:4b"
const LLM_TIMEOUT: float = 30.0
const LLM_TEMPERATURE: float = 0.7
const MAX_CONCURRENT_REQUESTS: int = 2

var _active_requests: int = 0
var _sequence: int = 0  # Monotonic counter for FIFO ordering within same priority tier
var _request_queue: Array = []  # Array of {id, body, priority, seq}
var _http_pool: Array = []  # Reusable HTTPRequest nodes

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

## Send a chat completion request to Ollama.
## Returns a request_id. Listen to request_completed/request_failed signals.
##
## Priority levels (lower = dispatched first):
##   1 — player-involved conversations (req_id prefix: conv_player_)
##   2 — NPC-to-NPC conversations      (req_id prefix: conv_)
##   3 — NPC decision-making           (default)
##   4 — memory extraction             (req_id prefix: extract_)
##   5 — background tasks              (req_id prefix: fuzzy_, opinion_, impression_)
func send_chat(request_id: String, messages: Array, format: Dictionary = {}, priority: int = 3) -> String:
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
	return request_id

func _process_queue() -> void:
	if _request_queue.is_empty():
		return

	# Sort by priority ascending (1 = highest), then by seq ascending (lower = earlier).
	# Godot's sort_custom uses introsort (not stable), so seq is required to
	# preserve FIFO order within the same priority tier.
	_request_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		return a.seq < b.seq
	)

	for pool_entry in _http_pool:
		if pool_entry.busy:
			continue
		if _request_queue.is_empty():
			break

		var queued: Dictionary = _request_queue.pop_front()
		_send_request(pool_entry, queued.id, queued.body)

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

	var response: Dictionary = json.data if json.data is Dictionary else {}
	print("[LLM] Request '%s' completed successfully" % req_id)
	_finish_request(pool_entry, req_id, response, "")

func _finish_request(pool_entry: Dictionary, req_id: String, response: Dictionary, error: String) -> void:
	pool_entry.busy = false
	pool_entry.request_id = ""
	_active_requests -= 1

	if error.is_empty():
		request_completed.emit(req_id, response)
	else:
		push_warning("[LLM] Request '%s' failed: %s" % [req_id, error])
		request_failed.emit(req_id, error)
