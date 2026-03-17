extends Node3D
## Dialogue bubble rendered via a single Label3D — no SubViewports.

var _label: Label3D

var _display_timer: float = 0.0
var _display_duration: float = 4.0
var _showing: bool = false
var _dialogue_queue: Array = []

const MAX_WORDS_PER_BUBBLE: int = 12

func _ready() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.008
	_label.font_size = 24
	_label.outline_size = 12
	_label.modulate = Color(1, 1, 1, 1)
	_label.outline_modulate = Color(0.12, 0.1, 0.08, 0.85)
	_label.width = 300
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.no_depth_test = true
	_label.render_priority = 10
	add_child(_label)
	visible = false

func _process(delta: float) -> void:
	if not _showing:
		return
	_display_timer += delta
	if _display_timer >= _display_duration:
		if not _dialogue_queue.is_empty():
			_show_next_chunk()
		else:
			hide_bubble()

func show_dialogue(text: String, duration: float = -1.0) -> void:
	_dialogue_queue.clear()
	var sentences := _split_sentences(text)
	for sentence: String in sentences:
		var words := sentence.split(" ", false)
		if words.size() > MAX_WORDS_PER_BUBBLE:
			var i := 0
			while i < words.size():
				var end := mini(i + MAX_WORDS_PER_BUBBLE, words.size())
				_dialogue_queue.append(" ".join(words.slice(i, end)))
				i = end
		else:
			_dialogue_queue.append(sentence)
	if not _dialogue_queue.is_empty():
		var first: String = _dialogue_queue.pop_front()
		_show_chunk(first, duration)

func _split_sentences(text: String) -> Array:
	var sentences: Array = []
	var current := ""
	for i in text.length():
		var ch := text.substr(i, 1)
		current += ch
		var is_end := ch == "." or ch == "!" or ch == "?"
		if is_end and (i + 1 >= text.length() or text.substr(i + 1, 1) == " "):
			var prev_is_punct := i > 0 and text.substr(i - 1, 1) in [".", "!", "?"]
			var next_is_punct := i + 1 < text.length() and text.substr(i + 1, 1) in [".", "!", "?"]
			if not prev_is_punct and not next_is_punct:
				sentences.append(current.strip_edges())
				current = ""
	if not current.strip_edges().is_empty():
		sentences.append(current.strip_edges())
	return sentences

func _show_chunk(text: String, duration: float = -1.0) -> void:
	_label.text = text
	_display_duration = duration if duration > 0.0 else _calc_duration(text)
	_display_timer = 0.0
	_showing = true
	visible = true

func _show_next_chunk() -> void:
	var chunk: String = _dialogue_queue.pop_front()
	_show_chunk(chunk)

func _calc_duration(text: String) -> float:
	var word_count := text.split(" ", false).size()
	return clampf(word_count * 0.4, 3.0, 12.0)

func hide_bubble() -> void:
	_showing = false
	visible = false
	_dialogue_queue.clear()
