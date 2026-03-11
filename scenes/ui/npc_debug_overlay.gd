extends Node3D
## Debug overlay that draws 3D lines between NPCs within social proximity.
## Toggled with F1 (same as debug panel).

const SOCIAL_PROXIMITY: float = 12.0
const REFRESH_INTERVAL: float = 0.5
const LINE_HEIGHT: float = 2.0
const CONVERSATION_EXPIRE: float = 6.0

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _refresh_timer: float = 0.0
var _visible: bool = true

# Signal-based conversation tracking: "a<>b" -> {timer: float, last_speaker: String, last_line: String}
var _active_conversations: Dictionary = {}

# Label3D pool for conversation labels
var _labels: Array[Label3D] = []
var _label_index: int = 0

func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.no_depth_test = true
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	visible = _visible

	GameEvents.npc_spoke.connect(_on_npc_spoke)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F1:
		_visible = not _visible
		visible = _visible

func _process(delta: float) -> void:
	if not _visible:
		return

	# Tick conversation expiry timers
	var expired_keys: Array = []
	for key in _active_conversations:
		_active_conversations[key]["timer"] -= delta
		if _active_conversations[key]["timer"] <= 0.0:
			expired_keys.append(key)
	for key in expired_keys:
		_active_conversations.erase(key)

	_refresh_timer += delta
	if _refresh_timer < REFRESH_INTERVAL:
		return
	_refresh_timer = 0.0
	_rebuild_lines()

func _on_npc_spoke(speaker_id: String, dialogue: String, target_id: String) -> void:
	if target_id.is_empty():
		return
	var key := _pair_key(speaker_id, target_id)
	_active_conversations[key] = {
		"timer": CONVERSATION_EXPIRE,
		"last_speaker": speaker_id,
		"last_line": dialogue
	}

func _pair_key(a: String, b: String) -> String:
	if a < b:
		return a + "<>" + b
	return b + "<>" + a

func _rebuild_lines() -> void:
	var mesh := ImmediateMesh.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = _material
	_label_index = 0

	# Collect adventurer NPCs
	var adventurers: Array = []
	for entity_id in WorldState.entities:
		var data: Dictionary = WorldState.get_entity_data(entity_id)
		if data.get("type", "") != "npc":
			continue
		if not WorldState.is_alive(entity_id):
			continue
		var node := WorldState.get_entity(entity_id)
		if not node or not is_instance_valid(node):
			continue
		adventurers.append({"id": entity_id, "node": node})

	# Build lookup of adventurer nodes by id
	var node_map: Dictionary = {}
	for adv in adventurers:
		node_map[adv["id"]] = adv["node"]

	# Draw lines only between actively conversing pairs
	for key in _active_conversations:
		var parts: PackedStringArray = key.split("<>")
		var id_a: String = parts[0]
		var id_b: String = parts[1]
		if not node_map.has(id_a) or not node_map.has(id_b):
			continue

		var node_a: Node3D = node_map[id_a]
		var node_b: Node3D = node_map[id_b]
		var pos_a: Vector3 = node_a.global_position + Vector3(0, LINE_HEIGHT, 0)
		var pos_b: Vector3 = node_b.global_position + Vector3(0, LINE_HEIGHT, 0)

		var color := Color(0.2, 1.0, 0.2, 0.8)
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(pos_a)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(pos_b)
		mesh.surface_end()

		var conv: Dictionary = _active_conversations[key]
		var midpoint: Vector3 = (pos_a + pos_b) * 0.5 + Vector3(0, 0.3, 0)
		var snippet: String = conv["last_line"]
		if snippet.length() > 30:
			snippet = snippet.substr(0, 27) + "..."
		var label_text: String = conv["last_speaker"].capitalize() + ": " + snippet
		_place_label(midpoint, label_text)

	# Hide unused labels
	for k in range(_label_index, _labels.size()):
		_labels[k].visible = false

func _place_label(pos: Vector3, text: String) -> void:
	var label: Label3D
	if _label_index < _labels.size():
		label = _labels[_label_index]
	else:
		label = Label3D.new()
		label.font_size = 32
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.outline_size = 8
		label.modulate = Color(0.2, 1.0, 0.2, 1.0)
		add_child(label)
		_labels.append(label)

	label.text = text
	label.global_position = pos
	label.visible = true
	_label_index += 1
