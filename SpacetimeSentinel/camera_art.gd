extends RefCounted

const WIDTH := 480
const HEIGHT := 360
const MACHINE_BOUNDS := Rect2(104.0 / WIDTH, 190.0 / HEIGHT, 62.0 / WIDTH, 128.0 / HEIGHT)

static var courtyard_image: Image
static var gate_texture: Texture2D
static var pruned_texture: Texture2D
static var guard_texture: Texture2D

var canvas: Image
var random := RandomNumberGenerator.new()

static func gate() -> Texture2D:
	if gate_texture == null:
		var shot = courtyard()
		shot.paint_machine()
		gate_texture = ImageTexture.create_from_image(shot.canvas)
	return gate_texture

static func pruned() -> Texture2D:
	if pruned_texture == null:
		pruned_texture = ImageTexture.create_from_image(courtyard().canvas)
	return pruned_texture

static func guard() -> Texture2D:
	if guard_texture == null:
		var shot = courtyard()
		shot.paint_guard()
		guard_texture = ImageTexture.create_from_image(shot.canvas)
	return guard_texture

static func courtyard():
	var art = load("res://camera_art.gd").new()
	art.random.seed = 370184
	if courtyard_image == null:
		art.canvas = Image.create_empty(WIDTH, HEIGHT, false, Image.FORMAT_RGB8)
		art.paint_courtyard()
		courtyard_image = art.canvas
	art.canvas = courtyard_image.duplicate()
	return art

func fill(x: int, y: int, w: int, h: int, tint: Color) -> void:
	if w > 0 and h > 0:
		canvas.fill_rect(Rect2i(x, y, w, h), tint)

func polygon(points: Array, tint: Color) -> void:
	var first_row := HEIGHT
	var last_row := 0
	for p: Vector2 in points:
		first_row = mini(first_row, floori(p.y))
		last_row = maxi(last_row, ceili(p.y))
	for y in range(maxi(first_row, 0), mini(last_row, HEIGHT)):
		var crossings := PackedFloat32Array()
		var scan := y + 0.5
		for i in range(points.size()):
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % points.size()]
			if scan >= minf(a.y, b.y) and scan < maxf(a.y, b.y):
				crossings.append(lerpf(a.x, b.x, (scan - a.y) / (b.y - a.y)))
		crossings.sort()
		for i in range(0, crossings.size() - 1, 2):
			var x := clampi(ceili(crossings[i] - 0.5), 0, WIDTH)
			fill(x, y, mini(WIDTH, ceili(crossings[i + 1] - 0.5)) - x, 1, tint)

func ink_line(from: Vector2, to: Vector2, width: int, tint: Color) -> void:
	var count := maxi(1, ceili(from.distance_to(to)))
	for i in count + 1:
		var p := from.lerp(to, i / float(count))
		fill(roundi(p.x) - width / 2, roundi(p.y) - width / 2, width, width, tint)

func wash(p: Vector2i, tint: Color, rate: float) -> void:
	if Rect2i(0, 0, WIDTH, HEIGHT).has_point(p):
		canvas.set_pixelv(p, canvas.get_pixelv(p).lerp(tint, rate))

func paint_courtyard() -> void:
	paint_sky()
	paint_snowfield()
	masonry([Vector2(0, 155), Vector2(153, 151), Vector2(156, 242), Vector2(0, 249)],
		Color("#374550"), 10)
	masonry([Vector2(365, 155), Vector2(480, 126), Vector2(480, 222), Vector2(365, 263)],
		Color("#52616a"), 12)
	masonry([Vector2(150, 148), Vector2(191, 134), Vector2(195, 252), Vector2(151, 241)],
		Color("#293841"), 13)
	masonry([Vector2(190, 130), Vector2(369, 144), Vector2(365, 264), Vector2(193, 250)],
		Color("#536069"), 14)
	parapet(Vector2(-4, 147), Vector2(152, 144), 11, Color("#43525b"))
	parapet(Vector2(365, 149), Vector2(492, 116), 10, Color("#5a6870"))
	paint_tower()
	paint_gate()
	paint_snowbanks()
	paint_air()

