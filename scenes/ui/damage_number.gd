extends Node3D
## Floating damage number that arcs up then falls down like a fountain.

var _label: Label3D
var _time: float = 0.0
var _drift: Vector3 = Vector3.ZERO
var _start_pos: Vector3 = Vector3.ZERO
var _duration: float = 1.0
var _rise_time: float = 0.2
var _jump_height: float = 1.5
var _fall_depth: float = 0.5
const DRIFT_DISTANCE := 2.0

# Styled damage number system
const COLOR_WHITE := Color(1, 1, 1)
const COLOR_YELLOW := Color(1, 0.85, 0.0)
const COLOR_GRAY := Color(0.6, 0.6, 0.6)

const HIT_ICONS: Dictionary = {
	"weak":   "res://assets/textures/ui/fx/icon_weak.png",
	"resist": "res://assets/textures/ui/fx/icon_resist.png",
}

var _style: String = "normal"

func _ready() -> void:
	_label = Label3D.new()
	_label.font = UIHelper.GAME_FONT
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.01
	_label.font_size = 48
	_label.outline_size = 6
	_label.modulate = Color(1, 1, 1, 1)
	_label.outline_modulate = Color(0, 0, 0, 1)
	_label.no_depth_test = true
	add_child(_label)

func setup(damage: int, color: Color = Color(1, 1, 1), direction: Vector3 = Vector3.ZERO) -> void:
	_label.text = str(damage)
	_label.modulate = color
	_duration = 1.0
	_rise_time = 0.2
	_jump_height = 1.5
	_fall_depth = 0.5
	_start_pos = position
	_setup_drift(direction)

func setup_text(text: String, color: Color = Color(1, 1, 1), direction: Vector3 = Vector3.ZERO) -> void:
	_label.text = text
	_label.modulate = color
	_duration = 1.0
	_rise_time = 0.2
	_jump_height = 1.5
	_fall_depth = 0.5
	_start_pos = position
	_setup_drift(direction)

func setup_styled(damage: int, hit_type: String, is_crit: bool, direction: Vector3, color_override: Color = Color(-1, -1, -1)) -> void:
	_style = hit_type

	# Determine what to show based on hit_type
	# Text color: white (normal) or yellow (crit) — hit_type only adds icon
	var text_color: Color = COLOR_YELLOW if is_crit else COLOR_WHITE
	match hit_type:
		"weak":
			# Icon + number
			_label.text = str(damage)
			_label.font_size = 72 if is_crit else 56
			_label.modulate = text_color
			_label.outline_size = 6
			_add_icon("weak", Vector3(-0.7, 0, 0), 0.5)
			_duration = 1.0
			_rise_time = 0.2
			_jump_height = 1.5
			_fall_depth = 0.5
			if is_crit:
				_do_pop_scale()
		"resist":
			# Icon + number
			_label.text = str(damage)
			_label.font_size = 56 if is_crit else 36
			_label.modulate = text_color
			_label.outline_size = 4
			_add_icon("resist", Vector3(-0.6, 0, 0), 0.45)
			_duration = 0.8
			_rise_time = 0.15
			_jump_height = 0.8
			_fall_depth = 0.6
			if is_crit:
				_do_pop_scale()
		"miss":
			# Text only
			_label.text = "MISS"
			_label.font_size = 32
			_label.modulate = color_override if color_override.r >= 0 else COLOR_GRAY
			_label.outline_size = 4
			_duration = 0.5
			_rise_time = 0.1
			_jump_height = 0.4
			_fall_depth = 0.2
		_:
			# Normal or crit — number only
			_label.text = str(damage)
			if is_crit:
				_label.font_size = 72
				_label.modulate = COLOR_YELLOW
				_label.outline_size = 6
				_duration = 1.5
				_rise_time = 0.25
				_jump_height = 2.0
				_fall_depth = 0.6
				_do_pop_scale()
			else:
				_label.font_size = 48
				_label.modulate = COLOR_WHITE
				_label.outline_size = 4
				_duration = 1.0
				_rise_time = 0.2
				_jump_height = 1.5
				_fall_depth = 0.5

	_start_pos = position
	_setup_drift(direction)

func _add_icon(icon_key: String, offset: Vector3, icon_scale: float) -> void:
	var path: String = HIT_ICONS.get(icon_key, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var sprite := Sprite3D.new()
	sprite.texture = load(path)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.no_depth_test = true
	sprite.pixel_size = 0.01
	sprite.position = offset
	sprite.scale = Vector3.ONE * icon_scale
	add_child(sprite)

func _do_pop_scale() -> void:
	scale = Vector3(2.0, 2.0, 2.0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _setup_drift(direction: Vector3) -> void:
	# Compute drift direction (XZ plane) with slight randomness
	_drift = direction
	if _drift.length_squared() < 0.01:
		var angle := randf() * TAU
		_drift = Vector3(cos(angle), 0, sin(angle))
	_drift += Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
	_drift = _drift.normalized()

func _process(delta: float) -> void:
	if not _label:
		return
	_time += delta

	# XZ drift: linear outward
	var t_total := clampf(_time / _duration, 0.0, 1.0)
	position.x = _start_pos.x + _drift.x * DRIFT_DISTANCE * t_total
	position.z = _start_pos.z + _drift.z * DRIFT_DISTANCE * t_total

	# Y: rise phase then fall phase
	if _time < _rise_time:
		# Rise: ease out (fast start, slow end)
		var t := _time / _rise_time
		position.y = _start_pos.y + _jump_height * (1.0 - (1.0 - t) * (1.0 - t))
	else:
		# Fall: ease in (slow start, fast end) — like gravity
		var t := clampf((_time - _rise_time) / (_duration - _rise_time), 0.0, 1.0)
		var peak_y := _start_pos.y + _jump_height
		var end_y := _start_pos.y - _fall_depth
		position.y = peak_y + (end_y - peak_y) * t * t

	# Fade out in the fall phase
	if _time > _rise_time:
		var fade_t := clampf((_time - _rise_time) / (_duration - _rise_time), 0.0, 1.0)
		var alpha := 1.0 - fade_t
		_label.modulate.a = alpha
		for child in get_children():
			if child is Sprite3D:
				child.modulate.a = alpha

	if _time >= _duration:
		queue_free()
