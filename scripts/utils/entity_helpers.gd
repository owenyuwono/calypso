class_name EntityHelpers
## Shared utility functions for entity lifecycle events.

static func apply_death_gold_penalty(inventory: Node, penalty_ratio: float) -> int:
	## Deducts a percentage of gold on death. Returns the amount lost.
	var gold: int = inventory.get_gold_amount()
	var lost := int(gold * penalty_ratio)
	inventory.remove_gold_amount(lost)
	return lost
