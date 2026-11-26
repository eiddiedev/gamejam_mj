extends RefCounted

const BONE := Color("#b8b5aa")
const SHADE := Color("#849195")
const SNOW := Color("#b8c9d5")
const DARK := Color("#252d33")
const OXIDE := Color("#53676b")
const IRON := Color("#879394")
const GRAPHITE := Color("#414b50")
const LEFT_EYE := Vector2(-0.54, 1.36)
const RIGHT_EYE := Vector2(0.51, 1.34)
const LEFT_RADIUS := Vector2(0.44, 0.39)
const RIGHT_RADIUS := Vector2(0.35, 0.37)
const BASE := 0.36
const HEIGHT := 2.77
const SLICES := 27
const SIDES := 52

static func build(world) -> void:
	var pose := Basis.from_euler(Vector3(-0.39, 0.17, -0.18))
	var seat: Vector3 = world.at(137, 247, 1.17)
	var origin := seat - pose * Vector3(LEFT_EYE.x, 1.17, 1.10)
	var frame := Transform3D(pose, origin)
	world.sculpture("黑曜长墙 · 霜蚀裂颅", func():
		skull_shell(world, frame)
		orbit(world, frame, LEFT_EYE, LEFT_RADIUS, true)
		orbit(world, frame, RIGHT_EYE, RIGHT_RADIUS, false)
		nasal_opening(world, frame)
		jaw(world, frame)
		brow_plate(world, frame)
	)
	ink_cracks(world, frame)
	buried_drift(world)

static func skull_shell(world, frame: Transform3D) -> void:
	var previous := PackedVector3Array()
	for row in range(SLICES + 1):
		var height := lerpf(BASE + 0.003, HEIGHT - 0.003, row / float(SLICES))
		var ring := PackedVector3Array()
		for index in range(SIDES):
			ring.append(shell(height, index * TAU / SIDES))
		if not previous.is_empty():
			for index in range(SIDES):
				var next := (index + 1) % SIDES
				var mid := (previous[index] + previous[next] + ring[index] + ring[next]) * 0.25
				if face_opening(mid):
					continue
				var angle := (index + 0.5) * TAU / SIDES
				var paint := bone_pigment(mid, angle)
				world.mesh.quad(frame * previous[index], frame * ring[index],
					frame * ring[next], frame * previous[next], paint)
		previous = ring

static func shell(height: float, angle: float, offset := 0.0) -> Vector3:
	var fraction := clampf(inverse_lerp(BASE, HEIGHT, height), 0.0, 1.0)
	var profile := pow(maxf(0.003, sin(PI * fraction)), 0.58)
	var x := cos(angle) * profile * (1.33 - fraction * 0.16 + 0.078 * sin(angle + 0.58))
	var z := sin(angle) * profile * (1.12 - 0.12 * cos(fraction * 3.91))
	var rough := sin(angle * 7.0 + height * 4.2) * 0.024 + sin(angle * 3.0 - height * 3.9) * 0.017
	var fracture := ridge_split(height, angle)
	var lateral := 0.024 * cos(fraction * PI * 1.91) - 0.061 * (fraction - 0.46)
	return Vector3(x * (1.0 + rough - fracture * 0.21) + lateral + cos(angle) * offset,
		height + 0.022 * sin(angle * 3.0) * profile,
		z * (1.0 + rough - fracture * 0.22) - 0.06 * (fraction - 0.45) + sin(angle) * offset)

static func ridge_split(height: float, angle: float) -> float:
	var split := 1.22 + 0.22 * (height - 2.0) + sin(height * 13.9) * 0.071
	var separation := absf(angle_difference(split, angle))
	return (1.0 - smoothstep(0.012, 0.125, separation)) * smoothstep(1.87, 2.09, height)

static func bone_pigment(point: Vector3, angle: float) -> Color:
	var frost := sin(angle * 4.0 + point.y * 6.2) + sin(angle * 7.0 - point.y * 3.7) * 0.79
	var weather := smoothstep(-0.1, 0.90, frost)
	var earth := 1.0 - smoothstep(BASE, 0.95, point.y)
	var split := ridge_split(point.y, angle)
	var color := BONE.lerp(SHADE, earth * 0.72 + weather * 0.18)
	var snow_line := 2.29 + 0.11 * sin(angle * 5.0) + 0.09 * cos(angle * 8.0)
	if point.y > snow_line:
		color = color.lerp(SNOW, 0.46 + 0.37 * weather)
	return color.lerp(GRAPHITE, split * 0.68)

static func face_opening(point: Vector3) -> bool:
	if point.z < 0.55:
		return false
	if ((Vector2(point.x, point.y) - LEFT_EYE) / LEFT_RADIUS).length_squared() < 1.07:
		return true
	if ((Vector2(point.x, point.y) - RIGHT_EYE) / RIGHT_RADIUS).length_squared() < 1.05:
		return true
	var nostril := (1.04 - point.y) / 0.40
	return nostril > 0.0 and nostril < 1.0 and absf(point.x + 0.028) < (nostril * 0.17 + 0.025)

