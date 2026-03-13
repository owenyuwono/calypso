extends Camera3D

@export var target_path: NodePath
@export var zoom_min: float = 8.0
@export var zoom_max: float = 25.0
@export var zoom_step: float = 1.0
var _offset: Vector3
var _screen_correction: Vector3 = Vector3.ZERO
var _corrected: bool = false
var _target: Node3D

func _ready() -> void:
	_target = get_node(target_path)
	_offset = global_position - _target.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				size = clampf(size - zoom_step, zoom_min, zoom_max)
				_corrected = false
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				size = clampf(size + zoom_step, zoom_min, zoom_max)
				_corrected = false

func _process(_delta: float) -> void:
	global_position = _target.global_position + _offset + _screen_correction

	# Compute screen-space correction once after first frame renders
	if not _corrected and is_current():
		var screen_center := get_viewport().get_visible_rect().size * 0.5
		var player_screen_pos := unproject_position(_target.global_position)
		var pixel_offset := screen_center - player_screen_pos
		# Convert pixel offset to world offset along camera's local axes
		# For orthographic: pixels_per_unit = viewport_height / camera_size
		var pixels_per_unit := get_viewport().get_visible_rect().size.y / size
		var world_offset_y := pixel_offset.y / pixels_per_unit
		_screen_correction = global_transform.basis.y.normalized() * world_offset_y
		_corrected = true
