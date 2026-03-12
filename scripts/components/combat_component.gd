extends Node
## Component that owns combat logic for an entity.
## Depends on: StatsComponent (hp, atk, def), EquipmentComponent (atk/def bonuses, optional).

var _stats: Node       # StatsComponent ref (required)
var _equipment: Node   # EquipmentComponent ref (optional — monsters don't have equipment)

func setup(stats_component: Node, equipment_component: Node = null) -> void:
	_stats = stats_component
	_equipment = equipment_component

func is_alive() -> bool:
	return _stats.is_alive()

func get_stat(stat_name: String) -> Variant:
	return _stats.get(stat_name) if stat_name in _stats else 0

func get_effective_atk() -> int:
	var base: int = _stats.atk
	if _equipment:
		base += _equipment.get_atk_bonus()
	return base

func get_effective_def() -> int:
	var base: int = _stats.def
	if _equipment:
		base += _equipment.get_def_bonus()
	return base

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
		# Fallback: direct entity_data mutation
		var data := WorldState.get_entity_data(target_id)
		var hp: int = maxi(data.get("hp", 0) - damage, 0)
		data["hp"] = hp
		GameEvents.entity_damaged.emit(target_id, attacker_id, damage, hp)
		if hp <= 0:
			GameEvents.entity_died.emit(target_id, attacker_id)
