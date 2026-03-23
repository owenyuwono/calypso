class_name InteriorBase
extends Node3D
## Base class for all interior scenes.
## Subclasses build geometry in _ready() then call super._ready() last
## (or call _interior_setup() after geometry is placed).
## Emits interior_ready after navmesh bake completes.
## Emits exit_requested when the player enters the ExitDoor Area3D.

signal interior_ready
signal exit_requested

var interior_type: String = ""
var _nav_region: NavigationRegion3D
var _spawn_point: Vector3 = Vector3.ZERO


func _ready() -> void:
	_nav_region = _find_nav_region()
	if not _nav_region:
		push_warning("[InteriorBase] No NavigationRegion3D found in %s" % name)

	var spawn_marker: Node = find_child("SpawnPoint", true, false)
	if spawn_marker and spawn_marker is Marker3D:
		_spawn_point = (spawn_marker as Marker3D).global_position

	var exit_door: Node = find_child("ExitDoor", true, false)
	if exit_door and exit_door is Area3D:
		(exit_door as Area3D).body_entered.connect(_on_exit_door_body_entered)
	else:
		push_warning("[InteriorBase] No ExitDoor Area3D found in %s" % name)

	await get_tree().create_timer(0.5).timeout
	if _nav_region:
		TerrainHelpers.begin_navmesh_bake(_nav_region, _on_navmesh_baked)
	else:
		interior_ready.emit()


## Returns the world position of the SpawnPoint Marker3D.
## Reads global_position at call time so the result is correct after the interior
## has been repositioned (e.g. to Y=-50) following _ready().
func get_spawn_point() -> Vector3:
	var spawn_marker: Node = find_child("SpawnPoint", true, false)
	if spawn_marker and spawn_marker is Marker3D:
		return (spawn_marker as Marker3D).global_position
	return _spawn_point

## Returns the NavigationRegion3D so callers can get its map RID.
func get_nav_region() -> NavigationRegion3D:
	return _nav_region


# --- Private ------------------------------------------------------------------

func _find_nav_region() -> NavigationRegion3D:
	for child in get_children():
		if child is NavigationRegion3D:
			return child as NavigationRegion3D
	return null


func _on_navmesh_baked() -> void:
	if _nav_region and _nav_region.navigation_mesh.get_polygon_count() == 0:
		push_warning("[InteriorBase] Navmesh is EMPTY after bake in %s" % name)
	interior_ready.emit()


func _on_exit_door_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		exit_requested.emit()
