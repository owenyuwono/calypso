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

# Ammo
signal ammo_changed(entity_id: String, magazine_current: int, magazine_max: int, reserve: int)
signal reload_started(entity_id: String)
signal reload_finished(entity_id: String)
signal combat_mode_changed(entity_id: String, mode: String)

# Resources
signal resources_updated(snapshot: Dictionary)
signal resource_depleted(resource_type: String)
signal device_shutdown(device_id: String, device_type: String)
signal grid_status_changed(connected: bool)

# Personal needs
signal needs_changed(needs: Dictionary)
signal need_critical(need_type: String)
