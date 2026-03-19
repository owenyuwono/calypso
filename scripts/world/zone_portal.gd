extends Area3D
## Area3D trigger that fires a ZoneManager transition when the player walks through.
## Instantiated and configured at runtime by ZoneManager via setup().

var target_zone: String = ""
var target_spawn: Vector3 = Vector3.ZERO
var _ring_material: StandardMaterial3D

func setup(portal_def: Dictionary) -> void:
	target_zone = portal_def["target"]
	target_spawn = portal_def["target_spawn"]

	# Create collision shape from source_rect
	var rect: Rect2 = portal_def["source_rect"]
	var shape: BoxShape3D = BoxShape3D.new()
	# rect is in XZ plane: rect.position.x/y map to world X/Z
	shape.size = Vector3(rect.size.x, 4.0, rect.size.y)  # 4m tall trigger

	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	# Position at center of rect, vertically centered on the 4m trigger height
	global_position = Vector3(
		rect.position.x + rect.size.x / 2.0,
		2.0,  # center of 4m height
		rect.position.y + rect.size.y / 2.0
	)

	# Detect bodies on layer 1 (physics/player) only; this Area3D emits no layer
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false

	body_entered.connect(_on_body_entered)
	_create_visuals()

func _create_visuals() -> void:
	_create_ground_ring()
	_create_destination_label()
	_start_pulse()

func _create_ground_ring() -> void:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 1.8
	mesh.outer_radius = 2.2
	mesh.rings = 32
	mesh.ring_segments = 12

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.6, 1.0, 0.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_material = mat

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = Vector3(0.0, -1.8, 0.0)
	add_child(instance)

func _create_destination_label() -> void:
	var label: Label3D = Label3D.new()
	label.text = "To " + ZoneDatabase.get_zone_name(target_zone)
	label.position = Vector3(0.0, 1.5, 0.0)
	label.font_size = 48
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.5, 0.85, 1.0)
	label.outline_size = 10
	label.outline_modulate = Color(0.0, 0.0, 0.0)
	add_child(label)

func _start_pulse() -> void:
	var emission_tween: Tween = create_tween().set_loops()
	emission_tween.tween_property(_ring_material, "emission_energy_multiplier", 1.2, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	emission_tween.tween_property(_ring_material, "emission_energy_multiplier", 0.4, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var alpha_tween: Tween = create_tween().set_loops()
	alpha_tween.tween_property(_ring_material, "albedo_color:a", 0.85, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	alpha_tween.tween_property(_ring_material, "albedo_color:a", 0.4, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node3D) -> void:
	if "entity_id" in body and body.entity_id == "player":
		if not ZoneManager.is_transitioning():
			ZoneManager.load_zone(target_zone, target_spawn)
