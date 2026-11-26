extends RefCounted

const Detail = preload("res://scripts/model/ReliefDetail.gd")
const Ink = preload("res://world/mesh_builder.gd")
const CURRENT = preload("res://scripts/model/root_keep_water.gdshader")
const STONE := Color("#727e70")
const CAP := Color("#919784")
const MORTAR := Color("#4b594f")
const WATER := Color("#446c70")
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
		[538,235],[545,274],[526,306],[477,340],[432,354],[358,352],[307,332],[256,315],[228,277],[223,238]], Color("#777862"))
	sward(world, [[264,197],[317,181],[368,172],[449,176],[502,184],[519,207],[509,250],
		[479,289],[442,318],[371,324],[320,311],[275,288],[253,247]], Color("#827f66"), 0.009)
	sward(world, [[-8,116],[52,106],[104,116],[137,155],[156,204],[146,242],[117,260],[154,304],
		[177,341],[145,365],[121,326],[77,295],[42,280],[-8,272]], Color("#72745b"))
	sward(world, [[638,199],[661,202],[681,230],[686,274],[699,309],[744,324],[780,356],
		[769,387],[724,375],[681,363],[645,336],[628,301],[633,260],[621,234]], Color("#657463"))
	sward(world, [[596,362],[647,346],[710,352],[756,384],[766,447],[720,474],[665,487],[614,463],[592,423]], Color("#77755b"), 0.007)
	sward(world, [[104,406],[150,382],[196,389],[235,408],[284,410],[333,434],[365,461],[341,488],
		[283,491],[216,478],[157,486],[104,463]], Color("#737258"))

static func sward(world, raw: Array, tint: Color, height := 0.004) -> void:
	var edge := PackedVector2Array()
	for p in raw:
		edge.append(Vector2(p[0], p[1]))
	var shape: Array[Vector2] = []
	for index in range(edge.size()):
		var a := edge[index]
		var b := edge[(index + 1) % edge.size()]
		shape.append(a.lerp(b, 0.16))
		shape.append(a.lerp(b, 0.84))
	world.patch(shape, height, Color(tint, 0.29))

static func build_moats(world) -> void:
	var current := Ink.new()
	for index in range(world.layout.water.size()):
		var shoreline := PackedVector2Array()
		for p in world.layout.water[index]:
			shoreline.append(Vector2(p[0], p[1]))
		var bed := Geometry2D.triangulate_polygon(shoreline)
		for triangle in range(0, bed.size(), 3):
			current.triangle(world.from_floor(shoreline[bed[triangle]], 0.021),
				world.from_floor(shoreline[bed[triangle + 2]], 0.021),
				world.from_floor(shoreline[bed[triangle + 1]], 0.021), WATER, Vector3.UP)
		var outward_normals := PackedVector2Array()
		var winding := -1.0 if Geometry2D.is_polygon_clockwise(shoreline) else 1.0
		for corner in range(shoreline.size()):
			var pick := shoreline[corner]
			var incoming := shoreline[posmod(corner - 1, shoreline.size())].direction_to(pick)
			var outgoing := pick.direction_to(shoreline[(corner + 1) % shoreline.size()])
			var tangent := (incoming + outgoing).normalized()
			var outside := Vector2(tangent.y, -tangent.x) * winding
			outward_normals.append(outside)
		for edge in range(shoreline.size()):
			var next := (edge + 1) % shoreline.size()
			var a := shoreline[edge]
			var b := shoreline[next]
			build_bank(world, a, b, outward_normals[edge], outward_normals[next], index * 7 + edge)
	var surface := MeshInstance3D.new()
	surface.name = "墨洗水湾"
	surface.mesh = current.build()
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := ShaderMaterial.new()
	paint.shader = CURRENT
	paint.set_shader_parameter("still_water", WATER)
	surface.material_override = paint
	world.canal_paint = paint
	world.add_child(surface)
	# The moving decks are created by the level, between these abutments.
	abutments(world, Vector2(237, 303), -0.69)
	abutments(world, Vector2(532, 331), 0.87)
	# Abandoned fishing platform at the southerly bend.
	dock(world, Vector2(634, 413), 0.28)

