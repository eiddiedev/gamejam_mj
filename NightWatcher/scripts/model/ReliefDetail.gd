extends RefCounted

const PIN := Color("#b39870")
const SOCKET := Color("#3a3c38")

static func contact(world, center: Vector2, span: Vector2, shade: Color, turn := 0.0, height := 0.011) -> void:
	# Keep the support footprint readable with two irregular rings on the ground plane.
	for ring in range(2):
		var loop: Array[Vector2] = []
		for step in range(15):
			var direction := Vector2.from_angle(step * TAU / 15.0)
			var wobble := 0.91 + cos(step * 2.61 + center.x * 0.08) * 0.11
			loop.append(center + (span * direction * wobble * (1.0 - 0.22 * ring)).rotated(turn))
		world.patch(loop, height + ring * 0.002, shade.darkened(ring * 0.12))

static func jaw(world, at: Vector2, lip_height: float, angle: float, tint: Color, width := 22.0, depth := 17.0) -> void:
	# A recessed rectangular bed with low lips leaves the center open for a tower foot.
	world.stone(at.x, at.y, width, depth, 0.060, SOCKET, angle, lip_height - 0.11)
	for side: float in [-1.0, 1.0]:
		var point := at + Vector2(width * 0.46 * side, 0).rotated(angle)
		world.stone(point.x, point.y, 4.2, depth, 0.17, tint, angle, lip_height - 0.12)
		for along: float in [-1.0, 1.0]:
			var pin := point + Vector2(0, along * (depth - 5.0) * 0.5).rotated(angle)
			world.stone(pin.x, pin.y, 2.8, 2.8, 0.07, PIN, angle, lip_height + 0.032)
	var back := at + Vector2(0, -depth * 0.48).rotated(angle)
	world.stone(back.x, back.y, width * 0.83, 4.6, 0.16, tint.darkened(0.12), angle, lip_height - 0.12)

static func vessel(world, at: Vector2, base: float, size: float, tint: Color) -> void:
	world.ellipsoid(world.at(at.x, at.y, base + size * 0.78), Vector3(size * 0.67, size * 0.78, size * 0.62), tint, 11, 6)
	world.ellipsoid(world.at(at.x - 0.4, at.y, base + size * 1.54), Vector3(size * 0.48, size * 0.12, size * 0.45), tint.lightened(0.20), 10, 4)
	world.ellipsoid(world.at(at.x - 0.4, at.y, base + size * 1.585), Vector3(size * 0.32, size * 0.08, size * 0.29), tint.darkened(0.55), 9, 4)

static func vine(world, points: Array, width: float, stem: Color, leaf: Color, phase: float) -> void:
	var centerline := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in range(points.size()):
		var data: Array = points[i]
		centerline.append(world.at(data[0], data[1], data[2]))
		radii.append(lerpf(width, width * 0.37, float(i) / maxf(1, points.size() - 1)))
	world.mesh.smooth_tube(centerline, radii, stem, 6, 0.045)
	for segment in range(centerline.size() - 1):
		var a := centerline[segment]
		var b := centerline[segment + 1]
		for i in range(3):
			var origin := a.lerp(b, (i + 0.3) / 3.0)
			var branch := Vector3(sin(i * 3.8 + segment * 1.7 + phase), 0.08, 0.44 + cos(i * 2.0 + phase) * 0.20).normalized()
			var reach := 0.11 + fposmod(i * 0.037 + phase * 0.027 + segment * 0.071, 0.125)
			var color := leaf.lightened(fposmod(i * 0.065 + phase * 0.015, 0.21))
			var tip := origin + branch * reach
			var wing := branch.cross(Vector3.UP).normalized() * reach * 0.36
			var ridge := origin.lerp(tip, 0.62) + Vector3.UP * reach * 0.21
			world.mesh.triangle(origin, ridge - wing, tip, color, Vector3.UP)
			world.mesh.triangle(origin, tip, ridge + wing, color.darkened(0.15), Vector3.UP)

static func plank(world, at: Vector2, span: float, angle: float, base: float, tint: Color) -> void:
	world.stone(at.x, at.y, span, 2.8, 0.056, tint, angle, base)
	for longitudinal: float in [-1.0, 1.0]:
		var end := at + Vector2(span * longitudinal * 0.34, 0).rotated(angle)
		world.stone(end.x, end.y, 1.6, 1.6, 0.025, Color("#655552"), angle, base + 0.055)
