extends Node
## Zone lifecycle manager. Handles loading, unloading, and transitioning between zone scenes.
## Zones load as children of ZoneAnchor. NPCs persist under Main/NPCs and are never freed here.

signal zone_changed(old_zone_id: String, new_zone_id: String)
signal zone_load_started(zone_id: String)
signal zone_load_completed(zone_id: String)

var _loaded_zone: Node3D = null
var _zone_anchor: Node3D = null
var _player: CharacterBody3D = null
var _loading_screen: Node = null
var _is_transitioning: bool = false

# --- Setup ---

func setup(zone_anchor: Node3D, player: CharacterBody3D, root_node: Node) -> void:
	_zone_anchor = zone_anchor
	_player = player
	_loading_screen = load("res://scenes/ui/loading_screen.gd").new()
	root_node.add_child(_loading_screen)

# --- Accessors ---

func get_loaded_zone() -> Node3D:
	return _loaded_zone

func get_loading_screen() -> Node:
	return _loading_screen

func is_transitioning() -> bool:
	return _is_transitioning

# --- Zone Loading ---

func load_zone(zone_id: String, spawn_position: Vector3) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	var old_zone_id: String = ""
	if _loaded_zone and "zone_id" in _loaded_zone:
		old_zone_id = _loaded_zone.zone_id

	# Skip if already in this zone
	if old_zone_id == zone_id:
		_is_transitioning = false
		return

	# Disable player input during transition
	_player.set_process_unhandled_input(false)
	_player.set_physics_process(false)

	zone_load_started.emit(zone_id)

	# Show loading screen (handles fade-in internally; first load skips fade)
	await _loading_screen.show_loading(zone_id)

	# Unload current zone
	if _loaded_zone:
		await _unload_current_zone()

	# Load new zone — derive scene path directly from zone_id
	var scene_path: String = "res://scenes/zones/" + zone_id + ".tscn"
	var scene: PackedScene = load(scene_path)
	var zone_node: Node3D = scene.instantiate()
	_zone_anchor.add_child(zone_node)
	_loaded_zone = zone_node

	# Teleport player and clear navigation state
	_player.global_position = spawn_position
	if _player.has_method("_stop_navigation"):
		_player._stop_navigation()

	# Wait for zone to signal readiness (navmesh bake etc.), or fall back to next frame
	if zone_node.has_signal("zone_ready"):
		await zone_node.zone_ready
	else:
		await get_tree().process_frame

	# Notify NPCs and UI that the active zone changed
	zone_changed.emit(old_zone_id, zone_id)
	zone_load_completed.emit(zone_id)

	# Hide loading screen (enforces min display time, animates progress to 1.0, fades out)
	await _loading_screen.hide_loading()

	# Re-enable player
	_player.set_process_unhandled_input(true)
	_player.set_physics_process(true)

	_is_transitioning = false

# --- Internal ---

func _unload_current_zone() -> void:
	if not _loaded_zone:
		return

	# Unregister zone-owned entities (monsters, loot) before freeing.
	# NPCs live under Main/NPCs, not under the zone — they are intentionally skipped.
	var entities_to_remove: Array = []
	for entity_id in WorldState.entities:
		var node: Node3D = WorldState.entities[entity_id]
		if is_instance_valid(node) and _loaded_zone.is_ancestor_of(node):
			entities_to_remove.append(entity_id)

	for entity_id in entities_to_remove:
		WorldState.unregister_entity(entity_id)

	_loaded_zone.queue_free()
	_loaded_zone = null
	await get_tree().process_frame

