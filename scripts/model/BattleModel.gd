extends Node3D

const Builder = preload("res://scripts/model/MeshBuilder.gd")
const MapData = preload("res://scripts/battle/BattleMaps.gd")
const PAINT = preload("res://scripts/model/battle_model.gdshader")
const EDGES = preload("res://scripts/model/relief_ink.gdshader")
const FLAME = preload("res://scripts/model/flame.gdshader")
const HAZE = preload("res://scripts/model/hearth_haze.gdshader")
const HEARTH_BRUSH = preload("res://scripts/model/hearth_brush.gdshader")
const PITCH := 0.86
const PIXELS := 55.0

const LAND := [
	[Color("#576e6b"), Color("#374e58"), Color("#85988c"), Color("#7b8074")],
	[Color("#a6846c"), Color("#5f565d"), Color("#c1a079"), Color("#ac8b70")],
	[Color("#506b68"), Color("#385d60"), Color("#859477"), Color("#8e876e")],
	[Color("#748296"), Color("#3c4e60"), Color("#acb8c2"), Color("#8e9196")]
]
const REGIONS := [
	preload("res://scripts/model/FallenKing.gd"),
	preload("res://scripts/model/Sandstone.gd"),
	preload("res://scripts/model/RootKeep.gd"),
	preload("res://scripts/model/Obsidian.gd"),
]

var mesh := Builder.new()
var contour := Builder.new()
var random := RandomNumberGenerator.new()
var layout: Dictionary
var palette: Array
var camera: Camera3D
var material: ShaderMaterial
var stroke: ShaderMaterial
var moon: DirectionalLight3D
var hearth_light: OmniLight3D
var carry_lamp: SpotLight3D
var hearth_flame: MeshInstance3D
var fire_paint: ShaderMaterial
var haze_layers: Array[ShaderMaterial] = []
var hearth_paints: Array[ShaderMaterial] = []
var hearth_strokes: Builder
var canal_paint: ShaderMaterial
var air: Environment
var bridges: Array[Node3D] = []
var crystal_nodes: Array[Node3D] = []

func build_region(region: int) -> void:
	random.seed = 57429 + region * 374
	layout = MapData.MAPS[region].duplicate()
	var anchor_points: Array = []
	for support in MapData.SUPPORTS[region]:
		anchor_points.append(support[0])
	layout["slots"] = anchor_points
	palette = LAND[region]
	make_camera()
	if region == 0:
		hearth_strokes = Builder.new()
	make_ground(region not in [0, 1])
	REGIONS[region].build(self)
	if region in [0, 2]:
		make_ground_cover(region)
	var land := MeshInstance3D.new()
	land.name = "Terrain, ruins and landmarks"
	land.mesh = mesh.build()
	land.material_override = material
	add_child(land)
	var detail := MeshInstance3D.new()
	detail.name = "Charcoal cuts on the masonry"
	detail.mesh = contour.build()
	detail.material_override = material
	detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(detail)
	make_hearth_flame()
	make_hearth_haze()
	if region in [0, 1]:
		make_hearth_pigment()
	if region == 2:
		make_drawbridges()
	if region == 3:
		make_crystals()
	mesh = null
	contour = null