static func build_bank(world, a: Vector2, b: Vector2, left: Vector2, right: Vector2, seed: int) -> void:
	var length := a.distance_to(b)
	var count := maxi(1, ceili(length / 13.0))
	for index in range(count):
		var start := float(index) / count
		var end := float(index + 1) / count
		var near := a.lerp(b, start)
		var far := a.lerp(b, end)
		var outward := left.lerp(right, start)
		var next_outward := left.lerp(right, end)
		var lip := near + outward * (4.2 + sin(start * 5.1 + seed) * 1.6)
		var next_lip := far + next_outward * (4.2 + sin(end * 5.1 + seed) * 1.6)
		var turf := BANK.lerp(Color("#8b7659"), 0.28 + 0.13 * cos(seed))
		world.mesh.quad(world.from_floor(near, 0.025), world.from_floor(lip, 0.14),
			world.from_floor(next_lip, 0.14), world.from_floor(far, 0.025), Color(turf, 0.78))
		if (index + seed) % 4 == 1:
			var at := near.lerp(far, 0.52) + outward * 2.9
			var height := 0.14 if world.route_distance(at) < 14.0 else 0.20
			world.stone(at.x, at.y, 8.9, 6.8, height, turf.darkened(0.12), (b - a).angle())
			if (index + seed) % 8 == 1:
				reeds(world, at + outward * 4.6, seed * 0.56 + index)
		if (index + seed) % 3 != 1:
			var water_edge := PackedVector3Array()
			for ink_step in range(4):
				var t := float(ink_step) / 3.0
				var foam := near.lerp(far, 0.08 + t * 0.84)
				foam -= outward.lerp(next_outward, t) * (1.7 + sin(t * PI) * 0.78)
				water_edge.append(world.from_floor(foam, 0.033))
			world.pencil(water_edge, 0.019, Color("#91b3a8"))

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
	# Continuous battered masonry follows the old ring between the two bridge spans.
	var lay_wall := func(points: PackedVector2Array, heights: PackedFloat32Array, thickness: float) -> void:
		var foot := PackedVector2Array()
		for index in points.size():
			var before := points[maxi(index - 1, 0)]
			var after := points[mini(index + 1, points.size() - 1)]
			foot.append(before.direction_to(after).orthogonal())
		var tiers := PackedFloat32Array([0.0, 0.22, 0.77, 1.0])
		var shoulders := PackedFloat32Array([1.0, 1.0, 0.79, 0.74])
		var washes := [MORTAR.darkened(0.05), STONE, STONE.lerp(CAP, 0.34)]
		for index in range(points.size() - 1):
			var left := points[index]
			var right := points[index + 1]
			for tier in range(tiers.size() - 1):
				for side: float in [-1.0, 1.0]:
					var a := left + foot[index] * thickness * shoulders[tier] * side * 0.5
					var b := right + foot[index + 1] * thickness * shoulders[tier] * side * 0.5
					var c := right + foot[index + 1] * thickness * shoulders[tier + 1] * side * 0.5
					var d := left + foot[index] * thickness * shoulders[tier + 1] * side * 0.5
					var panel := PackedVector3Array([world.from_floor(a, tiers[tier] * heights[index]),
						world.from_floor(b, tiers[tier] * heights[index + 1]), world.from_floor(c, tiers[tier + 1] * heights[index + 1]),
						world.from_floor(d, tiers[tier + 1] * heights[index])])
					var normal := (panel[1] - panel[0]).cross(panel[3] - panel[0]).normalized()
					var outward: Vector3 = world.from_floor(a) - world.from_floor(left)
					if normal.dot(outward) < 0.0:
						normal = -normal
					var tint := Color(washes[tier].lightened(sin(index * 2.03 + side) * 0.045), 0.78)
					world.mesh.triangle(panel[0], panel[1], panel[2], tint, normal)
					world.mesh.triangle(panel[0], panel[2], panel[3], tint, normal)
					if heights[index] < 0.52 or (tier == 2 and index % 3 == 1):
						continue
					var ink := tint.darkened(0.45)
					for corner in panel.size():
						panel[corner] += normal * 0.029
					world.contour.panel_stroke(panel, PackedVector2Array([Vector2(0.0, 0.55), Vector2(0.24, 0.58),
						Vector2(0.59, 0.51), Vector2(0.83, 0.58), Vector2(1.0, 0.55)]), 0.037, ink, normal, false, false)
					if tier != 1:
						continue
					var seam := 0.31 + fposmod(index * 0.37, 0.45)
					world.contour.panel_stroke(panel, PackedVector2Array([Vector2(seam, 0.0), Vector2(seam - 0.035, 0.26),
						Vector2(seam + 0.028, 0.55)]), 0.020, ink, normal)
					world.contour.panel_stroke(panel, PackedVector2Array([Vector2(1.02 - seam, 0.55),
						Vector2(0.99 - seam, 0.83), Vector2(1.0 - seam, 1.0)]), 0.018, ink, normal)
			var cap_left := foot[index] * thickness * shoulders[-1] * 0.5
			var cap_right := foot[index + 1] * thickness * shoulders[-1] * 0.5
			world.mesh.quad(world.from_floor(left - cap_left, heights[index]), world.from_floor(left + cap_left, heights[index]),
				world.from_floor(right + cap_right, heights[index + 1]), world.from_floor(right - cap_right, heights[index + 1]), CAP.darkened(0.10))
			if index % 3 != 1 and heights[index] > 0.67:
				var crown := left.lerp(right, 0.36)
				var yaw: float = (world.from_floor(right) - world.from_floor(left)).signed_angle_to(Vector3.RIGHT, Vector3.UP)
				world.stone(crown.x, crown.y, minf(14.0 + index % 3, left.distance_to(right) * 0.64), thickness * 0.80,
					0.15 + 0.12 * (index % 3), CAP, yaw, lerpf(heights[index], heights[index + 1], 0.36) - 0.065)
		for end: int in [0, points.size() - 1]:
			var at := points[end]
			var low := foot[end] * thickness * 0.5
			var top := low * shoulders[-1]
			world.mesh.quad(world.from_floor(at - low), world.from_floor(at + low),
				world.from_floor(at + top, heights[end]), world.from_floor(at - top, heights[end]), MORTAR)
	lay_wall.call(PackedVector2Array([Vector2(219,199), Vector2(223,169), Vector2(236,143), Vector2(264,121),
		Vector2(300,117), Vector2(332,118), Vector2(366,121), Vector2(396,124)]),
		PackedFloat32Array([0.78,1.40,1.51,1.53,1.38,1.10,0.91,0.53]), 17.5)
	lay_wall.call(PackedVector2Array([Vector2(451,130), Vector2(478,120), Vector2(511,120), Vector2(541,138), Vector2(550,171)]),
		PackedFloat32Array([0.87,1.32,1.58,1.54,0.72]), 18.0)
	lay_wall.call(PackedVector2Array([Vector2(302,321), Vector2(319,331), Vector2(339,337), Vector2(358,341), Vector2(378,343),
		Vector2(398,341), Vector2(416,336), Vector2(436,330), Vector2(454,322)]),
		PackedFloat32Array([0.76,1.28,1.35,1.34,0.98,1.19,1.41,1.25,0.63]), 18.0)
	tower(world, Vector2(267, 147), 41.0, 38.0, 2.94, -0.25)
	tower(world, Vector2(495, 119), 29.0, 29.0, 2.15, 0.28)
	# The entrances face the bridge approaches so the lane crosses their open
	# centers, instead of running along the arch and into its pillars.
	world.arch(Vector2(249, 290), 34.0, 2.72, STONE, 0.81)
	world.arch(Vector2(511, 296), 37.0, 2.76, STONE, -0.46)
	for door in [[249.0, 290.0, 0.81, 2.76], [511.0, 296.0, -0.46, 2.80]]:
		# Cap only the top of the ring. The arch stones still define its clearance.
		world.stone(door[0], door[1], 37.0, 13.0, 0.10, CAP.darkened(0.08), door[2], door[3] + 0.17)
		world.stone(door[0] - 4.0, door[1] - 1.0, 9.0, 11.0, 0.20, STONE, door[2], door[3] + 0.25)
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
	Detail.vine(world, [[267,166,2.71],[261,168,2.42],[262,169,2.02],[269,171,1.52],[268,172,0.81],[265,174,0.08]],0.018,stem,leaf,0.2)
	Detail.vine(world, [[226,177,1.34],[229,185,1.04],[227,192,0.78],[231,200,0.48],[237,209,0.05]],0.018,stem,leaf,2.6)
	Detail.vine(world, [[345,343,1.31],[350,347,0.98],[346,349,0.78],[346,351,0.45],[340,353,0.07]],0.023,stem,leaf,4.6)
	Detail.vine(world, [[429,339,1.25],[421,342,0.96],[426,344,0.57],[424,346,0.12]],0.018,stem,leaf,5.2)
	# A few laid stones remain at the inner wall and tower footing. Keep the
	# bridges and their lever banks open, with rubble concentrated off their lanes.
	for flags in [[327,313,10.5,-0.28], [343,318,12.5,0.22], [354,322,8.7,0.13],
			[402,320,10.2,-0.18], [412,317,9.5,-0.44], [296,178,11.9,-0.18], [289,163,8.0,0.13]]:
		world.stone(flags[0], flags[1], flags[2], 7.2, 0.079, BANK.lightened(0.09), flags[3])
	for location in [[291,229],[311,241],[440,219],[479,240],[567,365],[455,433]]:
		var p := Vector2(location[0], location[1])
		if int(p.x) % 3 == 0:
			Detail.vessel(world, p, 0.0, 0.135, Color("#8a705a"))
		else:
			Detail.plank(world, p, 11.0, p.x * 0.041, 0.016, WOOD.darkened(0.13))

