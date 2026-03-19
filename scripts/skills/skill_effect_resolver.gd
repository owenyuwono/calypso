class_name SkillEffectResolver
extends RefCounted
## Static utility for resolving skill damage effects.
## Handles melee_attack, aoe_melee, armor_pierce, and bleed skill types.
## All methods are static — no instance needed.


static func resolve_skill_hit(
		combat: Node,
		perception: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String,
		attacker_pos: Vector3,
		active_bleeds: Dictionary,
		attacker_id: String,
		effectiveness_data: Dictionary = {}
) -> Array:
	## Main dispatch: routes to the correct resolver based on skill_data.type.
	## Returns Array of {target_id: String, damage: int}.
	## Self-harm entries additionally carry {self_harm: true}.
	var skill_type: String = skill_data.get("type", "")
	var results: Array = []
	match skill_type:
		"melee_attack":
			results = resolve_melee_attack(combat, skill_data, skill_level, target_id, effectiveness_data)
		"aoe_melee":
			results = resolve_aoe(combat, perception, skill_data, skill_level, target_id, attacker_pos, attacker_id, effectiveness_data)
		"armor_pierce":
			results = resolve_armor_pierce(combat, skill_data, skill_level, target_id, effectiveness_data)
		"bleed":
			results = resolve_bleed(combat, skill_data, skill_level, target_id, active_bleeds, effectiveness_data)
		_:
			push_warning("SkillEffectResolver: unknown skill type '%s'" % skill_type)
			return []

	# Self-harm check
	var self_harm_chance: float = effectiveness_data.get("self_harm_chance", 0.0)
	var self_harm_pct: float = effectiveness_data.get("self_harm_percent", 0.0)

	# Apply reduced_self_harm bonus
	var synergy_bonuses: Dictionary = effectiveness_data.get("synergy_bonuses", {})
	var reduced: float = synergy_bonuses.get("reduced_self_harm", 0.0)
	self_harm_pct = maxf(0.0, self_harm_pct - reduced)

	if self_harm_chance > 0.0 and randf() < self_harm_chance:
		var raw_atk: float = combat.get_effective_atk()
		var multiplier: float = skill_data.get("damage_multiplier", 1.0)
		var would_be_damage: int = floori(raw_atk * multiplier)
		var self_damage: int = maxi(1, floori(would_be_damage * self_harm_pct))
		results.append({"target_id": attacker_id, "damage": self_damage, "self_harm": true})

	return results


static func resolve_melee_attack(
		combat: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String,
		effectiveness_data: Dictionary = {}
) -> Array:
	## Single-target melee strike. Damage = effective_atk * multiplier, then reduced by target DEF.
	if not WorldState.is_alive(target_id):
		return []
	var multiplier: float = _calc_multiplier(skill_data, skill_level)
	var raw_damage: int = floori(combat.get_effective_atk() * multiplier)
	raw_damage = _apply_effectiveness(raw_damage, effectiveness_data)
	var actual_damage: int = combat.deal_damage_amount_to(target_id, raw_damage)
	return [{"target_id": target_id, "damage": actual_damage}]


static func resolve_aoe(
		combat: Node,
		perception: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String,
		attacker_pos: Vector3,
		attacker_id: String,
		effectiveness_data: Dictionary = {}
) -> Array:
	## AoE melee: hits primary target then all nearby hostiles within aoe_radius.
	## No friendly fire — only entities whose id starts with "monster_".
	var results: Array = []
	var multiplier: float = _calc_multiplier(skill_data, skill_level)
	var raw_damage: int = floori(combat.get_effective_atk() * multiplier)
	raw_damage = _apply_effectiveness(raw_damage, effectiveness_data)

	# Primary target hit
	if WorldState.is_alive(target_id):
		var primary_damage: int = combat.deal_damage_amount_to(target_id, raw_damage)
		results.append({"target_id": target_id, "damage": primary_damage})

	# Determine AoE center
	var aoe_center: Vector3 = attacker_pos
	var center_mode: String = skill_data.get("aoe_center", "self")
	if center_mode == "target":
		var target_entity: Node3D = WorldState.get_entity(target_id)
		if target_entity and is_instance_valid(target_entity):
			aoe_center = target_entity.global_position

	var bonuses: Dictionary = effectiveness_data.get("synergy_bonuses", {})
	var radius_bonus: float = bonuses.get("aoe_radius_bonus", 0.0)
	var effective_radius: float = skill_data.get("aoe_radius", 3.0) + radius_bonus

	# Gather secondary targets from perception — fetch slightly wider than effective_radius,
	# then filter precisely by distance to aoe_center below.
	var nearby: Array = perception.get_nearby(effective_radius + 5.0)

	for entry in nearby:
		var eid: String = entry.get("id", "")
		# Skip primary target, self, non-monsters, and dead entities
		if eid == target_id:
			continue
		if eid == attacker_id:
			continue
		if not eid.begins_with("monster_"):
			continue
		if not WorldState.is_alive(eid):
			continue
		# Check distance to aoe_center (not to attacker)
		var node: Node3D = entry.get("node")
		if not node or not is_instance_valid(node):
			continue
		var dist_to_center: float = aoe_center.distance_to(node.global_position)
		if dist_to_center > effective_radius:
			continue
		var splash_damage: int = combat.deal_damage_amount_to(eid, raw_damage)
		results.append({"target_id": eid, "damage": splash_damage})

	return results