func make_camera() -> void:
	var environment := WorldEnvironment.new()
	air = Environment.new()
	air.background_mode = Environment.BG_COLOR
	air.background_color = palette[1].darkened(0.49)
	air.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	air.ambient_light_color = Color("#b7c9cb")
	air.ambient_light_energy = 0.72
	environment.environment = air
	add_child(environment)
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-53, -32, 0)
	moon.light_color = Color("#e5ebd5")
	moon.light_energy = 0.44
	moon.shadow_enabled = true
	moon.shadow_blur = 1.8
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 50.0
	add_child(moon)
	hearth_light = OmniLight3D.new()
	var pair: Array = layout["fire"]
	hearth_light.position = at(pair[0],pair[1],0.93)
	hearth_light.omni_range = 6.6
	hearth_light.omni_attenuation = 1.37
	hearth_light.light_color = Color("#ffac66")
	hearth_light.light_energy = 1.15
	hearth_light.shadow_enabled = true
	hearth_light.shadow_bias = 0.14
	add_child(hearth_light)
	carry_lamp = SpotLight3D.new()
	carry_lamp.spot_range = 4.85
	carry_lamp.spot_angle = 38.0
	carry_lamp.spot_angle_attenuation = 0.72
	carry_lamp.spot_attenuation = 1.34
	carry_lamp.light_color = Color("#ffc278")
	carry_lamp.shadow_enabled = true
	carry_lamp.shadow_bias = 0.125
	carry_lamp.shadow_blur = 1.6
	add_child(carry_lamp)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = MapData.SIZE.y / PIXELS
	camera.near = 0.1
	camera.far = 85.0
	add_child(camera)
	camera.position = Vector3(0.0, sin(PITCH) * 29.0, cos(PITCH) * 29.0)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	material = ShaderMaterial.new()
	material.shader = PAINT
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	screen.mesh = quad
	screen.extra_cull_margin = 100.0
	stroke = ShaderMaterial.new()
	stroke.shader = EDGES
	stroke.render_priority = 85
	stroke.set_shader_parameter("air_pigment", palette[1].lightened(0.10))
	screen.material_override = stroke
	camera.add_child(screen)

func animate(clock: float, bridge_closed: int, crystals: Array[Dictionary]) -> void:
	material.set_shader_parameter("seconds", clock)
	stroke.set_shader_parameter("seconds", clock)
	if canal_paint != null:
		canal_paint.set_shader_parameter("seconds", clock)
	for index in range(bridges.size()):
		var bridge := bridges[index]
		var inclination := -1.02 if index == bridge_closed else 0.0
		bridge.rotation.x = lerpf(bridge.rotation.x, inclination, 0.095)
	for index in range(crystal_nodes.size()):
		crystal_nodes[index].visible = crystals[index]["hp"] > 0.0

func paint_textured_prop(prop: Node3D) -> void:
	var surfaces := prop.find_children("*", "MeshInstance3D", true, false)
	if prop is MeshInstance3D:
		surfaces.append(prop)
	for surface: MeshInstance3D in surfaces:
		if surface.mesh == null:
			continue
		for index in range(surface.mesh.get_surface_count()):
			var imported := surface.get_active_material(index) as StandardMaterial3D
			if imported == null or imported.albedo_texture == null or imported.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var brush := material.duplicate() as ShaderMaterial
			brush.set_shader_parameter("has_pigment_atlas", true)
			brush.set_shader_parameter("pigment_atlas", imported.albedo_texture)
			brush.set_shader_parameter("pigment_tint", imported.albedo_color)
			surface.set_surface_override_material(index, brush)

func relight(night: bool, fuel: float, clock: float) -> void:
	moon.light_color = Color("#91aed1") if night else Color("#dde9e2")
	moon.light_energy = 0.32 if night else 0.49
	air.ambient_light_color = Color("#b0c7d4") if night else Color("#c5d3cc")
	air.ambient_light_energy = 0.61 if night else 0.77
	var flicker := 0.97 + sin(clock * 9.5) * 0.066 + sin(clock * 21.6) * 0.028
	hearth_light.light_energy = fuel * flicker * (1.24 if night else 0.92)
	hearth_light.omni_range = lerpf(2.2, 6.6 if hearth_paints.is_empty() else 7.1, fuel)
	hearth_flame.visible = fuel > 0.0
	fire_paint.set_shader_parameter("t",clock)
	fire_paint.set_shader_parameter("fuel",fuel)
	for layer in haze_layers:
		layer.set_shader_parameter("clock", clock)
		layer.set_shader_parameter("fuel", fuel * (1.0 if night else 0.64))
	for paint in hearth_paints:
		paint.set_shader_parameter("fuel", fuel)
		paint.set_shader_parameter("intensity", flicker * (1.0 if night else 0.77))

