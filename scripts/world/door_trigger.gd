extends StaticBody3D
## Clickable door on the exterior of a building that has an interior.
## Detected by the player's raycast via group "door" and collision layer 1.
## Registers with WorldState so the interaction system can look it up.

const InteriorDatabase = preload("res://scripts/data/interior_database.gd")

var building_type: String = ""
var door_id: String = ""

const DOOR_COLOR: Color = Color(0.25, 0.15, 0.08)


func setup(btype: String, did: String) -> void:
	building_type = btype
	door_id = did

	collision_layer = 1
	collision_mask = 0
	add_to_group("door")

	_build_collision()
	_build_mesh()
	_build_label()

	var interior: Dictionary = InteriorDatabase.get_interior(building_type)
	WorldState.register_entity(door_id, self, {
		"type": "door",
		"building_type": building_type,
		"interior_name": interior.get("name", building_type),
	})


func _exit_tree() -> void:
	if not door_id.is_empty():
		WorldState.unregister_entity(door_id)


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.6, 0.1)
	col.shape = shape
	col.position = Vector3(0.0, 0.0, 0.0)
	add_child(col)


func _build_mesh() -> void:
	var door_mesh_inst := MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(0.8, 1.6, 0.1)
	door_mesh_inst.mesh = door_box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DOOR_COLOR
	door_mesh_inst.material_override = mat
	door_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(door_mesh_inst)


func _build_label() -> void:
	var label := Label3D.new()
	label.text = "Enter"
	label.position = Vector3(0.0, 1.8, 0.0)
	label.font = UIHelper.GAME_FONT_DISPLAY
	label.font_size = 36
	label.pixel_size = 0.007
	label.modulate = Color(1.0, 0.85, 0.2)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
