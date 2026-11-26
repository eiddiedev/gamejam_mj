extends RefCounted

const SOIL := Color("#476457")
const STONE := Color("#65736b")
const RUST := Color("#a45736")
const BARK := Color("#46514e")
const Relief = preload("res://scripts/model/ReliefDetail.gd")
const Cranium = preload("res://assets/props/fallen_king/valley_tripo_cranium.glb")
const Thorax = preload("res://assets/props/fallen_king/valley_tripo_ribs.glb")
const Limbs = preload("res://assets/props/fallen_king/valley_tripo_arm.glb")
# Radius of the cranium at the lower and upper edges of each crown segment.
const CROWN_RADII := [
	Vector2(0.873, 0.758), Vector2(0.848, 0.726), Vector2(0.866, 0.764), Vector2(0.873, 0.779), Vector2(0.881, 0.778),
	Vector2(0.858, 0.774), Vector2(0.881, 0.791), Vector2(0.886, 0.814), Vector2(0.843, 0.801), Vector2(0.868, 0.773),
	Vector2(0.873, 0.764), Vector2(0.896, 0.732), Vector2(0.860, 0.689), Vector2(0.801, 0.648), Vector2(0.768, 0.638),
	Vector2(0.774, 0.644), Vector2(0.795, 0.668), Vector2(0.834, 0.721), Vector2(0.886, 0.756), Vector2(0.912, 0.754),
]

static func build(world) -> void:
	underpaint(world)
	ridge(world)
	ruins(world)
	skeleton(world)
	sword(world)
	old_tree(world)
	camp_hardware(world)
	understory(world)
	for muddy in world.layout["mud"]:
		var patch: Array[Vector2] = []
		for p in muddy:
			patch.append(Vector2(p[0],p[1]))
		world.patch(patch, 0.012, Color("#4e6e61"))
		var center: Vector2 = patch[0].lerp(patch[3], 0.5)
		world.ring_patch(center, Vector2(23,9), 0.024, Color("#63887a"), 11)
		world.ring_patch(center + Vector2(11,2), Vector2(11,4), 0.026, Color("#8ca696"), 9)

static func underpaint(world) -> void:
	var banks := [
		[Vector2(109, 165), Vector2(97, 63), -0.39, Color("#536e68")],
		[Vector2(76, 348), Vector2(61, 47), 0.44, Color("#415c55")],
		[Vector2(203, 409), Vector2(88, 37), 0.29, Color("#5e7763")],
		[Vector2(314, 220), Vector2(66, 34), -0.73, Color("#55725d")],
		[Vector2(373, 411), Vector2(57, 37), -0.17, Color("#476a5e")],
		[Vector2(550, 306), Vector2(136, 86), -0.73, Color("#435d53")],
		[Vector2(586, 155), Vector2(70, 48), 0.68, Color("#3e5953")],
		[Vector2(692, 258), Vector2(71, 69), -0.42, Color("#587565")],
		[Vector2(629, 430), Vector2(99, 37), 0.31, Color("#4e695d")],
	]
	for id in range(banks.size()):
		var bank: Array = banks[id]
		var center: Vector2 = bank[0]
		var extent: Vector2 = bank[1]
		var angle: float = bank[2]
		var ink: Color = bank[3]
		var edge: Array[Vector2] = []
		var inner: Array[Vector2] = []
		for index in range(32):
			var t := TAU * index / 32.0
			var shape := 1.0 + sin(t * 3.0 + id * 0.56) * 0.16 + cos(t * 7.0 - id) * 0.09
			shape += sin(t * 13.0 + id * 0.39) * 0.043
			var offset := (extent * Vector2.from_angle(t) * shape).rotated(angle)
			edge.append(center + offset)
			inner.append(center + Vector2(-8.0, 5.0) + offset * (0.69 + 0.06 * cos(t * 5.0)))
		var soft_edge: Color = world.palette[0].lerp(ink, 0.65)
		world.patch(edge, 0.001 + id * 0.0009, Color(soft_edge, 0.24))
		world.patch(inner, 0.002 + id * 0.0009, Color(ink, 0.25))
		for piece in range(2):
			var start := (id * 17 + piece * 12) % edge.size()
			var marks := PackedVector3Array()
			for index in range(4 + (id + piece) % 3):
				var p := edge[(start + index) % edge.size()].lerp(center, 0.04)
				marks.append(world.from_floor(p, 0.004 + id * 0.0009))
			world.pencil(marks, 0.018, Color(ink.darkened(0.25), 0.74))

