extends RefCounted

const Detail = preload("res://scripts/model/ReliefDetail.gd")
const STONE := Color("#727e70")
const CAP := Color("#919784")
const MORTAR := Color("#4b594f")
const WATER := Color("#304e51")
const BANK := Color("#59675c")
const WOOD := Color("#71523d")
const BARK := Color("#624738")
const LEAF := Color("#555b45")

static func build(world) -> void:
	build_sward(world)
	build_contact_shadows(world)
	build_moats(world)
	build_ramparts(world)
	build_rootwork(world)
	build_emplacements(world)
	build_groundwork(world)
	build_ruin_details(world)

static func build_contact_shadows(world) -> void:
	Detail.contact(world, Vector2(267, 158), Vector2(32, 27), Color("#505e50"), -0.25)
	Detail.contact(world, Vector2(523, 165), Vector2(48, 27), Color("#455749"), -0.35)
	Detail.contact(world, Vector2(380, 345), Vector2(88, 21), Color("#535f51"), -0.10)
	Detail.contact(world, Vector2(106, 180), Vector2(19, 18), Color("#535e4f"), 0.15)

static func build_sward(world) -> void:
	# Broad moss and soil masses trace the castle island and the outer bank.
	sward(world, [[246,151],[297,136],[340,139],[409,128],[477,133],[537,147],[563,172],[549,201],
		[538,235],[545,274],[526,306],[477,340],[432,354],[358,352],[307,332],[256,315],[228,277],[223,238]], Color("#6d725e"))
	sward(world, [[264,197],[317,181],[368,172],[449,176],[502,184],[519,207],[509,250],
		[479,289],[442,318],[371,324],[320,311],[275,288],[253,247]], Color("#727b69"), 0.009)
	sward(world, [[2,125],[52,106],[104,116],[137,155],[156,204],[134,226],[91,219],[63,235],[24,221],[-6,187]], Color("#626752"))
	sward(world, [[596,362],[647,346],[710,352],[756,384],[766,447],[720,474],[665,487],[614,463],[592,423]], Color("#6e6e55"))
	sward(world, [[110,409],[150,385],[196,389],[224,413],[263,432],[288,463],[263,481],[155,488],[102,464]], Color("#66654f"))

static func sward(world, raw: Array, tint: Color, height := 0.004) -> void:
	var shape: Array[Vector2] = []
	for p in raw:
		shape.append(Vector2(p[0], p[1]))
	world.patch(shape, height, tint)

static func build_moats(world) -> void:
	for index in range(world.layout.water.size()):
		var shoreline: Array[Vector2] = []
		var center := Vector2.ZERO
		for p in world.layout.water[index]:
			var at := Vector2(p[0], p[1])
			shoreline.append(at)
			center += at
		center /= shoreline.size()
		world.patch(shoreline, 0.013, WATER.lightened(0.11))
		var dark_water: Array[Vector2] = []
		for p in shoreline:
			dark_water.append(p.lerp(center, 0.15))
		world.patch(dark_water, 0.018, WATER.darkened(0.08))
		for edge in range(shoreline.size()):
			var a: Vector2 = shoreline[edge]
			var b: Vector2 = shoreline[(edge + 1) % shoreline.size()]
			var apron_a := a + center.direction_to(a) * (4.6 + sin(edge * 2.1) * 1.8)
			var apron_b := b + center.direction_to(b) * (4.6 + sin((edge + 1) * 2.1) * 1.8)
			world.mesh.quad(world.at(a.x,a.y,0.025), world.at(apron_a.x,apron_a.y,0.15),
				world.at(apron_b.x,apron_b.y,0.15), world.at(b.x,b.y,0.025), BANK.darkened(edge % 3 * 0.085))
			_tidal_mark(world, a.lerp(center, 0.11), b.lerp(center, 0.11), 0.031, 1.05, Color("#668c81"))
			if edge % 3 != 1:
				_tidal_mark(world, a.lerp(center, 0.19).lerp(b, 0.12), b.lerp(center, 0.23).lerp(a, 0.22), 0.033, 0.70, Color("#536f6b"))
			for sample in range(maxi(1, roundi(a.distance_to(b) / 15.0))):
				var spacing := float(sample * 15 + 8) / a.distance_to(b)
				if spacing > 0.96:
					continue
				var at := a.lerp(b, spacing)
				var yaw := (b - a).angle()
				var rise := 0.12 + fposmod(edge * 0.21 + sample * 0.076, 0.14)
				if world.route_distance(at) < 14.0:
					rise = minf(rise, 0.14)
				world.stone(at.x, at.y, 11.0 + (sample % 3) * 1.85, 4.7, rise, BANK.darkened((edge % 3) * 0.066), yaw)
				if (sample + edge + index) % 4 == 0:
					var bank := at + center.direction_to(at) * 6.0
					reeds(world, bank, index * 2.91 + edge * 1.21 + sample * 3.50)
	# The moving decks are created by the level, between these abutments.
	abutments(world, Vector2(237, 303), -0.69)
	abutments(world, Vector2(532, 331), 0.87)
	# Abandoned fishing platform at the southerly bend.
	dock(world, Vector2(634, 413), 0.28)

