extends RefCounted

const Detail = preload("res://scripts/model/ReliefDetail.gd")
const OCHRE := Color("#be8c62")
const CLAY := Color("#a27160")
const UMBER := Color("#695663")
const MASONRY := Color("#b0987a")
const BONE := Color("#c8b48d")

static func build(world) -> void:
	build_sand_beds(world)
	build_contact_shadows(world)
	build_escarpments(world)
	build_ruins(world)
	build_ossuary(world)
	build_emplacements(world)
	build_dry_scrub(world)

static func build_contact_shadows(world) -> void:
	Detail.contact(world, Vector2(220, 225), Vector2(57, 42), Color("#775642"), 0.30)
	Detail.contact(world, Vector2(410, 197), Vector2(66, 38), Color("#795a4a"), 0.45)
	Detail.contact(world, Vector2(575, 179), Vector2(67, 54), Color("#795d4d"), -0.45)
	Detail.contact(world, Vector2(519, 390), Vector2(68, 51), Color("#775f51"), 0.15)
	for index in range(5):
		var x := 601.0 + index * 29.0
		var y := 169.0 + sin(index * 0.60) * 12.0
		Detail.contact(world, Vector2(x - 8, y + 92.0), Vector2(11, 14), Color("#866d53"), -0.3)

static func build_sand_beds(world) -> void:
	var drifts := [
		[[[2,104],[36,89],[75,100],[113,124],[141,192],[125,222],[96,194],[54,151],[0,149]], "#a17b65"],
		[[[259,66],[308,97],[340,126],[349,174],[330,217],[303,230],[266,229],[279,181],[285,133],[250,94]], "#9d745c"],
		[[[477,230],[514,199],[559,181],[600,161],[656,155],[722,173],[764,197],[785,304],[734,331],
			[680,330],[628,307],[583,294],[537,267],[505,270]], "#ad8364"],
		[[[577,221],[614,197],[666,184],[711,199],[743,222],[754,269],[731,291],[688,309],[650,293],[588,264]], "#bc9470"],
		[[[86,466],[118,420],[163,394],[190,374],[224,404],[260,426],[282,450],[344,490],[231,509],[132,496]], "#8b665c"],
		[[[449,420],[491,421],[531,413],[576,388],[615,398],[648,422],[666,466],[639,488],[539,503],[491,479]], "#b28366"],
		[[[286,256],[313,259],[344,249],[379,247],[413,263],[434,288],[414,328],[380,339],[343,325],[303,313],[279,287]], "#bb8a67"],
	]
	for index in range(drifts.size()):
		var beach := loop(drifts[index][0])
		for pass_number in range(2):
			var rounded: Array[Vector2] = []
			for side in range(beach.size()):
				var a := beach[side]
				var b := beach[(side + 1) % beach.size()]
				rounded.append(a.lerp(b, 0.23))
				rounded.append(a.lerp(b, 0.77))
			beach = rounded
		var height := 0.004 + index * 0.0011
		var color := Color(drifts[index][1])
		world.patch(beach, height, Color(color, 0.28))
		for fleck in range(3):
			var start := (7 + fleck * (beach.size() / 3) + index * 4) % beach.size()
			var ink := PackedVector3Array()
			for step in range(5):
				var pick := beach[(start + step) % beach.size()]
				if world.route_distance(pick) < 13.0 or world.slot_distance(pick) < 15.0:
					break
				ink.append(world.from_floor(pick, height + 0.002))
			if ink.size() >= 3:
				world.pencil(ink, 0.018, Color(color.darkened(0.31), 0.81))