func paint_sky() -> void:
	for y in 243:
		var tint := Color("#25343f").lerp(Color("#6c7d85"), pow(y / 242.0, 0.76))
		fill(0, y, WIDTH, 1, tint)
	for i in 125:
		var x := random.randi_range(-32, WIDTH - 1)
		var y := random.randi_range(9, 145)
		var wide := random.randi_range(14, 90)
		var tint := canvas.get_pixel(clampi(x, 0, WIDTH - 1), y)
		fill(x, y, wide, random.randi_range(1, 3), tint.lightened(random.randf_range(0.010, 0.049)))
	polygon([Vector2(0, 110), Vector2(32, 95), Vector2(43, 98), Vector2(69, 79),
		Vector2(91, 85), Vector2(119, 109), Vector2(156, 116), Vector2(187, 142),
		Vector2(0, 164)], Color("#52616b"))
	polygon([Vector2(0, 127), Vector2(36, 110), Vector2(75, 119), Vector2(101, 107),
		Vector2(148, 125), Vector2(182, 145), Vector2(0, 173)], Color("#475760"))
	polygon([Vector2(365, 140), Vector2(393, 113), Vector2(419, 100), Vector2(431, 102),
		Vector2(462, 89), Vector2(480, 91), Vector2(480, 164)], Color("#60717a"))
	for index in 22:
		var x := index * 7 - 8
		var base_y := 152 - (x % 6)
		var tall := random.randi_range(10, 35)
		polygon([Vector2(x - 4, base_y), Vector2(x, base_y - tall), Vector2(x + 5, base_y)],
			Color("#394851").lightened(random.randf_range(0.0, 0.09)))

func paint_snowfield() -> void:
	for y in range(219, HEIGHT):
		var tint := Color("#8d9ba0").lerp(Color("#657883"), (y - 219) / 142.0)
		fill(0, y, WIDTH, 1, tint)
	polygon([Vector2(0, 241), Vector2(143, 232), Vector2(220, 248), Vector2(289, 267),
		Vector2(472, 247), Vector2(480, 279), Vector2(310, 305), Vector2(172, 284),
		Vector2(60, 270), Vector2(0, 273)], Color("#7e8e96"))
	polygon([Vector2(269, 245), Vector2(307, 247), Vector2(342, 280), Vector2(453, 319),
		Vector2(468, 360), Vector2(261, 360), Vector2(278, 328), Vector2(286, 295),
		Vector2(262, 269)], Color("#79888d"))
	polygon([Vector2(283, 268), Vector2(307, 269), Vector2(336, 291), Vector2(409, 316),
		Vector2(452, 340), Vector2(387, 323), Vector2(327, 294)], Color("#98a6ab"))
	polygon([Vector2(0, 296), Vector2(31, 284), Vector2(82, 288), Vector2(129, 315),
		Vector2(207, 330), Vector2(233, 346), Vector2(160, 339), Vector2(95, 320),
		Vector2(26, 323), Vector2(0, 333)], Color("#82949d"))
	polygon([Vector2(0, 349), Vector2(52, 335), Vector2(104, 338), Vector2(167, 357),
		Vector2(199, 360), Vector2(0, 360)], Color("#98a6ae"))
	for i in 1180:
		var x := random.randi_range(0, WIDTH - 1)
		var y := random.randi_range(218, HEIGHT - 1)
		var anchor := Vector2i(x, y)
		var snowy := random.randf() < 0.76
		var tint := Color("#bdc9ca") if snowy else Color("#42515e")
		var length := random.randi_range(1, 4 if y < 276 else 12)
		var rate := random.randf_range(0.04, 0.18)
		for j in length:
			wash(anchor + Vector2i(j, 0), tint, rate)

func wall_point(corners: Array, u: float, v: float) -> Vector2:
	var top: Vector2 = corners[0].lerp(corners[1], u)
	var bottom: Vector2 = corners[3].lerp(corners[2], u)
	return top.lerp(bottom, v)