static func ridge(world) -> void:
	for index in range(12):
		var center := Vector2(index * 64.0 - 24.0, world.random.randf_range(-3.0,36.0))
		var height: float = world.random.randf_range(0.9,2.8)
		world.ellipsoid(world.from_floor(center,height*0.36),
			Vector3(world.random.randf_range(1.1,2.6),height,world.random.randf_range(0.60,1.90)),
			world.weathered(Color("#4a6663"),0.11), 7,5)
	for index in range(10):
		var y := 40.0 + index * 48.0
		var x: float = 768.0 - world.random.randf_range(-14.0,27.0)
		world.ellipsoid(world.at(x,y,0.38),Vector3(0.72,world.random.randf_range(0.50,1.9),1.28),
			world.weathered(STONE.darkened(0.15),0.10),8,5)
	for at in [Vector2(75,158),Vector2(71,329),Vector2(142,424),Vector2(263,460),Vector2(636,329)]:
		world.ellipsoid(world.from_floor(at,0.02),Vector3(1.21,0.35,1.05),world.weathered(SOIL,0.05),10,5)
	for index in range(29):
		var sprinkle := Vector2(world.random.randf_range(23,732),world.random.randf_range(47,459))
		if world.route_distance(sprinkle) > 22.0 and world.slot_distance(sprinkle) > 18.0:
			world.tuft(sprinkle,world.random.randf_range(0.18,0.51),world.weathered(Color("#779274"),0.10))

static func ruins(world) -> void:
	world.wall([Vector2(19,191),Vector2(60,209),Vector2(91,230),Vector2(101,260),Vector2(91,286)],1.38,STONE,20)
	world.wall([Vector2(68,368),Vector2(123,396),Vector2(161,409),Vector2(196,437),Vector2(229,448)],1.12,STONE,21)
	var arc_start: int = world.mesh.vertices.size()
	world.wall([Vector2(267,419),Vector2(282,406),Vector2(314,408),Vector2(353,426),Vector2(378,428)],0.77,STONE,16)
	for run in [[Vector2(289,399), Vector2(292,399), Vector2(295,400), Vector2(298,400)],
			[Vector2(320,405), Vector2(323,405), Vector2(326,404), Vector2(328,404)]]:
		var samples := PackedVector3Array()
		for point: Vector2 in run:
			samples.append(world.from_floor(point))
		fire_rim(world, arc_start, samples, 0.021, 0.61)
	world.wall([Vector2(95,105),Vector2(136,101),Vector2(168,106),Vector2(187,96)],0.74,STONE,18)
	world.arch(Vector2(184,153),34.0,1.58,STONE,0.21)
	world.arch(Vector2(263,123),30.0,1.34,STONE,-0.27)
	world.steps(Vector2(201,191),Vector2(181,156),26.0,0.19,5,STONE)
	world.steps(Vector2(154,378),Vector2(115,337),28.0,0.67,8,STONE)

static func skeleton(world) -> void:
	var skull_anchor: Vector3 = world.at(586, 135)
	var shoulder: Vector3 = world.at(525, 187)
	place_bone(world, Cranium, "陨王 · 头骨", skull_anchor, Color("#adaa92"))
	world.sculpture("陨王 · 冠饰", func(): crown(world, skull_anchor, 1.0))
	place_bone(world, Thorax, "陨王 · 胸廓", shoulder, Color("#b6ae94"))
	place_bone(world, Limbs, "陨王 · 臂骨与指节", shoulder, Color("#b6ae94"))
	var saddle: Array[Vector2] = [Vector2(478, 194), Vector2(495, 185), Vector2(507, 167), Vector2(532, 148), Vector2(554, 161)]
	var split: Array[Vector2] = [Vector2(512, 400), Vector2(552, 398), Vector2(578, 359), Vector2(619, 328)]
	world.trail(saddle, 7.4, Color("#69776c53"))
	world.trail(split, 9.0, Color("#6b796c53"))

