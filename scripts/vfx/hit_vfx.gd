extends RefCounted
## Procedural hit impact VFX: slash arc + spark burst. No external assets.

static func spawn_hit_effect(caller: Node, hit_pos: Vector3, direction: Vector3) -> void:
	var scene: SceneTree = caller.get_tree()
	if not scene or not scene.current_scene:
		return
	var root: Node = scene.current_scene
	_spawn_slash_arc(root, hit_pos, direction)
	_spawn_sparks(root, hit_pos)


static func _spawn_slash_arc(root: Node, hit_pos: Vector3, direction: Vector3) -> void:
	# Build a curved slash quad using ImmediateMesh
	var mesh_inst := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mesh_inst.mesh = im

	# Slash arc: a fan of triangles forming a curved blade trail
	var arc_radius: float = 0.6
	var arc_thickness: float = 0.15
	var segments: int = 8
	var arc_angle: float = PI * 0.6  # ~108 degree arc

	# Compute orientation from direction
	var forward: Vector3 = direction
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()

	# Start angle offset so arc is centered on the swing
	var start_angle: float = -arc_angle * 0.5

	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0: float = start_angle + (arc_angle * i / segments)
		var a1: float = start_angle + (arc_angle * (i + 1) / segments)

		# Inner and outer points on the arc
		var inner0: Vector3 = (forward * cos(a0) + right * sin(a0)) * (arc_radius - arc_thickness)
		var outer0: Vector3 = (forward * cos(a0) + right * sin(a0)) * arc_radius
		var inner1: Vector3 = (forward * cos(a1) + right * sin(a1)) * (arc_radius - arc_thickness)
		var outer1: Vector3 = (forward * cos(a1) + right * sin(a1)) * arc_radius

		# Two triangles per segment
		im.surface_set_color(Color(1.0, 0.95, 0.7, 0.9))
		im.surface_add_vertex(inner0)
		im.surface_add_vertex(outer0)
		im.surface_add_vertex(outer1)

		im.surface_add_vertex(inner0)
		im.surface_add_vertex(outer1)
		im.surface_add_vertex(inner1)
	im.surface_end()

	# Unshaded transparent material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.7, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mesh_inst.material_override = mat

	root.add_child(mesh_inst)
	mesh_inst.global_position = hit_pos
	mesh_inst.scale = Vector3.ONE * 0.5

	# Animate: scale up + fade out
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3.ONE * 1.2, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tween.set_parallel(false)
	tween.tween_callback(mesh_inst.queue_free)


static func _spawn_sparks(root: Node, hit_pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.3
	particles.explosiveness = 1.0
	particles.fixed_fps = 60

	# Particle material
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -8, 0)
	mat.scale_min = 0.03
	mat.scale_max = 0.08
	mat.color = Color(1.0, 0.85, 0.3, 1.0)

	# Fade out via color ramp
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.4, 1.0))
	gradient.add_point(0.5, Color(1.0, 0.6, 0.2, 0.8))
	gradient.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	particles.process_material = mat

	# Small bright quad mesh for each particle
	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2(1.0, 1.0)
	particles.draw_pass_1 = spark_mesh

	# Unshaded billboard material for the spark quads
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_mesh.material = draw_mat

	root.add_child(particles)
	particles.global_position = hit_pos
	particles.emitting = true

	# Auto-free after particles die
	var timer := root.create_tween()
	timer.tween_interval(particles.lifetime + 0.1)
	timer.tween_callback(particles.queue_free)