static func resolve_armor_pierce(
		combat: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String,
		effectiveness_data: Dictionary = {}
) -> Array:
	## Armor-piercing strike: ignores a percentage of target DEF.
	## Requires CombatComponent.deal_damage_amount_to_with_pierce().
	if not WorldState.is_alive(target_id):
		return []
	var multiplier: float = _calc_multiplier(skill_data, skill_level)
	var raw_damage: int = floori(combat.get_effective_atk() * multiplier)
	raw_damage = _apply_effectiveness(raw_damage, effectiveness_data)

	var bonuses: Dictionary = effectiveness_data.get("synergy_bonuses", {})
	var pierce_bonus: float = bonuses.get("pierce_bonus", 0.0)
	var effective_pierce: float = skill_data.get("def_ignore_percent", 0.0) + pierce_bonus
	effective_pierce = clampf(effective_pierce, 0.0, 1.0)

	var actual_damage: int = combat.deal_damage_amount_to_with_pierce(target_id, raw_damage, effective_pierce)
	return [{"target_id": target_id, "damage": actual_damage}]


static func resolve_bleed(
		combat: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String,
		active_bleeds: Dictionary,
		effectiveness_data: Dictionary = {}
) -> Array:
	## Initial bleed hit + registers ongoing bleed ticks in active_bleeds.
	## Caller must call process_bleeds() each frame to apply tick damage.
	if not WorldState.is_alive(target_id):
		return []
	var multiplier: float = _calc_multiplier(skill_data, skill_level)
	var raw_damage: int = floori(combat.get_effective_atk() * multiplier)
	raw_damage = _apply_effectiveness(raw_damage, effectiveness_data)
	var actual_damage: int = combat.deal_damage_amount_to(target_id, raw_damage)

	var bleed_multiplier_per_tick: float = skill_data.get("bleed_multiplier_per_tick", 0.1)
	var bleed_ticks: int = skill_data.get("bleed_ticks", 5)

	var bonuses: Dictionary = effectiveness_data.get("synergy_bonuses", {})
	var bleed_dur_bonus: float = bonuses.get("bleed_duration_bonus", 0.0)
	var effective_duration: float = skill_data.get("bleed_duration", 3.0) * (1.0 + bleed_dur_bonus)

	var tick_interval: float = effective_duration / float(bleed_ticks) if bleed_ticks > 0 else effective_duration
	var damage_per_tick: int = floori(combat.get_effective_atk() * bleed_multiplier_per_tick)

	active_bleeds[target_id] = {
		"combat": combat,
		"damage_per_tick": damage_per_tick,
		"ticks_remaining": bleed_ticks,
		"tick_timer": tick_interval,
		"tick_interval": tick_interval,
	}

	return [{"target_id": target_id, "damage": actual_damage}]


static func process_bleeds(active_bleeds: Dictionary, delta: float) -> Array:
	## Called every _process() frame. Advances bleed timers and deals tick damage.
	## Removes expired or dead-target bleeds from active_bleeds in-place.
	## Returns Array of {target_id: String, damage: int} for ticks that fired this frame.
	var results: Array = []
	var to_remove: Array = []

	for target_id in active_bleeds:
		if not WorldState.is_alive(target_id):
			to_remove.append(target_id)
			continue

		var bleed: Dictionary = active_bleeds[target_id]
		bleed["tick_timer"] -= delta

		if bleed["tick_timer"] <= 0.0:
			var combat: Node = bleed.get("combat")
			var damage_per_tick: int = bleed.get("damage_per_tick", 1)
			if combat and is_instance_valid(combat):
				var tick_damage: int = combat.deal_damage_amount_to(target_id, damage_per_tick)
				results.append({"target_id": target_id, "damage": tick_damage})
				# If the tick killed the target, remove bleed immediately this frame
				if not WorldState.is_alive(target_id):
					to_remove.append(target_id)
					continue
			bleed["ticks_remaining"] -= 1
			bleed["tick_timer"] = bleed.get("tick_interval", 1.0)

		if bleed.get("ticks_remaining", 0) <= 0:
			to_remove.append(target_id)

	for target_id in to_remove:
		active_bleeds.erase(target_id)

	return results


# --- Internal helpers ---

static func _calc_multiplier(skill_data: Dictionary, skill_level: int) -> float:
	## Computes the effective damage multiplier for a given skill level.
	var base: float = skill_data.get("damage_multiplier", 1.0)
	var per_level: float = skill_data.get("damage_multiplier_per_level", 0.0)
	return base + (skill_level - 1) * per_level


static func _apply_effectiveness(raw_damage: int, effectiveness_data: Dictionary) -> int:
	## Applies effectiveness scaling, synergy damage_bonus, and crit_chance to raw_damage.
	## Returns the modified raw_damage value (before DEF reduction).
	var effectiveness: float = effectiveness_data.get("effectiveness", 1.0)
	var bonuses: Dictionary = effectiveness_data.get("synergy_bonuses", {})

	# Effectiveness scaling
	var result: int = floori(raw_damage * effectiveness)

	# Additive damage bonus from synergies
	result = floori(result * (1.0 + bonuses.get("damage_bonus", 0.0)))

	# Crit chance from synergies
	var crit_chance: float = bonuses.get("crit_chance", 0.0)
	if crit_chance > 0.0 and randf() < crit_chance:
		result = floori(result * 1.5)

	return result
