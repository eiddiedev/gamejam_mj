extends Node3D

const Terrain = preload("res://terrain.gd")
const Builder = preload("res://world/mesh_builder.gd")
const INK_SHADER = preload("res://world/ink_material.gdshader")
const OUTLINE_SHADER = preload("res://world/ink_outline.gdshader")
const Study = preload("res://world/fort_study.gd")
const FIELD_OFFSET := Vector2(249, -76)
const FIELD_SCALE := 1.29
const ORIGIN := (Vector2(640, 400) - FIELD_OFFSET) / FIELD_SCALE
const MAP_SCALE := Vector2(50.0, 33.4565)
const PITCH := 0.7330383
const STONE := Color(0.326, 0.422, 0.418, 1.0)
const JOINT := Color(0.123, 0.177, 0.176, 0.89)
const BARK := Color(0.163, 0.214, 0.243, 0.75)
const GRASS := Color(0.25, 0.345, 0.267, 0.48)

var ink: ShaderMaterial
var outline: ShaderMaterial
var camera: Camera3D
var stage: WorldEnvironment
var random := RandomNumberGenerator.new()
var gates: Array[MeshInstance3D] = []
var model: MeshInstance3D
var study_enabled := false
var ink_materials: Array[ShaderMaterial] = []

static func space(point: Vector2, height := 0.0) -> Vector3:
	var plane := (point - ORIGIN) / MAP_SCALE
	return Vector3(plane.x, height, plane.y)

func _ready() -> void:
	random.seed = 1541
	ink = prepare_material(INK_SHADER)
	make_camera()
	var builder := Builder.new()
	var wall := Builder.new() if study_enabled else builder
	var arch_mesh := Builder.new() if study_enabled else builder
	var roots := Builder.new() if study_enabled else builder
	make_ground(builder)
	make_ring(builder, wall)
	make_ruins(builder, arch_mesh)
	make_tree(builder, roots)
	make_flora(builder)
	make_scree(builder)
	model = add_mesh(builder, "Fort masonry, terraces and forest")
	if study_enabled:
		var marks := Study.make_marks()
		var wall_paint := prepare_material(INK_SHADER)
		wall_paint.set_shader_parameter("study_stone", true)
		Study.apply_marks(wall_paint, marks)
		add_mesh(wall, "Study · courtyard wall", wall_paint)
		var arch_paint := prepare_material(INK_SHADER)
		arch_paint.set_shader_parameter("study_stone", true)
		Study.apply_marks(arch_paint, marks)
		arch_paint.set_shader_parameter("study_arch", true)
		add_mesh(arch_mesh, "Study · near arch", arch_paint)
		var root_paint := prepare_material(Study.ROOT_SHADER)
		Study.apply_marks(root_paint, marks)
		add_mesh(roots, "Study · fireside roots", root_paint)
	make_gate_meshes()
	make_outline()

func prepare_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("map_origin", ORIGIN)
	material.set_shader_parameter("map_scale", MAP_SCALE)
	material.set_shader_parameter("hearth", Terrain.FIRE)
	ink_materials.append(material)
	return material

func make_camera() -> void:
	stage = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#293e41")
	stage.environment = environment
	add_child(stage)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 800.0 / (FIELD_SCALE * MAP_SCALE.x)
	camera.near = 0.08
	camera.far = 72.0
	add_child(camera)
	camera.position = Vector3(0.0, sin(PITCH) * 25.0, cos(PITCH) * 25.0)
	camera.look_at(Vector3.ZERO)
	camera.make_current()