func masonry(corners: Array, tint: Color, courses: int) -> void:
	polygon(corners, tint.darkened(0.24))
	var width: float = corners[0].distance_to(corners[1])
	var edge: float = corners[0].distance_to(corners[3])
	for course in courses:
		var top := (course + 0.08) / courses
		var bottom := (course + 0.96) / courses
		var offset := 0.0
		while offset < 0.998:
			var span := random.randf_range(10.0, 24.0) / width
			if course % 2 == 1 and offset == 0.0:
				span *= 0.54
			var stop := minf(offset + span, 1.0)
			var right := maxf(offset + 0.001, stop - 0.8 / width)
			var top_left := wall_point(corners, offset, top)
			var top_right := wall_point(corners, right, top + random.randf_range(-0.48, 0.58) / edge)
			var a := wall_point(corners, right, bottom)
			var b := wall_point(corners, offset, bottom)
			var variation := random.randf_range(-0.048, 0.062)
			var fade := (1.0 - top) * 0.030
			var stone := Color(tint.r + variation + fade, tint.g + variation + fade, tint.b + variation + fade)
			polygon([top_left, top_right, a, b], stone)
			if span * width > 11.0 and random.randf() < 0.72:
				ink_line(top_left.lerp(top_right, 0.13) + Vector2.DOWN, top_left.lerp(top_right, 0.77) + Vector2.DOWN,
					1, stone.lightened(random.randf_range(0.033, 0.11)))
				var speck := top_left.lerp(a, 0.53)
				fill(roundi(speck.x), roundi(speck.y), random.randi_range(2, 5), 1, stone.darkened(0.12))
			offset = stop

func parapet(a: Vector2, b: Vector2, count: int, tint: Color) -> void:
	for i in count:
		var x := a.lerp(b, i / float(count))
		var z := a.lerp(b, (i + 0.69) / count)
		var height := 10.0 + random.randf_range(-2.0, 1.0)
		var lift := Vector2(0, -height)
		polygon([x + lift, z + lift, z + Vector2(0, 5), x + Vector2(0, 5)], tint)
		polygon([x + lift, x + lift + Vector2(5, -4), z + lift + Vector2(4, -4), z + lift],
			Color("#a0afb4"))
		ink_line(z + lift, z + Vector2(0, 3), 1, tint.darkened(0.26))

func paint_tower() -> void:
	polygon([Vector2(208, 68), Vector2(328, 73), Vector2(348, 91), Vector2(346, 133),
		Vector2(208, 122)], Color("#27343e"))
	polygon([Vector2(328, 73), Vector2(348, 91), Vector2(346, 133), Vector2(327, 128)], Color("#44545c"))
	for bay in 5:
		var x := 215 + bay * 22
		var y := 85 + bay / 2
		fill(x, y, 16, 29, Color("#121f27"))
		fill(x, y, 2, 29, Color("#646f72"))
		fill(x + 4, y + 5, 9, 15, Color("#333f47"))
		for slat in 4:
			fill(x + 4, y + 6 + slat * 4, 9, 1, Color("#485861"))
		fill(x + 14, y, 2, 29, Color("#3a484d"))
	fill(211, 110, 126, 4, Color("#4a565c"))
	roof(Vector2(175, 130), Vector2(377, 142), Vector2(226, 91), Vector2(326, 97), 20)
	fill(219, 61, 102, 19, Color("#28363f"))
	for i in 5:
		fill(225 + i * 19, 62, 3, 14, Color("#55636a"))
	roof(Vector2(197, 73), Vector2(354, 82), Vector2(236, 38), Vector2(311, 43), 17)
	ink_line(Vector2(233, 38), Vector2(311, 44), 3, Color("#222c34"))
	ink_line(Vector2(231, 35), Vector2(311, 41), 2, Color("#a8b6ba"))
	polygon([Vector2(227, 38), Vector2(230, 31), Vector2(232, 31), Vector2(233, 37), Vector2(240, 41)],
		Color("#4e606b"))
	polygon([Vector2(309, 42), Vector2(313, 35), Vector2(316, 36), Vector2(314, 41), Vector2(318, 45)],
		Color("#596873"))