static func tower(world, center: Vector2, width: float, depth: float, height: float, yaw: float) -> void:
	# A darker plinth and a pair of horizontal stone belts give the angle tower
	# a single mass. The top is low enough for the existing mounted deck.
	world.stone(center.x, center.y, width, depth, 0.26, MORTAR.darkened(0.10), yaw)
	world.stone(center.x, center.y, width * 0.94, depth * 0.93, height - 0.37, Color(STONE, 0.78), yaw, 0.25)
	world.stone(center.x, center.y, width * 0.99, depth * 0.99, 0.11, CAP.darkened(0.17), yaw, height - 0.14)
	var rim: Array[Vector2] = []
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var at := center + Vector2(corner.x * width, corner.y * depth).rotated(yaw) * 0.45
		rim.append(at)
	world.patch(rim, height - 0.03, MORTAR)
	for i in range(rim.size()):
		var a := rim[i]
		var b := rim[(i + 1) % rim.size()]
		var angle := (b - a).angle()
		var ridge := a.lerp(b, 0.5)
		world.stone(ridge.x, ridge.y, a.distance_to(b) * 1.04, 5.7, 0.12, STONE.darkened(0.08), angle, height - 0.02)
		for position: float in [0.09, 0.53, 0.82]:
			if (i == 2 and position > 0.75) or (height < 2.5 and i == 1 and position > 0.50):
				continue
			var at := a.lerp(b, position)
			world.stone(at.x, at.y, 7.2, 7.4, 0.29 if position > 0.4 else 0.40, CAP, angle, height + 0.075)
	# One surviving arrow slit is inked under a fractured lintel facing the yard.
	var facing := center + Vector2(0, depth * 0.515).rotated(yaw)
	var sill: Vector3 = world.from_floor(facing, height * 0.42)
	var across := Vector3(cos(yaw), 0.0, sin(yaw)) * 0.068
	var lintel := Vector3.UP * 0.49
	world.contour.quad(sill - across, sill + across, sill + lintel + across * 0.68,
		sill + lintel - across * 0.68, MORTAR.darkened(0.57))