func add_mesh(builder: Builder, title: String, material: ShaderMaterial = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = title
	instance.mesh = builder.build()
	instance.material_override = ink if material == null else material
	add_child(instance)
	return instance

func make_outline() -> void:
	outline = ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.render_priority = 90
	if study_enabled:
		var wall_path := PackedVector2Array()
		for point in Terrain.WALL_RUNS[1]:
			var vertex := space(point)
			wall_path.append(Vector2(vertex.x, vertex.z))
		outline.set_shader_parameter("study_enabled", true)
		outline.set_shader_parameter("study_wall", wall_path)
		outline.set_shader_parameter("study_arch", space(Vector2(391, 238)))
	var screen := QuadMesh.new()
	screen.size = Vector2(2, 2)
	var pass_mesh := MeshInstance3D.new()
	pass_mesh.name = "Ink contour pass"
	pass_mesh.mesh = screen
	pass_mesh.material_override = outline
	pass_mesh.extra_cull_margin = 80.0
	camera.add_child(pass_mesh)

func make_ground(mesh: Builder) -> void:
	var floor_ink := Color(0.368, 0.431, 0.368, 0.22)
	for z in range(-13, 13):
		for x in range(-15, 16):
			var a := ground_vertex(x, z)
			var b := ground_vertex(x, z + 1)
			var c := ground_vertex(x + 1, z + 1)
			var d := ground_vertex(x + 1, z)
			mesh.quad(a, b, c, d, floor_ink)

func ground_vertex(x: int, z: int) -> Vector3:
	var fringe := smoothstep(5.2, 10.0, absf(float(x))) + smoothstep(7.3, 12.0, absf(float(z)))
	var height := (sin(x * 0.85 + z * 1.73) * 0.22 + cos(z * 0.49 + x) * 0.18) * fringe
	return Vector3(float(x) * 1.35, height - 0.055, float(z) * 1.35)

func make_ring(builder: Builder, wall: Builder) -> void:
	for run_index in range(Terrain.WALL_RUNS.size()):
		var run: Array = Terrain.WALL_RUNS[run_index]
		var mesh := wall if run_index == 1 else builder
		var trace_stone := mesh == builder
		var curve := Curve3D.new()
		curve.bake_interval = 0.065
		for index in range(run.size()):
			var a := space(run[maxi(0, index - 1)])
			var b := space(run[mini(run.size() - 1, index + 1)])
			var handle := a.direction_to(b) * 0.20
			curve.add_point(space(run[index]), -handle, handle)
		var length := curve.get_baked_length()
		var distance := 0.0
		while distance < length - 0.018:
			var chunk := minf(0.51, length - distance)
			var center := curve.sample_baked(distance + chunk * 0.5)
			var yaw := curve_yaw(curve, distance + chunk * 0.5)
			mesh.block(center, chunk + 0.065, rampart_height(center, distance, length) - 0.14,
				0.60, yaw, JOINT, 0.020)
			distance += chunk
		for course in range(8):
			distance = 0.0
			while distance < length - 0.045:
				var span := minf(random.randf_range(0.34, 0.94), length - distance)
				if distance == 0.0 and course % 2 == 1:
					span *= 0.60
				var center := curve.sample_baked(distance + span * 0.5)
				var height := rampart_height(center, distance, length)
				var layer := course * 0.31
				if layer < height - 0.05:
					var yaw := curve_yaw(curve, distance + span * 0.5)
					var depth := random.randf_range(0.69, 0.84)
					var rise := minf(height - layer, random.randf_range(0.291, 0.332))
					center.y = layer + random.randf_range(-0.026, 0.035)
					mesh.block(center, maxf(0.055, span - 0.028), rise, depth,
						yaw + random.randf_range(-0.042, 0.042), variation(STONE, 0.055),
						random.randf_range(0.034, 0.101), random.randf_range(-0.098, 0.098), trace_stone)
				distance += span
		distance = 0.16
		while distance < length - 0.17:
			var span := minf(random.randf_range(0.48, 0.95), length - distance)
			var center := curve.sample_baked(distance + span * 0.5)
			center.y = rampart_height(center, distance, length) - 0.07
			if random.randf() > 0.16:
				var yaw := curve_yaw(curve, distance + span * 0.5)
				mesh.block(center, span - 0.033, random.randf_range(0.13, 0.31), random.randf_range(0.82, 0.99),
					yaw, variation(STONE, 0.037), 0.105, random.randf_range(-0.10, 0.10), trace_stone)
			distance += span

func rampart_height(at: Vector3, distance: float, length: float) -> float:
	var y := at.z * MAP_SCALE.y + ORIGIN.y
	var height := lerpf(0.91, 2.11, smoothstep(429.0, 560.0, y))
	var damaged := smoothstep(0.04, 0.67, minf(distance, length - distance))
	return height * lerpf(0.64, 1.0, damaged) + sin(at.x * 2.31 + at.z * 1.97) * 0.094

func curve_yaw(curve: Curve3D, distance: float) -> float:
	var before := curve.sample_baked(maxf(0.0, distance - 0.09))
	var after := curve.sample_baked(minf(curve.get_baked_length(), distance + 0.09))
	return plan_angle(after - before)

func blockwork(mesh: Builder, a: Vector3, b: Vector3, height: float, depth: float) -> void:
	var direction := (b - a).normalized()
	var span := a.distance_to(b)
	var rotation := plan_angle(direction)
	var count := maxi(2, roundi(height / 0.34))
	var layer := height / count
	mesh.block((a + b) * 0.5, span + 0.10, height - 0.06, depth * 0.80, rotation, JOINT, 0.045)
	for row in range(count):
		var offset := 0.0
		while offset < span - 0.055:
			var width := minf(random.randf_range(0.40, 0.82), span - offset)
			if row % 2 == 1 and offset == 0.0:
				width *= 0.74
			var stone_height := layer * random.randf_range(0.84, 1.04)
			var push := random.randf_range(-0.037, 0.037)
			var center := a + direction * (offset + width * 0.5) + Vector3(0, row * layer + push, 0)
			mesh.block(center, maxf(0.08, width - 0.036), stone_height,
				depth * random.randf_range(0.89, 1.11), rotation + random.randf_range(-0.03, 0.03),
				variation(STONE, 0.082), random.randf_range(0.028, 0.085), random.randf_range(-0.08, 0.08))
			offset += width
	var cap_offset := 0.14
	while cap_offset < span - 0.36:
		var width := minf(span - cap_offset, random.randf_range(0.42, 0.82))
		if random.randf() > 0.17:
			var cap := a + direction * (cap_offset + width * 0.5)
			cap.y += height - 0.035
			mesh.block(cap, width - 0.02, random.randf_range(0.13, 0.27), depth + 0.10,
				rotation + random.randf_range(-0.10, 0.10), variation(STONE, 0.065), 0.105, random.randf_range(-0.085, 0.085))
		cap_offset += width

func make_ruins(mesh: Builder, near_arch: Builder) -> void:
	arch(near_arch, Vector2(391, 238), 0.66, 1.18, 0.56, 7, near_arch == mesh)
	arch(mesh, Vector2(407, 167), 0.74, 1.44, 0.63, 7)
	arch(mesh, Vector2(281, 215), 0.43, 1.19, 0.60, 6)
	arch(mesh, Vector2(492, 178), 0.54, 1.46, 0.55, 5)
	blockwork(mesh, space(Vector2(210, 198)), space(Vector2(250, 185)), 1.34, 0.7)
	blockwork(mesh, space(Vector2(290, 183)), space(Vector2(316, 177)), 1.13, 0.59)
	blockwork(mesh, space(Vector2(414, 118)), space(Vector2(440, 127)), 1.84, 0.72)
	blockwork(mesh, space(Vector2(490, 147)), space(Vector2(521, 163)), 1.53, 0.64)
	blockwork(mesh, space(Vector2(536, 174)), space(Vector2(564, 210)), 1.19, 0.57)
	blockwork(mesh, space(Vector2(428, 170)), space(Vector2(473, 176)), 1.37, 0.61)
	blockwork(mesh, space(Vector2(300, 213)), space(Vector2(323, 205)), 1.43, 0.58)
	blockwork(mesh, space(Vector2(504, 190)), space(Vector2(531, 216)), 1.27, 0.61)
	steps(mesh, Vector2(384, 251), 1.70, 4, 0.10)
	steps(mesh, Vector2(408, 193), 2.10, 6, 0.122)
	steps(mesh, Vector2(270, 238), 1.55, 5, 0.105)
	outer_stair(mesh)
	for position in [Vector2(237,195), Vector2(299,187), Vector2(433,153), Vector2(522,169)]:
		ivy(mesh, space(position), 1.12)
	for index in range(19):
		var x := random.randf_range(-18, 18)
		var z := random.randf_range(-15.6, -11.8)
		var slab_tint := variation(Color(0.245, 0.330, 0.315, 1.0), 0.065)
		mesh.block(Vector3(x, -0.2, z), random.randf_range(1.15, 3.4),
			random.randf_range(2.9, 8.7), random.randf_range(0.9, 2.8),
			random.randf_range(-PI, PI), slab_tint, 0.28, random.randf_range(-0.41, 0.41))

func outer_stair(mesh: Builder) -> void:
	var count := 21
	for step in range(count):
		var progress := float(step) / (count - 1)
		var point := Vector2(161.0 - sin(progress * PI * 0.92) * 61.0, 625.0 - progress * 238.0)
		var rise := step * 0.072
		var rotation := lerpf(-0.49, 0.24, progress)
		var width := 1.24 + sin(progress * PI) * 0.25
		var tread := space(point)
		mesh.block(tread + Vector3(0, rise - 0.16, 0), width, 0.23, 0.40,
			rotation, variation(STONE, 0.053), 0.078, random.randf_range(-0.039, 0.039))
		if step % 2 == 1:
			mesh.block(tread + Vector3(-width * 0.49, -0.035, 0), 0.34,
				rise + 0.36, 0.57, rotation, variation(STONE.darkened(0.10), 0.062), 0.088)

func ivy(mesh: Builder, origin: Vector3, height: float) -> void:
	for branch_index in range(4):
		for index in range(12):
			var t := float(index) / 12.0
			var center := origin + Vector3(sin(t * 8.0 + branch_index) * 0.145 +
				branch_index * 0.105 - 0.15, t * height, 0.27)
			var size := random.randf_range(0.06, 0.16)
			var turn := -1.0 if index % 2 == 0 else 1.0
			var color := variation(Color(0.245, 0.365, 0.271, 0.58), 0.071)
			mesh.triangle(center, center + Vector3(turn * size, size * 0.75, 0.03),
				center + Vector3(turn * size * 1.08, -size * 0.25, 0.04), color, Vector3.BACK)

func arch(mesh: Builder, point: Vector2, radius: float, pillar: float, depth: float, upper_stones: int,
		trace_stone := true) -> void:
	var anchor := space(point)
	var ring := 0.32
	for side in [-1.0, 1.0]:
		for row in range(5):
			var layer := pillar / 5.0
			var center := anchor + Vector3(side * (radius + ring * 0.48), row * layer, 0)
			mesh.block(center, ring * 1.04, layer * 0.965, depth, random.randf_range(-0.048, 0.048),
				variation(STONE, 0.092), 0.05, random.randf_range(-0.055, 0.055))
	for index in range(upper_stones):
		var first := PI * index / 7.0 + 0.030
		var second := PI * (index + 1) / 7.0 - 0.029
		var cross_section := [Vector2(cos(first), sin(first)) * radius,
			Vector2(cos(second), sin(second)) * radius,
			Vector2(cos(second), sin(second)) * (radius + ring),
			Vector2(cos(first), sin(first)) * (radius + ring + random.randf_range(-0.029, 0.044))]
		var front := PackedVector3Array()
		var rear := PackedVector3Array()
		for stone in cross_section:
			var vertex := anchor + Vector3(stone.x, pillar + stone.y, 0)
			front.append(vertex + Vector3(0, 0, depth * 0.5))
			rear.append(vertex - Vector3(0, 0, depth * 0.5))
		var tint := variation(STONE, 0.08)
		mesh.quad(front[0], front[1], front[2], front[3], tint)
		if trace_stone:
			mesh.panel_stroke(front, PackedVector2Array([Vector2(0.015, 0.12), Vector2(0.38, 0.09),
				Vector2(0.66, 0.15), Vector2(0.98, 0.13)]), 0.024,
				Color(tint.darkened(0.54), 0.85), Vector3.BACK, false, false)
		mesh.quad(rear[3], rear[2], rear[1], rear[0], tint)
		for edge in range(4):
			var next := (edge + 1) % 4
			mesh.quad(rear[next], rear[edge], front[edge], front[next], tint)

func steps(mesh: Builder, point: Vector2, width: float, count: int, rise: float) -> void:
	var anchor := space(point)
	for step in range(count):
		var offset := float(step) * 0.28
		mesh.block(anchor + Vector3(0, -0.025, -offset), width + (count - step) * 0.04,
			(step + 1) * rise, 0.32, -0.08, variation(STONE, 0.041), 0.075, 0.018)

func make_tree(mesh: Builder, roots: Builder) -> void:
	var origin := space(Terrain.TRUNK)
	var trunk := PackedVector3Array([origin, origin + Vector3(-0.38,1.25,-0.23),
		origin + Vector3(-0.87,2.24,-0.19), origin + Vector3(-1.04,3.49,-0.66),
		origin + Vector3(-1.51,4.68,-0.71), origin + Vector3(-1.95,5.93,-0.96),
		origin + Vector3(-2.34,7.31,-1.13), origin + Vector3(-2.38,8.21,-1.61)])
	roots.smooth_tube(trunk, PackedFloat32Array([0.86,0.63,0.58,0.46,0.37,0.28,0.15,0.024]), BARK, 13, 0.10, true)
	if roots != mesh:
		roots.move_above(mesh, 1.88)
	for index in range(8):
		var direction := Vector3(cos(index * 2.399), 0, sin(index * 2.399))
		var length := random.randf_range(1.05, 2.04)
		var root_mesh := roots if index in [0, 3, 5] else mesh
		root_mesh.tube(PackedVector3Array([origin + Vector3(0,0.66,0),
			origin + direction * 0.67 + Vector3(0,0.20,0),
			origin + direction.rotated(Vector3.UP, 0.27) * length + Vector3(0,0.045,0)]),
			PackedFloat32Array([0.33, 0.27, 0.014]), BARK.darkened(0.08), 7, 0.15, true)
	branch(mesh, trunk[2], Vector3(3.35,1.06,-1.08), 0.24, 3, 1.0)
	branch(mesh, trunk[3], Vector3(-2.45,1.85,0.47), 0.29, 3, -1.0)
	branch(mesh, trunk[4], Vector3(3.30,2.15,-1.45), 0.36, 3, 1.0)
	branch(mesh, trunk[5], Vector3(-1.68,2.69,-0.43), 0.21, 2, -1.0)
	branch(mesh, trunk[6], Vector3(1.03,1.31,0.64), 0.11, 2, 1.0)
	branch(mesh, trunk[1], Vector3(-3.12,0.65,1.03), 0.16, 2, -1.0)
func branch(mesh: Builder, start: Vector3, extension: Vector3, radius: float, depth: int, side: float) -> void:
	var bend := Vector3(-0.26 * side, extension.length() * 0.15, extension.z * -0.19)
	var joint := start + extension * 0.51 + bend
	var hook := start + extension * 0.81 + bend * 0.33 + Vector3(0.20 * side, -0.13, 0.22 * side)
	var tip := start + extension
	mesh.smooth_tube(PackedVector3Array([start, joint, hook, tip]),
		PackedFloat32Array([radius, radius * 0.67, radius * 0.40, radius * 0.065]),
		variation(BARK, 0.034), 7, side * 0.082, true)
	if depth > 0:
		var fork := extension * 0.54 + Vector3(-0.54 * side, 0.31, 0.36 * side)
		branch(mesh, joint, fork, radius * 0.49, depth - 1, -side)
		branch(mesh, hook, extension * 0.39 + Vector3(0.20 * side, 0.34, -0.26), radius * 0.36, depth - 1, side)

func make_flora(mesh: Builder) -> void:
	for patch in range(92):
		var center := Vector2(random.randf_range(-100, 725), random.randf_range(80, 731))
		if Terrain.walkable(center) and random.randf() < 0.76:
			continue
		for leaf in range(6):
			var point := center + Vector2.from_angle(random.randf_range(0.0, TAU)) * random.randf_range(1.0, 29.0)
			if point.distance_to(Terrain.FIRE) < 47.0 or (Terrain.walkable(point) and random.randf() < 0.78):
				continue
			if leaf == 0 or leaf == 3:
				fern(mesh, space(point), random.randf_range(0.54, 0.95))
			else:
				grass(mesh, space(point), random.randf_range(0.15, 0.46))
	for run in Terrain.WALL_RUNS:
		for index in range(run.size() - 1):
			var a: Vector2 = run[index]
			var b: Vector2 = run[index + 1]
			for sample in range(4):
				var point := a.lerp(b, (sample + random.randf()) / 4.0) + a.direction_to(b).orthogonal() * 14.0
				if sample == 1:
					fern(mesh, space(point), random.randf_range(0.45, 0.81))
				else:
					grass(mesh, space(point), random.randf_range(0.26, 0.52))

func grass(mesh: Builder, root: Vector3, height: float) -> void:
	var tint := variation(GRASS, 0.069)
	var turn := random.randf() * TAU
	for leaf in range(7):
		var angle := turn + leaf * 2.399
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var edge := Vector3(-direction.z, 0, direction.x)
		var blade := height * random.randf_range(0.54, 1.18)
		var base := root + direction * random.randf_range(0.03, 0.16)
		var middle := base + direction * blade * 0.45 + Vector3(0, blade * 0.53, 0)
		var tip := base + direction * blade * 0.82 + Vector3(0, blade * 0.88, 0)
		mesh.triangle(base - edge * 0.030, base + edge * 0.046, middle, tint, Vector3.UP)
		mesh.triangle(middle - edge * 0.024, middle + edge * 0.042, tip, tint.lightened(0.065), Vector3.UP)

func fern(mesh: Builder, root: Vector3, scale_factor: float) -> void:
	var tint := variation(Color(0.246, 0.367, 0.313, 0.52), 0.050)
	var bias := random.randf_range(0, TAU)
	for part in range(4):
		var angle := bias + part * 2.399
		var axis := Vector3(cos(angle), 0, sin(angle))
		var across := Vector3(-axis.z, 0, axis.x)
		for leaf in range(1, 6):
			var progress := leaf / 6.0
			var center := root + axis * scale_factor * progress + Vector3(0, sin(progress * PI * 0.83) * scale_factor * 0.56, 0)
			var width := scale_factor * sin(PI * (progress * 0.84 + 0.1)) * 0.25
			for side in [-1.0, 1.0]:
				var tip: Vector3 = center + axis * scale_factor * 0.17 + across * width * side
				var leaf_middle: Vector3 = center.lerp(tip, 0.55) + Vector3(0, 0.027, 0)
				var left: Vector3 = leaf_middle - axis * scale_factor * 0.09
				var right: Vector3 = leaf_middle + axis * scale_factor * 0.081
				mesh.triangle(center, left, tip, tint, Vector3.UP)
				mesh.triangle(center, tip, right, tint.lightened(0.15), Vector3.UP)
				mesh.triangle(center + Vector3(0,0.005,0), tip + Vector3(0,0.005,0),
					leaf_middle + axis * 0.021 + Vector3(0,0.008,0), tint.darkened(0.29), Vector3.UP)

func make_scree(mesh: Builder) -> void:
	for index in range(156):
		var point := Vector2(random.randf_range(-170, 710), random.randf_range(87, 765))
		if point.distance_to(Terrain.FIRE) < 43.0:
			continue
		var on_path := Terrain.walkable(point)
		var size := random.randf_range(0.08, 0.20) if on_path else random.randf_range(0.15, 0.67)
		mesh.block(space(point), size * 1.52, size * 0.53, size,
			random.randf_range(-PI, PI), variation(STONE, 0.10), size * 0.26, random.randf_range(-0.26, 0.26))
	for index in range(11):
		var rotation := TAU * float(index) / 11.0
		var offset := Vector2.from_angle(rotation) * Vector2(17.4, 12.4)
		mesh.block(space(Terrain.FIRE + offset), 0.27, random.randf_range(0.08, 0.19), 0.20,
			rotation + PI * 0.5, variation(STONE, 0.088), 0.047)

	for index in range(5):
		var yaw := float(index) * 2.399
		var offset := Vector2.from_angle(yaw) * 6.2
		mesh.block(space(Terrain.FIRE + offset, 0.032 + index * 0.017), 0.41, 0.085,
			0.112, yaw, Color(0.27, 0.16, 0.13, 0.73), 0.026, 0.08)


func make_gate_meshes() -> void:
	for index in range(Terrain.GATES.size()):
		var gate := Builder.new()
		var center := space(Terrain.GATES[index])
		var direction := Vector2.from_angle(Terrain.GATE_ANGLES[index]) / MAP_SCALE
		var lane := Vector3(direction.x, 0.0, direction.y).normalized()
		for row in range(3):
			for stone in range(4):
				var at := center + lane * (stone - 1.5) * 0.222 + Vector3(0, row * 0.16, 0)
				gate.block(at, 0.206, 0.16, 0.29, plan_angle(lane), variation(STONE, 0.068), 0.033)
		var instance := add_mesh(gate, "Repaired breach %s" % (index + 1))
		instance.hide()
		gates.append(instance)

func variation(color: Color, amount: float) -> Color:
	var shift := random.randf_range(-amount, amount)
	return Color(color.r + shift, color.g + shift * 0.92, color.b + shift * 0.81, color.a)

func plan_angle(direction: Vector3) -> float:
	return atan2(direction.z, direction.x)
