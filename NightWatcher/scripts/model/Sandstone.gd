extends RefCounted

const Detail = preload("res://scripts/model/ReliefDetail.gd")
const OCHRE := Color("#b68a59")
const CLAY := Color("#906249")
const UMBER := Color("#614c43")
const MASONRY := Color("#a88b6d")
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
	# Large soft-color strata wind between the cliffs behind the playable routes.
	world.patch(loop([[4,101],[37,84],[83,88],[114,120],[124,171],[143,209],[127,219],[104,196],[82,162],[49,147],[1,146]]),
		0.006, Color("#9e7b5b"))
	world.patch(loop([[263,68],[308,98],[346,136],[351,175],[328,214],[298,227],[286,233],[269,219],[291,170],[289,131],[252,96]]),
		0.006, Color("#987355"))
	world.patch(loop([[478,228],[517,198],[558,181],[594,170],[634,161],[685,160],[726,179],[760,209],
		[768,318],[726,331],[668,327],[629,307],[581,290],[542,270],[507,269]]), 0.007, Color("#9f7e5d"))
	world.patch(loop([[578,219],[617,198],[666,188],[715,202],[744,230],[751,274],[731,299],[688,307],[646,293],[585,268]]),
		0.010, Color("#a68a66"))
	world.patch(loop([[92,453],[124,418],[166,392],[190,378],[222,399],[262,419],[284,448],[341,479],[227,507],[136,498]]),
		0.006, Color("#816353"))
	world.patch(loop([[458,419],[529,411],[581,391],[616,400],[648,422],[663,466],[639,489],[538,497],[489,479]]),
		0.006, Color("#9b7a5d"))

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
	var lower := footprint
	for band in range(1, elevations.size()):
		var ridge: Array[Vector2] = []
		var shrink := float(band) / elevations.size() * 0.34 + (0.030 if band % 2 == 0 else -0.003)
		for i in range(lower.size()):
			var shift := sin(i * 2.51 + band * 1.37) * 0.026
			ridge.append(footprint[i].lerp(center, shrink + shift))
		var tint := base.lerp(cap, float(band) / elevations.size() * 0.57)
		if band % 2 == 0:
			tint = tint.darkened(0.16)
		for i in range(ridge.size()):
			var j := (i + 1) % ridge.size()
			var lo := elevations[band - 1]
			var hi := elevations[band]
			var face := PackedVector3Array([
				world.at(lower[i].x, lower[i].y, lo), world.at(ridge[i].x, ridge[i].y, hi),
				world.at(ridge[j].x, ridge[j].y, hi), world.at(lower[j].x, lower[j].y, lo),
			])
			world.mesh.quad(face[0], face[1], face[2], face[3], tint)
			if band % 2 == 1 or i % 3 == 0:
				ink_seam(world, face, tint.darkened(0.44), i % 2 == 0)
		lower = ridge
	world.patch(lower, elevations[-1], cap)

static func ink_seam(world, face: PackedVector3Array, tint: Color, cracks: bool) -> void:
	var normal := (face[1] - face[0]).cross(face[3] - face[0]).normalized()
	world.mesh.panel_stroke(face, PackedVector2Array([Vector2(0.43, 0.07), Vector2(0.39, 0.33),
		Vector2(0.51, 0.53), Vector2(0.46, 0.76), Vector2(0.51, 0.93)]), 0.032, tint, normal)
	if cracks:
		world.mesh.panel_stroke(face, PackedVector2Array([Vector2(0.98, 0.66), Vector2(0.78, 0.65),
			Vector2(0.60, 0.71), Vector2(0.49, 0.72)]), 0.026, tint, normal)

