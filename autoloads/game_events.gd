extends Node
## Global signal bus for decoupled world events.

# Combat
signal entity_damaged(target_id: String, attacker_id: String, damage: int, remaining_hp: int)
signal entity_healed(entity_id: String, amount: int, current_hp: int)
signal entity_died(entity_id: String, killer_id: String)
signal entity_respawned(entity_id: String)
signal damage_defended(target_id: String, attacker_id: String, amount_negated: int, defense_type: String)

# Economy
signal item_looted(entity_id: String, item_id: String, count: int)

# Time
signal time_phase_changed(old_phase: String, new_phase: String)
signal game_hour_changed(hour: int)

# Stamina
signal stamina_changed(entity_id: String, stamina: float, max_stamina: float)
