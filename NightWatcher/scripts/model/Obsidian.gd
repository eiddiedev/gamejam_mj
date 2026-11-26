extends RefCounted

const Relic = preload("res://scripts/model/ObsidianRelic.gd")
const STONE := Color("#535866")
const DARK := Color("#454655")
const SNOW := Color("#aab8c4")
const FROST := Color("#7f92a4")
const ICED := Color("#72798c")

static func build(world) -> void:
	for index in range(18):
		var at := Vector2(index*44.0-15, 25.0+sin(index*0.72)*32.0)
		var height: float = world.random.randf_range(1.7, 3.5)
		world.ellipsoid(world.from_floor(at,height*0.46),
			Vector3(world.random.randf_range(0.92,1.59),height,world.random.randf_range(0.90,1.57)),
			world.weathered(DARK,0.088), 7,5)
		world.ellipsoid(world.from_floor(at+Vector2(-7,5),height*1.09),Vector3(0.57,height*0.41,0.51),
			world.weathered(FROST,0.046),7,5)
	for index in range(12):
		var y := index*45.0 + 35
		var x: float = 757 - sin(index*0.8)*23.0
		var height: float = world.random.randf_range(0.75,2.19)
		world.ellipsoid(world.at(x,y,height*0.27),Vector3(0.67,height,1.0),
			world.weathered(STONE,0.09),7,6)
		world.stone(x,y+5,25,26,0.08,world.weathered(SNOW,0.08),0.2,height*1.06)
	wall_walk(world)
	Relic.build(world)
	for index in range(37):
		var at := Vector2(world.random.randf_range(33,696),world.random.randf_range(83,463))
		if world.route_distance(at) < 15.0 or world.slot_distance(at) < 18.0:
			continue
		var width: float = world.random.randf_range(10,31)
		world.ring_patch(at,Vector2(width,width*0.63),0.024,world.weathered(SNOW,0.08),9)
		if index%3==0:
			world.ellipsoid(world.from_floor(at,0.10),Vector3(0.39,0.31,0.35),
				world.weathered(ICED,0.10),7,5)

static func wall_walk(world) -> void:
	var wall := PackedVector2Array([Vector2(233,119),Vector2(286,146),Vector2(338,176),Vector2(395,213),Vector2(454,241)])
	world.sculpture("黑曜长墙 · 山口防线", func(): siege_curtain(world, wall))
	world.wall([Vector2(377,302),Vector2(411,325),Vector2(440,334)],1.24,STONE,24.0)
	world.wall([Vector2(475,317),Vector2(517,325),Vector2(570,299),Vector2(602,288)],1.80,STONE,29.0)
	world.wall([Vector2(673,227),Vector2(711,247),Vector2(727,271)],1.59,STONE,25.0)
	world.wall([Vector2(513,139),Vector2(546,160),Vector2(588,157),Vector2(601,152)],1.40,ICED,23.0)
	world.arch(Vector2(460,270),37.0,2.15,ICED,0.34)
	world.arch(Vector2(615,146),22.0,1.86,ICED,-0.53)
	turret(world,Vector2(458,227),2.61)
	turret(world,Vector2(574,138),2.95)
	world.steps(Vector2(714,93),Vector2(675,155),28.0,0.52,10,ICED)
	world.steps(Vector2(655,306),Vector2(630,250),34.0,0.25,8,ICED)
	gate_flagstones(world)

static func siege_curtain(world, spine: PackedVector2Array) -> void:
	var heights := PackedFloat32Array([0.0, 0.24, 1.94, 2.07, 2.27, 2.37])
	var widths := PackedFloat32Array([15.5, 15.4, 12.6, 13.5, 13.0, 12.0])
	var color_bands := [Color("#3c444f"), Color("#575e68"), Color("#404651"),
		Color("#646976"), Color("#757e89")]
	var end_height := PackedFloat32Array([2.39, 2.24, 2.31, 2.18, 2.33])
	var merlon_height := PackedFloat32Array([0.275, 0.092, 0.291, 0.212])
	var normals := PackedVector2Array()
	for index in range(spine.size()):
		var before := spine[maxi(index - 1, 0)]
		var after := spine[mini(index + 1, spine.size() - 1)]
		normals.append(before.direction_to(after).orthogonal())
	for index in range(spine.size() - 1):
		var start := spine[index]
		var finish := spine[index + 1]
		var normal_a := normals[index]
		var normal_b := normals[index + 1]
		var height_a := end_height[index] - heights[-1]
		var height_b := end_height[index + 1] - heights[-1]
		for side: float in [-1.0, 1.0]:
			for tier in range(heights.size() - 1):
				var a := start + normal_a * widths[tier] * side
				var b := finish + normal_b * widths[tier] * side
				var c := finish + normal_b * widths[tier + 1] * side
				var d := start + normal_a * widths[tier + 1] * side
				var lower := heights[tier]
				var upper := heights[tier + 1]
				var panel := PackedVector3Array([world.from_floor(a, lower + height_a * lower / heights[-1]),
					world.from_floor(b, lower + height_b * lower / heights[-1]),
					world.from_floor(c, upper + height_b * upper / heights[-1]),
					world.from_floor(d, upper + height_a * upper / heights[-1])])
				var outward: Vector3 = world.from_floor(a) - world.from_floor(start)
				var tint: Color = color_bands[tier]
				if side < 0.0:
					tint = tint.darkened(0.10)
				tint = Color(tint.lerp(ICED, fposmod(index * 0.147, 0.16)), 0.79)
				var normal := wall_panel(world, panel, outward, tint)
				if tier == 1:
					wall_mortar(world, panel, normal, index, side)
		var deck := PackedVector3Array([world.from_floor(start - normal_a * 12.0, end_height[index]),
			world.from_floor(start + normal_a * 12.0, end_height[index]),
			world.from_floor(finish + normal_b * 12.0, end_height[index + 1]),
			world.from_floor(finish - normal_b * 12.0, end_height[index + 1])])
		wall_panel(world, deck, Vector3.UP, Color("#69707bca"))
		var yaw: float = (world.from_floor(finish) - world.from_floor(start)).signed_angle_to(Vector3.RIGHT, Vector3.UP)
		for index_in_span in range(3):
			var along := (index_in_span + 0.30) / 3.0
			var crenel := start.lerp(finish, along) + normal_a.lerp(normal_b, along) * 8.5
			var base := lerpf(end_height[index], end_height[index + 1], along)
			var chip := (index * 3 + index_in_span) % 4
			world.stone(crenel.x, crenel.y, 10.3 + chip % 2 * 2.0, 7.8, merlon_height[chip], ICED.darkened(0.13), yaw, base - 0.036)
			if chip == 2:
				world.stone(crenel.x, crenel.y - 1.2, 5.8, 4.4, 0.047, SNOW.darkened(0.12), yaw, base + merlon_height[chip] - 0.060)
		for factor: float in [0.16, 0.66]:
			if index == spine.size() - 2 and factor > 0.60:
				continue
			wall_buttress(world, start.lerp(finish, factor), start.direction_to(finish), -normal_a.lerp(normal_b, factor),
				1.94 + lerpf(height_a, height_b, factor))
	for end: int in [0, spine.size() - 1]:
		var point := spine[end]
		var outward: Vector3 = world.from_floor(point) - world.from_floor(spine[1 if end == 0 else end - 1])
		var half := normals[end]
		wall_panel(world, PackedVector3Array([world.from_floor(point - half * 15.5), world.from_floor(point + half * 15.5),
			world.from_floor(point + half * 12.0, end_height[end]), world.from_floor(point - half * 12.0, end_height[end])]),
			outward, Color("#505663ca"))