static func loop(raw: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for p in raw:
		result.append(Vector2(p[0], p[1]))
	return result

static func build_escarpments(world) -> void:
	# The mesas follow the same solid outlines used for collision and light occlusion.
	mesa(world, loop(world.layout.walls[0]), PackedFloat32Array([0.0, 0.50, 0.91, 1.61, 2.14]), CLAY, OCHRE)
	mesa(world, loop(world.layout.walls[1]), PackedFloat32Array([0.0, 0.32, 0.63, 1.08]), UMBER, MASONRY)
	mesa(world, loop(world.layout.walls[2]), PackedFloat32Array([0.0, 0.62, 1.08, 1.55, 2.56, 3.08]), CLAY, OCHRE)
	mesa(world, loop(world.layout.walls[3]), PackedFloat32Array([0.0, 0.30, 0.60, 0.96]), UMBER, MASONRY)
	mesa(world, loop([[0,36],[42,43],[78,69],[74,101],[47,105],[10,96],[-16,69]]),
		PackedFloat32Array([0.0, 0.70, 1.21, 2.18, 3.21]), CLAY, MASONRY)
	mesa(world, loop([[-16,253],[15,253],[63,274],[90,318],[71,365],[24,382],[-15,357]]),
		PackedFloat32Array([0.0, 0.72, 1.40, 2.25, 3.65]), UMBER, OCHRE)
	mesa(world, loop([[98,-12],[210,-18],[264,14],[274,60],[249,99],[194,106],[148,83],[123,47]]),
		PackedFloat32Array([0.0, 1.08, 1.68, 2.37, 3.43]), CLAY, MASONRY)
	mesa(world, loop([[413,-14],[509,-20],[570,9],[611,39],[613,67],[536,69],[460,56],[415,47]]),
		PackedFloat32Array([0.0, 0.81, 1.42, 2.05, 3.62]), UMBER, MASONRY)
	mesa(world, loop([[682,8],[764,0],[799,55],[784,110],[727,119],[686,92],[666,50]]),
		PackedFloat32Array([0.0, 0.38, 1.13, 1.64, 2.30]), UMBER, CLAY)
	mesa(world, loop([[663,394],[706,385],[753,406],[779,443],[773,488],[674,491],[637,462],[632,421]]),
		PackedFloat32Array([0.0, 0.40, 0.84, 1.36, 1.83]), CLAY, MASONRY)

static func mesa(world, footprint: Array[Vector2], elevations: PackedFloat32Array, base: Color, cap: Color) -> void:
	var center := Vector2.ZERO
	for p in footprint:
		center += p
	center /= footprint.size()
	var perimeter: Array[Vector2] = []
	for edge in range(footprint.size()):
		var a := footprint[edge]
		var b := footprint[(edge + 1) % footprint.size()]
		var divisions := clampi(ceili(a.distance_to(b) / 14.0), 2, 7)
		for index in range(divisions):
			perimeter.append(a.lerp(b, float(index) / divisions))
	var lower := rock_ring(world, perimeter, center, 0.0, 0.0, 0.0)
	var ridge := lower
	var stages := PackedVector2Array([Vector2(0.20, 0.018), Vector2(0.66, 0.045),
		Vector2(0.83, -0.010), Vector2(1.0, 0.0)])
	for band in range(elevations.size() - 1):
		for layer in range(stages.size()):
			var stage := stages[layer]
			var height := lerpf(elevations[band], elevations[band + 1], stage.x)
			var fraction := (band + stage.x) / elevations.size()
			ridge = rock_ring(world, perimeter, center, height, 0.34 * fraction + stage.y, fraction)
			var tone := base.lerp(cap, fraction * 0.48)
			if layer == 1:
				tone = tone.lerp(UMBER, 0.18)
			elif layer == 2:
				tone = tone.lerp(cap, 0.34)
			rock_band(world, lower, ridge, tone, band, layer)
			lower = ridge
	var top := PackedVector2Array()
	for p in ridge:
		top.append(Vector2(p.x, p.z))
	var triangles := Geometry2D.triangulate_polygon(top)
	for index in range(0, triangles.size(), 3):
		var a := ridge[triangles[index]]
		var b := ridge[triangles[index + 1]]
		var c := ridge[triangles[index + 2]]
		var color := cap.lerp(base, 0.13 + sin((a.x + b.z) * 2.7) * 0.035)
		world.mesh.triangle(a, c, b, color, Vector3.UP)

static func rock_ring(world, perimeter: Array[Vector2], center: Vector2, height: float,
		shrink: float, fraction: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	var seed := center.x * 0.18 + center.y * 0.37
	for i in range(perimeter.size()):
		var theta := TAU * i / perimeter.size()
		var ruffle := sin(theta * 6.0 + seed) * 0.021 + cos(theta * 11.0 - seed) * 0.013
		var sag := sin(theta * 3.0 + seed + fraction * 3.2) * 0.087 + sin(theta * 7.0 + seed) * 0.032
		var step := clampf(height * 4.0, 0.0, 1.0)
		var p := perimeter[i].lerp(center, shrink + ruffle * step)
		result.append(world.from_floor(p, height + sag * step))
	return result

static func rock_band(world, lower: PackedVector3Array, ridge: PackedVector3Array, tone: Color,
		band: int, layer: int) -> void:
	for i in range(ridge.size()):
		var j := (i + 1) % ridge.size()
		var a := lower[i]
		var b := ridge[i]
		var c := ridge[j]
		var d := lower[j]
		var pigment := tone.lerp(UMBER, 0.065 + 0.045 * cos((a.x + a.z) * 1.17))
		world.mesh.quad(a, b, c, d, Color(pigment, 0.84))
		# Draw the strata along the real bevel, with gaps where the rock sheared.
		var normal := (b - a).cross(d - a).normalized()
		var ink := Color(tone.lerp(UMBER, 0.48).darkened(0.43), 0.81)
		if layer == 2 and (i + band * 3) % 11 != 9:
			var face := PackedVector3Array([
				a, b, c, d
			])
			world.contour.panel_stroke(face, PackedVector2Array([Vector2(0.65, 0.0),
				Vector2(0.61 + sin(i * 2.2) * 0.12, 0.43), Vector2(0.65, 1.0)]),
				0.026, ink, normal, false, false)
		elif layer == 1 and (i + band * 4) % 7 in [1, 4]:
			var face := PackedVector3Array([a, b, c, d])
			world.contour.panel_stroke(face, PackedVector2Array([Vector2(0.06, 0.36), Vector2(0.28, 0.44),
				Vector2(0.56, 0.37), Vector2(0.74, 0.50), Vector2(0.93, 0.47)]), 0.022, ink, normal)

static func build_ruins(world) -> void:
	# The paired portals share a ledge cut into the upper cliff. The dark recesses
	# sit behind the dressed arches, and the surviving cornice ties the piers together.
	var ash := Color("#897667")
	var cap := Color("#b19879")
	world.stone(185, 106, 124.0, 31.0, 0.46, ash, 0.04)
	world.stone(246, 114, 44.0, 28.0, 0.45, ash, 0.17)
	world.stone(156, 71, 35.0, 8.0, 2.45, Color("#514b46"), 0.04)
	world.stone(232, 83, 40.0, 8.0, 2.78, Color("#514b46"), 0.10)
	world.wall([Vector2(105, 77), Vector2(134, 81)], 2.36, ash, 14.0)
	world.wall([Vector2(176, 84), Vector2(203, 89)], 2.68, MASONRY, 14.0)
	world.wall([Vector2(256, 96), Vector2(271, 108), Vector2(281, 128)], 1.78, ash, 13.0)
	world.arch(Vector2(155, 81), 35.0, 2.44, MASONRY.darkened(0.06), 0.13)
	world.arch(Vector2(232, 94), 43.0, 2.99, MASONRY, 0.13)
	# Silhouette of the doorway lies in front of the cliff where it fills the recess.
	var front := Vector3(-sin(0.13), 0.0, cos(0.13))
	var along := Vector3(front.z, 0.0, -front.x)
	for doorway in [[155.0, 81.0, 0.47, 1.84], [232.0, 94.0, 0.60, 2.24]]:
		var foot: Vector3 = world.at(doorway[0], doorway[1], 0.36) + front * 0.34
		var width: float = doorway[2]
		var spring: Vector3 = foot + Vector3.UP * (float(doorway[3]) - 0.36)
		var shadow := Color("#4a4039")
		world.contour.quad(foot - along * width, foot + along * width, spring + along * width,
			spring - along * width, shadow)
		for wedge in range(8):
			var a := float(wedge) * PI / 8.0
			var b := float(wedge + 1) * PI / 8.0
			world.contour.triangle(spring, spring + width * (along * cos(a) + Vector3.UP * sin(a)),
				spring + width * (along * cos(b) + Vector3.UP * sin(b)), shadow, front)
	world.stone(126, 77, 41.0, 19.0, 0.15, cap, 0.08, 2.71)
	world.stone(194, 86, 39.0, 18.0, 0.14, cap, 0.14, 2.80)
	column(world, Vector2(187, 97), 2.28)
	column(world, Vector2(268, 112), 1.39)
	world.steps(Vector2(151, 128), Vector2(155, 99), 27.0, 0.44, 6, cap)
	world.steps(Vector2(229, 133), Vector2(233, 102), 31.0, 0.70, 8, cap)
	# Two collapsed retaining walls pick up the profile of the natural terrace.
	# Keep the exposed stair run and the west mounting shelf approach free.
	world.wall([Vector2(181, 193), Vector2(199, 207), Vector2(216, 212)], 0.64, ash, 9.0)
	world.wall([Vector2(239, 172), Vector2(250, 186), Vector2(254, 203)], 0.53, cap, 10.0)
	world.steps(Vector2(268, 237), Vector2(242, 231), 32.0, 1.27, 10, cap)
	world.steps(Vector2(153, 205), Vector2(175, 183), 27.0, 1.11, 8, ash)
	column(world, Vector2(285, 247), 1.48)
	column(world, Vector2(173, 149), 1.40)
	# The smaller arch protects the separate high-ground firing position.
	world.wall([Vector2(369, 165), Vector2(392, 166), Vector2(405, 176)], 1.22, MASONRY, 15.0)
	world.wall([Vector2(417, 182), Vector2(434, 188), Vector2(451, 184)], 1.48, MASONRY, 17.0)
	world.arch(Vector2(406, 178), 30.0, 1.40, MASONRY.darkened(0.09), 0.17)
	# Foreground remnants read as the ends of two enclosure walls, with paving
	# fanning away from the pass and a fractured pier where they once joined.
	world.stone(183, 408, 61.0, 28.0, 0.13, ash, -0.17)
	world.wall([Vector2(154, 404), Vector2(176, 413), Vector2(205, 414)], 0.78, ash, 11.0)
	world.wall([Vector2(154, 402), Vector2(149, 389)], 0.43, MASONRY, 10.0)
	column(world, Vector2(151, 401), 1.22)
	world.stone(380, 419, 55.0, 26.0, 0.13, ash.darkened(0.08), -0.07)
	world.wall([Vector2(354, 400), Vector2(393, 406), Vector2(414, 396)], 0.59, ash, 12.0)
	world.wall([Vector2(479, 368), Vector2(509, 378), Vector2(540, 374)], 0.96, ash, 15.0)
	for data in [[120,158,0.83], [249,211,0.64], [462,184,1.12], [473,357,0.91], [410,401,0.82]]:
		column(world, Vector2(data[0], data[1]), float(data[2]))
	# The paving joints turn behind the walls and stop at the broken edge.
	for joints in [[[158,402],[168,401],[184,401],[195,403]], [[160,411],[174,412],[183,414]],
			[[363,421],[378,420],[391,422],[400,423]], [[374,415],[378,420],[378,425]]]:
		var seam := PackedVector3Array()
		for pair in joints:
			seam.append(world.at(pair[0], pair[1], 0.143))
		world.pencil(seam, 0.019, ash.darkened(0.38))
	for pair in [[141,159], [156,159], [247,255], [439,209], [447,213], [472,366], [483,409]]:
		var point := Vector2(pair[0], pair[1])
		Detail.vessel(world, point, 0.0, 0.105 + fposmod(point.y * 0.043, 0.07), Color("#9b6549"))
	for site: Vector2 in [Vector2(190,254), Vector2(262,215), Vector2(370,193), Vector2(446,235),
		Vector2(529,209), Vector2(602,168), Vector2(508,404), Vector2(549,393)]:
		talus(world, site)
	Detail.vine(world, [[138,80,1.86],[150,87,1.41],[158,94,0.99],[168,100,0.35],[178,107,0.04]],
		0.016, Color("#655445"), Color("#827153"), 1.4)

static func column(world, at: Vector2, height: float) -> void:
	var inclination := sin(at.x * 0.076 + at.y * 0.029) * 3.1
	var color := MASONRY.lightened(0.035)
	world.stone(at.x, at.y, 16.0, 14.0, 0.10, MASONRY.darkened(0.23), 0.18)
	world.stone(at.x, at.y, 13.0, 12.0, 0.12, color, 0.18, 0.09)
	var base: Vector3 = world.at(at.x, at.y, 0.18)
	var top: Vector3 = world.at(at.x + inclination, at.y, height)
	var shaft := PackedVector3Array([base, base.lerp(top, 0.11), base.lerp(top, 0.43),
		base.lerp(top, 0.46), base.lerp(top, 0.49), top])
	world.mesh.tube(shaft, PackedFloat32Array([0.205, 0.188, 0.174, 0.164, 0.172, 0.147]), color, 10, 0.016)
	world.stone(at.x + inclination, at.y, 11.0 if height < 1.55 else 16.0, 10.0, 0.10,
		color.lightened(0.06), 0.18 + inclination * 0.025, height - 0.055)
	var face := Vector3(0.036, 0.0, 0.177)
	world.pencil(PackedVector3Array([base.lerp(top, 0.15) + face, base.lerp(top, 0.35) + face * 0.98,
		base.lerp(top, 0.43) + face * 0.95]), 0.023, color.darkened(0.48))

static func build_ossuary(world) -> void:
	# The collapsed chest has two uneven banks with the spine displaced toward the ridge.
	var exposed := [
		[Vector2(582, 198), Vector2(9, -2), 0.76, 0.18, true],
		[Vector2(607, 194), Vector2(18, -11), 2.68, 0.22, false],
		[Vector2(638, 181), Vector2(21, -5), 3.04, 0.25, false],
		[Vector2(667, 176), Vector2(18, -2), 2.85, 0.23, false],
		[Vector2(699, 180), Vector2(22, 2), 2.19, 0.20, false],
		[Vector2(728, 186), Vector2(13, -6), 1.36, 0.18, true],
		[Vector2(593, 265), Vector2(7, -4), 0.72, 0.16, true],
		[Vector2(617, 270), Vector2(-26, -13), 2.54, 0.25, false],
		[Vector2(652, 274), Vector2(-24, -19), 3.01, 0.27, false],
		[Vector2(684, 272), Vector2(-7, -5), 1.08, 0.22, true],
		[Vector2(709, 266), Vector2(-16, -15), 2.42, 0.22, false],
		[Vector2(731, 259), Vector2(-13, -9), 1.65, 0.19, false],
	]
	world.sculpture("蚀沙古台 · 风白埋骨", func():
		for index in range(exposed.size()):
			var part: Array = exposed[index]
			ossuary_rib(world, part[0], part[1], part[2], part[3], part[4], index)
		var spine := [Vector2(620, 226), Vector2(642, 219), Vector2(663, 216), Vector2(686, 219),
			Vector2(708, 222), Vector2(728, 217), Vector2(744, 208)]
		for index in range(spine.size()):
			var previous: Vector2 = spine[maxi(index - 1, 0)]
			var following: Vector2 = spine[mini(index + 1, spine.size() - 1)]
			ossuary_vertebra(world, spine[index], previous.direction_to(following), index)
		for data in [[Vector2(577, 241), Vector2(588, 237), 0.18], [Vector2(634, 244), Vector2(647, 249), 0.20],
				[Vector2(696, 246), Vector2(708, 240), 0.17], [Vector2(711, 296), Vector2(726, 295), 0.125]]:
			var a: Vector3 = world.from_floor(data[0], 0.05)
			var end: Vector3 = world.from_floor(data[1], 0.10)
			world.mesh.smooth_tube(PackedVector3Array([a, a.lerp(end, 0.50) + Vector3.UP * 0.044, end]),
				PackedFloat32Array([data[2] * 0.65, data[2] * 0.45, data[2]]), BONE.darkened(0.21), 8, 0.06)
	)

static func ossuary_rib(world, root: Vector2, lean: Vector2, height: float, girth: float, broken: bool, index: int) -> void:
	var path := PackedVector3Array()
	var phase := index * 2.19
	var side := lean.normalized().orthogonal()
	var length := 13 if height > 1.5 else 9
	for step in range(length):
		var portion := step / float(length - 1)
		var offset := lean * (0.15 * portion + 0.85 * pow(portion, 1.89))
		offset += side * sin(PI * portion) * (3.8 + cos(phase) * 2.5)
		var rise := lerpf(-0.13, height, sin(portion * 1.24) / sin(1.24))
		path.append(world.from_floor(root + offset, rise))
	var tone := BONE.lerp(Color("#d8c29e"), 0.22 + 0.23 * sin(phase * 0.61))
	var previous := PackedVector3Array()
	for step in range(length):
		var portion := step / float(length - 1)
		var tangent := path[maxi(0, step - 1)].direction_to(path[mini(length - 1, step + 1)])
		var wide := tangent.cross(Vector3.UP).normalized()
		var narrow := wide.cross(tangent)
		var radius := girth * lerpf(1.19, 0.63 if broken else 0.26, portion)
		radius *= 0.94 + 0.13 * sin(PI * portion) + 0.046 * sin(portion * 8.19 + phase)
		var ring := PackedVector3Array()
		for edge in range(10):
			var bearing := edge * TAU / 10.0 + 0.22 * sin(phase + portion * 2.3)
			var rough := 1.0 + sin(edge * 3.71 + step * 0.81 + phase) * 0.048
			var push := narrow * cos(bearing) * 0.69 + wide * sin(bearing) * 1.17
			var chip := 0.056 * sin(edge * 2.71 + phase) if broken and step == length - 1 else 0.0
			ring.append(path[step] + push * radius * rough + tangent * chip)
		if step > 0:
			var buried := 1.0 - smoothstep(0.05, 0.78, path[step].y)
			var coat := tone.lerp(Color("#92765d"), buried * 0.72)
			for edge in range(10):
				var next := (edge + 1) % 10
				var panel := PackedVector3Array([previous[edge], ring[edge], ring[next], previous[next]])
				var shade := coat.darkened(0.15 if edge in [3, 4, 5, 6] else 0.022)
				world.mesh.quad(panel[0], panel[3], panel[2], panel[1], shade)
				if edge in [0, 7] and step in [3 + index % 3, 7, length - 2]:
					ossuary_mark(world, panel, shade.darkened(0.47), phase + edge)
		if step == length - 1:
			ossuary_cut(world, ring, path[step], tangent, tone, broken)
		previous = ring

static func ossuary_mark(world, panel: PackedVector3Array, tint: Color, phase: float) -> void:
	var normal := (panel[2] - panel[0]).cross(panel[1] - panel[0]).normalized()
	var skew := sin(phase) * 0.20
	world.contour.panel_stroke(panel, PackedVector2Array([Vector2(0.16, 0.23), Vector2(0.43, 0.37 + skew),
		Vector2(0.63, 0.40), Vector2(0.89, 0.61 - skew)]), 0.020, Color(tint, 0.87), normal)

static func ossuary_cut(world, lip: PackedVector3Array, center: Vector3, tangent: Vector3, tone: Color, broken: bool) -> void:
	var core := center - tangent * (0.095 if broken else 0.020)
	for index in range(lip.size()):
		var next := (index + 1) % lip.size()
		if broken:
			var a := core + (lip[index] - center) * (0.47 + sin(index * 2.37) * 0.15)
			var b := core + (lip[next] - center) * (0.47 + sin(next * 2.37) * 0.15)
			world.mesh.quad(lip[index], lip[next], b, a, tone.lightened(0.075))
			world.mesh.triangle(a, b, core, Color("#66513f").lightened(index % 3 * 0.046))
		else:
			world.mesh.triangle(lip[index], lip[next], core, tone.darkened(0.08))

static func ossuary_vertebra(world, foot: Vector2, direction: Vector2, index: int) -> void:
	var phase := index * 2.42
	var scale := 0.83 + cos(index * 0.53) * 0.15
	var bed: Vector3 = world.from_floor(foot, 0.13 + sin(phase) * 0.035)
	var axis: Vector3 = bed.direction_to(world.from_floor(foot + direction * 22.0, bed.y))
	var across := axis.cross(Vector3.UP)
	var shade := BONE.darkened(0.16 + 0.039 * sin(phase))
	world.ellipsoid(bed, Vector3(0.37, 0.24, 0.30) * scale, shade, 11, 5)
	world.ellipsoid(bed - axis * (0.20 * scale), Vector3(0.27, 0.26, 0.28) * scale,
		shade.lightened(0.079), 10, 5)
	var attachment := bed + across * 0.23 * scale + Vector3.UP * 0.19
	var crest := bed + Vector3.UP * (0.40 + sin(phase) * 0.076) - axis * 0.037
	var arch := PackedVector3Array([attachment, crest + across * 0.19 * scale,
		crest, crest - across * 0.18 * scale, bed - across * 0.21 * scale + Vector3.UP * 0.16])
	world.mesh.smooth_tube(arch, PackedFloat32Array([0.12, 0.104, 0.084, 0.081, 0.10]), shade, 8, 0.07)
	var thorn := crest + axis * (0.20 + sin(phase) * 0.036) + Vector3.UP * (0.19 + cos(phase) * 0.065)
	world.mesh.smooth_tube(PackedVector3Array([crest - Vector3.UP * 0.025, crest.lerp(thorn, 0.48), thorn]),
		PackedFloat32Array([0.13, 0.082, 0.031]), shade.lightened(0.052), 8, 0.060)

static func rib(world, start: Vector2, curl: Vector2, height: float, broken: bool) -> void:
	var curve := PackedVector3Array()
	var widths := PackedFloat32Array()
	var count := 7 if not broken or height > 1.5 else 5
	for i in range(count):
		var t := float(i) / 6.0
		var at := start + curl * (t * t)
		curve.append(world.at(at.x, at.y, sin(t * 1.42) * height + 0.04))
		widths.append(lerpf(0.19, 0.044 if count == 7 else 0.10, t))
	world.mesh.tube(curve, widths, BONE if not broken else BONE.darkened(0.10), 8, 0.06)
	world.ellipsoid(curve[-1], Vector3.ONE * widths[-1] * 0.83, BONE, 8, 4)

static func build_emplacements(world) -> void:
	# The west mounting shelf protrudes out of the mesa, on a battered pilaster.
	var west := Vector2(227, 243)
	for tier in range(3):
		world.stone(west.x, west.y + tier * 0.55, 31.0 - tier * 2.8, 15.0 + tier * 0.75, 0.45,
			MASONRY.darkened(0.12 - tier * 0.045), 0.09, tier * 0.43)
	world.stone(west.x, west.y, 30.0, 20.0, 0.17, MASONRY.lightened(0.06), 0.09, 1.15)
	Detail.jaw(world, west, 1.42, 0.09, MASONRY.darkened(0.16), 23.0, 16.0)
	# The open arch frames a stone base set atop its ancient altar.
	var altar := Vector2(405, 191)
	world.stone(altar.x, altar.y, 36.0, 23.0, 0.23, MASONRY, -0.13, 0.88)
	world.stone(altar.x, altar.y + 2, 30.0, 20.0, 0.18, MASONRY.lightened(0.07), -0.13, 1.05)
	Detail.jaw(world, altar, 1.30, -0.13, MASONRY.darkened(0.13), 23.0, 16.0)
	# Weathered bone wraps around the buried seat and naturally breaks in front.
	var collar := Vector2(598, 321)
	var path := PackedVector3Array()
	var widths := PackedFloat32Array()
	for i in range(13):
		var rad := lerpf(-PI * 0.13, PI * 1.18, i / 12.0)
		var at := collar + Vector2(cos(rad) * 16.0, -sin(rad) * 11.0)
		path.append(world.at(at.x, at.y, 0.22 + sin(i * 1.2) * 0.044))
		widths.append(0.095 + sin(i * 2.63) * 0.037)
	world.mesh.smooth_tube(path, widths, BONE.lightened(0.12), 8, 0.11)
	rib(world, collar + Vector2(-13, 8), Vector2(-6, -8), 0.75, false)
	rib(world, collar + Vector2(14, -4), Vector2(8, 6), 0.65, false)
	Detail.jaw(world, collar, 0.38, 0.08, BONE.darkened(0.31), 20.5, 14.0)
	# The southern cliff buttress breaks into a low oil gutter beside the approach.
	var parapet := Vector2(572, 317)
	world.wall([Vector2(548,342), Vector2(555,334), Vector2(563,328)], 0.39, MASONRY, 9.0)
	world.stone(parapet.x, parapet.y, 32.0, 19.0, 0.15, MASONRY, -0.54, 0.04)
	Detail.jaw(world, parapet, 0.30, -0.54, MASONRY.darkened(0.12), 25.0, 15.0)

	# Collapsed low masonry and earthworks continue the four lane-side fittings.
	world.wall([Vector2(160,278),Vector2(169,276)],0.35,MASONRY,9.0)
	world.wall([Vector2(187,270),Vector2(200,265)],0.45,MASONRY,10.0)
	world.stone(178,273,24.0,13.0,0.10,CLAY,0.33)
	world.steps(Vector2(295,224),Vector2(303,210),24.0,0.14,4,MASONRY.darkened(0.16))
	world.stone(310,208,28.0,20.0,0.13,MASONRY.lightened(0.09),-0.22)
	world.stone(321,202,7.2,7.4,0.23,CLAY,-0.28)
	world.stone(482,280,30.0,16.0,0.18,MASONRY,-0.28)
	world.stone(485,272,28.0,7.0,0.28,CLAY,-0.28)
	world.stone(471,276,7.5,10.4,0.23,UMBER,-0.28)
	for i in range(5):
		var p := Vector2(359 + (i - 2) * 6.0, 321 + sin(i * 0.6) * 2.5)
		world.stone(p.x,p.y+8.2,5.9,5.4,0.086,CLAY,i * 0.035)
		world.stone(p.x,p.y-8.2,6.2,4.8,0.075,MASONRY,-i * 0.038)
	world.stone(359,321,31.0,11.0,0.043,UMBER.darkened(0.18),-0.11)

static func talus(world, center: Vector2) -> void:
	for i in range(5):
		var p := center + Vector2.from_angle(i * 2.61 + center.x * 0.08) * (4.0 + i * 2.4)
		var size := 10.2 - i * 1.26
		world.stone(p.x, p.y, size, size * 0.74, 0.26 - i * 0.026, CLAY.lightened(i * 0.041), i * 0.782)

static func build_dry_scrub(world) -> void:
	for index in range(38):
		var x: float = world.random.randf_range(104, 744)
		var y: float = world.random.randf_range(101, 468)
		if Vector2(x, y).distance_to(Vector2(387, 265)) < 50.0:
			continue
		var span: float = world.random.randf_range(3.6, 11.0)
		world.stone(x, y, span, span * 0.66, 0.09 + span * 0.009, CLAY.darkened(index % 4 * 0.035), index * 1.08)
		if index % 3 == 0:
			for leaf in range(4):
				var lean := Vector2.from_angle(index * 0.7 + leaf * TAU / 4.0) * span
				world.mesh.tube(PackedVector3Array([world.at(x, y, 0.01), world.at(x + lean.x * 0.43, y + lean.y * 0.42, 0.24),
					world.at(x + lean.x, y + lean.y, 0.31 + leaf * 0.021)]), PackedFloat32Array([0.026, 0.018, 0.006]),
					Color("#665b45"), 5, 0.05)