static func place_bone(world, scene: PackedScene, label: String, anchor: Vector3, tint: Color) -> void:
	var bone := scene.instantiate() as Node3D
	bone.name = label
	bone.position = anchor
	world.add_child(bone)
	world.paint_textured_prop(bone, tint)
	var meshes := bone.find_children("*", "MeshInstance3D", true, false)
	if bone is MeshInstance3D:
		meshes.append(bone)
	for part: MeshInstance3D in meshes:
		part.set_meta(&"walk_obstacle", true)

static func crown(world, anchor: Vector3, s: float) -> void:
	var copper := Color("#817052")
	var patina := Color("#4e6555")
	var trim := Color("#ad8a54")
	var washes: Array[Color] = []
	for index in range(12):
		washes.append(world.weathered(copper, 0.055))
	for index in range(20):
		var a := float(index)*TAU/20
		var b := float(index+1)*TAU/20
		var base_a := crown_metal(anchor, s, a, 1.59, 0.046)
		var base_b := crown_metal(anchor, s, b, 1.59, 0.046)
		var lip_height := 1.76 if index != 10 else 1.71
		var lip_a := crown_metal(anchor, s, a, lip_height, 0.039)
		var lip_b := crown_metal(anchor, s, b, lip_height, 0.039)
		var inner_a := crown_metal(anchor, s, a, lip_height, -0.015)
		var inner_b := crown_metal(anchor, s, b, lip_height, -0.015)
		var low_a := crown_metal(anchor, s, a, 1.59, -0.011)
		var low_b := crown_metal(anchor, s, b, 1.59, -0.011)
		var shade := 0.33 + 0.28 * sin(index * 2.7)
		world.mesh.quad(base_a,base_b,lip_b,lip_a,washes[index % washes.size()].lerp(patina, shade))
		world.mesh.quad(lip_a,lip_b,inner_b,inner_a,trim)
		world.mesh.quad(low_b,low_a,inner_a,inner_b,copper.darkened(0.37))
		world.mesh.quad(base_b,base_a,low_a,low_b,copper.darkened(0.31))
		if index % 3 != 2:
			continue
		var middle := lerpf(a,b,0.46)
		var raise := 2.02 + sin(index*1.95)*0.12
		var peak := crown_metal(anchor,s,middle,raise,0.067)
		var seam_a := crown_metal(anchor,s,lerpf(a,b,0.18),raise-0.07,0.058)
		var seam_b := crown_metal(anchor,s,lerpf(a,b,0.76),raise-0.045,0.054)
		world.mesh.quad(lip_a,lip_b,seam_b,seam_a,copper.lightened(0.07))
		world.mesh.triangle(seam_a,seam_b,peak,trim)
		var rim := lip_a.lerp(lip_b,0.46)
		var radial := Vector3(cos(middle),0,sin(middle))
		var framed := rim + radial * s * 0.027 - Vector3.UP * s * 0.062
		world.ellipsoid(framed,Vector3(0.056,0.073,0.053)*s,trim.darkened(0.18),7,5)
		world.ellipsoid(framed + radial*s*0.044,Vector3(0.041,0.053,0.042)*s,patina.darkened(0.42),7,5)

static func crown_metal(anchor: Vector3, s: float, angle: float, height: float, offset: float) -> Vector3:
	var bearing := height + sin(angle * 2.0 + 0.27) * 0.035
	var at := fposmod(angle, TAU) * CROWN_RADII.size() / TAU
	var segment := floori(at)
	var profile: Vector2 = CROWN_RADII[segment % CROWN_RADII.size()].lerp(
		CROWN_RADII[(segment + 1) % CROWN_RADII.size()], at - segment)
	var tarnish := 0.009 * sin(angle * 4.0 + 0.4)
	var radius := lerpf(profile.x, profile.y, clampf((height - 1.59) / 0.17, 0.0, 1.0)) + offset + tarnish
	return anchor + Vector3(cos(angle) * radius, bearing, -0.105 + sin(angle) * radius) * s

