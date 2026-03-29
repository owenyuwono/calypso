extends Node
## Global signal bus for decoupled NPC/world events.

# NPC lifecycle
signal npc_action_completed(npc_id: String, action: String, success: bool)

# Dialogue
signal npc_spoke(npc_id: String, dialogue: String, target_id: String)

# Combat
signal entity_damaged(target_id: String, attacker_id: String, damage: int, remaining_hp: int)
signal entity_healed(entity_id: String, amount: int, current_hp: int)
signal entity_died(entity_id: String, killer_id: String)
signal entity_respawned(entity_id: String)
signal damage_defended(target_id: String, attacker_id: String, amount_negated: int, defense_type: String)

# Progression
signal proficiency_xp_gained(entity_id: String, skill_id: String, amount: int, new_xp: int)
signal proficiency_level_up(entity_id: String, skill_id: String, new_level: int)

# Economy
signal item_looted(entity_id: String, item_id: String, count: int)

# Skills
signal skill_used(entity_id: String, skill_id: String)
signal skill_learned(entity_id: String, skill_id: String, new_level: int)

# Time
signal time_phase_changed(old_phase: String, new_phase: String)
signal game_hour_changed(hour: int)

# Stamina
signal stamina_changed(entity_id: String, stamina: float, max_stamina: float)

# Relationships
signal relationship_tier_changed(entity_id: String, partner_id: String, old_tier: String, new_tier: String)

# Quest
signal quest_accepted(entity_id: String, quest_id: String)
signal quest_objective_updated(entity_id: String, quest_id: String, objective_idx: int, progress: int)
signal quest_completed(entity_id: String, quest_id: String, rewards: Dictionary)

