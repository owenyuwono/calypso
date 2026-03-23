class_name InteriorManager
extends Node
## Handles the full enter/exit lifecycle for in-zone interior rooms.
## Interiors are instantiated at Y=-50 to isolate them from exterior geometry.
## Fade transitions, exterior hide/show, nav map switching, and player teleport
## are all managed here.

const INTERIOR_Y: float = -50.0
const NAVMESH_TIMEOUT: float = 2.0
const INTERIOR_YAW_DEG: float = 45.0

var _player: CharacterBody3D
var _zone_anchor: Node3D
var _loading_screen: Node
var _current_interior: Node3D = null
var _is_inside: bool = false
var _exterior_return_pos: Vector3
var _current_building_type: String = ""
var _transitioning: bool = false

# Cached zone NavigationRegion3D — found once per zone load.
var _zone_nav_region: NavigationRegion3D = null

# Camera state saved before entering interior.
var _saved_camera_distance: float = 18.0
var _saved_camera_yaw: float = 0.0


# --- Setup --------------------------------------------------------------------

func setup(player: CharacterBody3D, zone_anchor: Node3D, loading_screen: Node) -> void:
	_player = player
	_zone_anchor = zone_anchor
	_loading_screen = loading_screen
	# Keep zone nav region in sync when zone changes.
	ZoneManager.zone_load_completed.connect(_on_zone_load_completed)


# --- Public API ---------------------------------------------------------------

func is_inside() -> bool:
	return _is_inside


func enter_interior(building_type: String, door_world_pos: Vector3) -> void:
	if _transitioning or _is_inside:
		return

	var interior_data: Dictionary = InteriorDatabase.get_interior(building_type)
	if interior_data.is_empty():
		push_warning("[InteriorManager] Unknown building type: %s" % building_type)
		return

	var scene_path: String = interior_data.get("scene_path", "")
	if not ResourceLoader.exists(scene_path):
		push_warning("[InteriorManager] Scene not found for building type '%s': %s" % [building_type, scene_path])
		_transitioning = false
		return

	_transitioning = true
	_exterior_return_pos = door_world_pos
	_current_building_type = building_type

	# Stop player movement and disable input.
	_player.nav_agent.set_target_position(_player.global_position)
	if _player.has_method("_stop_navigation"):
		_player._stop_navigation()
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)

	var interior_name: String = interior_data.get("name", building_type)
	var art_path: String = interior_data.get("loading_art", "")
	await _loading_screen.show_custom(interior_name, art_path)

	_hide_exterior()

	# Load and instantiate interior scene.
	var scene: PackedScene = load(scene_path)
	_current_interior = scene.instantiate()
	_zone_anchor.add_child(_current_interior)
	_current_interior.global_position = Vector3(0.0, INTERIOR_Y, 0.0)

	# Wait for interior navmesh bake (interior_ready signal), with a timeout fallback.
	var ready_received: bool = false
	if _current_interior.has_signal("interior_ready"):
		var timeout_timer: SceneTreeTimer = get_tree().create_timer(NAVMESH_TIMEOUT)
		var done: bool = false
		_current_interior.interior_ready.connect(func() -> void: done = true, CONNECT_ONE_SHOT)
		while not done:
			await get_tree().process_frame
			if timeout_timer.time_left <= 0.0:
				push_warning("[InteriorManager] interior_ready timeout for %s" % building_type)
				break
		ready_received = true

	# Connect exit signal (no CONNECT_ONE_SHOT — interior is freed on exit which disconnects naturally).
	if _current_interior.has_signal("exit_requested"):
		_current_interior.exit_requested.connect(exit_interior)

	# Teleport player to interior spawn.
	_player.velocity = Vector3.ZERO
	_player.global_position = _current_interior.get_spawn_point()

	# Switch nav map to interior's NavigationRegion3D.
	var interior_nav: NavigationRegion3D = _current_interior.get_nav_region()
	if interior_nav:
		_player.nav_agent.set_navigation_map(interior_nav.get_navigation_map())
	else:
		push_warning("[InteriorManager] Interior has no NavigationRegion3D — nav map not switched")

	_switch_camera_to_isometric()

	_is_inside = true
	_transitioning = false

	_player.set_physics_process(true)
	_player.set_process_unhandled_input(true)

	await _loading_screen.hide_loading()

	GameEvents.entered_interior.emit(building_type)