static func _tidal_mark(world, a: Vector2, b: Vector2, height: float, width: float, tint: Color) -> void:
	var across := a.direction_to(b).orthogonal() * width
	world.mesh.quad(world.at(a.x - across.x, a.y - across.y, height), world.at(a.x + across.x, a.y + across.y, height),
		world.at(b.x + across.x, b.y + across.y, height), world.at(b.x - across.x, b.y - across.y, height), tint)

static func abutments(world, center: Vector2, heading: float) -> void:
	var travel := Vector2.from_angle(heading)
	var across := travel.orthogonal()
	for direction: float in [-1.0, 1.0]:
		var at := center + travel * direction * 24.0
		world.stone(at.x, at.y, 13.0, 27.0, 0.21, MORTAR, heading)
		world.stone(at.x, at.y, 13.0, 26.0, 0.067, CAP, heading, 0.19)
		for side: float in [-1.0, 1.0]:
			var post := at + across * side * 13.3
			world.stone(post.x, post.y, 4.5, 4.1, 0.48, WOOD, heading + 0.08)

static func dock(world, center: Vector2, heading: float) -> void:
	var travel := Vector2.from_angle(heading)
	var across := travel.orthogonal()
	for i in range(11):
		var at := center + travel * (i * 3.2 - 16.0)
		world.stone(at.x, at.y, 2.7, 20.0 + sin(i * 1.56) * 2.2, 0.085, WOOD.lightened(0.10 + i % 4 * 0.037), heading, 0.17)
	for along: float in [-15.0, 9.0, 16.0]:
		for side: float in [-1.0, 1.0]:
			var peg := center + travel * along + across * side * 10.0
			world.stone(peg.x, peg.y, 4.2, 4.1, 0.47, WOOD.darkened(0.16), heading)

static func build_ramparts(world) -> void:
	# Three separated courses leave the west and east bridge portals open.
	world.wall([Vector2(219, 199), Vector2(223, 169), Vector2(236, 143), Vector2(264, 121), Vector2(300, 117), Vector2(332, 118)], 1.58, STONE, 18.0)
	world.wall([Vector2(333, 118), Vector2(366, 121), Vector2(396, 124)], 0.92, STONE, 13.0)
	world.wall([Vector2(451, 130), Vector2(478, 120), Vector2(511, 120), Vector2(541, 138), Vector2(550, 171)], 1.61, STONE, 19.0)
	world.wall([Vector2(302, 321), Vector2(339, 337), Vector2(376, 343), Vector2(414, 337), Vector2(454, 322)], 1.42, STONE, 18.0)
	tower(world, Vector2(267, 147), 41.0, 38.0, 2.94, -0.25)
	tower(world, Vector2(495, 119), 29.0, 29.0, 2.15, 0.28)
	# The entrances face the bridge approaches so the lane crosses their open
	# centers, instead of running along the arch and into its pillars.
	world.arch(Vector2(249, 290), 34.0, 2.72, STONE, 0.81)
	world.arch(Vector2(511, 296), 37.0, 2.76, STONE, -0.46)
	world.arch(Vector2(431, 142), 34.0, 1.95, CAP, -0.12)
	world.arch(Vector2(128, 244), 25.0, 1.30, STONE.darkened(0.04), 0.25)
	world.steps(Vector2(137, 269), Vector2(133, 251), 17.0, 0.48, 7, STONE)
	world.steps(Vector2(470, 172), Vector2(445, 148), 25.0, 0.56, 8, STONE)
	world.wall([Vector2(105, 207), Vector2(122, 210), Vector2(139, 221)], 0.73, MORTAR, 10.0)
	world.wall([Vector2(604, 419), Vector2(628, 430), Vector2(659, 445)], 0.51, STONE.darkened(0.10), 12.0)
	world.wall([Vector2(214, 224), Vector2(215, 240), Vector2(223, 257)], 0.73, STONE.darkened(0.10), 12.0)
	world.wall([Vector2(552, 196), Vector2(553, 219), Vector2(545, 239)], 0.94, STONE.darkened(0.10), 13.0)
	for point: Vector2 in [Vector2(225,201), Vector2(295,157), Vector2(375,123), Vector2(449,152),
		Vector2(529,193), Vector2(321,329), Vector2(397,350), Vector2(457,334), Vector2(198,348)]:
		masonry_scrub(world, point)