func lantern(point: Vector2, direction: Vector2, active: bool, night: bool, radius_scale: float, mount: Node3D) -> void:
	carry_lamp.visible = active
	if active:
		var ahead := point + (direction if direction.length_squared() > 0.005 else Vector2.RIGHT) * 136.0
		var target := screen_floor(ahead, 0.01)
		var center := mount.to_global(Vector3(0.0, -0.15, 0.0))
		carry_lamp.global_position = center + center.direction_to(target) * 0.15
		carry_lamp.look_at(target)
		carry_lamp.light_energy = 1.16 if night else 0.70
		carry_lamp.spot_range = 4.85 * radius_scale

func make_hearth_flame() -> void:
	hearth_flame = MeshInstance3D.new()
	var body := QuadMesh.new()
	body.size = Vector2(0.90,0.74)
	hearth_flame.mesh = body
	var at_fire: Array = layout["fire"]
	hearth_flame.position = at(at_fire[0],at_fire[1],0.04)
	hearth_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire_paint = ShaderMaterial.new()
	fire_paint.shader = FLAME
	fire_paint.render_priority = 100
	hearth_flame.material_override = fire_paint
	add_child(hearth_flame)

func make_hearth_haze() -> void:
	var hearth: Array = layout["fire"]
	for index in range(3):
		var layer := MeshInstance3D.new()
		layer.name = "Low firelit haze"
		var plane := PlaneMesh.new()
		plane.size = Vector2(3.9, 3.0) - Vector2(0.67, 0.50) * index
		layer.mesh = plane
		layer.position = at(hearth[0], hearth[1], 0.043 + index * 0.28)
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var paint := ShaderMaterial.new()
		paint.shader = HAZE
		paint.render_priority = 92 + index
		paint.set_shader_parameter("thickness", 0.18 - float(index) * 0.034)
		layer.material_override = paint
		haze_layers.append(paint)
		add_child(layer)

func make_hearth_pigment() -> void:
	var hearth: Array = layout["fire"]
	var ground_plane := PlaneMesh.new()
	ground_plane.size = Vector2(11.9, 10.8)
	var wash := add_hearth_paint("Firelit pigment on the soil", ground_plane, false)
	wash.position = at(hearth[0], hearth[1], 0.040)
	if hearth_strokes != null:
		add_hearth_paint("Firelit edges of roots and stone", hearth_strokes.build(), true)
		hearth_strokes = null
	hearth_light.light_color = Color("#ffa35b")
	hearth_light.omni_attenuation = 1.14

func add_hearth_paint(label: String, geometry: Mesh, accent: bool) -> MeshInstance3D:
	var painted := MeshInstance3D.new()
	painted.name = label
	painted.mesh = geometry
	painted.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := ShaderMaterial.new()
	paint.shader = HEARTH_BRUSH
	paint.render_priority = 89 if accent else 86
	paint.set_shader_parameter("accent", accent)
	painted.material_override = paint
	hearth_paints.append(paint)
	add_child(painted)
	return painted

func hearth_stroke(path: PackedVector3Array, width: float, weight: float) -> void:
	var radii := PackedFloat32Array()
	for index in range(path.size()):
		var pressure := sin(float(index) / (path.size() - 1) * PI)
		radii.append(maxf(0.002, pressure * width))
	hearth_strokes.tube(path, radii, Color(1.0, 1.0, 1.0, weight), 5, 0.04)

func at(x: float, y: float, height := 0.0) -> Vector3:
	return screen_floor(MapData.ART.position + Vector2(x, y) / MapData.SKETCH * MapData.ART.size, height)

func screen_floor(point: Vector2, height := 0.0) -> Vector3:
	var screen := point - MapData.SIZE * 0.5
	return Vector3(screen.x / PIXELS, height, screen.y / (PIXELS * sin(PITCH)))

func from_floor(point: Vector2, height := 0.0) -> Vector3:
	return at(point.x, point.y, height)

