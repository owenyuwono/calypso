extends RefCounted
## Static helper for spawning loot drop nodes into the active zone.
## Centralises the RigidBody3D+loot_drop.gd construction that was copy-pasted
## across harvestables, monsters, and the inventory discard action.

const _LOOT_SCRIPT = preload("res://scenes/objects/loot_drop.gd")


## Spawn a single loot node at *world_pos* parented to the loaded zone.
## Falls back to the current scene root if no zone is loaded.
static func spawn_drop(world_pos: Vector3, item_id: String, item_count: int, gold: int) -> void:
	var loot := RigidBody3D.new()
	loot.set_script(_LOOT_SCRIPT)
	loot.item_id = item_id
	loot.item_count = item_count
	loot.gold_amount = gold
	loot.position = world_pos
	var parent: Node = ZoneManager.get_loaded_zone()
	if not parent:
		parent = Engine.get_main_loop().current_scene
	if parent:
		parent.call_deferred("add_child", loot)