static func sword(world) -> void:
	var tip: Vector3 = world.at(278,380,0.20)
	var base: Vector3 = world.at(390,141,0.62)
	var grip: Vector3 = world.at(426,82,0.55)
	var axis := (base-tip).normalized()
	var blade_side := axis.cross(Vector3.UP).normalized()
	var upper_left := base - blade_side*0.39
	var upper_right := base + blade_side*0.39
	var near_tip := tip.lerp(base,0.14)
	var left_edge := near_tip - blade_side*0.31
	var right_edge := near_tip + blade_side*0.31
	var spine := base + Vector3.UP*0.14
	world.mesh.quad(tip,left_edge,upper_left,spine,RUST.darkened(0.21))
	world.mesh.quad(tip,spine,upper_right,right_edge,RUST)
	world.mesh.triangle(tip,spine,near_tip+Vector3.UP*0.09,Color("#c38556"))
	var underside := -Vector3.UP * 0.105
	world.mesh.quad(upper_left,left_edge,left_edge+underside,upper_left+underside,RUST.darkened(0.41))
	world.mesh.quad(right_edge,upper_right,upper_right+underside,right_edge+underside,RUST.darkened(0.45))
	world.mesh.quad(tip,left_edge,left_edge+underside,tip+underside,RUST.darkened(0.42))
	world.mesh.quad(right_edge,tip,tip+underside,right_edge+underside,RUST.darkened(0.48))
	for index in range(19):
		var along := 0.13 + index * 0.042
		var setting := tip.lerp(base,along)
		var across := sin(index * 8.13) * 0.18
		var height := 0.14 * along * (1.0 - absf(across) / 0.42) + 0.012
		var scar := setting + blade_side * across + Vector3.UP * height
		world.mesh.triangle(scar,scar+axis*0.029+blade_side*0.050,
			scar+blade_side*0.015+axis*(0.14+(index%3)*0.07),Color("#633c2b"))
	for side in [-1.0,1.0]:
		var hilt: Vector3 = base + blade_side*side*1.04
		world.mesh.tube(PackedVector3Array([base,base.lerp(hilt,0.65)+Vector3.UP*0.05,hilt+Vector3.UP*0.16]),
			PackedFloat32Array([0.15,0.18,0.10]),Color("#9f7a4e"),8,0.14,true)
	world.mesh.tube(PackedVector3Array([base,base.lerp(grip,0.6),grip]),PackedFloat32Array([0.17,0.15,0.20]),
		Color("#543c2f"),9,0.05,true)
	world.ellipsoid(grip,Vector3(0.28,0.22,0.28),Color("#9d7a4c"),12,6)

static func camp_hardware(world) -> void:
	var hearth := Vector2(257,265)
	for sign_value in [-1.0,1.0]:
		var side: float = sign_value
		var at := hearth+Vector2(side*19,12+side*3)
		world.mesh.smooth_tube(PackedVector3Array([world.from_floor(at),
			world.from_floor(at,0.31),world.from_floor(at+Vector2(side*2,-1),0.56)]),
			PackedFloat32Array([0.075,0.057,0.040]),Color("#584638"),7,0.09,true)
		world.stone(at.x,at.y,5.5,6.2,0.103,STONE.darkened(0.21),side*0.3)
	for index in range(4):
		var at := Vector2(212+index*7.0,304+sin(index*2.17)*4)
		world.stone(at.x,at.y,7.0,2.6,0.047,Color("#796450"),index*0.31)
	Relief.vessel(world,Vector2(285,276),0.0,0.45,Color("#6c554e"))
	Relief.vessel(world,Vector2(282,279),0.0,0.32,Color("#526163"))