static func build_emplacements(world) -> void:
	# Structural beds share the same footprint and shoulder height as the mounted devices.
	var west := Vector2(221, 275)
	world.stone(west.x - 4, west.y + 3, 31.0, 22.0, 0.44, STONE, -0.54)
	world.stone(west.x, west.y, 29.0, 17.0, 0.13, CAP, -0.54, 0.36)
	world.stone(west.x - 13, west.y - 4, 8.5, 12.5, 0.65, MORTAR, -0.61)
	Detail.jaw(world, west, 0.55, -0.54, MORTAR, 20.0, 14.0)

	var crown := Vector2(267, 147)
	world.stone(crown.x, crown.y, 32.0, 24.0, 0.065, WOOD.darkened(0.17), -0.25, 2.90)
	for i in range(6):
		var p := crown + Vector2(0, (i - 2.5) * 4.0).rotated(-0.25)
		Detail.plank(world, p, 26.0 - (i % 2) * 3.0, -0.25, 2.945, WOOD.darkened(0.13 + i * 0.02))
	Detail.jaw(world, crown, 3.00, -0.25, WOOD, 19.0, 15.0)

	var fork := Vector2(465, 252)
	world.stone(fork.x, fork.y, 26.0, 16.0, 0.16, CAP, 0.28, 0.31)
	branch(world, [[481,178,1.19],[480,206,0.67],[493,224,0.43],[488,248,0.39],[476,254,0.35],[470,267,0.03]],
		[0.20,0.17,0.14,0.10,0.066,0.008], WOOD, true)
	branch(world, [[474,204,0.57],[465,219,0.43],[448,230,0.38],[452,247,0.29],[452,258,0.09],[443,262,0.03]],
		[0.18,0.14,0.11,0.09,0.055,0.008], BARK, true)
	Detail.jaw(world, fork, 0.52, 0.28, MORTAR, 20.0, 14.0)

	var east := Vector2(526, 296)
	world.stone(east.x, east.y + 3, 32.0, 22.0, 0.32, MORTAR, 0.76)
	world.stone(east.x, east.y, 32.0, 16.0, 0.15, STONE, 0.76, 0.31)
	Detail.jaw(world, east, 0.54, 0.76, CAP.darkened(0.08), 25.0, 17.0)
	for side: float in [-1.0, 1.0]:
		var tie := east + Vector2(side * 17.0, 2.0).rotated(0.76)
		world.stone(tie.x, tie.y, 4.4, 6.3, 0.57, WOOD.darkened(0.14), 0.76)

	# At ground level each fixture continues a remaining piece of the old ruin.
	world.wall([Vector2(293,273), Vector2(303,279), Vector2(316,276)], 0.32, STONE, 11.0)
	world.stone(312,267,27.0,18.0,0.13,CAP,0.09)
	for i in range(5):
		var at := Vector2(358 + (i - 2) * 7.0, 260 + sin(i * 0.8) * 1.9)
		world.stone(at.x,at.y+5,6.5,4.7,0.075,MORTAR,i*0.05)
		world.stone(at.x,at.y-5,6.5,4.7,0.075,STONE,-i*0.04)
	world.stone(358,260,35.0,10.0,0.04,Color("#353f35"),0.12,0.01)
	for i in range(4):
		Detail.plank(world, Vector2(550 - i * 3.6, 352 + i * 2.7), 24.0, 0.45, 0.16, WOOD.darkened(0.10 + i * 0.043))
	world.stone(556,360,4.8,4.8,0.44,WOOD.darkened(0.12),0.36)
	world.stone(538,354,5.2,5.2,0.47,WOOD.darkened(0.12),0.36)
	world.stone(427,432,27.0,17.0,0.13,CAP,-0.20)
	world.stone(419,439,10.0,8.0,0.25,MORTAR,0.28)
	world.stone(436,439,9.0,8.0,0.22,STONE,-0.28)

