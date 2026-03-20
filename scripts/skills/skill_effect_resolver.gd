class_name SkillEffectResolver
extends RefCounted
## Static utility for resolving skill damage effects.
## Handles melee_attack, aoe_melee, armor_pierce, and bleed skill types.
## All methods are static — no instance needed.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

const RESISTANCE_MULTIPLIERS: Dictionary = {
	"fatal": 2.0, "weak": 1.5, "neutral": 1.0, "resist": 0.5, "immune": 0.0
}

const ARMOR_PHYS_TYPE_TABLE: Dictionary = {
	# armor_type -> {phys_type -> resistance_level}
	"heavy":  {"slash": "resist", "pierce": "neutral", "blunt": "weak"},
	"medium": {"slash": "neutral", "pierce": "weak",   "blunt": "neutral"},
	"light":  {"slash": "weak",   "pierce": "neutral", "blunt": "neutral"},
}

const ELEMENT_OPPOSITES: Dictionary = {
	"fire": "ice",  "ice": "fire",
	"lightning": "earth", "earth": "lightning",
	"light": "dark", "dark": "light",
}

static func get_element_modifier(attack_element, target_resistances: Dictionary) -> float:
	if attack_element == null or attack_element == "arcane":
		return 1.0
	if target_resistances.has(attack_element):
		var level: String = target_resistances[attack_element]
		return RESISTANCE_MULTIPLIERS.get(level, 1.0)
	return 1.0

static func get_phys_type_modifier(phys_type: String, armor_type: String) -> float:
	var armor_table: Dictionary = ARMOR_PHYS_TYPE_TABLE.get(armor_type, {})
	var level: String = armor_table.get(phys_type, "neutral")
	return RESISTANCE_MULTIPLIERS.get(level, 1.0)


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
	## Returns Array of {target_id: String, damage: int, is_crit: bool, is_miss: bool}.
	## Self-harm entries additionally carry {self_harm: true}.
	var skill_type: String = skill_data.get("type", "")
	var results: Array = []
	match skill_type:
		"melee_attack":
			results = resolve_melee_attack(combat, skill_data, skill_level, target_id, attacker_id, effectiveness_data)
		"aoe_melee":
			results = resolve_aoe(combat, perception, skill_data, skill_level, target_id, attacker_pos, attacker_id, effectiveness_data)
		"armor_pierce":
			results = resolve_armor_pierce(combat, skill_data, skill_level, target_id, attacker_id, effectiveness_data)
		"bleed":
			results = resolve_bleed(combat, skill_data, skill_level, target_id, active_bleeds, attacker_id, effectiveness_data)
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
		# SkillsComponent handles the actual HP deduction for self-harm entries.
		results.append({"target_id": attacker_id, "damage": self_damage, "is_crit": false, "is_miss": false, "self_harm": true})

	return results


