extends RefCounted

const IVORY := Color("#c0b99b")
const WEATHERED_BONE := Color("#979986")
const CORTEX := Color("#a9a58b")
const CAVITY := Color("#4a514b")
const INK := Color("#535c54")
const SIDES := 12
const STATIONS := [0.0, 0.10, 0.27, 0.49, 0.72, 0.90, 1.0]

static func build(world) -> void:
	humerus(world, Vector2(532, 187), Vector2(524, 179), 0.32, 0.29, 1)
	humerus(world, Vector2(490, 153), Vector2(458, 132), 0.33, 0.32, -1)
	humerus(world, Vector2(458, 132), Vector2(396, 153), 0.30, 0.29)
	forearm(world, Vector2(396, 153), Vector2(420, 91), 0.185, 0.26)
	hand(world, Vector2(420, 91), -1.0)

	humerus(world, Vector2(554, 218), Vector2(612, 346), 0.24, 0.39)
	forearm(world, Vector2(612, 346), Vector2(603, 350), 0.22, 0.27, 1)
	forearm(world, Vector2(554, 374), Vector2(521, 387), 0.19, 0.28, -1)
	hand(world, Vector2(521, 387), 1.0)

	var saddle: Array[Vector2] = [Vector2(478, 194), Vector2(495, 185), Vector2(507, 167), Vector2(532, 148), Vector2(554, 161)]
	var split: Array[Vector2] = [Vector2(512, 400), Vector2(552, 398), Vector2(578, 359), Vector2(619, 328)]
	world.trail(saddle, 7.4, Color("#69776c53"))
	world.trail(split, 9.0, Color("#6b796c53"))

static func humerus(world, shoulder: Vector2, elbow: Vector2, lift: float, radius: float, broken := 0) -> void:
	var top: Vector3 = world.from_floor(shoulder, lift * 1.10)
	var low: Vector3 = world.from_floor(elbow, lift)
	var across := top.direction_to(low).cross(Vector3.UP).normalized()
	var crown := radius if broken != -1 else radius * 0.68
	var condyle := radius * (0.84 if broken != 1 else 0.68)
	shaft(world, top, low, across * radius * 0.19 - Vector3.UP * radius * 0.20,
		Vector3(crown, radius * 0.51, condyle), IVORY, broken)
	if broken != 1:
		var end := low.lerp(top, 0.035)
		for side: float in [-1.0, 1.0]:
			world.ellipsoid(end + across * radius * side * 0.35,
				Vector3(radius * 0.44, radius * 0.62, radius * 0.52),
				CORTEX if side > 0.0 else IVORY, 9, 5)

static func forearm(world, elbow: Vector2, wrist: Vector2, lift: float, width: float, broken := 0) -> void:
	var top: Vector3 = world.from_floor(elbow, lift)
	var low: Vector3 = world.from_floor(wrist, lift * 0.91)
	var across := top.direction_to(low).cross(Vector3.UP).normalized()
	var ulna_end := low - across * width * 0.43
	var radius_end := low + across * width * 0.44 + Vector3.UP * 0.024
	shaft(world, top - across * width * 0.42, ulna_end, -across * width * 0.17,
		Vector3(width * 0.52, width * 0.36, width * 0.39), WEATHERED_BONE, broken)
	shaft(world, top + across * width * 0.41, radius_end, across * width * 0.26 + Vector3.UP * 0.035,
		Vector3(width * 0.38, width * 0.34, width * 0.47), IVORY, broken)

static func hand(world, wrist: Vector2, side: float) -> void:
	var palm_center: Vector3 = world.from_floor(wrist, 0.18)
	for index in range(3):
		var at := palm_center + Vector3(0.045 + index * 0.085, 0.012 * index, (index - 1) * 0.074)
		world.ellipsoid(at, Vector3(0.107, 0.090, 0.106), CORTEX if index == 1 else IVORY, 8, 5)

	for index in range(4):
		var knuckle := wrist + Vector2(index * 4.5, (index - 2) * 3.9)
		var tip := knuckle + Vector2(-22.0 * side, 24.0 * side + index * 3.0)
		var base: Vector3 = world.from_floor(wrist + Vector2(index * 1.70, (index - 2) * 1.28), 0.19 + index * 0.016)
		var first: Vector3 = world.from_floor(knuckle.lerp(tip, 0.27), 0.22 + index * 0.026)
		var second: Vector3 = world.from_floor(knuckle.lerp(tip, 0.61) + Vector2(0, -0.8), 0.18 + index * 0.019)
		var third: Vector3 = world.from_floor(knuckle.lerp(tip, 0.84), 0.105 + index * 0.015)
		var last: Vector3 = world.from_floor(tip, 0.092 + index * 0.014)
		var color := IVORY.lerp(WEATHERED_BONE, index * 0.13)
		var breadth := 1.0 - float(abs(index - 1)) * 0.09
		digit_piece(world, base, first, 0.103 * breadth, color)
		digit_piece(world, first, second, 0.093 * breadth, color)
		digit_piece(world, second, third, 0.074 * breadth, color)
		digit_piece(world, third, last, 0.058 * breadth, color, 1 if index == 3 else 0)
		world.ellipsoid(first, Vector3(0.089, 0.072, 0.085) * breadth, CORTEX, 8, 5)

	var thumb_base: Vector3 = world.from_floor(wrist + Vector2(-2, -3 * side), 0.137)
	var thumb_knuckle: Vector3 = world.from_floor(wrist + Vector2(-8 * side, 0.5 * side), 0.132)
	var thumb_hinge: Vector3 = world.from_floor(wrist + Vector2(-16 * side, 2 * side), 0.098)
	var thumb_tip: Vector3 = world.from_floor(wrist + Vector2(-21 * side, 5 * side), 0.074)
	digit_piece(world, thumb_base, thumb_knuckle, 0.076, WEATHERED_BONE)
	digit_piece(world, thumb_knuckle, thumb_hinge, 0.071, IVORY)
	digit_piece(world, thumb_hinge, thumb_tip, 0.055, IVORY)