func make_ground(draw_hearth_pad: bool) -> void:
	var low: Color = palette[0]
	var soil := Color(low, 0.22)
	var ground := [Vector2(-85,-108), Vector2(861,-108), Vector2(861,568), Vector2(-85,568)]
	patch(ground, -0.055, soil)
	for pair in layout["routes"]:
		var points: Array[Vector2] = []
		for item in pair:
			points.append(Vector2(item[0], item[1]))
		trail(points, 10.6, Color(low.lerp(palette[3], 0.61), 0.32))
	var fire_pair: Array = layout["fire"]
	var hearth := Vector2(fire_pair[0], fire_pair[1])
	if draw_hearth_pad:
		ring_patch(hearth, Vector2(42, 27), 0.033, Color(palette[3], 0.32), 19)
	for index in range(11):
		var anchor := hearth + Vector2(cos(float(index) * TAU / 11.0) * 12.5, sin(float(index) * TAU / 11.0) * 9.5)
		stone(anchor.x, anchor.y, 4.7, 5.2, random.randf_range(0.09,0.16), Color("#6c6861"), index * 0.57)
	for index in range(4):
		var ember := hearth + Vector2(sin(index*2.39)*2.5, cos(index*2.39)*3.1)
		stone(ember.x,ember.y,13.6,2.9,0.081,Color("#573b2c"),index*2.399,0.03+index*0.028)
	for index in range(145):
		var p := Vector2(random.randf_range(-14,780), random.randf_range(-13,504))
		var in_path := p.distance_to(hearth) < 38.0 or route_distance(p) < 19.0 or slot_distance(p) < 20.0
		if in_path:
			continue
		var width := random.randf_range(4, 12)
		stone(p.x, p.y, width, width * random.randf_range(0.8, 1.35), random.randf_range(0.06,0.27),
			weathered(palette[1], 0.11), random.randf_range(-PI,PI))
		if index % 3 == 0 and p.y > 8:
			tuft(p, random.randf_range(0.12,0.30), weathered(palette[2], 0.10))

func route_distance(at_point: Vector2) -> float:
	var best := 10000.0
	for positions in layout["routes"]:
		for index in range(positions.size() - 1):
			var a := Vector2(positions[index][0], positions[index][1])
			var b := Vector2(positions[index+1][0], positions[index+1][1])
			best = minf(best, at_point.distance_to(Geometry2D.get_closest_point_to_segment(at_point, a, b)))
	return best

func slot_distance(at_point: Vector2) -> float:
	var best := 10000.0
	for slot in layout["slots"]:
		best = minf(best, at_point.distance_to(Vector2(slot[0], slot[1])))
	return best

func trail(points: Array[Vector2], half_width: float, tint: Color) -> void:
	var curve := Curve2D.new()
	curve.bake_interval = 9.0
	for index in range(points.size()):
		var previous := points[maxi(index - 1, 0)]
		var next := points[mini(index + 1, points.size() - 1)]
		var tangent := (next - previous) * 0.13
		curve.add_point(points[index], -tangent, tangent)
	var samples := curve.get_baked_points()
	var back := PackedVector2Array()
	var front := PackedVector2Array()
	for index in range(samples.size()):
		var a := samples[maxi(0, index - 1)]
		var b := samples[mini(samples.size() - 1, index + 1)]
		var side := a.direction_to(b).orthogonal() * (half_width + sin(index * 0.57) * 2.3 + cos(index * 0.19) * 2.0)
		back.append(samples[index] - side)
		front.append(samples[index] + side)
	for index in range(samples.size() - 1):
		var grain := sin(0.55 * index + samples[index].y * 0.12)
		var edge: Color = palette[0].lerp(tint, 0.54 + grain * 0.05)
		var stride_a := back[index].lerp(front[index], 0.20 + grain * 0.07)
		var stride_b := back[index].lerp(front[index], 0.80 + grain * 0.06)
		var next_a := back[index + 1].lerp(front[index + 1], 0.20 + grain * 0.07)
		var next_b := back[index + 1].lerp(front[index + 1], 0.80 + grain * 0.06)
		mesh.quad(from_floor(front[index], 0.014), from_floor(stride_b, 0.016),
			from_floor(next_b, 0.016), from_floor(front[index + 1], 0.014), edge)
		mesh.quad(from_floor(stride_b, 0.016), from_floor(stride_a, 0.016),
			from_floor(next_a, 0.016), from_floor(next_b, 0.016), tint)
		mesh.quad(from_floor(stride_a, 0.016), from_floor(back[index], 0.014),
			from_floor(back[index + 1], 0.014), from_floor(next_a, 0.016), edge)

