extends BaseComponent
## Player personal needs: hunger, thirst, hygiene, health.
## Decays in real-time. Consumes resources for replenishment.
## Health is a consequence meter — damaged by other needs at 0.

const SECONDS_PER_GAME_HOUR: float = 112.5

# Decay rates per game-hour
const HUNGER_DECAY: float = 3.0
const THIRST_DECAY: float = 5.0
const HYGIENE_DECAY: float = 1.5

# Health damage from depleted needs (per game-hour)
const HUNGER_HP_DRAIN: float = 5.0
const THIRST_HP_DRAIN: float = 8.0
const HYGIENE_DISEASE_CHANCE: float = 0.05  # per game-hour when hygiene < 25
const DISEASE_HEALTH_PENALTY: float = 20.0

# Natural health recovery (per game-hour, when hunger > 50 AND thirst > 50)
const HEALTH_REGEN: float = 2.0

# Debuff multipliers at 0%
const HUNGER_ATK_MULT: float = 0.5
const THIRST_SPEED_MULT: float = 0.7

# Threshold levels
const THRESHOLD_WARNING: float = 75.0
const THRESHOLD_MODERATE: float = 50.0
const THRESHOLD_CRITICAL: float = 25.0

var hunger: float = 100.0
var thirst: float = 100.0
var hygiene: float = 100.0
var health: float = 100.0

var _signal_timer: float = 0.0
var _disease_check_accumulator: float = 0.0
var _last_thresholds: Dictionary = {}

const SIGNAL_INTERVAL: float = 1.0
const DISEASE_CHECK_INTERVAL_SECONDS: float = SECONDS_PER_GAME_HOUR  # once per game-hour


func _ready() -> void:
	_last_thresholds = {
		"hunger": _get_threshold_level(hunger),
		"thirst": _get_threshold_level(thirst),
		"hygiene": _get_threshold_level(hygiene),
		"health": _get_threshold_level(health),
	}


func _process(delta: float) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return
	if "_is_dead" in parent and parent._is_dead:
		return

	# Decay needs
	var decay_mult: float = delta / SECONDS_PER_GAME_HOUR
	hunger = maxf(0.0, hunger - HUNGER_DECAY * decay_mult)
	thirst = maxf(0.0, thirst - THIRST_DECAY * decay_mult)
	hygiene = maxf(0.0, hygiene - HYGIENE_DECAY * decay_mult)

	# Health consequences
	if hunger <= 0.01:
		health = maxf(0.0, health - HUNGER_HP_DRAIN * decay_mult)
	if thirst <= 0.01:
		health = maxf(0.0, health - THIRST_HP_DRAIN * decay_mult)

	# Natural health recovery
	if hunger > THRESHOLD_MODERATE and thirst > THRESHOLD_MODERATE and health < 100.0:
		health = minf(100.0, health + HEALTH_REGEN * decay_mult)

	# Disease check from low hygiene
	_disease_check_accumulator += delta
	if _disease_check_accumulator >= DISEASE_CHECK_INTERVAL_SECONDS:
		_disease_check_accumulator = 0.0
		if hygiene < THRESHOLD_CRITICAL:
			if randf() < HYGIENE_DISEASE_CHANCE:
				health = maxf(0.0, health - DISEASE_HEALTH_PENALTY)

	# Health at 0 = death via StatsComponent
	if health <= 0.01:
		var stats: Node = parent.get_node_or_null("StatsComponent")
		if stats and stats.is_alive():
			stats.take_damage(int(ceil(stats.hp)))

	# Throttled signal emission
	_signal_timer += delta
	if _signal_timer >= SIGNAL_INTERVAL:
		_signal_timer = 0.0
		GameEvents.needs_changed.emit(_get_snapshot())
		_check_threshold_crossings()


func _check_threshold_crossings() -> void:
	var needs_map: Dictionary = {"hunger": hunger, "thirst": thirst, "hygiene": hygiene, "health": health}
	for need_type in needs_map:
		var level: int = _get_threshold_level(needs_map[need_type])
		var last: int = _last_thresholds.get(need_type, 4)
		if level != last:
			_last_thresholds[need_type] = level
			if level <= 1:  # critical
				GameEvents.need_critical.emit(need_type)
			_sync()


func _get_threshold_level(value: float) -> int:
	if value > THRESHOLD_WARNING:
		return 4  # fine
	elif value > THRESHOLD_MODERATE:
		return 3  # warning
	elif value > THRESHOLD_CRITICAL:
		return 2  # moderate
	else:
		return 1  # critical


# --- Replenishment API ---

func eat(nutrition: float) -> void:
	hunger = minf(100.0, hunger + nutrition)

func drink(amount: float) -> void:
	thirst = minf(100.0, thirst + amount)

func restore_hygiene(amount: float) -> void:
	hygiene = minf(100.0, hygiene + amount)

func heal_health(amount: float) -> void:
	health = minf(100.0, health + amount)


# --- Debuff Queries ---

func get_hunger_atk_multiplier() -> float:
	if hunger > THRESHOLD_CRITICAL:
		return 1.0
	# Linear interpolation from 1.0 at threshold to HUNGER_ATK_MULT at 0
	var t: float = hunger / THRESHOLD_CRITICAL
	return lerpf(HUNGER_ATK_MULT, 1.0, t)

func get_thirst_speed_multiplier() -> float:
	if thirst > THRESHOLD_CRITICAL:
		return 1.0
	var t: float = thirst / THRESHOLD_CRITICAL
	return lerpf(THIRST_SPEED_MULT, 1.0, t)


# --- Snapshot & Sync ---

func _get_snapshot() -> Dictionary:
	return {
		"hunger": hunger,
		"thirst": thirst,
		"hygiene": hygiene,
		"health": health,
	}

func _sync() -> void:
	var eid: String = _get_entity_id()
	if eid.is_empty():
		return
	WorldState.set_entity_data(eid, "needs", _get_snapshot())

func load_state() -> void:
	var eid: String = _get_entity_id()
	if eid.is_empty():
		return
	var data: Dictionary = WorldState.get_entity_data(eid).get("needs", {})
	if data.is_empty():
		return
	hunger = data.get("hunger", 100.0)
	thirst = data.get("thirst", 100.0)
	hygiene = data.get("hygiene", 100.0)
	health = data.get("health", 100.0)