static func build_rootwork(world) -> void:
	world.sculpture("枯木环堡 · 绞堡古树", func():
		var bark := Color("#665443")
		var lit_bark := Color("#80634c")
		var dark_bark := Color("#524638")
		branch(world, [[536,155,-0.13],[531,153,0.64],[536,145,1.48],[551,134,2.31],
				[559,125,3.08],[574,109,4.18],[592,91,5.17],[614,76,5.97]],
			[0.91,0.85,0.71,0.61,0.55,0.45,0.35,0.19], bark, true, true)
		branch(world, [[553,133,2.50],[531,129,2.99],[511,123,3.29],[492,116,3.51],
				[480,105,3.85],[458,101,4.10],[449,88,4.16]],
			[0.40,0.32,0.26,0.18,0.111,0.067,0.013], bark, true, true)
		branch(world, [[508,121,3.31],[494,126,3.65],[477,134,3.85],[454,131,4.01],[436,113,4.10]],
			[0.159,0.12,0.088,0.047,0.011], dark_bark, false, true)
		branch(world, [[533,129,2.98],[525,113,3.34],[509,98,3.54],[509,86,3.78]],
			[0.17,0.12,0.074,0.014], dark_bark, false, true)
		branch(world, [[570,113,4.02],[586,117,4.51],[608,112,4.83],[629,99,5.20],[648,78,5.51]],
			[0.33,0.29,0.22,0.14,0.018], bark, true, true)
		branch(world, [[614,110,4.94],[633,122,4.95],[654,125,5.06],[680,112,5.32]],
			[0.14,0.10,0.061,0.011], dark_bark, false, true)
		branch(world, [[557,125,3.17],[572,139,3.52],[592,149,3.70],[617,151,3.81],
				[634,145,4.03],[653,156,4.08],[678,148,4.29]],
			[0.29,0.26,0.20,0.155,0.104,0.058,0.011], bark, true, true)
		branch(world, [[615,151,3.83],[631,167,3.91],[642,171,4.11],[654,182,4.19]],
			[0.114,0.091,0.052,0.010], dark_bark, false, true)

		# The broad rear root crests the surviving east curtain, then drops into the yard.
		branch(world, [[539,143,1.46],[528,137,1.54],[520,124,1.69],[505,119,1.72],
				[485,123,1.54],[473,134,1.18],[466,151,0.84],[447,172,0.61],
				[425,184,0.54],[414,197,0.15],[400,199,-0.05]],
			[0.53,0.48,0.42,0.36,0.309,0.25,0.23,0.18,0.122,0.065,0.016], lit_bark, true, true)
		branch(world, [[467,154,0.82],[454,158,0.87],[441,156,1.08],[429,163,0.86],
				[423,174,0.33],[408,179,-0.02]],
			[0.17,0.155,0.12,0.101,0.060,0.013], dark_bark, true, true)
		branch(world, [[498,122,1.66],[493,138,1.49],[482,150,1.18],[477,167,1.23],
				[481,178,1.19],[481,192,0.94]],
			[0.26,0.225,0.194,0.187,0.185,0.092], bark, true, true)
		branch(world, [[534,151,1.08],[537,168,0.96],[521,182,0.80],[507,201,0.67],
				[502,222,0.42],[489,234,0.17],[479,238,-0.05]],
			[0.56,0.46,0.36,0.32,0.236,0.127,0.018], bark, true, true)
		branch(world, [[519,184,0.77],[504,182,0.59],[487,191,0.34],[477,199,0.08],
				[459,205,-0.04]], [0.20,0.17,0.13,0.073,0.011], dark_bark, true, true)
		branch(world, [[542,151,0.90],[550,171,0.93],[555,189,1.03],[558,212,1.05],
				[551,230,0.89],[559,244,0.56],[575,256,0.21],[582,274,-0.045]],
			[0.44,0.39,0.32,0.26,0.215,0.143,0.068,0.014], bark, true, true)
		branch(world, [[550,167,0.88],[567,177,0.55],[580,190,0.34],[596,198,0.19],
				[608,211,-0.035]], [0.25,0.22,0.16,0.081,0.010], dark_bark, true, true)

		# A buried continuation emerges under the lower parapet, away from both bridges.
		branch(world, [[454,307,-0.075],[449,314,0.36],[443,320,0.76],[434,328,1.21],
				[427,333,1.50],[418,336,1.47],[412,341,0.99],[411,346,0.22],[406,351,-0.05]],
			[0.15,0.20,0.19,0.19,0.16,0.137,0.10,0.058,0.012], dark_bark, true, true)
		branch(world, [[418,336,1.40],[423,342,1.06],[424,346,0.60],[432,350,0.15],
				[437,352,-0.04]], [0.086,0.078,0.053,0.031,0.009], bark, true, true)

		# Leaner branches on the west bank stay subordinate to the old tree.
		branch(world, [[104,171,-0.10],[102,155,0.81],[93,139,1.52],[85,112,2.23],
				[71,89,2.96],[56,64,3.80]], [0.44,0.36,0.28,0.23,0.133,0.033], dark_bark, true, true)
		branch(world, [[91,136,1.65],[112,115,1.84],[126,96,2.31],[149,81,2.66],
				[170,63,3.08]], [0.22,0.18,0.131,0.066,0.012], dark_bark, false, true)
		branch(world, [[85,113,2.21],[60,110,2.39],[47,92,2.73],[21,73,2.94]],
			[0.188,0.12,0.069,0.012], dark_bark, false, true)
		branch(world, [[106,159,0.61],[122,165,0.44],[131,183,0.27],[137,201,0.15],
				[149,209,-0.03]], [0.23,0.18,0.133,0.064,0.012], dark_bark, true, true)
	)

