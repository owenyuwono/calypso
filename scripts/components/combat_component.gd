extends BaseComponent
## Component that owns combat logic for an entity.
## Depends on: StatsComponent (hp, atk, def), EquipmentComponent (atk/def bonuses, optional).
## Player block/parry: hold defend to block (reduced damage), tap-time for parry (full negate + stagger).

const ItemDatabase = preload("res://scripts/data/item_database.gd")

var _stats: Node       # StatsComponent ref (required)
var _equipment: Node   # EquipmentComponent ref (optional — monsters don't have equipment)
var _progression: Node # ProgressionComponent ref (optional — for item penalty calculation)

# --- Block/Parry constants ---
const BLOCK_REDUCTION_BASE: float = 0.30
const BLOCK_REDUCTION_SHIELD_MIN: float = 0.50
const BLOCK_REDUCTION_SHIELD_MAX: float = 0.70
const PARRY_WINDOW_BASE_MS: int = 200
const PARRY_WINDOW_PER_PROF_LEVEL_MS: int = 20
const PARRY_WINDOW_MAX_MS: int = 400
const BLOCK_STAMINA_DRAIN_PER_SEC: float = 2.0
const BLOCK_STAMINA_HIT_RATIO: float = 0.5
const PARRY_STAMINA_RESTORE: float = 10.0
const PARRY_STAGGER_DURATION: float = 0.75
const GUARD_BREAK_VULNERABILITY: float = 0.5
const BLOCK_MOVE_SPEED_MULT: float = 0.5

# --- Block/Parry state ---
var _is_blocking: bool = false
var _block_start_time_ms: int = 0
var _guard_broken: bool = false
var _guard_break_timer: float = 0.0
var _stamina_ref: Node = null

func setup(stats_component: Node, equipment_component: Node = null, progression_component: Node = null) -> void:
	_stats = stats_component
	_equipment = equipment_component
	_progression = progression_component

func set_stamina(stamina_comp: Node) -> void:
	_stamina_ref = stamina_comp

func is_alive() -> bool:
	return _stats.is_alive()

# --- Block/Parry API ---

func start_blocking() -> void:
	if _guard_broken:
		return
	if _stamina_ref and _stamina_ref.get_stamina() <= 0.0:
		return
	_is_blocking = true
	_block_start_time_ms = Time.get_ticks_msec()

func stop_blocking() -> void:
	_is_blocking = false

func is_blocking() -> bool:
	return _is_blocking

func is_guard_broken() -> bool:
	return _guard_broken

func is_in_parry_window() -> bool:
	if not _is_blocking:
		return false
	var elapsed_ms: int = Time.get_ticks_msec() - _block_start_time_ms
	return elapsed_ms <= _get_parry_window_ms()

func get_block_move_speed_mult() -> float:
	return BLOCK_MOVE_SPEED_MULT if _is_blocking else 1.0

func tick_block(delta: float) -> void:
	## Called each frame by the owner. Handles passive stamina drain and guard break recovery.
	if _guard_broken:
		_guard_break_timer -= delta
		if _guard_break_timer <= 0.0:
			_guard_broken = false
		return
	if _is_blocking and _stamina_ref:
		_stamina_ref.drain_flat(BLOCK_STAMINA_DRAIN_PER_SEC * delta)
		if _stamina_ref.get_stamina() <= 0.0:
			_trigger_guard_break()

func receive_damage(incoming_damage: int, attacker_id: String) -> Dictionary:
	## Called on the TARGET's CombatComponent when blocking. Returns {final_damage, result}.
	if not _is_blocking:
		return {"final_damage": incoming_damage, "result": "normal"}

	# Check parry window
	var elapsed_ms: int = Time.get_ticks_msec() - _block_start_time_ms
	if elapsed_ms <= _get_parry_window_ms():
		# Successful parry — full negate, restore stamina, stagger attacker
		if _stamina_ref:
			_stamina_ref.drain_flat(-PARRY_STAMINA_RESTORE)  # negative drain = restore
		_stagger_attacker(attacker_id)
		return {"final_damage": 0, "result": "parried"}

	# Block — reduce damage, drain stamina per hit
	var reduction: float = _get_block_reduction()
	var blocked_amount: int = int(incoming_damage * reduction)
	var final_damage: int = maxi(1, incoming_damage - blocked_amount)

	if _stamina_ref:
		_stamina_ref.drain_flat(blocked_amount * BLOCK_STAMINA_HIT_RATIO)
		if _stamina_ref.get_stamina() <= 0.0:
			_trigger_guard_break()
			return {"final_damage": final_damage, "result": "guard_break"}

	return {"final_damage": final_damage, "result": "blocked"}

