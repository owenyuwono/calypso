extends Node
## Tracks magazine rounds and ammo reserves for ranged weapons.
## Handles reload timing (manual R key + auto-reload on empty).

var _entity_id: String
var _magazine_current: int
var _magazine_max: int
var _reserve: int
var _reload_time: float
var _reload_timer: float = 0.0
var _is_reloading: bool = false

func setup(entity_id: String, magazine_max: int, reload_time: float, starting_reserve: int) -> void:
	_entity_id = entity_id
	_magazine_max = magazine_max
	_magazine_current = magazine_max
	_reserve = starting_reserve
	_reload_time = reload_time
	_emit_ammo_changed()

func _process(delta: float) -> void:
	if not _is_reloading:
		return
	_reload_timer -= delta
	if _reload_timer <= 0.0:
		_finish_reload()

func try_consume() -> bool:
	if _magazine_current <= 0 or _is_reloading:
		return false
	_magazine_current -= 1
	_emit_ammo_changed()
	return true

func start_reload() -> void:
	if _is_reloading:
		return
	if _magazine_current >= _magazine_max:
		return
	if _reserve <= 0:
		return
	_is_reloading = true
	_reload_timer = _reload_time
	GameEvents.reload_started.emit(_entity_id)

func cancel_reload() -> void:
	if not _is_reloading:
		return
	_is_reloading = false
	_reload_timer = 0.0

func _finish_reload() -> void:
	var needed: int = _magazine_max - _magazine_current
	var transfer: int = mini(needed, _reserve)
	_magazine_current += transfer
	_reserve -= transfer
	_is_reloading = false
	_reload_timer = 0.0
	GameEvents.reload_finished.emit(_entity_id)
	_emit_ammo_changed()

func can_fire() -> bool:
	return _magazine_current > 0 and not _is_reloading

func is_reloading() -> bool:
	return _is_reloading

func get_magazine_current() -> int:
	return _magazine_current

func get_magazine_max() -> int:
	return _magazine_max

func get_reserve() -> int:
	return _reserve

func add_reserve(amount: int) -> void:
	_reserve += amount
	_emit_ammo_changed()

func configure_weapon(magazine_max: int, reload_time: float) -> void:
	cancel_reload()
	_magazine_max = magazine_max
	_reload_time = reload_time
	_magazine_current = mini(_magazine_current, _magazine_max)
	_emit_ammo_changed()

func _emit_ammo_changed() -> void:
	GameEvents.ammo_changed.emit(_entity_id, _magazine_current, _magazine_max, _reserve)
