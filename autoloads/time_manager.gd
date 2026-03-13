extends Node
## Global game clock singleton. Tracks in-game time and emits phase-change signals.
## 1 in-game day = 2700 real seconds (45 min). 4 phases: dawn, day, dusk, night.

const DAY_LENGTH_SECONDS: float = 2700.0
const HOURS_PER_DAY: float = 24.0

var _game_hours: float = 8.0  # Start at 8:00 AM
var _day_count: int = 1
var _current_phase: String = "day"
var _last_emitted_hour: int = 8
var _paused: bool = false

func _process(delta: float) -> void:
	if _paused:
		return
	_game_hours += delta * (HOURS_PER_DAY / DAY_LENGTH_SECONDS)
	if _game_hours >= HOURS_PER_DAY:
		_game_hours -= HOURS_PER_DAY
		_day_count += 1

	# Emit hourly tick
	var current_hour := int(_game_hours)
	if current_hour != _last_emitted_hour:
		_last_emitted_hour = current_hour
		GameEvents.game_hour_changed.emit(current_hour)

	# Check phase transitions
	var new_phase := _calculate_phase()
	if new_phase != _current_phase:
		var old_phase := _current_phase
		_current_phase = new_phase
		GameEvents.time_phase_changed.emit(old_phase, new_phase)

func _calculate_phase() -> String:
	if _game_hours >= 5.0 and _game_hours < 7.0:
		return "dawn"
	elif _game_hours >= 7.0 and _game_hours < 18.0:
		return "day"
	elif _game_hours >= 18.0 and _game_hours < 20.0:
		return "dusk"
	else:
		return "night"

func get_game_hour() -> float:
	return _game_hours

func get_phase() -> String:
	return _current_phase

func get_time_display() -> String:
	var hours := int(_game_hours)
	var minutes := int((_game_hours - hours) * 60.0)
	return "%02d:%02d" % [hours, minutes]

func get_day() -> int:
	return _day_count

func is_night() -> bool:
	return _current_phase == "night"

func set_time(hour: float) -> void:
	_game_hours = fmod(hour, HOURS_PER_DAY)
	_last_emitted_hour = int(_game_hours)
	var new_phase := _calculate_phase()
	if new_phase != _current_phase:
		var old_phase := _current_phase
		_current_phase = new_phase
		GameEvents.time_phase_changed.emit(old_phase, new_phase)

func set_paused(paused: bool) -> void:
	_paused = paused
