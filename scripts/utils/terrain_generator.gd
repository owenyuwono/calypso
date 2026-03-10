extends RefCounted
## Static utility for generating subdivided terrain meshes with noise height and vertex color painting.
## Follows the same pattern as model_helper.gd.

static func generate_terrain(center: Vector3, size: Vector2, subdivisions: Vector2i, noise: FastNoiseLite, height_scale: float, paint_rules: Array) -> Dictionary:
	var mesh_instance := MeshInstance3D.new()
	var static_body := StaticBody3D.new()

	var cols := subdivisions.x + 1
	var rows := subdivisions.y + 1
	var half_x := size.x * 0.5
	var half_z := size.y * 0.5

	# Build vertex data
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	vertices.resize(cols * rows)
	normals.resize(cols * rows)
	uvs.resize(cols * rows)
	colors.resize(cols * rows)

	# Generate vertices
	for z_idx in rows:
		for x_idx in cols:
			var vi := z_idx * cols + x_idx
			var local_x: float = -half_x + (size.x * x_idx / float(subdivisions.x))
			var local_z: float = -half_z + (size.y * z_idx / float(subdivisions.y))
			var world_x: float = center.x + local_x
			var world_z: float = center.z + local_z

			var height: float = 0.0
			if noise and height_scale > 0.0:
				height = noise.get_noise_2d(world_x, world_z) * height_scale

			# Apply flatten rules (override height to 0 in specified areas)
			for rule in paint_rules:
				if rule["type"] == "flatten":
					var fc: Vector2 = rule["center"]
					var fr: float = rule["radius"]
					var dist: float = Vector2(world_x, world_z).distance_to(fc)
					if dist < fr:
						var blend: float = smoothstep(fr * 0.7, fr, dist)
						height = lerpf(0.0, height, blend)

			vertices[vi] = Vector3(local_x, height, local_z)
			uvs[vi] = Vector2(world_x, world_z)
			colors[vi] = Color(0, 0, 0, 1)  # Default: all grass

	# Paint vertex colors (inline to avoid PackedArray copy-on-write issues)
	for rule in paint_rules:
		var rtype: String = rule["type"]
		if rtype == "line":
			var start: Vector2 = rule["start"]
			var end: Vector2 = rule["end"]
			var width: float = rule["width"]
			var channel: int = rule["channel"]
			var falloff: float = rule.get("falloff", 1.0)
			var line_dir := (end - start).normalized()
			var line_len := start.distance_to(end)
			for i in vertices.size():
				var world_x: float = center.x + vertices[i].x
				var world_z: float = center.z + vertices[i].z
				var p := Vector2(world_x, world_z)
				var t: float = clampf((p - start).dot(line_dir) / line_len, 0.0, 1.0)
				var closest := start + line_dir * t * line_len
				var dist: float = p.distance_to(closest)
				if dist < width:
					var strength: float = 1.0 - smoothstep(width * (1.0 - falloff), width, dist)
					var c := colors[i]
					if channel == 0:
						c.r = maxf(c.r, strength)
					elif channel == 1:
						c.g = maxf(c.g, strength)
					colors[i] = c
		elif rtype == "circle":
			var circle_center: Vector2 = rule["center"]
			var radius: float = rule["radius"]
			var channel: int = rule["channel"]
			var falloff: float = rule.get("falloff", 0.3)
			for i in vertices.size():
				var world_x: float = center.x + vertices[i].x
				var world_z: float = center.z + vertices[i].z
				var dist: float = Vector2(world_x, world_z).distance_to(circle_center)
				if dist < radius:
					var strength: float = 1.0 - smoothstep(radius * (1.0 - falloff), radius, dist)
					var c := colors[i]
					if channel == 0:
						c.r = maxf(c.r, strength)
					elif channel == 1:
						c.g = maxf(c.g, strength)
					colors[i] = c
		elif rtype == "fill":
			var channel: int = rule["channel"]
			var strength: float = rule.get("strength", 1.0)
			for i in colors.size():
				var c := colors[i]
				if channel == 0:
					c.r = strength
				elif channel == 1:
					c.g = strength
				colors[i] = c

	# Generate indices (two triangles per quad, CCW winding for upward normals)
	for z_idx in subdivisions.y:
		for x_idx in subdivisions.x:
			var tl := z_idx * cols + x_idx
			var tr := tl + 1
			var bl := (z_idx + 1) * cols + x_idx
			var br := bl + 1
			# Triangle 1: tl -> tr -> bl (CCW from above)
			indices.append(tl)
			indices.append(tr)
			indices.append(bl)
			# Triangle 2: tr -> br -> bl (CCW from above)
			indices.append(tr)
			indices.append(br)
			indices.append(bl)

	# Compute normals from triangles
	for i in normals.size():
		normals[i] = Vector3.ZERO

	for i in range(0, indices.size(), 3):
		var i0 := indices[i]
		var i1 := indices[i + 1]
		var i2 := indices[i + 2]
		var v0 := vertices[i0]
		var v1 := vertices[i1]
		var v2 := vertices[i2]
		var face_normal := (v1 - v0).cross(v2 - v0).normalized()
		normals[i0] += face_normal
		normals[i1] += face_normal
		normals[i2] += face_normal

	for i in normals.size():
		if normals[i].length_squared() > 0.0001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP

	# Build ArrayMesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = arr_mesh
	mesh_instance.position = center

	# Collision shape from mesh triangles
	var col_shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	var tri_verts := PackedVector3Array()
	for i in range(0, indices.size(), 3):
		tri_verts.append(vertices[indices[i]])
		tri_verts.append(vertices[indices[i + 1]])
		tri_verts.append(vertices[indices[i + 2]])
	concave.set_faces(tri_verts)
	col_shape.shape = concave
	static_body.position = center
	static_body.add_child(col_shape)

	return {"mesh_instance": mesh_instance, "static_body": static_body}


static func get_height_at(noise: FastNoiseLite, x: float, z: float, height_scale: float) -> float:
	if noise == null or height_scale <= 0.0:
		return 0.0
	return noise.get_noise_2d(x, z) * height_scale
