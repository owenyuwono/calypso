extends Node
## Component that owns combat logic for an entity.
## Depends on: StatsComponent (hp, atk, def), EquipmentComponent (atk/def bonuses, optional).

const ItemDatabase = preload("res://scripts/data/item_database.gd")

var _stats: Node       # StatsComponent ref (required)
var _equipment: Node   # EquipmentComponent ref (optional — monsters don't have equipment)

func setup(stats_component: Node, equipment_component: Node = null) -> void:
	_stats = stats_component
	_equipment = equipment_component

func is_alive() -> bool:
	return _stats.is_alive()

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

func get_attack_speed_multiplier() -> float:
	## Returns the speed multiplier for the equipped weapon (penalty-adjusted).
	if not _equipment:
		return 1.0
	var weapon_id: String = _equipment.get_weapon()
	if weapon_id.is_empty():
		return 1.0
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

func _get_item_penalty(item_id: String) -> Dictionary:
	## Calculate penalty for using an item above your proficiency level.
	var item: Dictionary = ItemDatabase.get_item(item_id)
	var required_skill: String = item.get("required_skill", "")
	var required_level: int = item.get("required_level", 1)
	if required_skill.is_empty():
		return {"stat_mult": 1.0, "speed_mult": 1.0}

	var parent := get_parent()
	if not parent:
		return {"stat_mult": 1.0, "speed_mult": 1.0}
	var progression = parent.get_node_or_null("ProgressionComponent")
	if not progression:
		return {"stat_mult": 1.0, "speed_mult": 1.0}

	var prof_level: int = progression.get_proficiency_level(required_skill)
	var level_gap: int = maxi(0, required_level - prof_level)
	var stat_mult: float = maxf(0.25, 1.0 - level_gap * 0.15)
	var speed_mult: float = minf(1.75, 1.0 + level_gap * 0.15)
	return {"stat_mult": stat_mult, "speed_mult": speed_mult}

func deal_damage_to(target_id: String) -> int:
	## Standard auto-attack: effective_atk - target_effective_def, min 1.
	var target_entity = WorldState.get_entity(target_id)
	if not target_entity or not is_instance_valid(target_entity):
		return 0
	var target_combat = target_entity.get_node_or_null("CombatComponent")
	var atk: int = get_effective_atk()
	var def: int = target_combat.get_effective_def() if target_combat else 0
	var damage: int = maxi(atk - def, 1)
	_apply_damage_to(target_id, damage)
	return damage

func deal_damage_amount_to(target_id: String, amount: int) -> int:
	## Skill damage: raw amount - target_effective_def, min 1.
	var target_entity = WorldState.get_entity(target_id)
	if not target_entity or not is_instance_valid(target_entity):
		return 0
	var target_combat = target_entity.get_node_or_null("CombatComponent")
	var def: int = target_combat.get_effective_def() if target_combat else 0
	var damage: int = maxi(amount - def, 1)
	_apply_damage_to(target_id, damage)
	return damage

func heal(amount: int) -> int:
	var healed: int = _stats.heal(amount)
	if healed > 0:
		var eid := _get_entity_id()
		if not eid.is_empty():
			GameEvents.entity_healed.emit(eid, healed, _stats.hp)
	return healed

func _get_entity_id() -> String:
	var parent := get_parent()
	if parent and "entity_id" in parent:
		return parent.entity_id
	return ""

func _apply_damage_to(target_id: String, damage: int) -> void:
	var target_entity = WorldState.get_entity(target_id)
	if not target_entity or not is_instance_valid(target_entity):
		return
	var attacker_id := _get_entity_id()
	var target_stats = target_entity.get_node_or_null("StatsComponent")
	if target_stats:
		target_stats.take_damage(damage)
		GameEvents.entity_damaged.emit(target_id, attacker_id, damage, target_stats.hp)
		if not target_stats.is_alive():
			GameEvents.entity_died.emit(target_id, attacker_id)
	else:
		push_warning("CombatComponent: target '%s' has no StatsComponent — damage dropped" % target_id)
		return
