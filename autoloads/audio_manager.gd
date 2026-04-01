extends Node
## Autoload: manages a pool of non-positional AudioStreamPlayer nodes for UI sounds.
## Positional (3D) SFX are handled by AudioComponent on each entity.

const UI_POOL_SIZE: int = 4

var _pool_ui: Array[AudioStreamPlayer] = []
var _audio_cache: Dictionary = {}


func _ready() -> void:
	# Start muted — player can raise volume in settings
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), -80.0)
	for i in UI_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"UI"
		add_child(player)
		_pool_ui.append(player)


func play_ui_sfx(sfx_key: String) -> void:
	var sfx: Dictionary = SfxDatabase.get_sfx(sfx_key)
	if sfx.is_empty():
		return
	var stream: AudioStream = _load_stream(sfx["path"])
	if stream == null:
		return
	var player: AudioStreamPlayer = _get_idle_ui_player()
	player.stream = stream
	player.volume_db = sfx["volume_db"]
	var variance: float = sfx.get("pitch_variance", 0.0)
	if variance > 0.0:
		player.pitch_scale = 1.0 + randf_range(-variance, variance)
	else:
		player.pitch_scale = 1.0
	player.play()


func _get_idle_ui_player() -> AudioStreamPlayer:
	for player in _pool_ui:
		if not player.playing:
			return player
	# All busy — steal the first one
	return _pool_ui[0]


func _load_stream(path: String) -> AudioStream:
	if _audio_cache.has(path):
		return _audio_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	_audio_cache[path] = stream
	return stream