func weathered(tint: Color, amount: float) -> Color:
	var shift := random.randf_range(-amount, amount)
	return Color(tint.r + shift, tint.g + shift * 0.87, tint.b + shift * 0.72, tint.a)

func pencil(path: PackedVector3Array, strength: float, tint: Color) -> void:
	var widths := PackedFloat32Array()
	for index in range(path.size()):
		var pressure := sin(float(index + 1) * PI / (path.size() + 1))
		widths.append(maxf(0.004, pressure * strength))
	contour.tube(path, widths, tint, 5, 0.025)

func sculpture(label: String, draw_mesh: Callable) -> void:
	var ground := mesh
	mesh = Builder.new()
	draw_mesh.call()
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh.build()
	part.material_override = material
	part.set_meta(&"walk_obstacle", true)
	add_child(part)
	mesh = ground

func make_ground_cover(region: int) -> void:
	var pockets := [
		[Vector2(49,305),Vector2(137,281),Vector2(141,364),Vector2(197,396),Vector2(248,373),
			Vector2(222,200),Vector2(290,203),Vector2(315,258),Vector2(312,348),
			Vector2(353,296),Vector2(375,427),Vector2(543,383),Vector2(566,327),Vector2(626,275)],
		[Vector2(243,248),Vector2(286,200),Vector2(351,192),Vector2(436,201),Vector2(462,223),
			Vector2(303,292),Vector2(343,305),Vector2(400,303),Vector2(448,288),Vector2(526,285),
			Vector2(173,322),Vector2(214,403),Vector2(315,419),Vector2(538,393),Vector2(566,348)]
	]
	for at: Vector2 in pockets[0 if region == 0 else 1]:
		for bunch in range(6):
			var pick := at + Vector2.from_angle(bunch * 2.399 + at.y) * (2.3 + bunch * 3.45)
			if route_distance(pick) < 13.0 or slot_distance(pick) < 14.0:
				continue
			var root := from_floor(pick, 0.016)
			var tone: Color = weathered(palette[2].darkened(0.16), 0.10)
			for blade in range(6):
				var angle := blade * 2.399 + bunch
				var axis := Vector3(cos(angle), 0.0, sin(angle))
				var across := axis.cross(Vector3.UP)
				var length := random.randf_range(0.13, 0.39) * (1.15 if blade == 0 else 1.0)
				var begin := root + axis * (0.025 + blade * 0.003)
				var belly := begin + axis * length * 0.37 + Vector3.UP * length * 0.60
				var tip := begin + axis * length * 0.93 + Vector3.UP * length * 0.50
				var width := length * random.randf_range(0.070, 0.16)
				contour.triangle(begin, belly + across * width, tip, tone.lightened(0.11), Vector3.UP)
				contour.triangle(begin, tip, belly - across * width * 0.59, tone.darkened(0.13), Vector3.UP)
				if blade == 0:
					pencil(PackedVector3Array([begin, belly + Vector3.UP * 0.008, tip]), 0.008, tone.darkened(0.36))

func stone(x: float, y: float, width: float, depth: float, height: float, tint: Color,
		angle := 0.0, base := 0.0) -> void:
	var width_world := width * MapData.ART.size.x / MapData.SKETCH.x / PIXELS
	var depth_world := depth * MapData.ART.size.y / MapData.SKETCH.y / (PIXELS * sin(PITCH))
	var bevel := minf(minf(width_world, depth_world) * 0.24, 0.31)
	mesh.block(at(x,y,base), width_world, height, depth_world, angle, tint, bevel,
		sin(x * 0.48 + y * 0.07) * minf(height * 0.09,0.09), height > 0.58 and width >= 23)

