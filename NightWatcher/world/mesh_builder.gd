extends RefCounted

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()

func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color, normal := Vector3.ZERO) -> void:
	if normal == Vector3.ZERO:
		normal = (b - a).cross(c - a).normalized()
	vertices.append_array(PackedVector3Array([a, b, c]))
	normals.append_array(PackedVector3Array([normal, normal, normal]))
	colors.append_array(PackedColorArray([color, color, color]))

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	triangle(a, b, c, color, normal)
	triangle(a, c, d, color, normal)

func panel_stroke(panel: PackedVector3Array, path: PackedVector2Array, width: float,
		tint: Color, normal: Vector3, taper_start := true, taper_end := true) -> void:
	var points := PackedVector3Array()
	var lift := normal * 0.006
	for uv in path:
		# Use the same diagonal as the mesh so marks sit on both triangles.
		var at := panel[0].lerp(panel[2], minf(uv.x, uv.y))
		if uv.x > uv.y:
			at += (panel[1] - panel[0]) * (uv.x - uv.y)
		else:
			at += (panel[3] - panel[0]) * (uv.y - uv.x)
		points.append(at + lift)
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in range(points.size()):
		var travel := points[mini(i + 1, points.size() - 1)] - points[maxi(0, i - 1)]
		var pressure := 0.57 + 0.43 * sin(0.85 + i * 1.37) ** 2
		if (i == 0 and taper_start) or (i == points.size() - 1 and taper_end):
			pressure *= 0.15
		var across := travel.cross(normal).normalized() * width * 0.5 * pressure
		left.append(points[i] - across)
		right.append(points[i] + across)
	for i in range(points.size() - 1):
		triangle(left[i], right[i], right[i + 1], tint, normal)
		triangle(left[i], right[i + 1], left[i + 1], tint, normal)

func block(center: Vector3, length: float, height: float, depth: float, angle: float,
		color: Color, bevel := 0.065, tilt := 0.0, trace_stone := true) -> void:
	var half_length := length * 0.5
	var half_depth := depth * 0.5
	var x := half_length
	var z := half_depth
	var cut := minf(bevel, minf(x, z) * 0.69)
	var rim := PackedVector2Array([Vector2(-x + cut, -z), Vector2(x - cut, -z),
		Vector2(x, -z + cut), Vector2(x, z - cut), Vector2(x - cut, z), Vector2(-x + cut, z),
		Vector2(-x, z - cut), Vector2(-x, -z + cut)])
	var bottom := PackedVector3Array()
	var shoulder := PackedVector3Array()
	var cap := PackedVector3Array()
	for point in rim:
		var shape_noise := sin(center.x * 13.7 + center.y * 7.13 + center.z * 11.21 + point.x * 2.7 + point.y * 3.14)
		var weather := point * (1.0 + shape_noise * 0.064)
		var planar := weather.rotated(angle)
		var inner := (weather * (0.935 + shape_noise * 0.043)).rotated(angle)
		bottom.append(center + Vector3(planar.x, 0, planar.y))
		shoulder.append(center + Vector3(planar.x, height * 0.83 + point.x * tilt, planar.y))
		cap.append(center + Vector3(inner.x, height + point.x * tilt, inner.y))
	for index in range(8):
		var next := (index + 1) % 8
		quad(bottom[index], shoulder[index], shoulder[next], bottom[next], color)
		quad(shoulder[index], cap[index], cap[next], shoulder[next], color.lerp(Color(0.50, 0.55, 0.54, color.a), 0.10))
		if index >= 1 and index < 7:
			triangle(cap[0], cap[next], cap[index], color.lerp(Color(0.57, 0.61, 0.56, color.a), 0.12))
	if trace_stone and color.a > 0.98 and length >= 0.44 and depth >= 0.35:
		draw_stone_marks(bottom, shoulder, cap, color, center, angle, height)

func draw_stone_marks(bottom: PackedVector3Array, shoulder: PackedVector3Array, cap: PackedVector3Array,
		color: Color, center: Vector3, angle: float, height: float) -> void:
	var pattern := fposmod(sin(center.dot(Vector3(27.4, 88.1, 17.3))) * 31721.41, 1.0)
	var ink := Color(color.darkened(0.60), 0.85)
	if height < 0.48 and pattern < 0.47:
		var top := PackedVector3Array([cap[0], cap[3], cap[4], cap[7]])
		var crack := PackedVector2Array([Vector2(0.19, 0.53), Vector2(0.33, 0.50),
			Vector2(0.43, 0.58), Vector2(0.56, 0.49), Vector2(0.70, 0.62), Vector2(0.82, 0.60)])
		if pattern > 0.28:
			crack = PackedVector2Array([Vector2(0.25, 0.26), Vector2(0.42, 0.36),
				Vector2(0.49, 0.53), Vector2(0.64, 0.60), Vector2(0.65, 0.81)])
		panel_stroke(top, crack, 0.029, ink, Vector3.UP)
		if pattern < 0.18:
			panel_stroke(top, PackedVector2Array([Vector2(0.55, 0.49), Vector2(0.61, 0.36),
				Vector2(0.76, 0.29)]), 0.017, ink, Vector3.UP)
	# Choose the face that turns toward the player, including the sides of the curved wall.
	var axis := Vector2.from_angle(angle)
	var face := 4 if axis.x > 0.0 else 0
	if absf(axis.y) > 0.77:
		face = 2 if axis.y > 0.0 else 6
	var next := (face + 1) % 8
	if height >= 0.13 and height < 0.36 and pattern < 0.80:
		var bevel_normal := (cap[face] - shoulder[face]).cross(cap[next] - shoulder[face]).normalized()
		var bevel := PackedVector3Array([shoulder[face], shoulder[next], cap[next], cap[face]])
		var edge_ink := Color(color.darkened(0.52), 0.86)
		panel_stroke(bevel, PackedVector2Array([Vector2(0.018, 0.36), Vector2(0.26, 0.33),
			Vector2(0.48, 0.50), Vector2(0.65, 0.27), Vector2(0.84, 0.41),
			Vector2(0.98, 0.42)]), 0.027, edge_ink, bevel_normal)
	if height < 0.24 or pattern > 0.67:
		return
	var normal := (shoulder[face] - bottom[face]).cross(bottom[next] - bottom[face]).normalized()
	var side := PackedVector3Array([bottom[face], bottom[next], shoulder[next], shoulder[face]])
	var drift := pattern * 0.48
	panel_stroke(side, PackedVector2Array([Vector2(0.20 + drift, 0.89), Vector2(0.32 + drift, 0.66),
		Vector2(0.29 + drift, 0.40), Vector2(0.46 + drift, 0.33),
		Vector2(0.54 + drift, 0.15)]), 0.024, ink, normal)