static func build_ruins(world) -> void:
	# Main terrace, two extant gates and the broken approach down into camp.
	world.arch(Vector2(155, 77), 38.0, 2.55, MASONRY.darkened(0.12), -0.07)
	world.arch(Vector2(232, 94), 44.0, 2.95, MASONRY, 0.17)
	world.wall([Vector2(104, 71), Vector2(124, 75), Vector2(137, 78)], 2.05, MASONRY, 17.0)
	world.wall([Vector2(251, 98), Vector2(274, 110), Vector2(283, 136)], 1.16, MASONRY, 14.0)
	world.steps(Vector2(229, 130), Vector2(233, 102), 30.0, 0.75, 7, MASONRY)
	world.steps(Vector2(268, 237), Vector2(242, 231), 32.0, 1.27, 10, MASONRY)
	world.steps(Vector2(153, 205), Vector2(175, 183), 27.0, 1.11, 8, MASONRY.darkened(0.11))
	world.wall([Vector2(369, 165), Vector2(392, 166), Vector2(405, 176)], 1.22, MASONRY, 15.0)
	world.wall([Vector2(417, 182), Vector2(434, 188), Vector2(451, 184)], 1.48, MASONRY, 17.0)
	world.arch(Vector2(406, 178), 30.0, 1.40, MASONRY.darkened(0.09), 0.17)
	world.wall([Vector2(479, 368), Vector2(509, 378), Vector2(540, 374)], 0.96, MASONRY, 15.0)
	world.wall([Vector2(354, 400), Vector2(393, 406), Vector2(414, 396)], 0.59, MASONRY.darkened(0.14), 12.0)
	for data in [[120,158,0.83], [173,149,1.40], [249,211,0.64], [287,249,1.03], [462,184,1.12], [473,357,0.91]]:
		column(world, Vector2(data[0], data[1]), float(data[2]))
	for pair in [[141,159], [156,159], [247,255], [439,209], [447,213], [472,366], [483,409]]:
		var point := Vector2(pair[0], pair[1])
		Detail.vessel(world, point, 0.0, 0.105 + fposmod(point.y * 0.043, 0.07), Color("#9b6549"))
	for site: Vector2 in [Vector2(190,254), Vector2(262,215), Vector2(370,193), Vector2(446,235),
		Vector2(529,209), Vector2(602,168), Vector2(508,404), Vector2(549,393)]:
		talus(world, site)
	Detail.vine(world, [[138,80,1.86],[150,87,1.41],[158,94,0.99],[168,100,0.35],[178,107,0.04]],
		0.016, Color("#655445"), Color("#827153"), 1.4)

static func column(world, at: Vector2, height: float) -> void:
	world.stone(at.x, at.y, 15.0, 15.0, 0.10, MASONRY.darkened(0.19), 0.18)
	world.stone(at.x, at.y, 12.0, 12.0, 0.12, MASONRY, 0.18, 0.09)
	var base: Vector3 = world.at(at.x, at.y, 0.18)
	var top: Vector3 = world.at(at.x + 2, at.y, height)
	world.mesh.tube(PackedVector3Array([base, top]), PackedFloat32Array([0.18, 0.14]), MASONRY, 9, 0.0)
	world.stone(at.x + 2, at.y, 11.0, 11.0, 0.08, MASONRY.lightened(0.07), 0.18, height - 0.05)

static func build_ossuary(world) -> void:
	# Paired ribs curve over the sandy hollow with different fractures and burial depths.
	for i in range(5):
		var x := 601.0 + i * 29.0
		var y := 169.0 + sin(i * 0.60) * 12.0
		rib(world, Vector2(x, y), Vector2(-21, 30), 2.52 - i * 0.21, false)
		rib(world, Vector2(x - 8, y + 93.0), Vector2(24, -29), 2.09 - i * 0.22, true)
	for i in range(5):
		var x := 619.0 + i * 22.0
		var head: Vector3 = world.at(x, 215.0, 0.18 + i * 0.024)
		world.ellipsoid(head, Vector3(0.25, 0.23, 0.19), BONE.darkened(0.14), 9, 5)
		world.ellipsoid(head + Vector3(0, 0.20, 0), Vector3(0.11, 0.15, 0.11), BONE, 8, 4)
	for p in [Vector2(568, 237), Vector2(587, 264), Vector2(648, 269), Vector2(703, 247), Vector2(713, 299)]:
		world.stone(p.x, p.y, 13.0, 7.0, 0.13, BONE.darkened(0.10), p.x * 0.029)
	for i in range(7):
		var p := Vector2(710 + i * 5.1, 211 + sin(i * 0.61) * 13.0)
		world.ellipsoid(world.at(p.x,p.y,0.19), Vector3(0.16,0.20,0.15), BONE.darkened(0.20 + i * 0.012), 8, 5)

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