func patch(points: Array, height: float, tint: Color) -> void:
	var shape := PackedVector2Array(points)
	var triangles := Geometry2D.triangulate_polygon(shape)
	for index in range(0, triangles.size(), 3):
		mesh.triangle(from_floor(shape[triangles[index]], height), from_floor(shape[triangles[index + 2]], height),
			from_floor(shape[triangles[index + 1]], height), tint, Vector3.UP)

func ring_patch(center: Vector2, radii: Vector2, height: float, tint: Color, sides := 12) -> void:
	var points: Array[Vector2] = []
	for index in range(sides):
		var direction := Vector2.from_angle(float(index) / sides * TAU)
		var roughness := 0.96 + 0.08 * sin(index * 2.1 + center.x)
		points.append(center + radii * direction * roughness)
	patch(points, height, tint)

func wall(points: Array, height: float, tint: Color, thickness := 21.0) -> void:
	for segment in range(points.size() - 1):
		var a: Vector2 = points[segment]
		var b: Vector2 = points[segment + 1]
		var length := a.distance_to(b)
		var courses := maxi(1, ceili(height / 0.48))
		var rise := height / courses
		var rotation := (at(b.x, b.y) - at(a.x,a.y)).signed_angle_to(Vector3.RIGHT, Vector3.UP)
		for row in range(courses):
			var span := 0.0
			while span < length - 2.0:
				var width := minf(length - span, random.randf_range(17.0, 31.0))
				if span == 0.0 and row % 2 == 1:
					width = maxf(3.0, width * 0.57)
				var center := a.lerp(b, (span + width * 0.5) / length)
				var broken := row == courses - 1 and random.randf() < 0.09
				stone(center.x, center.y, width + 0.30, thickness + random.randf_range(-1.9,1.9), rise * (0.76 if broken else 1.02),
					weathered(tint, 0.053), rotation + random.randf_range(-0.054,0.054), row * rise)
				span += width
		var count := maxi(1, roundi(length / 30.0))
		for index in range(count):
			if random.randf() < 0.21:
				continue
			var center := a.lerp(b,(index + 0.5) / count)
			stone(center.x,center.y,length/count-0.2,thickness*1.17,random.randf_range(0.14,0.28),
				weathered(tint.lightened(0.09), 0.038),rotation,height)

func steps(start: Vector2, end: Vector2, width: float, height: float, count: int, tint: Color) -> void:
	var run := end - start
	var rotation := (from_floor(end) - from_floor(start)).signed_angle_to(Vector3.BACK, Vector3.UP)
	for index in range(count):
		var fraction := float(index) / float(count)
		var center := start + run * fraction
		stone(center.x,center.y,width,run.length() / count * 1.3,height * (index + 1) / count,
			weathered(tint, 0.043),rotation)

func arch(center: Vector2, width: float, height: float, tint: Color, angle := 0.0) -> void:
	var anchor := from_floor(center)
	var n := Vector3(cos(angle),0,sin(angle))
	var depth := Vector3(-sin(angle),0,cos(angle))
	var radius := width * 0.5 * MapData.ART.size.x / MapData.SKETCH.x / PIXELS
	var ring := minf(0.33, radius * 0.43)
	var spring := maxf(maxf(height, 1.81) - radius, 0.52)
	var brick_depth := ring * 2.15
	for sign in [-1.0,1.0]:
		for row in range(4):
			var place: Vector3 = anchor + n * sign * (radius + ring * 0.52) + Vector3.UP * row * spring / 4
			mesh.block(place, ring * 1.12, spring / 4.0, brick_depth, angle, weathered(tint, 0.06), 0.053, 0.025, false)
	for index in range(9):
		var first := float(index) * PI / 9.0 + 0.013
		var second := float(index + 1) * PI / 9.0 - 0.013
		var wedge := [Vector2.from_angle(first) * radius, Vector2.from_angle(second) * radius,
			Vector2.from_angle(second) * (radius + ring), Vector2.from_angle(first) * (radius + ring)]
		var front := PackedVector3Array()
		var rear := PackedVector3Array()
		for point in wedge:
			var p: Vector3 = anchor + n * point.x + Vector3.UP * (spring + point.y)
			front.append(p + depth * brick_depth * 0.5)
			rear.append(p - depth * brick_depth * 0.5)
		var face := weathered(tint, 0.068)
		mesh.quad(front[0],front[1],front[2],front[3],face)
		mesh.quad(rear[3],rear[2],rear[1],rear[0],face)
		for edge in range(4):
			var next := (edge + 1) % 4
			mesh.quad(rear[next],rear[edge],front[edge],front[next],face)
		if index % 3 == 1:
			var ridge := front[0].lerp(front[3], 0.55)
			var crack := front[1].lerp(front[2], 0.72)
			var shift := depth * 0.012
			pencil(PackedVector3Array([ridge + shift, ridge.lerp(crack, 0.44) + shift + Vector3.DOWN * 0.019,
				ridge.lerp(crack, 0.65) + shift, crack + shift]), 0.014, tint.darkened(0.34))