static func face_depth(point: Vector2) -> float:
	var low := 0.0
	var high := PI
	for sample in range(11):
		var middle := (low + high) * 0.5
		if shell(point.y, middle).x > point.x:
			low = middle
		else:
			high = middle
	return shell(point.y, (low + high) * 0.5).z

static func orbit(world, frame: Transform3D, center: Vector2, radii: Vector2, left: bool) -> void:
	var lip := PackedVector3Array()
	var aperture := PackedVector3Array()
	var throat := PackedVector3Array()
	var facets := 18
	var pivot := Vector3(center.x, center.y, 0.47)
	for index in range(facets):
		var angle := index * TAU / facets
		var radial := Vector2.from_angle(angle)
		var shake := 1.0 + sin(index * 2.49 + center.x * 5.0) * 0.055
		var outside := center + radial * radii * shake * Vector2(1.20, 1.23)
		var inside := center + radial * radii * shake * Vector2(0.92, 0.89)
		var orbit_rise := maxf(0.0, radial.y) * 0.075
		lip.append(Vector3(outside.x, outside.y, face_depth(outside) + 0.039 + orbit_rise))
		aperture.append(Vector3(inside.x, inside.y, face_depth(inside) + 0.078 + orbit_rise))
		throat.append(pivot + Vector3(radial.x * radii.x * 0.69, radial.y * radii.y * 0.66,
			0.12 * sin(angle + (0.4 if left else -0.6))))
	for index in range(facets):
		var next := (index + 1) % facets
		var frost := smoothstep(0.06, 0.84, sin(index * TAU / facets))
		var worn := SHADE.lerp(BONE, 0.46 + 0.36 * frost)
		world.mesh.quad(frame * lip[index], frame * lip[next], frame * aperture[next], frame * aperture[index], worn)
		world.mesh.quad(frame * aperture[index], frame * aperture[next], frame * throat[next], frame * throat[index],
			DARK.lerp(SHADE, 0.22 + 0.10 * frost))
		world.mesh.triangle(frame * throat[index], frame * throat[next], frame * pivot, DARK)
	for start in [2, 10]:
		var line := PackedVector3Array()
		for index in range(start, start + 4):
			var point := lip[index].lerp(aperture[index], 0.58 + sin(index * 2.31) * 0.16)
			line.append(frame * (point + Vector3.BACK * 0.012))
		world.pencil(line, 0.018, GRAPHITE)

static func nasal_opening(world, frame: Transform3D) -> void:
	var edge := PackedVector2Array([Vector2(-0.020,1.05), Vector2(0.055,0.99),
		Vector2(0.133,0.78), Vector2(0.051,0.68), Vector2(-0.122,0.71), Vector2(-0.145,0.78)])
	var recess := Vector3(-0.028, 0.81, 0.81)
	for index in range(edge.size()):
		var a := edge[index]
		var b := edge[(index + 1) % edge.size()]
		var near_edge := Vector3(a.x, a.y, face_depth(a) + 0.043)
		var far_edge := Vector3(b.x, b.y, face_depth(b) + 0.043)
		world.mesh.triangle(frame * near_edge, frame * far_edge, frame * recess, DARK.lerp(GRAPHITE, 0.19))

static func jaw(world, frame: Transform3D) -> void:
	var upper := PackedVector3Array([frame * Vector3(-0.60,0.70,0.78), frame * Vector3(-0.30,0.62,0.90),
		frame * Vector3(0.02,0.59,0.96), frame * Vector3(0.37,0.58,0.91), frame * Vector3(0.57,0.62,0.73)])
	world.mesh.smooth_tube(upper,PackedFloat32Array([0.090,0.181,0.196,0.154,0.083]),BONE.lerp(SHADE,0.29),10,0.07)
	for side: float in [-1.0, 1.0]:
		var cheek := PackedVector3Array([frame * Vector3(side*0.99,1.05,0.56),
			frame * Vector3(side*0.81,0.92,0.80), frame * Vector3(side*0.65,0.69,0.94),
			frame * Vector3(side*0.43,0.63,0.98)])
		world.mesh.smooth_tube(cheek,PackedFloat32Array([0.095,0.163,0.139,0.058]),BONE.lerp(SHADE,0.37),10,0.06)
	var opening := PackedVector3Array([Vector3(-0.51,0.42,0.73), Vector3(-0.27,0.37,0.94),
		Vector3(0.12,0.33,1.01), Vector3(0.40,0.37,0.88)])
	for index in range(opening.size()):
		opening[index] = frame * opening[index]
	world.mesh.smooth_tube(opening,PackedFloat32Array([0.035,0.072,0.059,0.020]),DARK,9,0.06)
	for index in range(8):
		if index in [1, 6]:
			continue
		var x := (index - 3.6) * 0.135
		var z := 1.077 - absf(x) * 0.23
		var tooth := PackedVector3Array([frame * Vector3(x,0.52,z - 0.045),
			frame * Vector3(x + sin(index*2.3)*0.022,0.34 + sin(index*1.97)*0.034,z + 0.014)])
		world.mesh.tube(tooth,PackedFloat32Array([0.078,0.025]),BONE.lerp(SHADE,0.20),7,0.12)
	var splinter := PackedVector3Array([frame * Vector3(0.79,0.70,0.79), frame * Vector3(0.65,0.24,1.01),
		frame * Vector3(0.50,0.10,1.08), frame * Vector3(0.26,0.10,1.03)])
	world.mesh.smooth_tube(splinter,PackedFloat32Array([0.145,0.166,0.123,0.042]),SHADE.lerp(BONE,0.40),8,0.07)

