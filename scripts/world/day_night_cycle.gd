extends Node3D
## Animates DirectionalLight3D + WorldEnvironment based on TimeManager phases.
## Added as a child of Main so it persists across zone transitions.
## Re-acquires lighting nodes from the newly loaded zone on each zone_changed signal.

var _sun: DirectionalLight3D = null
var _environment: Environment = null

var _tween: Tween = null

const TRANSITION_DURATION: float = 30.0

const PHASE_SETTINGS: Dictionary = {
	"dawn": {
		"sun_color": Color(1.0, 0.7, 0.4),
		"sun_energy": 0.6,
		"sun_rotation": Vector3(-15.0, -45.0, 0.0),
		"ambient_color": Color(0.7, 0.55, 0.4),
		"ambient_energy": 0.2,
		"fog_color": Color(0.8, 0.65, 0.45),
		"fog_density": 0.003,
	},
	"day": {
		"sun_color": Color(1.0, 0.98, 0.92),
		"sun_energy": 1.2,
		"sun_rotation": Vector3(-55.0, -45.0, 0.0),
		"ambient_color": Color(0.6, 0.6, 0.65),
		"ambient_energy": 0.25,
		"fog_color": Color(0.75, 0.72, 0.65),
		"fog_density": 0.002,
	},
	"dusk": {
		"sun_color": Color(1.0, 0.5, 0.3),
		"sun_energy": 0.5,
		"sun_rotation": Vector3(-10.0, 135.0, 0.0),
		"ambient_color": Color(0.6, 0.4, 0.35),
		"ambient_energy": 0.18,
		"fog_color": Color(0.7, 0.45, 0.35),
		"fog_density": 0.004,
	},
	"night": {
		"sun_color": Color(0.4, 0.45, 0.7),
		"sun_energy": 0.15,
		"sun_rotation": Vector3(-30.0, -45.0, 0.0),
		"ambient_color": Color(0.2, 0.22, 0.35),
		"ambient_energy": 0.1,
		"fog_color": Color(0.15, 0.15, 0.25),
		"fog_density": 0.005,
	},
}

# Intermediate values for fog — tweened via _process since Environment
# doesn't support tween_property on nested resource properties.
var _target_fog_color: Color = Color(0.75, 0.72, 0.65)
var _target_fog_density: float = 0.002
var _current_fog_color: Color = Color(0.75, 0.72, 0.65)
var _current_fog_density: float = 0.002
var _fog_lerp_active: bool = false
var _fog_lerp_elapsed: float = 0.0
var _fog_lerp_duration: float = TRANSITION_DURATION
var _fog_start_color: Color = Color(0.75, 0.72, 0.65)
var _fog_start_density: float = 0.002


func _ready() -> void:
	GameEvents.time_phase_changed.connect(_on_time_phase_changed)
	ZoneManager.zone_changed.connect(_on_zone_changed)


func _process(delta: float) -> void:
	if not _fog_lerp_active:
		return
	_fog_lerp_elapsed = minf(_fog_lerp_elapsed + delta, _fog_lerp_duration)
	var t: float = _fog_lerp_elapsed / _fog_lerp_duration
	_current_fog_color = _fog_start_color.lerp(_target_fog_color, t)
	_current_fog_density = lerpf(_fog_start_density, _target_fog_density, t)
	if _environment:
		_environment.fog_light_color = _current_fog_color
		_environment.fog_density = _current_fog_density
	if _fog_lerp_elapsed >= _fog_lerp_duration:
		_fog_lerp_active = false


# --- Zone lifecycle ----------------------------------------------------------

func _on_zone_changed(_old_zone_id: String, _new_zone_id: String) -> void:
	_acquire_lighting_nodes()
	_apply_phase_immediate(TimeManager.get_phase())


func _acquire_lighting_nodes() -> void:
	var zone: Node3D = ZoneManager.get_loaded_zone()
	if not zone:
		_sun = null
		_environment = null
		return

	_sun = zone.get_node_or_null("DirectionalLight3D") as DirectionalLight3D

	var world_env: WorldEnvironment = zone.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env:
		_environment = world_env.environment
	else:
		_environment = null

	if not _sun:
		push_warning("[DayNightCycle] No DirectionalLight3D found in zone: " + zone.name)
	if not _environment:
		push_warning("[DayNightCycle] No WorldEnvironment found in zone: " + zone.name)


# --- Phase application -------------------------------------------------------

func _apply_phase_immediate(phase: String) -> void:
	if not PHASE_SETTINGS.has(phase):
		return
	var s: Dictionary = PHASE_SETTINGS[phase]

	if _tween and _tween.is_valid():
		_tween.kill()
	_fog_lerp_active = false

	if _sun:
		_sun.light_color = s["sun_color"]
		_sun.light_energy = s["sun_energy"]
		_sun.rotation_degrees = s["sun_rotation"]

	if _environment:
		_environment.ambient_light_color = s["ambient_color"]
		_environment.ambient_light_energy = s["ambient_energy"]
		_environment.fog_light_color = s["fog_color"]
		_environment.fog_density = s["fog_density"]

	_current_fog_color = s["fog_color"]
	_current_fog_density = s["fog_density"]
	_target_fog_color = s["fog_color"]
	_target_fog_density = s["fog_density"]


func _on_time_phase_changed(_old_phase: String, new_phase: String) -> void:
	if not PHASE_SETTINGS.has(new_phase):
		return
	var s: Dictionary = PHASE_SETTINGS[new_phase]

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true)

	if _sun:
		_tween.tween_property(_sun, "light_color", s["sun_color"], TRANSITION_DURATION)
		_tween.tween_property(_sun, "light_energy", s["sun_energy"], TRANSITION_DURATION)
		_tween.tween_property(_sun, "rotation_degrees", s["sun_rotation"], TRANSITION_DURATION)

	if _environment:
		_tween.tween_property(_environment, "ambient_light_color", s["ambient_color"], TRANSITION_DURATION)
		_tween.tween_property(_environment, "ambient_light_energy", s["ambient_energy"], TRANSITION_DURATION)

	# Fog properties can't be tweened via tween_property on a nested resource
	# directly in all Godot 4 builds — drive them manually in _process.
	_fog_start_color = _current_fog_color
	_fog_start_density = _current_fog_density
	_target_fog_color = s["fog_color"]
	_target_fog_density = s["fog_density"]
	_fog_lerp_elapsed = 0.0
	_fog_lerp_duration = TRANSITION_DURATION
	_fog_lerp_active = true