# --- Effective stats ---

func get_effective_atk() -> int:
	var base: int = _stats.atk
	if _equipment:
		var weapon_id: String = _equipment.get_weapon()
		if not weapon_id.is_empty():
			var item: Dictionary = ItemDatabase.get_item(weapon_id)
			var atk_bonus: int = item.get("atk_bonus", 0)
			var penalty: Dictionary = _get_item_penalty(weapon_id)
			base += floori(atk_bonus * penalty.stat_mult)
		# else unarmed — no equipment bonus
	return base

func get_effective_def() -> int:
	var base: int = _stats.def
	if _equipment:
		var armor_id: String = _equipment.get_armor()
		if not armor_id.is_empty():
			var item: Dictionary = ItemDatabase.get_item(armor_id)
			var def_bonus: int = item.get("def_bonus", 0)
			var penalty: Dictionary = _get_item_penalty(armor_id)
			base += floori(def_bonus * penalty.stat_mult)
	return base

func get_effective_matk() -> int:
	var base: int = _stats.matk
	if _equipment:
		base += _equipment.get_matk_bonus()
	return base

func get_effective_mdef() -> int:
	var base: int = _stats.mdef
	if _equipment:
		base += _equipment.get_mdef_bonus()
	return base

func get_armor_type() -> String:
	return _equipment.get_armor_type() if _equipment else "light"

func roll_crit() -> Dictionary:
	var is_crit: bool = randf() < (_stats.crit_rate / 100.0)
	var multiplier: float = _stats.crit_damage / 100.0
	return {"is_crit": is_crit, "multiplier": multiplier}

func get_attack_speed_multiplier() -> float:
	## Returns the speed multiplier for the equipped weapon (penalty-adjusted).
	if not _equipment:
		return 1.5  # Unarmed: fast flurry
	var weapon_id: String = _equipment.get_weapon()
	if weapon_id.is_empty():
		return 1.5  # Unarmed: fast flurry
	var item: Dictionary = ItemDatabase.get_item(weapon_id)
	var penalty: Dictionary = _get_item_penalty(weapon_id)
	var base_speed: float = item.get("attack_speed", 1.0)
	return base_speed * penalty.speed_mult

func get_equipped_weapon_type() -> String:
	## Returns the weapon_type of the equipped weapon, or "mace" for unarmed.
	if not _equipment:
		return "mace"
	var weapon_id: String = _equipment.get_weapon()
	if weapon_id.is_empty():
		return "mace"
	var item: Dictionary = ItemDatabase.get_item(weapon_id)
	return item.get("weapon_type", "mace")

func get_equipped_phys_type() -> String:
	## Returns the phys_type of the equipped weapon, or "blunt" for unarmed.
	if not _equipment:
		return "blunt"
	var weapon_id: String = _equipment.get_weapon()
	if weapon_id.is_empty():
		return "blunt"
	var item: Dictionary = ItemDatabase.get_item(weapon_id)
	return item.get("phys_type", "blunt")

# --- Damage application ---

func apply_flat_damage_to(target_id: String, amount: int) -> int:
	## Applies a pre-computed damage amount directly, bypassing DEF calculation.
	## Returns actual damage dealt (0 if parried, reduced if blocked).
	var target_entity = WorldState.get_entity(target_id)
	if not target_entity or not is_instance_valid(target_entity):
		return 0
	var clamped: int = maxi(1, amount)
	return _apply_damage_to(target_id, clamped)

func heal(amount: int) -> int:
	var healed: int = _stats.heal(amount)
	if healed > 0:
		var eid := _get_entity_id()
		if not eid.is_empty():
			GameEvents.entity_healed.emit(eid, healed, _stats.hp)
	return healed

