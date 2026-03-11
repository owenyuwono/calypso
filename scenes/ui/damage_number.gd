extends Node3D
## Floating damage number that arcs up then falls down like a fountain.

var _label: Label3D
var _time: float = 0.0
var _drift: Vector3 = Vector3.ZERO
var _start_pos: Vector3 = Vector3.ZERO
const RISE_TIME := 0.2
const TOTAL_TIME := 1.0
const JUMP_HEIGHT := 1.5
const FALL_DEPTH := 0.5
const DRIFT_DISTANCE := 2.0

func _ready() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.01
	_label.font_size = 64
	_label.outline_size = 6
	_label.modulate = Color(1, 1, 1, 1)
	_label.outline_modulate = Color(0, 0, 0, 1)
	_label.no_depth_test = true
	add_child(_label)

func setup(damage: int, color: Color = Color(1, 1, 1), direction: Vector3 = Vector3.ZERO) -> void:
	_label.text = str(damage)
	_label.modulate = color
	_start_pos = position

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
	var t_total := clampf(_time / TOTAL_TIME, 0.0, 1.0)
	position.x = _start_pos.x + _drift.x * DRIFT_DISTANCE * t_total
	position.z = _start_pos.z + _drift.z * DRIFT_DISTANCE * t_total

	# Y: rise phase then fall phase
	if _time < RISE_TIME:
		# Rise: ease out (fast start, slow end)
		var t := _time / RISE_TIME
		position.y = _start_pos.y + JUMP_HEIGHT * (1.0 - (1.0 - t) * (1.0 - t))
	else:
		# Fall: ease in (slow start, fast end) — like gravity
		var t := clampf((_time - RISE_TIME) / (TOTAL_TIME - RISE_TIME), 0.0, 1.0)
		var peak_y := _start_pos.y + JUMP_HEIGHT
		var end_y := _start_pos.y - FALL_DEPTH
		position.y = peak_y + (end_y - peak_y) * t * t

	# Fade out in the fall phase
	if _time > RISE_TIME:
		var fade_t := clampf((_time - RISE_TIME) / (TOTAL_TIME - RISE_TIME), 0.0, 1.0)
		_label.modulate.a = 1.0 - fade_t

	if _time >= TOTAL_TIME:
		queue_free()