static func brow_plate(world, frame: Transform3D) -> void:
	for index in range(19):
		if index in [7, 8]:
			continue
		var start := index / 19.0
		var finish := (index + 1) / 19.0
		var heel := frame * plate_edge(start, false, 0.020)
		var toe := frame * plate_edge(finish, false, 0.024)
		var ridge := frame * plate_edge(start, true, 0.044)
		var crest := frame * plate_edge(finish, true, 0.040)
		var pigment := OXIDE.lerp(IRON, 0.11 + sin(index * 0.61) * 0.10)
		world.mesh.quad(heel, toe, crest, ridge, pigment)
		world.mesh.quad(ridge, crest, frame * plate_edge(finish, true, 0.012),
			frame * plate_edge(start, true, 0.012), IRON)
		if index % 4 == 1:
			var t := lerpf(start, finish, 0.43)
			var mount := frame * plate_edge(t, true, 0.054)
			var base := frame * plate_edge(t, false, 0.054)
			var rivet := mount.lerp(base, 0.52)
			world.ellipsoid(rivet,Vector3(0.036, 0.039, 0.037),IRON,7,4)

static func plate_edge(t: float, upper: bool, lift: float) -> Vector3:
	var angle := lerpf(2.88, 0.22, t)
	var height := 1.37 + sin(t * PI) * 0.67 + t * 0.20
	if upper:
		height += 0.18 + sin(t * 11.0) * 0.037
	return shell(height, angle, lift)

static func ink_cracks(world, frame: Transform3D) -> void:
	for branch in [
		[Vector2(2.72,1.44), Vector2(2.59,1.41), Vector2(2.47,1.35), Vector2(2.32,1.40), Vector2(2.18,1.24), Vector2(2.05,1.30)],
		[Vector2(2.48,1.39), Vector2(2.42,1.57), Vector2(2.44,1.68), Vector2(2.32,1.72)],
		[Vector2(2.20,2.55), Vector2(2.12,2.52), Vector2(2.01,2.61), Vector2(1.94,2.59)],
		[Vector2(0.93,0.47), Vector2(0.83,0.49), Vector2(0.75,0.65), Vector2(0.64,0.63)]
	]:
		var mark := PackedVector3Array()
		for pick: Vector2 in branch:
			mark.append(frame * shell(pick.x, pick.y, 0.019))
		world.pencil(mark, 0.017 if branch.size() > 4 else 0.012, GRAPHITE)

static func buried_drift(world) -> void:
	var edge: Array[Vector2] = [Vector2(97,240), Vector2(109,227), Vector2(119,220), Vector2(138,221),
		Vector2(154,211), Vector2(179,215), Vector2(189,226), Vector2(205,232), Vector2(207,248),
		Vector2(193,259), Vector2(180,258), Vector2(166,272), Vector2(143,275), Vector2(131,268),
		Vector2(115,270), Vector2(103,258)]
	var center := Vector2(159,245)
	for index in range(edge.size()):
		var next := (index + 1) % edge.size()
		var a: Vector3 = world.from_floor(edge[index], 0.018)
		var b: Vector3 = world.from_floor(edge[next], 0.018)
		var shelf: Vector3 = world.from_floor(center.lerp(edge[index], 0.64), 0.09 + sin(index*2.71)*0.034)
		var ledge: Vector3 = world.from_floor(center.lerp(edge[next], 0.64), 0.09 + sin(next*2.71)*0.034)
		var tint := SHADE.lerp(SNOW, 0.34 + sin(index*2.19)*0.13)
		world.mesh.triangle(a, ledge, b, tint, Vector3.UP)
		world.mesh.triangle(a, shelf, ledge, tint, Vector3.UP)
		world.mesh.triangle(shelf, ledge, world.from_floor(center, 0.14), tint.lightened(0.055), Vector3.UP)
	for slot: Vector2 in [Vector2(119,249), Vector2(134,264), Vector2(167,264), Vector2(183,253)]:
		var base := slot.x + slot.y * 0.4
		world.stone(slot.x,slot.y,7.4,6.6,0.16,BONE.lerp(SHADE,0.52),sin(base),0.034)