static func build_ruin_details(world) -> void:
	var stem := Color("#3a5142")
	var leaf := Color("#657557")
	Detail.vine(world, [[267,167,2.84],[261,169,2.45],[259,170,1.94],[268,170,1.55],[270,172,0.79],[265,175,0.08]],0.018,stem,leaf,0.2)
	Detail.vine(world, [[279,167,2.40],[285,169,1.96],[278,170,1.60],[281,173,0.96],[293,175,0.26]],0.018,stem,leaf,1.7)
	Detail.vine(world, [[221,192,1.48],[226,197,1.32],[223,204,1.06],[229,208,0.66],[233,212,0.08]],0.018,stem,leaf,2.6)
	Detail.vine(world, [[511,138,1.87],[506,141,1.53],[509,146,1.04],[503,147,0.65],[514,150,0.09]],0.020,stem,leaf,3.2)
	Detail.vine(world, [[349,345,1.38],[352,346,0.95],[346,348,0.87],[346,351,0.50],[342,353,0.09]],0.023,stem,leaf,4.6)
	Detail.vine(world, [[429,344,1.30],[421,346,0.91],[429,349,0.54],[424,352,0.14]],0.018,stem,leaf,5.2)
	for location in [[230,287],[291,229],[311,241],[440,226],[479,249],[505,320],[567,365],[455,433]]:
		var p := Vector2(location[0], location[1])
		if int(p.x) % 3 == 0:
			Detail.vessel(world, p, 0.0, 0.135, Color("#8a705a"))
		else:
			Detail.plank(world, p, 11.0, p.x * 0.041, 0.016, WOOD.darkened(0.13))

static func tower(world, center: Vector2, width: float, depth: float, height: float, yaw: float) -> void:
	var rim: Array[Vector2] = []
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var at := center + Vector2(corner.x * width, corner.y * depth).rotated(yaw) * 0.5
		rim.append(at)
	var tower_wall: Array[Vector2] = rim.duplicate()
	tower_wall.append(rim[0])
	world.wall(tower_wall, height, STONE, 10.0)
	world.patch(rim, height - 0.03, MORTAR)
	for i in range(rim.size()):
		var a := rim[i]
		var b := rim[(i + 1) % rim.size()]
		var angle := (b - a).angle()
		for j in range(3):
			var at := a.lerp(b, (j + 0.14) / 3.0)
			world.stone(at.x, at.y, 7.0, 9.0, 0.29 if j != 0 else 0.44, CAP, angle, height - 0.035)
	var facade := center + Vector2(0, depth * 0.58).rotated(yaw)
	world.arch(facade, 9.5, 0.65, CAP.darkened(0.13), yaw)

static func build_rootwork(world) -> void:
	# The main silhouette grows away from the courtyard and threads through the stone.
	branch(world, [[532,153,0.15],[525,152,1.05],[544,135,2.12],[563,120,3.04],[572,110,4.20],[589,87,5.13],[604,76,5.88]],
		[0.71,0.66,0.55,0.46,0.36,0.26,0.115], BARK, true)
	branch(world, [[544,135,2.18],[525,136,2.88],[502,131,3.35],[477,119,3.67],[448,115,3.96],[415,97,4.18]],
		[0.33,0.29,0.20,0.14,0.09,0.016], BARK.darkened(0.09), true)
	branch(world, [[494,128,3.45],[477,139,3.63],[452,138,3.91],[433,125,4.03]],
		[0.12,0.084,0.048,0.008], BARK.darkened(0.11), false)
	branch(world, [[571,113,4.10],[586,119,4.82],[610,104,5.07],[622,93,5.51],[648,80,5.74]],
		[0.27,0.21,0.14,0.073,0.013], BARK, true)
	branch(world, [[587,117,4.76],[618,132,4.92],[641,129,5.05],[665,137,5.22],[685,124,5.41]],
		[0.17,0.14,0.09,0.046,0.008], BARK.darkened(0.09), false)
	branch(world, [[560,120,3.29],[574,136,3.65],[606,152,3.77],[629,151,4.02],[645,166,4.08],[669,155,4.25]],
		[0.24,0.21,0.16,0.092,0.063,0.009], BARK.darkened(0.10), false)
	branch(world, [[534,143,1.62],[513,148,1.39],[488,170,1.68],[459,174,1.05],[437,181,0.68],[409,187,0.11],[389,190,0.04]],
		[0.43,0.36,0.31,0.22,0.18,0.088,0.012], WOOD, true)
	branch(world, [[532,145,1.14],[534,172,1.13],[524,194,0.73],[508,209,0.10],[493,231,0.035]],
		[0.44,0.34,0.28,0.13,0.018], BARK, true)
	branch(world, [[520,163,0.77],[500,178,0.60],[491,192,0.48],[477,196,0.07],[454,208,0.03]],
		[0.27,0.22,0.18,0.10,0.008], WOOD.darkened(0.11), true)
	branch(world, [[541,153,1.08],[561,158,0.72],[573,187,0.45],[592,201,0.15],[609,217,0.04]],
		[0.38,0.30,0.22,0.11,0.009], BARK, true)
	branch(world, [[561,165,0.63],[562,195,0.52],[550,217,0.38],[567,246,0.08],[573,270,0.035]],
		[0.24,0.18,0.15,0.07,0.012], BARK.darkened(0.06), true)
	branch(world, [[488,170,1.52],[472,169,1.20],[460,152,0.90],[448,141,0.39],[434,131,0.035]],
		[0.23,0.20,0.15,0.09,0.011], BARK.darkened(0.10), true)
	branch(world, [[481,178,1.30],[468,190,0.67],[474,211,0.37],[460,222,0.12],[444,218,0.02]],
		[0.22,0.19,0.13,0.066,0.010], WOOD, true)
	# A second bare silhouette brackets the western ruins.
	branch(world, [[104,171,0.02],[102,156,0.91],[88,132,1.58],[85,108,2.30],[66,85,2.96],[57,63,3.87]],
		[0.41,0.35,0.28,0.19,0.13,0.031], BARK.darkened(0.19), true)
	branch(world, [[88,132,1.56],[118,106,1.81],[126,89,2.52],[154,77,2.82],[176,60,3.30]],
		[0.22,0.16,0.09,0.05,0.01], BARK.darkened(0.16), false)
	branch(world, [[85,108,2.23],[56,108,2.48],[48,91,2.86],[19,70,3.12]],
		[0.19,0.12,0.06,0.01], BARK.darkened(0.17), false)
	branch(world, [[105,159,0.65],[127,166,0.38],[134,196,0.18],[151,209,0.02]],
		[0.21,0.17,0.12,0.012], BARK.darkened(0.19), true)