func roof(left: Vector2, right: Vector2, ridge_a: Vector2, ridge_b: Vector2, tiles: int) -> void:
	var left_curl := left + Vector2(10, 8)
	var right_curl := right + Vector2(-12, 7)
	polygon([left, left_curl, left + Vector2(37, -2), ridge_a, ridge_b,
		right + Vector2(-39, -3), right_curl, right, right + Vector2(-11, 13),
		left + Vector2(15, 14)], Color("#1d2b35"))
	polygon([left_curl, ridge_a, ridge_b, right_curl,
		right + Vector2(-43, 8), left + Vector2(45, 8)], Color("#41515c"))
	for index in tiles:
		var u := index / float(tiles - 1)
		var crest := ridge_a.lerp(ridge_b, u) + Vector2(0, 1)
		var lip := left_curl.lerp(right_curl, u) + Vector2(0, 4.4 * sin(u * PI))
		var bend := crest.lerp(lip, 0.56) + Vector2(-2.4 + u * 5, 0)
		ink_line(crest, bend, 1, Color("#283944"))
		ink_line(bend, lip, 1, Color("#253540"))
		ink_line(bend + Vector2(2, -1), lip + Vector2(2, -1), 1,
			Color("#516370") if index % 3 == 1 else Color("#4b5a64"))
	polygon([ridge_a + Vector2(-1, 0), ridge_b, ridge_b + Vector2(17, 14),
		ridge_b + Vector2(8, 13), ridge_b + Vector2(0, 9), ridge_a + Vector2(48, 10),
		ridge_a + Vector2(33, 6), ridge_a + Vector2(20, 11), ridge_a + Vector2(7, 8),
		ridge_a + Vector2(-11, 17), ridge_a + Vector2(-8, 9)], Color("#a3b1b7"))
	ink_line(left + Vector2(6, 5), left + Vector2(47, 8), 2, Color("#8497a1"))
	ink_line(left + Vector2(49, 8), right + Vector2(-28, 10), 2, Color("#677983"))
	ink_line(right + Vector2(-25, 10), right + Vector2(-3, 4), 2, Color("#9daeb5"))
	for end in tiles - 1:
		var bracket := left_curl.lerp(right_curl, (end + 0.5) / tiles) + Vector2(0, 7)
		fill(roundi(bracket.x), roundi(bracket.y), 4, 3, Color("#37444d"))

func paint_gate() -> void:
	var center := Vector2(282, 202)
	var rim := PackedVector2Array()
	var interior := PackedVector2Array([Vector2(246, 253)])
	for i in 19:
		var theta := PI - PI * i / 18.0
		var normal := Vector2(cos(theta), -sin(theta))
		rim.append(center + normal * Vector2(46.0, 47.0))
		interior.append(center + normal * Vector2(36.0, 35.0))
	interior.append(Vector2(318, 260))
	polygon(Array(interior), Color("#101d25"))
	polygon([Vector2(246, 201), Vector2(258, 201), Vector2(264, 245), Vector2(318, 254),
		Vector2(318, 260), Vector2(246, 253)], Color("#2e4049"))
	polygon([Vector2(266, 209), Vector2(279, 180), Vector2(300, 189), Vector2(314, 208),
		Vector2(315, 251), Vector2(266, 245)], Color("#182932"))
	for i in 18:
		var tint := Color("#78848a").darkened(random.randf_range(0.02, 0.26))
		var a := rim[i]
		var b := rim[i + 1]
		polygon([a, a.lerp(b, 0.91), interior[i + 1].lerp(interior[i + 2], 0.91), interior[i + 1]], tint)
		if i >= 8 and i <= 14:
			ink_line(a, a.lerp(b, 0.84), 1, tint.lightened(0.17))
	for side in [0, 1]:
		var x := 236 if side == 0 else 318
		var top := 202 if side == 0 else 203
		for row in 7:
			var y := top + row * 8
			fill(x + row % 2, y, 10, 7, Color("#63717a").lightened(random.randf_range(0.0, 0.12)))
	ink_line(Vector2(244, 252), Vector2(319, 260), 2, Color("#9baab0"))
	ink_line(Vector2(242, 256), Vector2(322, 264), 1, Color("#52636e"))
	var plaque := Color("#3a474c")
	polygon([Vector2(261, 148), Vector2(303, 151), Vector2(302, 161), Vector2(261, 158)], plaque)
	ink_line(Vector2(262, 148), Vector2(302, 151), 1, Color("#919da1"))
	for i in 3:
		var x := 268 + i * 10
		var y: int = 151 + i
		fill(x, y + 1, 6, 1, Color("#a0a09a"))
		fill(x + 2, y, 1, 5, Color("#a0a09a"))
		fill(x + 4, y + 4, 2, 1, Color("#a0a09a"))