func tube(points: PackedVector3Array, radii: PackedFloat32Array, color: Color, sides: int,
		twist := 0.15, trace_bark := false) -> void:
	var previous := PackedVector3Array()
	for row in range(points.size()):
		var before := points[maxi(row - 1, 0)]
		var after := points[mini(row + 1, points.size() - 1)]
		var forward := (after - before).normalized()
		var axis := forward.cross(Vector3.FORWARD).normalized()
		if axis.length_squared() < 0.3:
			axis = forward.cross(Vector3.RIGHT).normalized()
		var across := axis.cross(forward)
		var ring := PackedVector3Array()
		for index in range(sides):
			var angle := TAU * index / sides + row * twist
			var radius := radii[row] * (1.0 + sin(index * 3.67 + row * 1.9) * 0.13)
			ring.append(points[row] + radius * (axis * cos(angle) + across * sin(angle)))
		if row > 0:
			for index in range(sides):
				var next := (index + 1) % sides
				var shade := color.darkened(0.11 if index % 3 == 0 else 0.0)
				shade.a = color.a
				quad(previous[index], ring[index], ring[next], previous[next], shade)
				if trace_bark and radii[row] > 0.074 and index % 2 == 0:
					bark_grain(previous, ring, index, next, row, radii[row], shade)
		previous = ring

func bark_grain(previous: PackedVector3Array, ring: PackedVector3Array,
		edge: int, next: int, row: int, radius: float, color: Color) -> void:
	var panel := PackedVector3Array([previous[edge], previous[next], ring[next], ring[edge]])
	var normal := (ring[edge] - previous[edge]).cross(ring[next] - previous[edge]).normalized()
	var seed := edge * 1.93
	var start := 0.48 + sin((row - 1) * 1.08 + seed) * 0.19
	var end := 0.48 + sin(row * 1.08 + seed) * 0.19
	var begins := row % 7 == 1
	var ends := row % 7 == 6
	var path := PackedVector2Array([Vector2(start, 0.23 if begins else 0.0),
		Vector2(lerpf(start, end, 0.29) + cos(seed + row) * 0.10, 0.32),
		Vector2(lerpf(start, end, 0.71), 0.72), Vector2(end, 0.89 if ends else 1.0)])
	var ink := Color(color.darkened(0.62), 0.85)
	panel_stroke(panel, path, clampf(radius * 0.086, 0.017, 0.048), ink, normal, begins, ends)
	if radius > 0.4 and (row + edge) % 5 == 1:
		panel_stroke(panel, PackedVector2Array([Vector2(0.76, 0.16), Vector2(0.91, 0.43),
			Vector2(0.82, 0.74), Vector2(0.62, 0.57), Vector2(0.68, 0.37),
			Vector2(0.78, 0.46)]), 0.020, ink, normal)
func smooth_tube(points: PackedVector3Array, radii: PackedFloat32Array,
		color: Color, sides: int, twist: float, trace_bark := false) -> void:
	var path := PackedVector3Array()
	var girth := PackedFloat32Array()
	for index in range(points.size() - 1):
		var before := points[maxi(0, index - 1)]
		var after := points[mini(points.size() - 1, index + 2)]
		for sample in range(3):
			var step := sample / 3.0
			path.append(points[index].cubic_interpolate(points[index + 1], before, after, step))
			girth.append(lerpf(radii[index], radii[index + 1], step))
	path.append(points[-1])
	girth.append(radii[-1])
	tube(path, girth, color, sides, twist, trace_bark)

func move_above(target: RefCounted, height: float) -> void:
	var keep_vertices := PackedVector3Array()
	var keep_normals := PackedVector3Array()
	var keep_colors := PackedColorArray()
	for index in range(0, vertices.size(), 3):
		var a := vertices[index]
		var b := vertices[index + 1]
		var c := vertices[index + 2]
		if minf(a.y, minf(b.y, c.y)) >= height:
			target.triangle(a, b, c, colors[index], normals[index])
		else:
			keep_vertices.append_array(vertices.slice(index, index + 3))
			keep_normals.append_array(normals.slice(index, index + 3))
			keep_colors.append_array(colors.slice(index, index + 3))
	vertices = keep_vertices
	normals = keep_normals
	colors = keep_colors

func build() -> ArrayMesh:
	var data := []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = vertices
	data[Mesh.ARRAY_NORMAL] = normals
	data[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	if not vertices.is_empty():
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	return result