static func wall_panel(world, panel: PackedVector3Array, outward: Vector3, tint: Color) -> Vector3:
	var normal := (panel[1] - panel[0]).cross(panel[3] - panel[0]).normalized()
	if normal.dot(outward) < 0.0:
		normal = -normal
	world.mesh.triangle(panel[0], panel[1], panel[2], tint, normal)
	world.mesh.triangle(panel[0], panel[2], panel[3], tint, normal)
	return normal

static func wall_buttress(world, center: Vector2, along: Vector2, out: Vector2, height: float) -> void:
	var lower := center + out * 17.1
	var higher := center + out * 14.1
	var outward: Vector3 = world.from_floor(lower) - world.from_floor(center)
	var shell := PackedVector3Array([world.from_floor(lower - along * 6.0), world.from_floor(lower + along * 6.0),
		world.from_floor(higher + along * 3.8, height), world.from_floor(higher - along * 3.8, height)])
	wall_panel(world, shell, outward, Color("#757c87ca"))
	for edge: int in [0, 1]:
		var lower_in := lower - out * 5.2 + along * (edge * 2 - 1) * 6.0
		var higher_in := higher - out * 3.1 + along * (edge * 2 - 1) * 3.8
		wall_panel(world, PackedVector3Array([shell[edge], world.from_floor(lower_in),
			world.from_floor(higher_in, height), shell[3 - edge]]),
			Vector3(along.x, 0.0, along.y) * (edge * 2 - 1), Color("#434957ca"))

static func wall_mortar(world, panel: PackedVector3Array, normal: Vector3, phase: int, side: float) -> void:
	var ink := Color("#292d36c9")
	for corner in range(4):
		panel[corner] += normal * 0.012
	for course in range(3):
		var level := 0.23 + course * 0.25
		var drift := sin(phase * 1.43 + course * 1.73 + side) * 0.020
		world.contour.panel_stroke(panel, PackedVector2Array([Vector2(0.02, level), Vector2(0.31, level + drift),
			Vector2(0.58, level - drift * 0.17), Vector2(0.88, level + drift * 0.67), Vector2(0.98, level)]),
			0.025 if course == 0 else 0.020, ink, normal, false, false)
		for seam in range(2):
			var site := 0.16 + seam * 0.47 + fposmod(course * 0.18 + phase * 0.093, 0.18)
			world.contour.panel_stroke(panel, PackedVector2Array([Vector2(site, level),
				Vector2(site + 0.018, level + 0.08), Vector2(site - 0.015, level + 0.23)]), 0.017, ink, normal)

static func gate_flagstones(world) -> void:
	# Half-buried slate helps the hearth catch the last part of the gate approach.
	for data in [[492.0,258.0,10.1,6.8],[504.0,247.0,12.4,8.5],[511.0,242.0,10.3,6.2],
			[521.0,232.0,11.6,8.1],[534.0,221.0,12.3,7.4],[545.0,215.0,11.0,8.1]]:
		world.stone(data[0], data[1], data[2], data[3], 0.035, ICED, 0.47, 0.018)

static func turret(world, at: Vector2, height: float) -> void:
	for row in range(8):
		var y := height*row/8.0
		world.stone(at.x,at.y,27.5,28.2,height/8.0,world.weathered(STONE,0.047),0.09,y)
	world.stone(at.x,at.y,33.0,34,0.18,ICED,0.09,height)
	for dx in [-12,12]:
		for dy in [-12,12]:
			world.stone(at.x+dx,at.y+dy,7,7,0.36,STONE,0.09,height+0.16)