static func understory(world) -> void:
	var patches := [
		Vector2(72,232),Vector2(140,245),Vector2(155,342),Vector2(178,383),
		Vector2(218,397),Vector2(236,311),Vector2(256,199),Vector2(309,182),
		Vector2(341,295),Vector2(362,387),Vector2(377,435),Vector2(502,341),
		Vector2(540,391),Vector2(653,279),Vector2(675,205),Vector2(638,147)
	]
	for index in range(patches.size()):
		var at: Vector2 = patches[index]
		var grass := Color("#6d8366") if index%3 else Color("#71816a")
		Relief.contact(world,at,Vector2(17+index%5*3,7+index%4*2),Color("#536a51"),sin(index)*0.4,0.010)
		for blade in range(9):
			var scatter: Vector2 = Vector2.from_angle(blade*2.399+index) * world.random.randf_range(2.5,11.0)
			world.tuft(at+scatter,world.random.randf_range(0.14,0.37),world.weathered(grass,0.071))
		if index%2==0:
			fern(world,at,float(index)*1.9)
	Relief.vine(world,[[122,242,1.39],[117,245,1.03],[119,252,0.48],[121,255,0.07]],
		0.034,Color("#465940"),Color("#77936d"),0.32)
	Relief.vine(world,[[203,402,0.87],[199,407,0.55],[194,410,0.35],[198,415,0.091]],
		0.022,Color("#42513b"),Color("#738d60"),2.31)

static func fern(world, at: Vector2, phase: float) -> void:
	var root: Vector3 = world.from_floor(at,0.022)
	for branch in range(3):
		var angle := phase + branch*TAU/3.0
		var axis := Vector3(cos(angle),0,sin(angle))
		var cross := axis.cross(Vector3.UP)
		var span: float = world.random.randf_range(0.36,0.56)
		var stem := PackedVector3Array()
		var widths := PackedFloat32Array()
		for joint in range(6):
			var along := joint / 5.0
			var lift := sin(along*2.32)*0.29
			var p := root + axis*span*along + Vector3.UP*lift
			stem.append(p)
			widths.append((1.0-along)*0.014+0.004)
			if joint == 0:
				continue
			var breadth := sin(along*PI*0.86) * 0.16
			for sign_value in [-1.0,1.0]:
				var sign_number: float = sign_value
				var tip := p + cross*breadth*sign_number + axis*(0.067+0.032*along) - Vector3.UP*0.015
				var rib := p.lerp(tip,0.46) + axis*0.019 + Vector3.UP*0.027
				world.mesh.triangle(p,rib,tip,Color("#7c9971"),Vector3.UP)
				world.mesh.triangle(p,tip,p+axis*0.036,Color("#506e57"),Vector3.UP)
		world.mesh.tube(stem,widths,Color("#78916b"),5,0.07,false)

