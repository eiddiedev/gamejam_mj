extends RefCounted

const NECK := Vector2(525, 187)
const PELVIS := Vector2(424, 347)
const IVORY := Color("#c5b99b")
const SHADED_IVORY := Color("#91917b")
const MARROW := Color("#725b47")
const INK := Color("#505448")
const RIB_SIDES := 10
const RIB_SPAN := [51.0, 60.0, 69.0, 74.0, 74.0, 71.0, 65.0, 56.0, 47.0]
const RIB_DROP := [42.0, 47.0, 50.0, 51.0, 50.0, 52.0, 50.0, 48.0, 46.0]

static func build(world) -> void:
	var along: Vector3 = (world.from_floor(PELVIS) - world.from_floor(NECK)).normalized()
	var across := along.cross(Vector3.UP)
	for index in range(11):
		var shift := Vector2(sin(index * 1.47) * 1.5, cos(index * 1.91) * 0.8)
		var anchor: Vector3 = world.from_floor(NECK.lerp(PELVIS, index / 10.0) + shift, 0.40)
		var tone: Color = world.weathered(Color("#a29a80"), 0.047)
		vertebra(world, anchor, along, across, tone, index)
	for index in range(RIB_SPAN.size()):
		for side: float in [-1.0, 1.0]:
			var tone: Color = world.weathered(IVORY if side > 0.0 else SHADED_IVORY, 0.039)
			rib(world, index, side, tone)
	pelvic_plate(world)

static func vertebra(world, at: Vector3, along: Vector3, across: Vector3, tone: Color, index: int) -> void:
	var size := 0.89 + sin(index * 0.31) * 0.12
	var positions := [-0.30, -0.21, -0.07, 0.12, 0.25, 0.30]
	var collars := [0.80, 1.0, 0.86, 0.84, 0.98, 0.78]
	var previous := PackedVector3Array()
	for slice in range(positions.size()):
		var ring := PackedVector3Array()
		for edge in range(RIB_SIDES):
			var angle := edge * TAU / RIB_SIDES + sin(index * 3.27) * 0.16
			var roughness := 0.98 + sin(edge * 3.13 + slice * 1.91 + index) * 0.065
			var crown := cos(angle) * 0.25 * roughness
			var width := sin(angle) * 0.34 * roughness
			var section: Vector3 = (across * width + Vector3.UP * crown) * size * collars[slice]
			ring.append(at + along * positions[slice] * size + section)
		if not previous.is_empty():
			for edge in range(RIB_SIDES):
				var next := (edge + 1) % RIB_SIDES
				var shade := tone.darkened(0.10 if slice in [2, 3] else 0.0)
				world.mesh.quad(previous[edge], previous[next], ring[next], ring[edge], shade)
		if slice == 0 or slice == positions.size() - 1:
			var center: Vector3 = at + along * positions[slice] * size
			var facing := -along if slice == 0 else along
			for edge in range(RIB_SIDES):
				world.mesh.triangle(center, ring[edge], ring[(edge + 1) % RIB_SIDES], tone.darkened(0.18), facing)
		previous = ring
	var root := at + Vector3.UP * 0.16
	var blade := at + along * 0.18 + Vector3.UP * (0.38 + sin(index * 2.3) * 0.028)
	world.mesh.smooth_tube(PackedVector3Array([root, root.lerp(blade, 0.62), blade]),
		PackedFloat32Array([0.142, 0.109, 0.025]), tone.lightened(0.065), 8, 0.065)
	for side: float in [-1.0, 1.0]:
		var joint := at + across * side * (0.25 + sin(index * 2.51 + side) * 0.026) + Vector3.UP * 0.08
		world.ellipsoid(joint, Vector3(0.155, 0.166, 0.16) * size, tone.darkened(0.07), 9, 5)

