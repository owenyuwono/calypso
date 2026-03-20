extends Node
## Per-entity audio composition node.
## Creates AudioStreamPlayer3D children on the ENTITY (not this Node) so they
## follow the entity's position. Plain Node children sit at world origin.
##
## Usage: add AudioComponent as child of entity, then call setup(entity).

var _footstep_player: AudioStreamPlayer3D = null
var _presence_player: AudioStreamPlayer3D = null
var _combat_loop_player: AudioStreamPlayer3D = null
var _oneshot_player: AudioStreamPlayer3D = null

var _current_footstep_surface: String = ""
var _current_presence_key: String = ""

var _stream_cache: Dictionary = {}


func setup(entity: Node3D) -> void:
	_footstep_player = _make_loop_player("FootstepPlayer", entity)
	_presence_player = _make_loop_player("PresencePlayer", entity)
	_combat_loop_player = _make_loop_player("CombatLoopPlayer", entity)

	_oneshot_player = AudioStreamPlayer3D.new()
	_oneshot_player.name = "OneShotPlayer"
	_oneshot_player.max_polyphony = 3
	_apply_3d_config(_oneshot_player)
	entity.add_child(_oneshot_player)


func start_footsteps(surface: String = "stone") -> void:
	var key: String = "footstep_" + surface
	if _current_footstep_surface == key and _footstep_player.playing:
		return
	var sfx: Dictionary = SfxDatabase.get_sfx(key)
	if sfx.is_empty():
		return
	_current_footstep_surface = key
	var stream: AudioStream = _load_stream(sfx["path"])
	if stream == null:
		return
	stream = _enable_loop(stream)
	_footstep_player.stream = stream
	_footstep_player.volume_db = sfx["volume_db"]
	_footstep_player.play()


func stop_footsteps() -> void:
	_footstep_player.stop()
	_current_footstep_surface = ""


func start_presence(sound_key: String) -> void:
	if _current_presence_key == sound_key and _presence_player.playing:
		return
	var sfx: Dictionary = SfxDatabase.get_sfx(sound_key)
	if sfx.is_empty():
		return
	_current_presence_key = sound_key
	var stream: AudioStream = _load_stream(sfx["path"])
	if stream == null:
		return
	stream = _enable_loop(stream)
	_presence_player.stream = stream
	_presence_player.volume_db = sfx["volume_db"]
	_presence_player.play()


func stop_presence() -> void:
	_presence_player.stop()
	_current_presence_key = ""


func start_combat_loop() -> void:
	if _combat_loop_player.playing:
		return
	var sfx: Dictionary = SfxDatabase.get_sfx("combat_loop")
	if sfx.is_empty():
		return
	var stream: AudioStream = _load_stream(sfx["path"])
	if stream == null:
		return
	stream = _enable_loop(stream)
	_combat_loop_player.stream = stream
	_combat_loop_player.volume_db = sfx["volume_db"]
	_combat_loop_player.play()


func stop_combat_loop() -> void:
	_combat_loop_player.stop()


func play_oneshot(sfx_key: String) -> void:
	var sfx: Dictionary = SfxDatabase.get_sfx(sfx_key)
	if sfx.is_empty():
		return
	var stream: AudioStream = _load_stream(sfx["path"])
	if stream == null:
		return
	_oneshot_player.stream = stream
	_oneshot_player.volume_db = sfx["volume_db"]
	var variance: float = sfx.get("pitch_variance", 0.0)
	if variance > 0.0:
		_oneshot_player.pitch_scale = 1.0 + randf_range(-variance, variance)
	else:
		_oneshot_player.pitch_scale = 1.0
	_oneshot_player.play()


func stop_all_loops() -> void:
	stop_footsteps()
	stop_presence()
	stop_combat_loop()


func resume_loops() -> void:
	# No-op: loops resume when entity state transitions call start_ methods again.
	pass


# --- Private helpers ---

func _make_loop_player(player_name: String, entity: Node3D) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = player_name
	_apply_3d_config(player)
	entity.add_child(player)
	return player


func _apply_3d_config(player: AudioStreamPlayer3D) -> void:
	player.max_distance = 40.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	player.unit_size = 10.0
	player.bus = &"SFX"


func _enable_loop(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		var looped: AudioStream = stream.duplicate()
		looped.loop = true
		return looped
	return stream


func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	_stream_cache[path] = stream
	return stream