func exit_interior() -> void:
	if _transitioning or not _is_inside:
		return

	_transitioning = true

	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)

	var exit_data: Dictionary = InteriorDatabase.get_interior(_current_building_type)
	var exit_name: String = exit_data.get("name", _current_building_type)
	var exit_art: String = exit_data.get("loading_art", "")
	await _loading_screen.show_custom(exit_name, exit_art)

	# Free interior — disconnect exit signal and clean up nav region first.
	if is_instance_valid(_current_interior):
		if _current_interior.exit_requested.is_connected(exit_interior):
			_current_interior.exit_requested.disconnect(exit_interior)
		var nav: NavigationRegion3D = _current_interior.get_nav_region()
		if nav:
			nav.enabled = false
			nav.navigation_mesh = null
		_current_interior.queue_free()
	_current_interior = null

	_show_exterior()

	# Teleport player back outside.
	_player.velocity = Vector3.ZERO
	_player.global_position = _exterior_return_pos
	if _player.has_method("_stop_navigation"):
		_player._stop_navigation()

	# Restore zone nav map and camera.
	_restore_zone_nav_map()
	_restore_camera()

	_is_inside = false
	_transitioning = false

	_player.set_physics_process(true)
	_player.set_process_unhandled_input(true)

	await _loading_screen.hide_loading()

	GameEvents.exited_interior.emit()


# --- Internal -----------------------------------------------------------------

func _hide_exterior() -> void:
	var zone_nav: NavigationRegion3D = _get_zone_nav_region()
	if zone_nav:
		zone_nav.visible = false

	var npcs_node: Node = _player.get_parent().get_node_or_null("NPCs")
	if npcs_node:
		for npc in npcs_node.get_children():
			npc.visible = false
			npc.set_process(false)
			npc.set_physics_process(false)


func _show_exterior() -> void:
	var zone_nav: NavigationRegion3D = _get_zone_nav_region()
	if zone_nav:
		zone_nav.visible = true

	var npcs_node: Node = _player.get_parent().get_node_or_null("NPCs")
	if npcs_node:
		for npc in npcs_node.get_children():
			npc.visible = true
			npc.set_process(true)
			npc.set_physics_process(true)


func _get_zone_nav_region() -> NavigationRegion3D:
	if is_instance_valid(_zone_nav_region):
		return _zone_nav_region
	# Fallback: search first child of zone anchor.
	var loaded_zone: Node3D = ZoneManager.get_loaded_zone()
	if not loaded_zone:
		return null
	for child in loaded_zone.get_children():
		if child is NavigationRegion3D:
			_zone_nav_region = child as NavigationRegion3D
			return _zone_nav_region
	return null


func _switch_camera_to_isometric() -> void:
	var camera: Camera3D = _player.get_viewport().get_camera_3d()
	if not camera:
		return
	if "_distance" in camera:
		_saved_camera_distance = camera._distance
		_saved_camera_yaw = camera._target_yaw
		camera._target_yaw = deg_to_rad(INTERIOR_YAW_DEG)
		camera._yaw = deg_to_rad(INTERIOR_YAW_DEG)
		camera._distance = 12.0


func _restore_camera() -> void:
	var camera: Camera3D = _player.get_viewport().get_camera_3d()
	if not camera:
		return
	if "_distance" in camera:
		camera._distance = _saved_camera_distance
	if "_target_yaw" in camera:
		camera._target_yaw = _saved_camera_yaw
		camera._yaw = _saved_camera_yaw


func _restore_zone_nav_map() -> void:
	var zone_nav: NavigationRegion3D = _get_zone_nav_region()
	if zone_nav:
		_player.nav_agent.set_navigation_map(zone_nav.get_navigation_map())
	else:
		push_warning("[InteriorManager] Could not restore zone nav map — NavigationRegion3D not found")


func _on_zone_load_completed(_zone_id: String) -> void:
	# Invalidate cached nav region so it is re-fetched for the new zone.
	_zone_nav_region = null
	# If somehow a zone transition fires while inside, force exit without transition.
	if _is_inside:
		if is_instance_valid(_current_interior):
			var nav: NavigationRegion3D = _current_interior.get_nav_region()
			if nav:
				nav.enabled = false
				nav.navigation_mesh = null
			_current_interior.queue_free()
		_current_interior = null
		_is_inside = false
		_transitioning = false
		_loading_screen.visible = false
		_player.set_physics_process(true)
		_player.set_process_unhandled_input(true)
		push_warning("[InteriorManager] Zone changed while inside — forced exit")