static func branch(world, points: Array, radii: Array, tint: Color, grain: bool, carved := false) -> void:
	var path := PackedVector3Array()
	for data in points:
		path.append(world.at(data[0], data[1], data[2]))
	if not carved:
		world.mesh.smooth_tube(path, PackedFloat32Array(radii), tint, 10, 0.088, grain)
		return
	var shape := PackedVector3Array()
	var widths := PackedFloat32Array()
	for index in range(path.size() - 1):
		var before := path[maxi(0, index - 1)]
		var after := path[mini(path.size() - 1, index + 2)]
		for sample in range(3):
			var fraction := sample / 3.0
			shape.append(path[index].cubic_interpolate(path[index + 1], before, after, fraction))
			widths.append(lerpf(radii[index], radii[index + 1], fraction))
	shape.append(path[-1])
	widths.append(radii[-1])
	var previous := PackedVector3Array()
	var phase := path[0].x * 1.43 + path[0].z * 0.69
	for index in range(shape.size()):
		var travel := shape[maxi(0, index - 1)].direction_to(shape[mini(index + 1, shape.size() - 1)])
		var flank := travel.cross(Vector3.BACK).normalized()
		if flank.length_squared() < 0.3:
			flank = travel.cross(Vector3.RIGHT).normalized()
		var crest := flank.cross(travel)
		var turning := index * 0.13 + phase * 0.17
		var ring := PackedVector3Array()
		for edge in range(9):
			var bearing := edge * TAU / 9.0 + turning
			var lobe := 0.98 + sin(bearing * 3.0 - turning * 0.61) * 0.115
			lobe += sin(edge * 4.37 + index * 0.67 + phase) * 0.054
			var direction := flank * cos(bearing) * 0.92 + crest * sin(bearing) * 0.77
			ring.append(shape[index] + direction * widths[index] * lobe)
		if index > 0:
			for edge in range(9):
				var next := (edge + 1) % 9
				var panel := PackedVector3Array([previous[edge], ring[edge], ring[next], previous[next]])
				var normal := (panel[1] - panel[0]).cross(panel[2] - panel[0]).normalized()
				var plane := sin(edge * 0.70 + turning) * 0.068
				var shadow := (0.17 if edge in [4, 5] else 0.07) + (1.0 - normal.dot(Vector3.BACK)) * 0.035
				var color := tint.darkened(shadow).lightened(maxf(0.0, plane))
				world.mesh.quad(panel[0], panel[1], panel[2], panel[3], color)
				if grain and widths[index] > 0.066 and edge in [1, 3, 7] and (index + edge) % 6 in [1, 2]:
					var drift := sin(phase + edge * 1.67 + index * 0.53) * 0.18
					world.contour.panel_stroke(panel, PackedVector2Array([Vector2(0.08, 0.38 + drift),
						Vector2(0.42, 0.51 + drift), Vector2(0.63, 0.48 + drift), Vector2(0.94, 0.60 + drift)]),
						clampf(widths[index] * 0.12, 0.014, 0.031), Color(color.darkened(0.56), 0.89), normal)
		if index == shape.size() - 1:
			for edge in range(9):
				world.mesh.triangle(shape[index], ring[(edge + 1) % 9], ring[edge], tint.darkened(0.19), travel)
		previous = ring

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