func paint_snowbanks() -> void:
	polygon([Vector2(0, 245), Vector2(20, 238), Vector2(54, 242), Vector2(76, 236),
		Vector2(125, 239), Vector2(140, 233), Vector2(169, 242), Vector2(202, 248),
		Vector2(229, 249), Vector2(243, 255), Vector2(205, 255), Vector2(163, 250),
		Vector2(114, 246), Vector2(68, 251), Vector2(0, 255)], Color("#a0aeb4"))
	polygon([Vector2(319, 258), Vector2(327, 248), Vector2(361, 254), Vector2(393, 243),
		Vector2(420, 233), Vector2(453, 230), Vector2(480, 216), Vector2(480, 232),
		Vector2(448, 243), Vector2(420, 244), Vector2(380, 259), Vector2(351, 266),
		Vector2(329, 266)], Color("#a9b6ba"))
	for i in 37:
		var x := random.randi_range(0, WIDTH - 1)
		var y := random.randi_range(264, HEIGHT - 1)
		var span := random.randi_range(3, 15)
		if i % 4 == 0:
			polygon([Vector2(x - 3, y), Vector2(x + 3, y - 2), Vector2(x + span, y + 1),
				Vector2(x + 4, y + 3)], Color("#74848d"))
		ink_line(Vector2(x, y - 1), Vector2(x + span, y), 1, Color("#9fadb2"))

func paint_air() -> void:
	for i in 420:
		var x := random.randi_range(0, WIDTH - 1)
		var y := random.randi_range(0, HEIGHT - 1)
		var strength := random.randf_range(0.13, 0.43)
		wash(Vector2i(x, y), Color("#b9c7cb"), strength)
		if i % 5 == 0:
			wash(Vector2i(x - 1, y), Color("#b9c7cb"), strength * 0.49)
	for i in 62:
		var x := random.randi_range(4, WIDTH - 4)
		var y := random.randi_range(4, HEIGHT - 4)
		var strength := random.randf_range(0.14, 0.43)
		for j in random.randi_range(3, 8):
			wash(Vector2i(x - j, y + j / 3), Color("#bbc8cd"), strength * (0.88 - j * 0.080))

