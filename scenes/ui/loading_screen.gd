extends CanvasLayer
## Loading screen shown during zone transitions. Built entirely in code — no .tscn counterpart.
## Displays zone-specific art, zone name, and a fake progress bar.

const MIN_DISPLAY_MS: int = 1000
const FADE_IN_TIME: float = 0.3
const FADE_OUT_TIME: float = 0.4

var _root: Control
var _zone_art: TextureRect
var _zone_name_label: Label
var _progress_bar: ProgressBar
var _show_time_ms: int = 0
var _is_first_load: bool = true
var _texture_cache: Dictionary = {}

func _ready() -> void:
	layer = 100
	_build_ui()

func _build_ui() -> void:
	# Root Control — all children live here; fade this node's modulate for transitions
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Background — full-screen black
	var background: ColorRect = ColorRect.new()
	background.color = Color(0, 0, 0, 1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	# Zone art — stretched to fill, preserving aspect
	_zone_art = TextureRect.new()
	_zone_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zone_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_zone_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_zone_art)

	# Overlay — semi-transparent dark for text readability
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)

	# Content VBox — anchored bottom-center
	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.anchor_left = 0.5
	content_vbox.anchor_right = 0.5
	content_vbox.anchor_top = 1.0
	content_vbox.anchor_bottom = 1.0
	content_vbox.offset_left = -200
	content_vbox.offset_right = 200
	content_vbox.offset_top = -120
	content_vbox.offset_bottom = -50
	content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(content_vbox)

	# Zone name label
	_zone_name_label = Label.new()
	_zone_name_label.add_theme_font_size_override("font_size", 32)
	_zone_name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	_zone_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_zone_name_label.add_theme_constant_override("shadow_offset_x", 2)
	_zone_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_zone_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(_zone_name_label)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	content_vbox.add_child(spacer)

	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(300, 8)
	_progress_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.14)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.65, 0.78, 0.95)
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4

	_progress_bar.add_theme_stylebox_override("background", bg_style)
	_progress_bar.add_theme_stylebox_override("fill", fill_style)

	content_vbox.add_child(_progress_bar)

func show_loading(zone_id: String) -> void:
	await _show(zone_id.capitalize(), "")


func show_custom(display_name: String, art_path: String = "") -> void:
	await _show(display_name, art_path)


func _show(display_name: String, art_path: String) -> void:
	_zone_name_label.text = display_name
	_progress_bar.value = 0.0

	# Load art texture (cached)
	if art_path != "":
		if _texture_cache.has(art_path):
			_zone_art.texture = _texture_cache[art_path]
		elif FileAccess.file_exists(art_path):
			var tex: Texture2D = load(art_path)
			_texture_cache[art_path] = tex
			_zone_art.texture = tex
		else:
			_zone_art.texture = null
	else:
		_zone_art.texture = null

	visible = true

	if _is_first_load:
		_root.modulate.a = 1.0
	else:
		_root.modulate.a = 0.0
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(_root, "modulate:a", 1.0, FADE_IN_TIME)
		await fade_tween.finished

	# Animate progress from 0 to 0.7 over 0.5s
	var progress_tween: Tween = create_tween()
	progress_tween.tween_property(_progress_bar, "value", 0.7, 0.5)

	_show_time_ms = Time.get_ticks_msec()

func hide_loading() -> void:
	var elapsed_ms: int = Time.get_ticks_msec() - _show_time_ms
	var remaining_ms: int = MIN_DISPLAY_MS - elapsed_ms
	if remaining_ms > 0:
		await get_tree().create_timer(remaining_ms / 1000.0).timeout

	# Jump progress to 1.0
	var progress_tween: Tween = create_tween()
	progress_tween.tween_property(_progress_bar, "value", 1.0, 0.2)
	await progress_tween.finished

	# Fade out
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(_root, "modulate:a", 0.0, FADE_OUT_TIME)
	await fade_tween.finished

	_is_first_load = false
	visible = false