func ellipsoid(center: Vector3, radii: Vector3, tint: Color, sides := 12, bands := 7) -> void:
	var previous := PackedVector3Array()
	for j in range(bands + 1):
		var elevation := lerpf(-PI * 0.5, PI * 0.5, float(j) / bands)
		var current := PackedVector3Array()
		for i in range(sides):
			var theta := TAU * float(i) / sides
			var variation := 1.0 + sin(i * 12.27 + j * 7.45) * 0.038
			var direction := Vector3(cos(theta) * cos(elevation), sin(elevation), sin(theta) * cos(elevation))
			current.append(center + direction * radii * variation)
		if j > 0:
			for i in range(sides):
				var next := (i + 1) % sides
				if j == 1:
					mesh.triangle(previous[i],current[i],current[next],tint)
				elif j == bands:
					mesh.triangle(previous[i],current[i],previous[next],tint)
				else:
					mesh.quad(previous[i],current[i],current[next],previous[next],tint)
		previous = current

func tuft(center: Vector2, height: float, tint: Color) -> void:
	var origin := from_floor(center)
	for index in range(5):
		var angle := index * 2.399
		var bend := Vector3(cos(angle),0,sin(angle))
		var across := Vector3(-bend.z,0,bend.x) * 0.023
		var base := origin + bend * 0.033
		var tip := base + bend * height * 0.67 + Vector3.UP * height * (0.72 + index * 0.095)
		mesh.triangle(base-across,base+across,tip,tint,Vector3.UP)

func make_drawbridges() -> void:
	for index in range(layout["bridges"].size()):
		var pair: Array = layout["bridges"][index]
		var scene_root := Node3D.new()
		scene_root.position = at(pair[0],pair[1],0.16)
		scene_root.rotation.y = -0.66 if index == 0 else 0.56
		add_child(scene_root)
		bridges.append(scene_root)
		var planks := Builder.new()
		for row in range(9):
			planks.block(Vector3(0, 0, (row - 4) * 0.14), 1.24, 0.07, 0.132, 0,
				weathered(Color("#816450"),0.09),0.018,0.018,false)
		for side in [-1.0,1.0]:
			planks.block(Vector3(side * 0.55,0.08,0),0.066,0.10,1.22,0,Color("#584536"),0.019,0,false)
		var deck := MeshInstance3D.new()
		deck.mesh = planks.build()
		deck.material_override = material
		scene_root.add_child(deck)

func make_crystals() -> void:
	for pair in layout["crystals"]:
		var prism := Builder.new()
		for index in range(4):
			var base := Vector3(cos(index * 2.399) * 0.28,0,sin(index * 2.399) * 0.28)
			var tip := base * 1.43 + Vector3.UP * (0.56 + index * 0.14)
			var widths := PackedFloat32Array([0.20-index*0.021,0.14-index*0.014,0.006])
			prism.tube(PackedVector3Array([base,base.lerp(tip,0.70),tip]), widths,
				Color("#60b8aa").lightened(index*0.067),5,0.22,false)
		var rocks := MeshInstance3D.new()
		rocks.mesh = prism.build()
		rocks.material_override = material
		rocks.position = at(pair[0], pair[1])
		add_child(rocks)
		crystal_nodes.append(rocks)
