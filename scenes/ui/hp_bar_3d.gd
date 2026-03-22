extends Node3D
## 3D HP bar using pure meshes + Label3D — zero SubViewports.
## Structure:
##   Node3D (this)
##     Label3D  (entity name, above bar)
##     MeshInstance3D  (bar background: dark quad)
##     MeshInstance3D  (bar fill: colored quad, anchored left)

const BAR_WIDTH: float = 1.4
const BAR_HEIGHT: float = 0.1
const BG_HEIGHT: float = 0.12  # slightly taller than fill for border effect

var _name_label: Label3D
var _bar_bg: MeshInstance3D
var _bar_fill: MeshInstance3D
var _fill_mesh: QuadMesh
var _fill_material: StandardMaterial3D

var _last_ratio: float = -1.0
var _pending_name: String = ""

# Shared background material — same across all hp bars
static var _shared_bg_material: StandardMaterial3D

func _ready() -> void:
	_build_bar()
	if not _pending_name.is_empty():
		_name_label.text = _pending_name

func _build_bar() -> void:
	# Name label
	_name_label = Label3D.new()
	_name_label.font = UIHelper.GAME_FONT_DISPLAY
	_name_label.font_size = 48
	_name_label.outline_size = 8
	_name_label.modulate = Color(1.0, 1.0, 0.85)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.pixel_size = 0.005
	_name_label.no_depth_test = true
	_name_label.position.y = BAR_HEIGHT / 2.0 + 0.08
	_name_label.text = ""
	add_child(_name_label)

	# Background quad
	_bar_bg = MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(BAR_WIDTH, BG_HEIGHT)
	_bar_bg.mesh = bg_mesh
	_bar_bg.material_override = _get_bg_material()
	add_child(_bar_bg)

	# Fill quad
	_bar_fill = MeshInstance3D.new()
	_fill_mesh = QuadMesh.new()
	_fill_mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_fill.mesh = _fill_mesh
	_fill_material = StandardMaterial3D.new()
	_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_material.no_depth_test = true
	_fill_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fill_material.albedo_color = Color(0.2, 0.8, 0.2)
	_bar_fill.material_override = _fill_material
	add_child(_bar_fill)

static func _get_bg_material() -> StandardMaterial3D:
	if not _shared_bg_material:
		_shared_bg_material = StandardMaterial3D.new()
		_shared_bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_bg_material.no_depth_test = true
		_shared_bg_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_shared_bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_bg_material.render_priority = -1
		_shared_bg_material.albedo_color = Color(0.0, 0.0, 0.0, 0.9)
	return _shared_bg_material

func set_entity_name(entity_name: String) -> void:
	_pending_name = entity_name
	if _name_label:
		_name_label.text = entity_name

func set_bar_visible(vis: bool) -> void:
	if _bar_bg:
		_bar_bg.visible = vis
	if _bar_fill:
		_bar_fill.visible = vis

func update_bar(current: int, max_val: int) -> void:
	if max_val <= 0:
		return
	var ratio: float = clampf(float(current) / float(max_val), 0.0, 1.0)
	if absf(ratio - _last_ratio) < 0.001:
		return
	_last_ratio = ratio

	var fill_width: float = ratio * BAR_WIDTH
	_fill_mesh.size.x = fill_width
	# Anchor fill to left edge (center_offset is in mesh-local/billboard space, not world space)
	_fill_mesh.center_offset.x = -(BAR_WIDTH - fill_width) / 2.0

	if ratio > 0.5:
		_fill_material.albedo_color = Color(0.2, 0.8, 0.2)
	elif ratio > 0.25:
		_fill_material.albedo_color = Color(0.9, 0.8, 0.1)
	else:
		_fill_material.albedo_color = Color(0.85, 0.15, 0.15)
