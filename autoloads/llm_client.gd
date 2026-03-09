extends Node
## Async HTTP pool for Ollama API calls with timeout and rate-limiting.

const OLLAMA_BASE_URL: String = "http://localhost:11434"
const OLLAMA_MODEL: String = "qwen3.5:4b"
const LLM_TIMEOUT: float = 30.0
const LLM_TEMPERATURE: float = 0.7
const MAX_CONCURRENT_REQUESTS: int = 2

var _active_requests: int = 0
var _request_queue: Array = []  # Array of {id, body, callback}
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
func send_chat(request_id: String, messages: Array, format: Dictionary = {}) -> String:
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

	_request_queue.append({
		"id": request_id,
		"body": body,
	})
	return request_id

func _process_queue() -> void:
	if _request_queue.is_empty():
		return

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

	# Disconnect any previous signal connections
	if http.request_completed.is_connected(_on_http_completed):
		http.request_completed.disconnect(_on_http_completed)
	http.request_completed.connect(_on_http_completed.bind(pool_entry), CONNECT_ONE_SHOT)

	var err := http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
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
	_finish_request(pool_entry, req_id, response, "")

func _finish_request(pool_entry: Dictionary, req_id: String, response: Dictionary, error: String) -> void:
	pool_entry.busy = false
	pool_entry.request_id = ""
	_active_requests -= 1

	if error.is_empty():
		request_completed.emit(req_id, response)
		GameEvents.llm_response_received.emit(req_id, response)
	else:
		request_failed.emit(req_id, error)
		GameEvents.llm_request_failed.emit(req_id, error)