func paint_machine() -> void:
	polygon([Vector2(108, 309), Vector2(151, 305), Vector2(184, 313), Vector2(165, 320),
		Vector2(121, 322), Vector2(95, 317)], Color("#52636e"))
	polygon([Vector2(104, 199), Vector2(143, 190), Vector2(166, 201), Vector2(165, 311),
		Vector2(146, 318), Vector2(104, 310)], Color("#101b24"))
	polygon([Vector2(143, 190), Vector2(166, 201), Vector2(165, 310), Vector2(145, 317)],
		Color("#3f515e"))
	polygon([Vector2(104, 199), Vector2(143, 190), Vector2(165, 201), Vector2(125, 212)],
		Color("#768890"))
	polygon([Vector2(105, 200), Vector2(145, 207), Vector2(144, 317), Vector2(105, 309)],
		Color("#4f616f"))
	polygon([Vector2(111, 206), Vector2(138, 212), Vector2(138, 306), Vector2(111, 302)],
		Color("#101e27"))
	ink_line(Vector2(106, 201), Vector2(144, 208), 2, Color("#9aadb4"))
	ink_line(Vector2(105, 201), Vector2(105, 308), 2, Color("#81959e"))
	ink_line(Vector2(144, 209), Vector2(143, 314), 1, Color("#a3b2b9"))
	ink_line(Vector2(163, 203), Vector2(162, 308), 1, Color("#778c98"))
	for module in 6:
		var y := 217 + module * 13
		polygon([Vector2(113, y), Vector2(136, y + 4), Vector2(136, y + 11), Vector2(113, y + 7)],
			Color("#374c59") if module % 3 != 0 else Color("#556b78"))
		ink_line(Vector2(114, y + 2), Vector2(135, y + 6), 1, Color("#8b9ca2"))
		ink_line(Vector2(115, y + 5), Vector2(132, y + 8), 1, Color("#1a2c36"))
		fill(133, y + 6, 2, 1, Color("#b9f3ea") if module % 3 == 0 else Color("#8bafac"))
	for slot in 12:
		var y := 220 + slot * 6
		ink_line(Vector2(151, y), Vector2(159, y - 2), 1, Color("#253743"))
	fill(113, 302, 7, 2, Color("#769096"))
	fill(123, 303, 2, 2, Color("#c6c09a"))
	ink_line(Vector2(105, 307), Vector2(137, 315), 2, Color("#899da5"))
	ink_line(Vector2(144, 316), Vector2(160, 311), 2, Color("#9babaf"))

