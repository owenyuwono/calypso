extends Node3D
## Styled dialogue bubble rendered via SubViewport + Sprite3D.

@onready var _viewport: SubViewport = $SubViewport
@onready var _panel: PanelContainer = $SubViewport/PanelContainer
@onready var _label: Label = $SubViewport/PanelContainer/MarginContainer/Label
@onready var _sprite: Sprite3D = $Sprite3D

var _display_timer: float = 0.0
var _display_duration: float = 4.0
var _showing: bool = false
var _dialogue_queue: Array = []

const MAX_WIDTH := 600
const PIXEL_SIZE := 0.01
const MAX_WORDS_PER_BUBBLE: int = 12

func _ready() -> void:
	visible = false
	_setup_style()

func _setup_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)

	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_font_size_override("font_size", 32)

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
			# Long sentence — fall back to word-count split
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
			# Don't split inside repeated punctuation (ellipsis "...", "!!", "??")
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
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_viewport_size()

func _show_next_chunk() -> void:
	var chunk: String = _dialogue_queue.pop_front()
	_show_chunk(chunk)

func _calc_duration(text: String) -> float:
	# ~0.4s per word, minimum 3s, maximum 12s
	var word_count := text.split(" ", false).size()
	return clampf(word_count * 0.4, 3.0, 12.0)

func hide_bubble() -> void:
	_showing = false
	visible = false
	_dialogue_queue.clear()

func _update_viewport_size() -> void:
	# Use font metrics directly for reliable measurement.
	var h_margin := 24  # left + right content margins (12+12)
	var v_margin := 16  # top + bottom content margins (8+8)

	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")

	# 1. Measure natural (unwrapped) text width via font metrics.
	var natural_size := font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var bubble_width := clampi(int(natural_size.x) + h_margin, 80, MAX_WIDTH)

	# 2. Measure wrapped text height at the constrained width.
	var wrap_width := bubble_width - h_margin
	var wrapped_size := font.get_multiline_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, font_size)
	var bubble_height := maxi(int(wrapped_size.y) + v_margin, 40)

	# 3. Apply sizes to viewport and panel; children with layout_mode=2 fill automatically.
	_viewport.size = Vector2i(bubble_width, bubble_height)

	# Wait one frame for viewport to re-render, then assign texture.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	_sprite.texture = _viewport.get_texture()