static func resolve_melee_attack(
		combat: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String,
		attacker_id: String,
		effectiveness_data: Dictionary = {}
) -> Array:
	## Single-target melee strike using full damage pipeline.
	if not WorldState.is_alive(target_id):
		return []

	# Hit/miss check
	if not combat.roll_hit(target_id):
		GameEvents.attack_missed.emit(target_id, attacker_id)
		return [{"target_id": target_id, "damage": 0, "is_crit": false, "is_miss": true}]

	var final_damage: int = _calc_damage(combat, skill_data, skill_level, target_id, effectiveness_data)
	var crit_result: Dictionary = combat.roll_crit()
	var is_crit: bool = crit_result["is_crit"]
	if is_crit:
		final_damage = maxi(1, int(final_damage * crit_result["multiplier"]))

	combat.apply_flat_damage_to(target_id, final_damage)
	return [{"target_id": target_id, "damage": final_damage, "is_crit": is_crit, "is_miss": false}]


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
	## Hit/miss and crit are checked per target individually.
	var results: Array = []

	# Primary target
	if WorldState.is_alive(target_id):
		if not combat.roll_hit(target_id):
			GameEvents.attack_missed.emit(target_id, attacker_id)
			results.append({"target_id": target_id, "damage": 0, "is_crit": false, "is_miss": true})
		else:
			var primary_damage: int = _calc_damage(combat, skill_data, skill_level, target_id, effectiveness_data)
			var crit_result: Dictionary = combat.roll_crit()
			var is_crit: bool = crit_result["is_crit"]
			if is_crit:
				primary_damage = maxi(1, int(primary_damage * crit_result["multiplier"]))
			combat.apply_flat_damage_to(target_id, primary_damage)
			results.append({"target_id": target_id, "damage": primary_damage, "is_crit": is_crit, "is_miss": false})

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

		if not combat.roll_hit(eid):
			GameEvents.attack_missed.emit(eid, attacker_id)
			results.append({"target_id": eid, "damage": 0, "is_crit": false, "is_miss": true})
		else:
			var splash_damage: int = _calc_damage(combat, skill_data, skill_level, eid, effectiveness_data)
			var crit_result: Dictionary = combat.roll_crit()
			var is_crit: bool = crit_result["is_crit"]
			if is_crit:
				splash_damage = maxi(1, int(splash_damage * crit_result["multiplier"]))
			combat.apply_flat_damage_to(eid, splash_damage)
			results.append({"target_id": eid, "damage": splash_damage, "is_crit": is_crit, "is_miss": false})

	return results


static func resolve_armor_pierce(
		combat: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String,
		attacker_id: String,
		effectiveness_data: Dictionary = {}
) -> Array:
	## Armor-piercing strike: ignores a percentage of target DEF during damage calc.
	if not WorldState.is_alive(target_id):
		return []

	# Hit/miss check
	if not combat.roll_hit(target_id):
		GameEvents.attack_missed.emit(target_id, attacker_id)
		return [{"target_id": target_id, "damage": 0, "is_crit": false, "is_miss": true}]

	var bonuses: Dictionary = effectiveness_data.get("synergy_bonuses", {})
	var pierce_bonus: float = bonuses.get("pierce_bonus", 0.0)
	var effective_pierce: float = clampf(skill_data.get("def_ignore_percent", 0.0) + pierce_bonus, 0.0, 1.0)

	var final_damage: int = _calc_damage(combat, skill_data, skill_level, target_id, effectiveness_data, effective_pierce)
	var crit_result: Dictionary = combat.roll_crit()
	var is_crit: bool = crit_result["is_crit"]
	if is_crit:
		final_damage = maxi(1, int(final_damage * crit_result["multiplier"]))

	combat.apply_flat_damage_to(target_id, final_damage)
	return [{"target_id": target_id, "damage": final_damage, "is_crit": is_crit, "is_miss": false}]


static func resolve_bleed(
		combat: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String,
		active_bleeds: Dictionary,
		attacker_id: String,
		effectiveness_data: Dictionary = {}
) -> Array:
	## Initial bleed hit uses the full damage pipeline.
	## Registers ongoing bleed ticks in active_bleeds (simpler — no element/crit per tick).
	## Caller must call process_bleeds() each frame to apply tick damage.
	if not WorldState.is_alive(target_id):
		return []

	# Hit/miss check
	if not combat.roll_hit(target_id):
		GameEvents.attack_missed.emit(target_id, attacker_id)
		return [{"target_id": target_id, "damage": 0, "is_crit": false, "is_miss": true}]

	var final_damage: int = _calc_damage(combat, skill_data, skill_level, target_id, effectiveness_data)
	var crit_result: Dictionary = combat.roll_crit()
	var is_crit: bool = crit_result["is_crit"]
	if is_crit:
		final_damage = maxi(1, int(final_damage * crit_result["multiplier"]))
	combat.apply_flat_damage_to(target_id, final_damage)

	# Register bleed ticks
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

	return [{"target_id": target_id, "damage": final_damage, "is_crit": is_crit, "is_miss": false}]


