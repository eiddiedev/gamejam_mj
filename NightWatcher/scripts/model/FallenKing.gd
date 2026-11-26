extends RefCounted

const BONE := Color("#c0b99b")
const MARROW := Color("#7f8170")
const SOIL := Color("#476457")
const STONE := Color("#65736b")
const DARK := Color("#2a3837")
const RUST := Color("#a45736")
const BARK := Color("#46514e")
const Relief = preload("res://scripts/model/ReliefDetail.gd")

static func build(world) -> void:
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
	# Raised moss banks pull a continuous shape beneath the broken masonry.
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
	world.sculpture("陨王 · 头骨与冠饰", func(): skull(world, Vector2(586,135), 1.0, true))
	world.sculpture("陨王 · 椎骨与胸廓", func(): ribcage(world))
	world.sculpture("陨王 · 臂骨与指节", func(): arms(world))

static func ribcage(world) -> void:
	var shade := MARROW.darkened(0.08)
	var torso_start := Vector2(525,187)
	var torso_end := Vector2(424,347)
	for index in range(11):
		var at := torso_start.lerp(torso_end,index / 10.0)
		world.ellipsoid(world.from_floor(at,0.43),Vector3(0.38,0.33,0.28),world.weathered(MARROW,0.065),8,5)
	for index in range(9):
		var fraction := index / 8.0
		var at := torso_start.lerp(torso_end,fraction)
		var span := sin(0.37 + fraction * 2.46) * 1.0
		for side in [-1.0,1.0]:
			var width: float = (38.0 + 37.0 * span) * side
			var body := PackedVector3Array([
				world.from_floor(at,0.36),world.at(at.x + width * 0.41, at.y + 3,0.97),
				world.at(at.x + width * 0.81, at.y + 17,1.10),
				world.at(at.x + width, at.y + 38,0.48),
				world.at(at.x + width * 0.79, at.y + 51,0.10)])
			world.mesh.smooth_tube(body,PackedFloat32Array([0.13,0.17,0.16,0.11,0.030]),
				world.weathered(BONE if side > 0 else shade,0.064),8,0.045,true)
			if index % 3 != 1:
				var tip := body[3] + Vector3.UP * 0.095
				var join := body[2] + Vector3.UP * 0.162
				world.pencil(PackedVector3Array([tip.lerp(join, 0.20), tip.lerp(join, 0.48) + Vector3.UP * 0.016,
					tip.lerp(join, 0.75), join]), 0.017, MARROW.darkened(0.27))
	world.ellipsoid(world.at(424,350,0.39),Vector3(0.78,0.35,0.44),BONE,10,6)
	world.ellipsoid(world.at(443,361,0.24),Vector3(0.64,0.31,0.35),MARROW,9,6)

static func arms(world) -> void:
	# A displaced shoulder break creates a real walkable saddle to the eye socket.
	bone(world,Vector2(532,187),Vector2(524,179),0.32,0.34)
	bone(world,Vector2(490,153),Vector2(458,132),0.33,0.37)
	var saddle: Array[Vector2] = [Vector2(478,194),Vector2(495,185),Vector2(507,167),Vector2(532,148),Vector2(554,161)]
	world.trail(saddle, 7.4, Color("#69776c53"))
	bone(world,Vector2(458,132),Vector2(396,153),0.30,0.32)
	bone(world,Vector2(396,153),Vector2(420,91),0.18,0.26)
	fingers(world,Vector2(420,91),-1.0)
	bone(world,Vector2(554,218),Vector2(612,346),0.24,0.42)
	bone(world,Vector2(612,346),Vector2(603,350),0.22,0.29)
	bone(world,Vector2(554,374),Vector2(521,387),0.19,0.32)
	var split: Array[Vector2] = [Vector2(512,400),Vector2(552,398),Vector2(578,359),Vector2(619,328)]
	world.trail(split,9.0,Color("#6b796c53"))
	fingers(world,Vector2(521,387),1.0)

static func bone(world, start: Vector2, end: Vector2, h: float, radius: float) -> void:
	var middle := start.lerp(end,0.46) + Vector2(5,-3)
	var points := PackedVector3Array([world.from_floor(start,h*1.12),world.from_floor(middle,h*0.91),world.from_floor(end,h)])
	world.mesh.smooth_tube(points,PackedFloat32Array([radius,radius*0.52,radius*0.92]),BONE,10,0.03,true)
	world.ellipsoid(points[0],Vector3.ONE * radius * 1.1,MARROW,9,5)
	world.ellipsoid(points[2],Vector3.ONE * radius,BONE,10,5)

static func fingers(world, origin: Vector2, side: float) -> void:
	for index in range(4):
		var proximal := origin + Vector2(index * 4.5, (index-2)*3.9)
		var tip := proximal + Vector2(-22.0 * side, 24.0 * side + index*3.0)
		bone(world, proximal, tip, 0.19+index*0.037, 0.110)

