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
		attacker_id: String
) -> Array:
	## Main dispatch: routes to the correct resolver based on skill_data.type.
	## Returns Array of {target_id: String, damage: int}.
	var skill_type: String = skill_data.get("type", "")
	match skill_type:
		"melee_attack":
			return resolve_melee_attack(combat, skill_data, skill_level, target_id)
		"aoe_melee":
			return resolve_aoe(combat, perception, skill_data, skill_level, target_id, attacker_pos, attacker_id)
		"armor_pierce":
			return resolve_armor_pierce(combat, skill_data, skill_level, target_id)
		"bleed":
			return resolve_bleed(combat, skill_data, skill_level, target_id, active_bleeds)
		_:
			push_warning("SkillEffectResolver: unknown skill type '%s'" % skill_type)
			return []


static func resolve_melee_attack(
		combat: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String
) -> Array:
	## Single-target melee strike. Damage = effective_atk * multiplier, then reduced by target DEF.
	if not WorldState.is_alive(target_id):
		return []
	var multiplier: float = _calc_multiplier(skill_data, skill_level)
	var raw_damage: int = floori(combat.get_effective_atk() * multiplier)
	var actual_damage: int = combat.deal_damage_amount_to(target_id, raw_damage)
	return [{"target_id": target_id, "damage": actual_damage}]


static func resolve_aoe(
		combat: Node,
		perception: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String,
		attacker_pos: Vector3,
		attacker_id: String
) -> Array:
	## AoE melee: hits primary target then all nearby hostiles within aoe_radius.
	## No friendly fire — only entities whose id starts with "monster_".
	var results: Array = []
	var multiplier: float = _calc_multiplier(skill_data, skill_level)
	var raw_damage: int = floori(combat.get_effective_atk() * multiplier)

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

	var aoe_radius: float = skill_data.get("aoe_radius", 3.0)

	# Gather secondary targets from perception — fetch slightly wider than aoe_radius,
	# then filter precisely by distance to aoe_center below.
	var nearby: Array = perception.get_nearby(aoe_radius + 5.0)

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
		if dist_to_center > aoe_radius:
			continue
		var splash_damage: int = combat.deal_damage_amount_to(eid, raw_damage)
		results.append({"target_id": eid, "damage": splash_damage})

	return results


static func resolve_armor_pierce(
		combat: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String
) -> Array:
	## Armor-piercing strike: ignores a percentage of target DEF.
	## Requires CombatComponent.deal_damage_amount_to_with_pierce().
	if not WorldState.is_alive(target_id):
		return []
	var multiplier: float = _calc_multiplier(skill_data, skill_level)
	var raw_damage: int = floori(combat.get_effective_atk() * multiplier)
	var pierce_percent: float = skill_data.get("def_ignore_percent", 0.0)
	var actual_damage: int = combat.deal_damage_amount_to_with_pierce(target_id, raw_damage, pierce_percent)
	return [{"target_id": target_id, "damage": actual_damage}]


static func resolve_bleed(
		combat: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String,
		active_bleeds: Dictionary
) -> Array:
	## Initial bleed hit + registers ongoing bleed ticks in active_bleeds.
	## Caller must call process_bleeds() each frame to apply tick damage.
	if not WorldState.is_alive(target_id):
		return []
	var multiplier: float = _calc_multiplier(skill_data, skill_level)
	var raw_damage: int = floori(combat.get_effective_atk() * multiplier)
	var actual_damage: int = combat.deal_damage_amount_to(target_id, raw_damage)

	var bleed_multiplier_per_tick: float = skill_data.get("bleed_multiplier_per_tick", 0.1)
	var bleed_duration: float = skill_data.get("bleed_duration", 5.0)
	var bleed_ticks: int = skill_data.get("bleed_ticks", 5)
	var tick_interval: float = bleed_duration / float(bleed_ticks) if bleed_ticks > 0 else bleed_duration
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