func paint_guard() -> void:
	var ink := Color("#141d24")
	var armor := Color("#35444d")
	var edge := Color("#6d7a7e")
	var cloth := Color("#573d3b")
	polygon([Vector2(188, 312), Vector2(243, 312), Vector2(258, 316), Vector2(244, 322),
		Vector2(205, 325), Vector2(180, 319)], Color("#576873"))
	polygon([Vector2(202, 289), Vector2(219, 293), Vector2(217, 316), Vector2(197, 318),
		Vector2(195, 313), Vector2(202, 309)], ink)
	polygon([Vector2(224, 290), Vector2(239, 287), Vector2(240, 307), Vector2(248, 311),
		Vector2(248, 316), Vector2(225, 317)], ink)
	ink_line(Vector2(201, 307), Vector2(215, 306), 2, Color("#64747b"))
	ink_line(Vector2(229, 306), Vector2(239, 304), 2, Color("#566971"))
	polygon([Vector2(201, 259), Vector2(237, 259), Vector2(244, 294), Vector2(236, 301),
		Vector2(224, 300), Vector2(222, 294), Vector2(215, 301), Vector2(201, 299),
		Vector2(194, 293)], ink)
	polygon([Vector2(203, 262), Vector2(235, 262), Vector2(241, 293), Vector2(234, 298),
		Vector2(223, 296), Vector2(221, 289), Vector2(214, 298), Vector2(202, 297),
		Vector2(197, 291)], cloth)
	for row in 5:
		var y := 270 + row * 5
		for x in range(199 + row % 2, 238 + row / 3, 7):
			if x >= 217 and x < 224 and row > 2:
				continue
			fill(x, y, 6, 4, armor.darkened(row * 0.04))
			fill(x + 1, y + 1, 2, 1, edge.darkened(0.18))
	polygon([Vector2(192, 228), Vector2(203, 216), Vector2(233, 215), Vector2(248, 228),
		Vector2(251, 251), Vector2(244, 266), Vector2(236, 268), Vector2(230, 257),
		Vector2(204, 258), Vector2(195, 271), Vector2(185, 267), Vector2(181, 252)], ink)
	polygon([Vector2(191, 232), Vector2(205, 232), Vector2(203, 254), Vector2(194, 264),
		Vector2(188, 263), Vector2(185, 253)], cloth)
	polygon([Vector2(234, 230), Vector2(247, 232), Vector2(248, 253), Vector2(241, 263),
		Vector2(236, 261), Vector2(235, 246)], cloth.darkened(0.18))
	polygon([Vector2(199, 227), Vector2(206, 218), Vector2(233, 218), Vector2(243, 228),
		Vector2(233, 251), Vector2(235, 265), Vector2(202, 266), Vector2(204, 251)], armor)
	ink_line(Vector2(204, 229), Vector2(233, 226), 2, edge)
	ink_line(Vector2(205, 240), Vector2(233, 239), 2, edge.darkened(0.15))
	for row in 4:
		var y := 230 + row * 6
		for l in 4:
			var x := 204 + l * 8 + row % 2
			fill(x, y, 7, 5, Color("#53616a").darkened(l * 0.047))
			fill(x + 2, y + 1, 2, 1, Color("#78888d"))
			fill(x + 1, y + 4, 5, 1, ink)
	polygon([Vector2(184, 232), Vector2(191, 221), Vector2(204, 219), Vector2(208, 224),
		Vector2(202, 236), Vector2(185, 242)], armor)
	polygon([Vector2(232, 217), Vector2(244, 220), Vector2(253, 231), Vector2(248, 239),
		Vector2(235, 235), Vector2(229, 226)], armor)
	for row in 3:
		ink_line(Vector2(187 - row, 229 + row * 4), Vector2(202 - row * 2, 224 + row * 4), 1, edge)
		ink_line(Vector2(234 + row, 222 + row * 5), Vector2(244 + row, 226 + row * 4), 1, edge)
	fill(188, 260, 5, 5, Color("#8a7774"))
	fill(241, 259, 5, 5, Color("#8a7774"))
	polygon([Vector2(202, 252), Vector2(234, 250), Vector2(236, 255), Vector2(203, 259)],
		Color("#784941"))
	fill(216, 251, 7, 6, Color("#a29277"))
	fill(218, 252, 3, 3, Color("#423a35"))
	polygon([Vector2(204, 207), Vector2(207, 199), Vector2(225, 198), Vector2(232, 209),
		Vector2(227, 218), Vector2(218, 224), Vector2(210, 219)], ink)
	polygon([Vector2(207, 204), Vector2(222, 202), Vector2(227, 208), Vector2(224, 216),
		Vector2(218, 220), Vector2(210, 214)], Color("#92837b"))
	fill(209, 207, 5, 2, Color("#25282b"))
	fill(220, 206, 5, 2, Color("#25282b"))
	fill(213, 208, 1, 1, Color("#c0b8a7"))
	fill(222, 207, 1, 1, Color("#c0b8a7"))
	fill(217, 210, 2, 3, Color("#b2a095"))
	fill(214, 215, 7, 1, Color("#514443"))
	polygon([Vector2(199, 204), Vector2(201, 199), Vector2(204, 188), Vector2(213, 182),
		Vector2(223, 182), Vector2(230, 190), Vector2(232, 199), Vector2(238, 201),
		Vector2(233, 206), Vector2(200, 208)], ink)
	polygon([Vector2(204, 199), Vector2(206, 188), Vector2(214, 184), Vector2(222, 185),
		Vector2(228, 192), Vector2(230, 199)], Color("#596972"))
	polygon([Vector2(209, 196), Vector2(212, 187), Vector2(217, 185), Vector2(216, 197)],
		Color("#88979e"))
	ink_line(Vector2(201, 204), Vector2(233, 201), 2, edge)
	ink_line(Vector2(215, 183), Vector2(217, 176), 3, Color("#4e453e"))
	polygon([Vector2(216, 179), Vector2(218, 172), Vector2(224, 172), Vector2(226, 175),
		Vector2(221, 176), Vector2(222, 182)], Color("#825349"))
	ink_line(Vector2(196, 317), Vector2(209, 319), 1, Color("#9dacb2"))
	ink_line(Vector2(225, 319), Vector2(246, 317), 1, Color("#9dacb2"))