static func old_tree(world) -> void:
	var origin: Vector3 = world.at(95,260)
	var low := origin + Vector3(-0.33,1.55,-0.46)
	var high := origin + Vector3(-0.91,3.00,-0.39)
	world.mesh.smooth_tube(PackedVector3Array([origin, low, high,
		origin + Vector3(-1.20, 4.09, -0.50), origin + Vector3(-1.08, 4.82, -0.61),
		origin + Vector3(-1.22, 5.75, -0.41), origin + Vector3(-1.78, 6.54, -0.52)]),
		PackedFloat32Array([0.77, 0.53, 0.45, 0.38, 0.312, 0.205, 0.047]), BARK, 13, 0.09, true)
	for index in range(7):
		var angle := index * 2.399
		var dir := Vector3(cos(angle),0,sin(angle))
		var root_start: int = world.mesh.vertices.size()
		world.mesh.smooth_tube(PackedVector3Array([origin+Vector3.UP*0.51,
			origin+dir*0.74+Vector3.UP*0.23,origin+dir*1.81]),
			PackedFloat32Array([0.33,0.22,0.013]),BARK,8,0.09,true)
		if index in [0, 5]:
			var across := dir.cross(Vector3.UP)
			for run in [[0.61, 0.74, 0.89, 1.02], [1.14, 1.24, 1.36, 1.49]]:
				var samples := PackedVector3Array()
				for length: float in run:
					samples.append(origin + dir * length + across * (0.11 - length * 0.047))
				fire_rim(world, root_start, samples, 0.026, 0.77 if index == 0 else 0.57)
		for mark in range(2):
			var across := dir.cross(Vector3.UP) * (0.062 + mark*0.062)
			world.pencil(PackedVector3Array([origin+dir*0.55+Vector3.UP*0.56+across,
				origin+dir*0.83+Vector3.UP*0.415+across*0.81,
				origin+dir*1.07+Vector3.UP*0.302+across*0.69,
				origin+dir*1.37+Vector3.UP*0.190+across*0.54]),
				0.016, BARK.darkened(0.36))

	var limbs := [
		[[Vector3(-0.39, 1.77, -0.47), Vector3(0.28, 2.47, -0.62),
			Vector3(1.15, 2.95, -0.83), Vector3(1.84, 3.02, -1.09),
			Vector3(2.48, 3.51, -1.34), Vector3(2.80, 4.16, -1.39),
			Vector3(3.30, 4.47, -1.52)], [0.36, 0.28, 0.22, 0.14, 0.097, 0.052, 0.009]],
		[[Vector3(1.69, 3.00, -1.04), Vector3(2.08, 3.18, -0.27),
			Vector3(2.63, 3.03, 0.10), Vector3(2.98, 3.12, 0.44),
			Vector3(3.26, 3.42, 0.50)], [0.12, 0.098, 0.067, 0.036, 0.006]],
		[[Vector3(2.73, 4.00, -1.41), Vector3(2.50, 4.70, -1.30),
			Vector3(2.61, 5.28, -1.35), Vector3(2.88, 5.61, -1.51)],
			[0.093, 0.065, 0.036, 0.007]],
		[[Vector3(-0.78, 2.82, -0.43), Vector3(-1.58, 2.85, -0.76),
			Vector3(-2.31, 3.38, -1.02), Vector3(-2.59, 4.18, -1.06),
			Vector3(-3.28, 4.46, -1.43), Vector3(-3.75, 4.92, -1.67)],
			[0.31, 0.24, 0.17, 0.11, 0.057, 0.010]],
		[[Vector3(-2.45, 3.78, -1.04), Vector3(-2.95, 3.94, -0.78),
			Vector3(-3.44, 3.67, -0.34), Vector3(-3.79, 3.74, 0.16)], [0.11, 0.083, 0.049, 0.009]],
		[[Vector3(-1.10, 4.73, -0.61), Vector3(-0.48, 5.07, -0.95),
			Vector3(-0.11, 5.62, -1.00), Vector3(0.46, 5.91, -0.97),
			Vector3(0.72, 6.39, -1.09), Vector3(1.20, 6.74, -1.24)],
			[0.23, 0.19, 0.13, 0.093, 0.044, 0.009]],
		[[Vector3(0.28, 5.84, -0.98), Vector3(0.70, 5.82, -1.50),
			Vector3(0.99, 5.94, -1.87), Vector3(1.48, 6.16, -2.00)], [0.10, 0.074, 0.046, 0.006]],
		[[Vector3(-1.39, 6.02, -0.44), Vector3(-1.61, 6.59, -0.01),
			Vector3(-1.92, 6.90, 0.24), Vector3(-2.42, 7.13, 0.38)], [0.105, 0.075, 0.035, 0.006]],
	]
	for limb in limbs:
		var branches := PackedVector3Array()
		for offset: Vector3 in limb[0]:
			branches.append(origin + offset)
		var girth := PackedFloat32Array(limb[1])
		world.mesh.smooth_tube(branches, girth, BARK, 9 if girth[0] > 0.14 else 7, 0.07, girth[0] > 0.20)

static func fire_rim(world, first: int, samples: PackedVector3Array, width: float, strength: float) -> void:
	var vertices: PackedVector3Array = world.mesh.vertices
	var rim := PackedVector3Array()
	for sample in samples:
		var above := sample + Vector3.UP * 2.4
		var below := sample + Vector3.DOWN * 0.1
		var highest := below
		for index in range(first, vertices.size(), 3):
			var hit = Geometry3D.segment_intersects_triangle(above, below,
				vertices[index], vertices[index + 1], vertices[index + 2])
			if hit != null and hit.y > highest.y:
				highest = hit
		if highest.is_equal_approx(below):
			return
		rim.append(highest + Vector3.UP * 0.014)
	world.hearth_stroke(rim, width, strength)