static func rib(world, index: int, side: float, tone: Color) -> void:
	var where := NECK.lerp(PELVIS, index / 8.0)
	var bend := sin(index * 3.04 + side * 1.73)
	var spread: float = RIB_SPAN[index] * (0.965 + bend * 0.026) * side
	var descent: float = RIB_DROP[index] + sin(index * 2.37 + side) * 2.3
	var lift := (1.04 if side > 0.0 else 0.93) + sin(index * 1.71 + side) * 0.059
	var broken := (index == 4 and side > 0.0) or (index == 2 and side < 0.0)
	var controls: Array[Vector3] = [Vector3(0.0, 0.37, 0.0), Vector3(0.23, 0.71 * lift, 0.014),
		Vector3(0.53, 0.99 * lift, 0.118), Vector3(0.81, 1.06 * lift, 0.327),
		Vector3(0.98, 0.59 * lift, 0.698), Vector3(0.90, 0.27, 0.87), Vector3(0.79, 0.093, 1.0)]
	var radii := PackedFloat32Array([0.143, 0.162, 0.153, 0.141, 0.109, 0.078, 0.027])
	if broken:
		controls.resize(5)
		radii.resize(5)
		radii[-1] = 0.126 if side > 0.0 else 0.104
	var knots := PackedVector3Array()
	for point in controls:
		knots.append(world.at(where.x + point.x * spread, where.y + point.z * descent, point.y))
	var path := PackedVector3Array()
	var girth := PackedFloat32Array()
	for section in range(knots.size() - 1):
		var previous := knots[maxi(0, section - 1)]
		var after := knots[mini(knots.size() - 1, section + 2)]
		for sample in range(3):
			var step := sample / 3.0
			path.append(knots[section].cubic_interpolate(knots[section + 1], previous, after, step))
			girth.append(lerpf(radii[section], radii[section + 1], step))
	path.append(knots[-1])
	girth.append(radii[-1])
	var previous_ring := PackedVector3Array()
	var phase := index * 2.43 + side * 1.63
	for row in range(path.size()):
		var before := path[maxi(0, row - 1)]
		var after := path[mini(path.size() - 1, row + 1)]
		var tangent := before.direction_to(after)
		var across := tangent.cross(Vector3.UP).normalized()
		var crown := across.cross(tangent).normalized()
		var ring := PackedVector3Array()
		var end_cut := broken and row == path.size() - 1
		for edge in range(RIB_SIDES):
			var theta := edge * TAU / RIB_SIDES + 0.21 * sin(row * 0.19 + phase)
			var roughness := 0.993 + sin(edge * 3.27 + row * 0.70 + phase) * 0.047
			var local := crown * cos(theta) * 0.83 + across * sin(theta) * 1.12
			var chip := tangent * (0.028 * sin(edge * 2.77 + phase) + 0.010 * cos(edge * 3.63)) if end_cut else Vector3.ZERO
			ring.append(path[row] + local * girth[row] * roughness + chip)
		if not previous_ring.is_empty():
			var buried := 1.0 - smoothstep(0.08, 0.42, path[row].y)
			var weathered := tone.lerp(Color("#777961"), buried * 0.48)
			for edge in range(RIB_SIDES):
				var next := (edge + 1) % RIB_SIDES
				var panel := PackedVector3Array([previous_ring[edge], ring[edge], ring[next], previous_ring[next]])
				var shade := weathered.darkened(0.108 if edge in [4, 5, 6] else 0.0)
				world.mesh.quad(panel[0], panel[3], panel[2], panel[1], shade)
				if edge in [0, 8] and (row + index) % 7 in [2, 3] and (edge == 0 or index % 3 == 1):
					weather_line(world, panel, phase + row * 0.97)
		if row == path.size() - 1:
			if broken:
				fracture(world, ring, path[row], tangent, phase)
			else:
				for edge in range(RIB_SIDES):
					world.mesh.triangle(path[row], ring[edge], ring[(edge + 1) % RIB_SIDES], tone)
		previous_ring = ring

static func weather_line(world, panel: PackedVector3Array, phase: float) -> void:
	var tilt := sin(phase) * 0.21
	var normal := (panel[2] - panel[0]).cross(panel[1] - panel[0]).normalized()
	world.contour.panel_stroke(panel, PackedVector2Array([Vector2(0.10, 0.40 - tilt),
		Vector2(0.38, 0.49 + tilt), Vector2(0.63, 0.41), Vector2(0.92, 0.46 + tilt)]),
		0.018 + sin(phase * 1.27) * 0.004, Color(INK, 0.84), normal)

static func fracture(world, rim: PackedVector3Array, at: Vector3, toward: Vector3, phase: float) -> void:
	var core := at - toward * 0.055
	var cavity := PackedVector3Array()
	for edge in range(RIB_SIDES):
		var thickness := 0.49 + sin(edge * 3.28 + phase) * 0.13
		cavity.append(core + (rim[edge] - at) * thickness)
	for edge in range(RIB_SIDES):
		var next := (edge + 1) % RIB_SIDES
		var edge_color := IVORY.lerp(MARROW, 0.21 + sin(edge * 2.01 + phase) * 0.14)
		world.mesh.quad(rim[edge], rim[next], cavity[next], cavity[edge], edge_color)
		var surface := MARROW.darkened(0.26 + sin(edge * 2.48 + phase) * 0.12)
		world.mesh.triangle(cavity[edge], cavity[next], core, surface)
		if edge % 2 == 0:
			var split := PackedVector3Array([rim[edge].lerp(cavity[edge], 0.15),
				rim[edge].lerp(cavity[edge], 0.45) + toward * 0.010,
				cavity[edge].lerp(cavity[next], 0.24) + toward * 0.012])
			world.pencil(split, 0.010, Color("#65503d"))

static func pelvic_plate(world) -> void:
	var hip: Vector3 = world.at(424, 350, 0.33)
	var side: Vector3 = world.at(443, 361, 0.22)
	world.ellipsoid(hip, Vector3(0.75, 0.31, 0.43), IVORY.darkened(0.07), 13, 7)
	world.ellipsoid(side, Vector3(0.61, 0.27, 0.34), SHADED_IVORY, 11, 6)
	var crest := PackedVector3Array([hip + Vector3(-0.58, 0.12, -0.10),
		hip + Vector3(-0.28, 0.32, -0.19), hip + Vector3(0.21, 0.35, -0.21),
		hip + Vector3(0.55, 0.19, -0.15)])
	world.mesh.smooth_tube(crest, PackedFloat32Array([0.042, 0.108, 0.10, 0.035]),
		IVORY.lightened(0.04), 9, 0.08)
	world.pencil(PackedVector3Array([crest[0] + Vector3.UP * 0.046, crest[1] + Vector3.UP * 0.116,
		crest[2] + Vector3.UP * 0.104, crest[3] + Vector3.UP * 0.048]), 0.013, INK)
