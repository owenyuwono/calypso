extends Camera3D

@export var target_path: NodePath

# Distance
@export var distance_default: float = 18.0
@export var distance_min: float = 8.0
@export var distance_max: float = 35.0
@export var zoom_step: float = 1.5

# Angle defaults (degrees converted to radians at ready)
@export var pitch_default_deg: float = 60.0
@export var pitch_min_deg: float = 30.0
@export var pitch_max_deg: float = 80.0

# Rotation sensitivity
@export var yaw_sensitivity: float = 0.005
@export var pitch_sensitivity: float = 0.003

# Smooth follow weight (1.0 = instant, lower = smoother)
@export var smooth_weight: float = 0.15

var _target: Node3D

var _distance: float = 18.0

# Current angles in radians
var _yaw: float = 0.0
var _pitch: float = 0.0

# Target angles (lerped toward)
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0

var _right_mouse_held: bool = false


func _ready() -> void:
	_target = get_node(target_path)
	_distance = distance_default
	_pitch = deg_to_rad(pitch_default_deg)
	_target_pitch = _pitch
	_yaw = 0.0
	_target_yaw = _yaw

	projection = PROJECTION_PERSPECTIVE
	fov = 50.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_right_mouse_held = mb.pressed
		elif mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_distance = clampf(_distance - zoom_step, distance_min, distance_max)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_distance = clampf(_distance + zoom_step, distance_min, distance_max)

	elif event is InputEventMouseMotion and _right_mouse_held:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_target_yaw -= mm.relative.x * yaw_sensitivity
		_target_pitch -= mm.relative.y * pitch_sensitivity
		_target_pitch = clampf(_target_pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))


func _process(_delta: float) -> void:
	if _target == null:
		return

	# Smooth angles toward targets
	_yaw = lerp(_yaw, _target_yaw, smooth_weight)
	_pitch = lerp(_pitch, _target_pitch, smooth_weight)

	var offset: Vector3 = Vector3(
		_distance * cos(_pitch) * sin(_yaw),
		_distance * sin(_pitch),
		_distance * cos(_pitch) * cos(_yaw)
	)

	global_position = _target.global_position + offset
	look_at(_target.global_position)