static func process_bleeds(active_bleeds: Dictionary, delta: float) -> Array:
	## Called every _process() frame. Advances bleed timers and deals tick damage.
	## Removes expired or dead-target bleeds from active_bleeds in-place.
	## Returns Array of {target_id: String, damage: int, is_crit: bool, is_miss: bool} for ticks that fired this frame.
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
				var tick_damage: int = combat.apply_flat_damage_to(target_id, damage_per_tick)
				results.append({"target_id": target_id, "damage": tick_damage, "is_crit": false, "is_miss": false})
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


static func _get_target_resistances(target_id: String) -> Dictionary:
	## Returns the target's elemental resistance table, if any.
	## Monsters store resistances in their entity_data (set by monster_base.gd).
	var entity_data: Dictionary = WorldState.get_entity_data(target_id)
	if entity_data.has("resistances"):
		return entity_data["resistances"]
	return {}


static func _get_target_armor_type(target_id: String) -> String:
	## Returns the armor_type of the target's equipped torso ("light" if none).
	var target_node: Node = WorldState.get_entity(target_id)
	if target_node:
		var combat: Node = target_node.get_node_or_null("CombatComponent")
		if combat:
			return combat.get_armor_type()
	return "light"


static func _calc_damage(
		combat: Node,
		skill_data: Dictionary,
		skill_level: int,
		target_id: String,
		effectiveness_data: Dictionary,
		def_ignore: float = 0.0
) -> int:
	## Full damage pipeline: ATK/MATK → multiplier → effectiveness → DEF → element → phys_type → min 1.
	## def_ignore (0.0–1.0) reduces effective DEF before subtraction (armor_pierce use case).
	## Crit is NOT applied here — callers apply it after this returns.
	var damage_category: String = skill_data.get("damage_category", "physical")
	var element = skill_data.get("element")  # String or null

	var is_magical: bool = damage_category == "magical"

	# Attack power
	var attack_power: int
	if is_magical:
		attack_power = combat.get_effective_matk()
	else:
		attack_power = combat.get_effective_atk()

	# Skill multiplier × effectiveness scaling × damage_bonus synergy
	var base_multiplier: float = _calc_multiplier(skill_data, skill_level)
	var effectiveness: float = effectiveness_data.get("effectiveness", 1.0)
	var synergy_bonuses: Dictionary = effectiveness_data.get("synergy_bonuses", {})
	var damage_bonus: float = synergy_bonuses.get("damage_bonus", 0.0)
	var effective_multiplier: float = base_multiplier * effectiveness * (1.0 + damage_bonus)

	var raw: float = attack_power * effective_multiplier

	# Target defense
	var target_defense: int = 0
	var target_node: Node = WorldState.get_entity(target_id)
	if target_node:
		var target_combat: Node = target_node.get_node_or_null("CombatComponent")
		if target_combat:
			var full_def: int
			if is_magical:
				full_def = target_combat.get_effective_mdef()
			else:
				full_def = target_combat.get_effective_def()
			target_defense = floori(full_def * (1.0 - def_ignore))

	var after_def: float = maxf(1.0, raw - target_defense)

	# Element modifier
	var target_resistances: Dictionary = _get_target_resistances(target_id)
	var element_mod: float = get_element_modifier(element, target_resistances)

	# Physical type modifier (physical attacks only)
	var phys_type_mod: float = 1.0
	if not is_magical:
		var phys_type: String = combat.get_equipped_phys_type()
		var armor_type: String = _get_target_armor_type(target_id)
		phys_type_mod = get_phys_type_modifier(phys_type, armor_type)

	return maxi(1, int(after_def * element_mod * phys_type_mod))


static func _apply_effectiveness(raw_damage: int, effectiveness_data: Dictionary) -> int:
	## Kept for backward compatibility. Applies effectiveness scaling and synergy damage_bonus only.
	## Crit is no longer handled here — use combat.roll_crit() in each resolver.
	var effectiveness: float = effectiveness_data.get("effectiveness", 1.0)
	var bonuses: Dictionary = effectiveness_data.get("synergy_bonuses", {})
	var result: int = floori(raw_damage * effectiveness)
	result = floori(result * (1.0 + bonuses.get("damage_bonus", 0.0)))
	return result