static func branch(world, points: Array, radii: Array, tint: Color, grain: bool) -> void:
	var path := PackedVector3Array()
	for data in points:
		path.append(world.at(data[0], data[1], data[2]))
	world.mesh.smooth_tube(path, PackedFloat32Array(radii), tint, 10, 0.088, grain)

static func build_groundwork(world) -> void:
	# Broken flagstones indicate the courtyard floor without covering paths or supplies.
	for row in range(8):
		for column in range(11):
			var at := Vector2(304.0 + column * 15.1 + (row % 2) * 4.4, 179.0 + row * 15.4)
			var distance := at.distance_to(Vector2(394, 229))
			if distance < 25.0 or distance > 116.0 or world.random.randf() < 0.49:
				continue
			world.stone(at.x, at.y, 8.0 + column % 3, 6.5 + row % 3, 0.048, BANK.lightened(column % 4 * 0.046), -0.30)
	for index in range(18):
		var at := Vector2(world.random.randf_range(9, 755), world.random.randf_range(85, 471))
		var distance := at.distance_to(Vector2(397, 228))
		if distance < 128.0:
			continue
		if index % 2 == 0:
			reeds(world, at, index * 1.91)
		else:
			world.stone(at.x, at.y, 7.0 + index % 3 * 2.0, 5.0, 0.15, MORTAR.lightened((index % 3) * 0.09), index * 0.18)

static func masonry_scrub(world, center: Vector2) -> void:
	for i in range(6):
		var at := center + Vector2.from_angle(i * 2.399 + center.y * 0.007) * (4.0 + i * 2.8)
		if i % 2 == 0:
			reeds(world, at, center.x * 1.39 + i * 0.49)
		else:
			world.stone(at.x, at.y, 6.0 + i % 3 * 2.0, 5.6, 0.14 + i * 0.022, BANK.lightened(i * 0.026), i * 1.203)

static func reeds(world, at: Vector2, phase: float) -> void:
	var root: Vector3 = world.at(at.x, at.y, 0.025)
	for i in range(5):
		var angle := phase + i * 2.399
		var lean := Vector2.from_angle(angle) * (4.0 + 1.7 * i)
		var height := 0.08 + 0.046 * (i + 2)
		var a: Vector3 = world.at(at.x + lean.x * 0.48, at.y + lean.y * 0.48, height * 0.8)
		var b: Vector3 = world.at(at.x + lean.x, at.y + lean.y, height)
		world.mesh.tube(PackedVector3Array([root, a, b]), PackedFloat32Array([0.015, 0.010, 0.002]),
			LEAF.lightened((i % 3) * 0.072), 5, 0.05)
