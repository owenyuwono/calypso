class_name BaseComponent
extends Node
## Base class for all entity components. Provides shared entity_id resolution.

func _get_entity_id() -> String:
	var parent := get_parent()
	if parent and "entity_id" in parent:
		return parent.entity_id
	return ""
