extends Camera3D

@export var target_path: NodePath

# Distance
@export var distance_default: float = 18.0
@export var distance_min: float = 8.0
@export var distance_max: float = 35.0
@export var zoom_step: float = 1.5

# Angle defaults (degrees converted to radians at ready)
@export var pitch_default_deg: float = 60.0

# Smooth follow weight (1.0 = instant, lower = smoother)
@export var smooth_weight: float = 0.15

var _target: Node3D
var _distance: float = 18.0
var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	_target = get_node(target_path)
	_distance = distance_default
	_pitch = deg_to_rad(pitch_default_deg)
	_yaw = 0.0
	projection = PROJECTION_PERSPECTIVE
	fov = 50.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - zoom_step, distance_min, distance_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + zoom_step, distance_min, distance_max)


func _process(_delta: float) -> void:
	if _target == null:
		return

	var offset: Vector3 = Vector3(
		_distance * cos(_pitch) * sin(_yaw),
		_distance * sin(_pitch),
		_distance * cos(_pitch) * cos(_yaw)
	)

	global_position = _target.global_position + offset
	look_at(_target.global_position)
