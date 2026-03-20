extends Node3D
## Phase-aware positional ambient sound emitter.
## Fades in/out based on time-of-day phase transitions.
## Add as a Node3D child of the scene at the desired world position.

var _player: AudioStreamPlayer3D = null
var _active_phases: Array = []
var _max_volume_db: float = 0.0
var _tween: Tween = null


func setup(
		stream_path: String,
		active_phases: Array,
		volume_db: float = 0.0,
		max_distance: float = 20.0) -> void:
	_active_phases = active_phases
	_max_volume_db = volume_db

	_player = AudioStreamPlayer3D.new()
	_player.max_distance = max_distance
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	_player.unit_size = 10.0
	_player.bus = &"Ambient"
	add_child(_player)

	if ResourceLoader.exists(stream_path):
		var stream: AudioStream = load(stream_path)
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		_player.stream = stream

	# Start silent then apply correct volume for current phase
	_player.volume_db = -80.0
	_player.play()

	GameEvents.time_phase_changed.connect(_on_time_phase_changed)

	# Set initial volume based on current phase without waiting for first change
	var current_phase: String = TimeManager.get_phase()
	if current_phase in _active_phases:
		_player.volume_db = _max_volume_db
	else:
		_player.volume_db = -80.0


func _on_time_phase_changed(old_phase: String, new_phase: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if new_phase in _active_phases:
		_tween.tween_property(_player, "volume_db", _max_volume_db, 3.0)
	else:
		_tween.tween_property(_player, "volume_db", -80.0, 3.0)
