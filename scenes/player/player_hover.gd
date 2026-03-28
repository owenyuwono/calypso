extends Node
## Proximity interaction prompt system.
## Shows [E] label + ground ring on the nearest interactable entity within range.
## Call setup(player) from player._ready() after adding as child.

const PROXIMITY_RANGE: float = 3.0
const PROXIMITY_CHECK_INTERVAL: float = 0.2
const INTERACTABLE_TYPES: PackedStringArray = ["npc", "interior_npc", "tree", "rock", "fishing_spot", "crafting_station", "door"]

var _player: Node3D

# Proximity prompt
var _proximity_target_id: String = ""
var _proximity_label: Label3D
var _proximity_ring: MeshInstance3D
var _proximity_ring_material: StandardMaterial3D
var _proximity_timer: float = 0.0


func setup(player: Node3D) -> void:
	_player = player
	_setup_proximity_label()


## Returns the entity id of the current proximity interaction target.
func get_proximity_target_id() -> String:
	return _proximity_target_id


func _setup_proximity_label() -> void:
	_proximity_label = Label3D.new()
	_proximity_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_proximity_label.font_size = 24
	_proximity_label.modulate = Color(1, 1, 0.9)
	_proximity_label.outline_modulate = Color(0, 0, 0)
	_proximity_label.outline_size = 8
	_proximity_label.no_depth_test = true
	_proximity_label.top_level = true
	_proximity_label.visible = false
	var font: Font = load("res://assets/fonts/Philosopher-Bold.ttf")
	if font:
		_proximity_label.font = font
	add_child(_proximity_label)

	# Ground ring for proximity target
	_proximity_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.6
	_proximity_ring.mesh = torus
	_proximity_ring.top_level = true
	_proximity_ring_material = StandardMaterial3D.new()
	_proximity_ring_material.albedo_color = Color(1.0, 0.9, 0.6, 0.45)
	_proximity_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_proximity_ring_material.no_depth_test = false
	_proximity_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_proximity_ring.material_override = _proximity_ring_material
	_proximity_ring.visible = false
	add_child(_proximity_ring)


func _process(delta: float) -> void:
	if not _player:
		return
	_process_proximity(delta)


func _process_proximity(_delta: float) -> void:
	_proximity_timer -= _delta
	if _proximity_timer > 0.0:
		# Track label + ring position every frame for smoothness
		if _proximity_label.visible and _proximity_target_id != "":
			var target := WorldState.get_entity(_proximity_target_id)
			if target and is_instance_valid(target):
				_proximity_label.global_position = target.global_position + Vector3(0, 2.2, 0)
				_proximity_ring.global_position = target.global_position + Vector3(0, 0.05, 0)
		return
	_proximity_timer = PROXIMITY_CHECK_INTERVAL

	var player_pos: Vector3 = _player.global_position
	var best_id: String = ""
	var best_dist: float = PROXIMITY_RANGE
	var best_node: Node3D = null

	for eid in WorldState.entities:
		if eid == "player":
			continue
		var node: Node3D = WorldState.entities[eid]
		if not node or not is_instance_valid(node):
			continue
		var dist: float = player_pos.distance_to(node.global_position)
		if dist >= best_dist:
			continue
		var data: Dictionary = WorldState.get_entity_data(eid)
		var etype: String = data.get("type", "")
		if etype in INTERACTABLE_TYPES:
			best_dist = dist
			best_id = eid
			best_node = node

	if best_id != _proximity_target_id:
		_proximity_target_id = best_id

		if best_id != "":
			var data: Dictionary = WorldState.get_entity_data(best_id)
			var etype: String = data.get("type", "")
			_proximity_label.text = _get_action_text(etype)
			_proximity_label.global_position = best_node.global_position + Vector3(0, 2.2, 0)
			_proximity_label.visible = true
			_proximity_ring.global_position = best_node.global_position + Vector3(0, 0.05, 0)
			_proximity_ring.visible = true
		else:
			_proximity_label.visible = false
			_proximity_ring.visible = false


static func _get_action_text(entity_type: String) -> String:
	match entity_type:
		"npc", "interior_npc":
			return "[E] Talk"
		"tree":
			return "[E] Chop"
		"rock":
			return "[E] Mine"
		"fishing_spot":
			return "[E] Fish"
		"crafting_station":
			return "[E] Craft"
		"door":
			return "[E] Enter"
	return "[E] Interact"
