extends Node
## Global signal bus for decoupled NPC/world events.

# NPC lifecycle
signal npc_action_started(npc_id: String, action: String, target: String)
signal npc_action_completed(npc_id: String, action: String, success: bool)
signal npc_state_changed(npc_id: String, old_state: String, new_state: String)
signal npc_goal_changed(npc_id: String, old_goal: String, new_goal: String)

# Dialogue
signal npc_spoke(npc_id: String, dialogue: String, target_id: String)
signal conversation_started(npc_a: String, npc_b: String)
signal conversation_ended(npc_a: String, npc_b: String)

# Items and objects
signal item_picked_up(item_id: String, by_entity_id: String)
signal item_dropped(item_id: String, by_entity_id: String, position: Vector3)
signal object_used(object_id: String, by_entity_id: String)

# LLM events
signal llm_request_sent(npc_id: String)
signal llm_response_received(npc_id: String, response: Dictionary)
signal llm_request_failed(npc_id: String, error: String)
