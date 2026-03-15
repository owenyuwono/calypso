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
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	vertices.resize(cols * rows)
	uvs.resize(cols * rows)
	colors.resize(cols * rows)

	# 1. Generate vertex grid
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

			# 2. Apply height rules (flatten)
			height = _apply_flatten_rules(height, world_x, world_z, paint_rules)

			vertices[vi] = Vector3(local_x, height, local_z)
			uvs[vi] = Vector2(world_x, world_z)
			colors[vi] = Color(0, 0, 0, 1)  # Default: all grass

	# 3. Apply paint rules (texture channels)
	_apply_texture_rules(vertices, colors, center, paint_rules, noise)

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

	# 4. Compute normals
	var normals: PackedVector3Array = _compute_normals(vertices, indices)

	# 5. Build ArrayMesh
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


## Returns the height after applying any flatten or flatten_rect rules at (world_x, world_z).
static func _apply_flatten_rules(height: float, world_x: float, world_z: float, rules: Array) -> float:
	for rule in rules:
		if rule["type"] == "flatten":
			var fc: Vector2 = rule["center"]
			var fr: float = rule["radius"]
			var dist: float = Vector2(world_x, world_z).distance_to(fc)
			if dist < fr:
				var blend: float = smoothstep(fr * 0.7, fr, dist)
				height = lerpf(0.0, height, blend)
		elif rule["type"] == "flatten_rect":
			var fc: Vector2 = rule["center"]
			var fs: Vector2 = rule["size"]
			var half_w: float = fs.x * 0.5
			var half_h: float = fs.y * 0.5
			if world_x >= fc.x - half_w and world_x <= fc.x + half_w and \
					world_z >= fc.y - half_h and world_z <= fc.y + half_h:
				height = 0.0
	return height


## Applies color channel strength to a Color for a given channel index.
## channel 3 (packed earth) uses inverted alpha — lower alpha = more packed earth.
static func _apply_channel(c: Color, channel: int, strength: float) -> Color:
	if channel == 0:
		c.r = maxf(c.r, strength)
	elif channel == 1:
		c.g = maxf(c.g, strength)
	elif channel == 2:
		c.b = maxf(c.b, strength)
	elif channel == 3:
		c.a = minf(c.a, 1.0 - strength)  # lower alpha = more packed earth
	return c


## Clears a color channel to zero (or restores alpha for channel 3).
static func _clear_channel(c: Color, channel: int) -> Color:
	if channel == 0:
		c.r = 0.0
	elif channel == 1:
		c.g = 0.0
	elif channel == 2:
		c.b = 0.0
	elif channel == 3:
		c.a = 1.0  # restore alpha = remove packed earth
	return c


## Paints vertex colors according to texture paint rules (line, rect, fill, clear_rect, circle).
## Modifies colors in-place. flatten/flatten_rect rules are skipped (handled in height pass).
static func _apply_texture_rules(vertices: PackedVector3Array, colors: PackedColorArray, center: Vector3, rules: Array, noise: FastNoiseLite) -> void:
	for rule in rules:
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
					colors[i] = _apply_channel(colors[i], channel, strength)
		elif rtype == "circle":
			var circle_center: Vector2 = rule["center"]
			var radius: float = rule["radius"]
			var channel: int = rule["channel"]
			var falloff: float = rule.get("falloff", 0.3)
			var noise_perturb: float = rule.get("noise_perturb", 0.0)
			for i in vertices.size():
				var world_x: float = center.x + vertices[i].x
				var world_z: float = center.z + vertices[i].z
				var eff_radius := radius
				if noise_perturb > 0.0 and noise:
					var n: float = noise.get_noise_2d(world_x * 1.2, world_z * 1.2)
					eff_radius = radius * (1.0 + n * noise_perturb)
				var dist: float = Vector2(world_x, world_z).distance_to(circle_center)
				if dist < eff_radius:
					var strength: float = (1.0 - smoothstep(eff_radius * (1.0 - falloff), eff_radius, dist)) * rule.get("strength", 1.0)
					colors[i] = _apply_channel(colors[i], channel, strength)
		elif rtype == "fill":
			var channel: int = rule["channel"]
			var strength: float = rule.get("strength", 1.0)
			for i in colors.size():
				colors[i] = _apply_channel(colors[i], channel, strength)
		elif rtype == "rect":
			var rect_center: Vector2 = rule["center"]
			var rect_size: Vector2 = rule["size"]
			var channel: int = rule["channel"]
			var strength: float = rule.get("strength", 1.0)
			var half_w: float = rect_size.x * 0.5
			var half_h: float = rect_size.y * 0.5
			for i in vertices.size():
				var world_x: float = center.x + vertices[i].x
				var world_z: float = center.z + vertices[i].z
				if world_x >= rect_center.x - half_w and world_x <= rect_center.x + half_w and \
						world_z >= rect_center.y - half_h and world_z <= rect_center.y + half_h:
					colors[i] = _apply_channel(colors[i], channel, strength)
		elif rtype == "clear_rect":
			var rect_center: Vector2 = rule["center"]
			var rect_size: Vector2 = rule["size"]
			var channel: int = rule["channel"]
			var half_w: float = rect_size.x * 0.5
			var half_h: float = rect_size.y * 0.5
			for i in vertices.size():
				var world_x: float = center.x + vertices[i].x
				var world_z: float = center.z + vertices[i].z
				if world_x >= rect_center.x - half_w and world_x <= rect_center.x + half_w and \
						world_z >= rect_center.y - half_h and world_z <= rect_center.y + half_h:
					colors[i] = _clear_channel(colors[i], channel)
		# flatten / flatten_rect are handled in the height pass — skip here


## Computes smooth per-vertex normals by accumulating face normals across all triangles.
static func _compute_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
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

	return normals


static func get_height_at(noise: FastNoiseLite, x: float, z: float, height_scale: float) -> float:
	if noise == null or height_scale <= 0.0:
		return 0.0
	return noise.get_noise_2d(x, z) * height_scale