static func digit_piece(world, start: Vector3, end: Vector3, radius: float, color: Color, broken := 0) -> void:
	var movement := start.direction_to(end)
	var seam := minf(radius * 0.26, start.distance_to(end) * 0.06)
	shaft(world, start + movement * seam, end - movement * seam, Vector3.UP * radius * 0.09,
		Vector3(radius * 0.86, radius * 0.63, radius * 0.78), color, broken)

static func shaft(world, start: Vector3, end: Vector3, bow: Vector3,
		profile: Vector3, color: Color, broken: int) -> void:
	var forward := start.direction_to(end)
	var across := forward.cross(Vector3.UP).normalized()
	var dorsal := across.cross(forward)
	var widths := [profile.x * 0.73, profile.x, profile.y * 1.08, profile.y,
		profile.y * 1.07, profile.z, profile.z * 0.72]
	var rings: Array[PackedVector3Array] = []
	for row in range(STATIONS.size()):
		var fraction: float = STATIONS[row]
		var center := start.lerp(end, fraction) + bow * sin(fraction * PI)
		var width: float = widths[row]
		var split_end := (row == 0 and broken == -1) or (row == STATIONS.size() - 1 and broken == 1)
		var ring := PackedVector3Array()
		for edge in range(SIDES):
			var angle := float(edge) * TAU / SIDES
			var oval := width * (1.0 + 0.032 * sin(edge * 1.77 + row * 0.82))
			var chip := (0.23 * sin(edge * 2.37) + 0.13 * cos(edge * 1.19)) * width if split_end else 0.0
			ring.append(center + across * cos(angle) * oval + dorsal * sin(angle) * oval * 0.82 + forward * chip)
		rings.append(ring)
		if row == 0:
			continue
		var prior := rings[row - 1]
		for edge in range(SIDES):
			var next := (edge + 1) % SIDES
			var tint := color.lerp(WEATHERED_BONE, 0.08 + (1.0 - sin(edge * TAU / SIDES)) * 0.14)
			world.mesh.quad(prior[edge], ring[edge], ring[next], prior[next], tint)
	end_face(world, rings[0], start, -forward, color, broken == -1)
	end_face(world, rings[-1], end, forward, color, broken == 1)
	if profile.y > 0.10:
		ink_shaft(world, rings)

static func end_face(world, rim: PackedVector3Array, center: Vector3, normal: Vector3, paint: Color, broken: bool) -> void:
	var recess := PackedVector3Array()
	if broken:
		for point in rim:
			recess.append(center.lerp(point, 0.55) - normal * 0.048)
	for edge in range(SIDES):
		var next := (edge + 1) % SIDES
		if broken:
			var chipped := IVORY if edge % 3 != 1 else CORTEX
			world.mesh.quad(rim[edge], rim[next], recess[next], recess[edge], chipped)
			world.mesh.triangle(center - normal * 0.058, recess[edge], recess[next], CAVITY, normal)
		else:
			world.mesh.triangle(center, rim[edge], rim[next], paint, normal)

static func ink_shaft(world, rings: Array[PackedVector3Array]) -> void:
	var scratch := PackedVector3Array()
	for index in range(1, rings.size() - 1):
		var panel := rings[index]
		scratch.append(panel[2].lerp(panel[3], 0.57 + 0.18 * sin(index * 2.2)) + Vector3.UP * 0.012)
	world.pencil(scratch, 0.016, INK)
	var seam := PackedVector3Array()
	for edge in range(1, 6):
		seam.append(rings[1][edge].lerp(rings[2][edge], 0.29 + 0.10 * sin(edge * 2.4)) + Vector3.UP * 0.012)
	world.pencil(seam, 0.012, INK)