func _apply_damage_to(target_id: String, damage: int) -> int:
	var target_entity = WorldState.get_entity(target_id)
	if not target_entity or not is_instance_valid(target_entity):
		return 0
	var attacker_id := _get_entity_id()
	var target_stats = target_entity.get_node_or_null("StatsComponent")
	if not target_stats:
		push_warning("CombatComponent: target '%s' has no StatsComponent — damage dropped" % target_id)
		return 0

	# Block/parry interception on target
	var final_damage: int = damage
	var defense_result: String = "normal"
	var target_combat = target_entity.get_node_or_null("CombatComponent")
	if target_combat and target_combat.is_blocking():
		var result: Dictionary = target_combat.receive_damage(damage, attacker_id)
		final_damage = result.get("final_damage", damage)
		defense_result = result.get("result", "normal")

	if defense_result == "parried":
		GameEvents.damage_defended.emit(target_id, attacker_id, damage, "parried")
		return 0

	if defense_result == "blocked" or defense_result == "guard_break":
		var negated: int = damage - final_damage
		GameEvents.damage_defended.emit(target_id, attacker_id, negated, defense_result)

	if final_damage > 0:
		target_stats.take_damage(final_damage)
	GameEvents.entity_damaged.emit(target_id, attacker_id, final_damage, target_stats.hp)
	if not target_stats.is_alive():
		GameEvents.entity_died.emit(target_id, attacker_id)
	return final_damage

# --- Private helpers ---

func _get_item_penalty(item_id: String) -> Dictionary:
	## Calculate penalty for using an item above your proficiency level.
	var item: Dictionary = ItemDatabase.get_item(item_id)
	var required_skill: String = item.get("required_skill", "")
	var required_level: int = item.get("required_level", 1)
	if required_skill.is_empty():
		return {"stat_mult": 1.0, "speed_mult": 1.0}

	if not _progression:
		return {"stat_mult": 1.0, "speed_mult": 1.0}

	var prof_level: int = _progression.get_proficiency_level(required_skill)
	var level_gap: int = maxi(0, required_level - prof_level)
	var stat_mult: float = maxf(0.25, 1.0 - level_gap * 0.15)
	var speed_mult: float = minf(1.75, 1.0 + level_gap * 0.15)
	return {"stat_mult": stat_mult, "speed_mult": speed_mult}

func _get_parry_window_ms() -> int:
	var weapon_type: String = get_equipped_weapon_type()
	var prof_level: int = 0
	if _progression:
		prof_level = _progression.get_proficiency_level(weapon_type)
	var window: int = PARRY_WINDOW_BASE_MS + prof_level * PARRY_WINDOW_PER_PROF_LEVEL_MS
	return mini(window, PARRY_WINDOW_MAX_MS)

func _get_block_reduction() -> float:
	if not _equipment:
		return BLOCK_REDUCTION_BASE
	var shield_id: String = _equipment.get_slot("off_hand")
	if shield_id.is_empty():
		return BLOCK_REDUCTION_BASE
	var item: Dictionary = ItemDatabase.get_item(shield_id)
	var def_bonus: int = item.get("def_bonus", 0)
	if def_bonus <= 0:
		return BLOCK_REDUCTION_BASE
	var quality: float = clampf(float(def_bonus - 3) / 12.0, 0.0, 1.0)
	return BLOCK_REDUCTION_SHIELD_MIN + quality * (BLOCK_REDUCTION_SHIELD_MAX - BLOCK_REDUCTION_SHIELD_MIN)

func _stagger_attacker(attacker_id: String) -> void:
	var attacker = WorldState.get_entity(attacker_id)
	if not attacker or not is_instance_valid(attacker):
		return
	if "_stagger_timer" in attacker:
		attacker._stagger_timer = PARRY_STAGGER_DURATION
	if "_hitstop_timer" in attacker:
		attacker._hitstop_timer = 0.1
	var parent := get_parent()
	if parent and "global_position" in parent and "global_position" in attacker:
		var dir: Vector3 = (attacker.global_position - parent.global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			if "_knockback_velocity" in attacker:
				attacker._knockback_velocity = dir.normalized() * 7.0
	var attacker_auto: Node = attacker.get_node_or_null("AutoAttackComponent")
	if attacker_auto:
		attacker_auto.cancel()

func _trigger_guard_break() -> void:
	_is_blocking = false
	_guard_broken = true
	_guard_break_timer = GUARD_BREAK_VULNERABILITY