static func skull(world, at: Vector2, scale_factor: float, crowned: bool) -> void:
	var anchor: Vector3 = world.from_floor(at)
	var cream := BONE.lightened(0.045)
	bone_shell(world, anchor, scale_factor, cream)
	world.ellipsoid(anchor + Vector3(0.0,0.31,0.52)*scale_factor,Vector3(0.68,0.39,0.66)*scale_factor,BONE,14,7)
	for side in [-1.0,1.0]:
		var socket: Vector3 = anchor + Vector3(side*0.43,1.02,0.68)*scale_factor
		world.ellipsoid(socket,Vector3(0.32,0.35,0.12)*scale_factor,DARK.darkened(0.21),13,7)
		var brow := PackedVector3Array([
			socket+Vector3(-0.27,0.18,0.09)*scale_factor, socket+Vector3(-0.128,0.28,0.10)*scale_factor,
			socket+Vector3(0.12,0.34,0.10)*scale_factor, socket+Vector3(0.29,0.24,0.06)*scale_factor
		])
		world.mesh.smooth_tube(brow,PackedFloat32Array([0.059,0.083,0.095,0.050]),cream,9,0.09,false)
		world.ellipsoid(anchor + Vector3(side * 0.58,0.59,0.78)*scale_factor,
			Vector3(0.20,0.19,0.27)*scale_factor,MARROW.lightened(0.17),9,6)
	var nose := anchor + Vector3(0,0.69,0.96)*scale_factor
	world.mesh.triangle(nose+Vector3(0,0.22,0.028)*scale_factor, nose+Vector3(-0.14,-0.15,0.01)*scale_factor,
		nose+Vector3(0.13,-0.13,0.015)*scale_factor,DARK)
	world.ellipsoid(anchor + Vector3(0,0.26,1.0)*scale_factor,Vector3(0.61,0.14,0.10)*scale_factor,DARK,10,6)
	for index in range(9):
		var x := (index-4)*0.115
		world.mesh.block(anchor + Vector3(x,0.28,1.085 - absf(x)*0.12)*scale_factor,
			0.084*scale_factor, 0.15*scale_factor, 0.076*scale_factor,0.0,cream,0.019,0.022,false)
	var forehead := [Vector2(0.35,1.89),Vector2(0.29,1.79),Vector2(0.18,1.71),Vector2(0.22,1.64),Vector2(0.15,1.55)]
	var seam := PackedVector3Array()
	for point in forehead:
		var z := 0.92 * sqrt(maxf(0.01,1.0 - pow(point.x/1.05,2.0) - pow((point.y-0.98)/1.15,2.0)))
		seam.append(anchor + Vector3(point.x,point.y,z+0.027)*scale_factor)
	world.pencil(seam,0.020*scale_factor,Color("#575e52"))
	if crowned:
		crown(world,anchor,scale_factor)

static func bone_shell(world, anchor: Vector3, multiplier: float, tone: Color) -> void:
	var previous := PackedVector3Array()
	for latitude in range(20):
		var local_ring := PackedVector3Array()
		var phi := lerpf(-1.5705, 1.5705, latitude / 19.0)
		for edge in range(36):
			var turn := edge * TAU / 36.0
			var chips := 0.98 + 0.029 * sin(edge * 9.92 + latitude * 7.67)
			local_ring.append(Vector3(cos(turn)*cos(phi)*1.05*chips,
				0.98+sin(phi)*1.15*chips,sin(turn)*cos(phi)*0.92*chips))
		if latitude > 0:
			for edge in range(36):
				var next := (edge+1)%36
				var center := (previous[edge]+local_ring[edge]+local_ring[next]+previous[next])*0.25
				var orbit := Vector2((absf(center.x)-0.43)/0.29,(center.y-1.02)/0.33)
				if center.z > 0.45 and orbit.length_squared() < 1.0:
					continue
				var grain := 0.018 * sin(edge * 7.6 + latitude * 4.2)
				var color := tone.darkened(absf(grain))
				world.mesh.quad(anchor+previous[edge]*multiplier,anchor+local_ring[edge]*multiplier,
					anchor+local_ring[next]*multiplier,anchor+previous[next]*multiplier,color)
		previous = local_ring

static func crown(world, anchor: Vector3, s: float) -> void:
	var copper := Color("#946a49")
	for index in range(12):
		var a := float(index)*TAU/12
		var b := float(index+1)*TAU/12
		var begin := anchor + Vector3(cos(a)*1.02,1.59,sin(a)*0.89)*s
		var end := anchor + Vector3(cos(b)*1.02,1.59,sin(b)*0.89)*s
		var raised := Vector3.UP*s*(0.38 if index%2 == 0 else 0.28)
		world.mesh.quad(begin,end,end+raised,begin+raised,copper)
		var p := begin.lerp(end,0.51) + raised
		world.mesh.triangle(begin+raised,end+raised,p+Vector3.UP*s*(0.44 if index%2==0 else 0.25),
			world.weathered(copper.lightened(0.13),0.10))
		if index%3==0:
			world.ellipsoid(p-Vector3.UP*s*0.16,Vector3(0.095,0.10,0.065)*s,Color("#254949"),7,5)

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
	var end := origin + Vector3(-1.13,6.35,0.1)
	world.mesh.smooth_tube(PackedVector3Array([origin,low,high,end]),
		PackedFloat32Array([0.77,0.53,0.45,0.17]),BARK,13,0.10,true)
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
	for index in range(5):
		var start: Vector3 = low.lerp(high,index/4.0)
		var side := 1.0 if index%2==0 else -1.0
		var finish := start + Vector3(side*(1.81+index*0.29),1.19+index*0.49,-0.94+index*0.31)
		var joint := start.lerp(finish,0.57)+Vector3(0,0.21,0.14)
		world.mesh.smooth_tube(PackedVector3Array([start,joint,finish]),PackedFloat32Array([0.26,0.138,0.025]),BARK,8,0.065,true)
		world.mesh.tube(PackedVector3Array([joint,joint.lerp(finish,0.38)+Vector3.UP*0.35,finish+Vector3(0.18,1.03,-0.23)]),
			PackedFloat32Array([0.095,0.063,0.015]),BARK,7,0.12,true)

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
