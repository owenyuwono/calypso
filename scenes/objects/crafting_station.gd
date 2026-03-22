extends StaticBody3D
## Crafting station — player clicks to open the crafting panel for a specific skill.
## Registers with WorldState as type "crafting_station" so click detection works.

static var _next_id: int = 1

# Station type determines which recipes are shown in the crafting panel.
var station_type: String = ""  # "cooking" | "smithing" | "crafting"
var station_name: String = ""
var _entity_id: String = ""

# Visual color per station type.
const TYPE_COLORS: Dictionary = {
	"smithing": Color(0.9, 0.45, 0.1),
	"cooking":  Color(0.9, 0.75, 0.1),
	"crafting": Color(0.2, 0.7, 0.6),
}


func setup(type: String, sname: String) -> void:
	station_type = type
	station_name = sname

	_entity_id = "crafting_station_%03d" % _next_id
	_next_id += 1

	_build_collision()
	_build_visual()
	_build_label()

	add_to_group("crafting_station")
	collision_layer = 1
	collision_mask = 0

	WorldState.register_entity(_entity_id, self, {
		"type": "crafting_station",
		"name": station_name,
		"station_type": station_type,
	})


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 2.0, 1.5)
	col.shape = shape
	col.position = Vector3(0.0, 1.0, 0.0)
	add_child(col)


func _build_visual() -> void:
	var color: Color = TYPE_COLORS.get(station_type, Color(0.5, 0.5, 0.5))

	# Stone pedestal underneath the indicator.
	var pedestal: MeshInstance3D = MeshInstance3D.new()
	var pedestal_mesh: CylinderMesh = CylinderMesh.new()
	pedestal_mesh.top_radius = 0.6
	pedestal_mesh.bottom_radius = 0.6
	pedestal_mesh.height = 0.1
	pedestal.mesh = pedestal_mesh
	pedestal.position = Vector3(0.0, 0.05, 0.0)
	var pedestal_mat: StandardMaterial3D = StandardMaterial3D.new()
	pedestal_mat.albedo_color = Color(0.35, 0.33, 0.3)
	pedestal.material_override = pedestal_mat
	pedestal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pedestal)

	var indicator: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.4
	mesh.height = 0.8
	indicator.mesh = mesh
	indicator.position = Vector3(0.0, 0.5, 0.0)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	indicator.material_override = mat
	indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(indicator)


func _build_label() -> void:
	var label := Label3D.new()
	label.font = UIHelper.GAME_FONT_DISPLAY
	label.text = station_name
	label.position = Vector3(0.0, 1.8, 0.0)
	label.pixel_size = 0.007
	label.font_size = 48
	label.modulate = Color(1.0, 0.95, 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
