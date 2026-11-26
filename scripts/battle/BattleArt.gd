extends Node2D

const MapData = preload("res://scripts/battle/BattleMaps.gd")
const Landscape = preload("res://scripts/model/BattleModel.gd")
const Works = preload("res://scripts/model/RelicWorks.gd")
const Impact = preload("res://scripts/model/BattleImpact.gd")
const Puppets = preload("res://scripts/model/CombatPuppets.gd")
const GOLD := Color("#ffe0a0")
const TEAL := Color("#8adebc")
const BLACK := Color("#152622")
const SKY := Color("#a8c5c9")

var battle
var texture: Texture2D
var model: Landscape
var reliquary: Node3D
var puppets: Puppets
var impact: Impact
var combat_camera: Camera2D
var fire_particles: CPUParticles2D
var support_range: MeshInstance3D
var support_range_material: StandardMaterial3D
var range_origin := Vector2.ZERO
var range_current := 0.0
var range_planned := 0.0
var colors := PackedColorArray([Color("#efb963"), Color("#ffdba1"), Color("#ee7d4c"), Color("#00000000")])

func initialize(level) -> void:
	battle = level
	var view := SubViewport.new()
	view.size = Vector2i(MapData.SIZE)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_2X
	add_child(view)
	model = Landscape.new()
	view.add_child(model)
	model.build_region(battle.biome)
	texture = view.get_texture()
	var fire := CPUParticles2D.new()
	fire.position = battle.fire_point - Vector2(0, 12)
	fire.amount = 22
	fire.lifetime = 1.5
	fire.direction = Vector2(0.1, -1)
	fire.spread = 32.0
	fire.gravity = Vector2(2, -13)
	fire.initial_velocity_min = 8.0
	fire.initial_velocity_max = 41.0
	fire.scale_amount_min = 1.8
	fire.scale_amount_max = 3.4
	fire.color = Color("#fbb775")
	var fragment := Image.create_empty(3, 3, false, Image.FORMAT_RGBA8)
	for point in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		fragment.set_pixelv(point, Color.WHITE)
	fire.texture = ImageTexture.create_from_image(fragment)
	var fade := Gradient.new()
	fade.colors = colors
	fire.color_ramp = fade
	add_child(fire)
	fire_particles = fire
	support_range = MeshInstance3D.new()
	support_range.name = "Support range on the ground"
	support_range.mesh = ImmediateMesh.new()
	support_range.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	support_range.hide()
	model.add_child(support_range)
	support_range_material = StandardMaterial3D.new()
	support_range_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	support_range_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	support_range_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	support_range_material.vertex_color_use_as_albedo = true
	support_range_material.render_priority = 90

func hide_support_range() -> void:
	support_range.hide()

func show_support_range(at: Vector2, current: float, planned: float) -> void:
	if current <= 0.0 and planned <= 0.0:
		hide_support_range()
		return
	support_range.show()
	if at == range_origin and current == range_current and planned == range_planned:
		return
	range_origin = at
	range_current = current
	range_planned = planned
	var mesh := support_range.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, support_range_material)
	if current > 0.0:
		trace_support_range(mesh, at, current, false)
	if planned > 0.0 and not is_equal_approx(current, planned):
		trace_support_range(mesh, at, planned, true)
	mesh.surface_end()

func trace_support_range(mesh: ImmediateMesh, at: Vector2, radius: float, planned: bool) -> void:
	const SEGMENTS := 120
	const ABOVE_GROUND := 0.11
	var center := at + Vector2(0, ABOVE_GROUND * Landscape.PIXELS * cos(Landscape.PITCH))
	var hue := Color("#f1c88dbe") if not planned else Color("#e6cd9cb0")
	for segment in SEGMENTS:
		if planned and segment % 6 >= 4:
			continue
		var a := Vector2.from_angle(TAU * segment / SEGMENTS)
		var b := Vector2.from_angle(TAU * (segment + 1) / SEGMENTS)
		var left := model.screen_floor(center + a * (radius - 1.45), ABOVE_GROUND)
		var right := model.screen_floor(center + b * (radius - 1.45), ABOVE_GROUND)
		var far_left := model.screen_floor(center + a * (radius + 1.45), ABOVE_GROUND)
		var far_right := model.screen_floor(center + b * (radius + 1.45), ABOVE_GROUND)
		mesh.surface_set_color(hue)
		for p in [left, right, far_right, left, far_right, far_left]:
			mesh.surface_add_vertex(p)

func attach_combat() -> void:
	battle.combat.campfire.hide()
	reliquary = Works.new()
	model.add_child(reliquary)
	reliquary.setup(model, battle)
	impact = Impact.new()
	model.add_child(impact)
	impact.setup(model, battle.combat)
	puppets = Puppets.new()
	model.add_child(puppets)
	puppets.setup(model, battle)
	combat_camera = Camera2D.new()
	combat_camera.name = "Combat presentation camera"
	combat_camera.position = MapData.SIZE * 0.5
	add_child(combat_camera)
	combat_camera.make_current()

func _process(delta: float) -> void:
	if not is_instance_valid(battle):
		return
	if battle.paused:
		combat_camera.offset = Vector2.ZERO
		return
	if is_instance_valid(puppets):
		puppets.sync(delta)
	if is_instance_valid(reliquary):
		reliquary.sync(battle.clock)
	if is_instance_valid(impact):
		impact.step(delta)
		combat_camera.offset = impact.camera_offset()
		impact.trace_blade(delta, puppets.sword_mount, battle.combat.watcher.swing > 0.0,
			battle.combat.strike_heavy)
	if is_instance_valid(model):
		var range_factor: float = (0.70 if battle.biome == 0 and battle.weather_left > 0.0 else 1.0) * (1.0 + battle.perks["lamp"] * 0.16)
		model.lantern(battle.player, battle.aim, battle.lantern_on and battle.oil > 0.0,
			battle.night, range_factor, puppets.lantern_mount)

func update_art() -> void:
	model.animate(battle.clock, battle.bridge_closed, battle.crystals)
	model.relight(battle.night, battle.fire_hp / 100.0, battle.clock)
	fire_particles.emitting = battle.fire_hp > 0.0
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(battle) or texture == null:
		return
	draw_texture_rect(texture, Rect2(Vector2.ZERO, MapData.SIZE), false)
	if battle.show_routes:
		draw_routes()
	if not battle.night:
		draw_support_hints()
	if battle.biome == 0:
		draw_mud()
	elif battle.biome == 2:
		draw_bridges()
	elif battle.biome == 3:
		draw_crystals()
	for item in battle.supplies:
		if not item["available"]:
			continue
		var at: Vector2 = item["position"]
		draw_supply(at, item["bone"] > 0, float(item["phase"]))
	draw_weather()

func draw_support_hints() -> void:
	for index in range(battle.slot_points.size()):
		var at: Vector2 = battle.slot_points[index]
		var distance: float = battle.player.distance_to(at)
		if distance > 128.0:
			continue
		var lift := float(MapData.SUPPORTS[battle.biome][index][1]) * Landscape.PIXELS * cos(Landscape.PITCH)
		var cue := at + Vector2(0, -lift - 16)
		var color := Color(GOLD, 0.26 + 0.55 * (1.0 - distance / 128.0))
		draw_polyline([cue + Vector2(-5, 0), cue + Vector2(0, -4), cue + Vector2(5, 0),
			cue + Vector2(0, 4), cue + Vector2(-5, 0)], color, 1.3, true)

func draw_routes() -> void:
	for index in range(battle.paths.size()):
		var route: PackedVector2Array = battle.route_for_actor(index, 10.0)
		if route.is_empty():
			continue
		var tint := Color("#e8af775d") if index == 0 else Color("#d0cdb54f")
		for segment in range(route.size() - 1):
			draw_dashed_line(route[segment], route[segment + 1], tint, 1.6, 7.0, true)
		draw_circle(route[0], 11, Color("#101b1ccc"), true, -1.0, true)
		draw_arc(route[0], 11, 0, TAU, 28, tint, 1.6, true)
		draw_string(battle.font, route[0] + Vector2(-4, 5), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)

func draw_mud() -> void:
	for shape in battle.mud:
		draw_colored_polygon(shape, Color("#5e9a7a19"))
		if battle.show_routes:
			draw_polyline(shape + PackedVector2Array([shape[0]]), Color("#7dbd9570"), 1.1, true)

func draw_bridges() -> void:
	for index in range(battle.bridges.size()):
		var at: Vector2 = battle.bridges[index]
		var axis := Vector2(1, -0.8) if index == 0 else Vector2(0.9, 0.7)
		var cross := axis.orthogonal().normalized() * 17
		if battle.bridge_closed == index:
			draw_dashed_line(at - cross, at + cross, Color("#f498615e"), 2.0, 4.0, true)
		var lever: Vector2 = battle.levers[index]
		draw_circle(lever, 8.0, BLACK, true, -1.0, true)
		draw_arc(lever, 8, 0, TAU, 24, GOLD if battle.bridge_cooldown <= 0 else Color("#7e8f84"), 1.35, true)
		draw_line(lever + Vector2(-3, 2), lever + Vector2(4, -5), GOLD, 1.5, true)

func draw_crystals() -> void:
	for crystal in battle.crystals:
		if crystal["hp"] <= 0.0:
			continue
		var at: Vector2 = crystal["position"]
		var pulse := 0.60 + 0.30 * sin(battle.clock * 2.2)
		draw_circle(at, 21.0, Color(TEAL, pulse * 0.13), true, -1.0, true)
		if battle.crystal_pulse > 0.0:
			draw_arc(at, 155.0 * (1.0 - battle.crystal_pulse / 1.2), 0, TAU, 92, Color(TEAL, battle.crystal_pulse * 0.35), 2.4, true)

func draw_supply(at: Vector2, bone: bool, phase: float) -> void:
	var t: float = sin(battle.clock * 1.9 + phase)
	var color := SKY if bone else GOLD
	draw_circle(at + Vector2(1, 3), 10.0, Color("#091211b5"), true, -1, true)
	var chip := PackedVector2Array([at + Vector2(-8, 3), at + Vector2(-4, -6), at + Vector2(5, -5),
		at + Vector2(8, 1), at + Vector2(2, 6)])
	ink_shape(chip, color.darkened(0.18))
	var cue := at + Vector2(0, -15 + t * 1.5)
	draw_polyline(PackedVector2Array([cue + Vector2(-4,0), cue + Vector2(0,-5), cue + Vector2(4,0),
		cue + Vector2(0,5), cue + Vector2(-4,0)]), Color(color, 0.64), 1.1, true)

func draw_weather() -> void:
	var active: bool = battle.weather_left > 0.0
	if not active and battle.biome != 3:
		return
	var cool: bool = battle.biome != 1
	var wind := -85.0 if cool else 152.0
	var tint := Color("#9ec0b3") if battle.biome == 0 else Color("#dfefef") if cool else Color("#dfb17a")
	for index in range(65 if active else 24):
		var x := fposmod(index * 63.8 + battle.clock * wind * (0.44 + (index % 5) * 0.18), 1280.0)
		var y := 47.0 + fposmod(index * 88.45 + battle.clock * (6.0 + (index % 3) * 9.0), 700.0)
		var from := Vector2(x, y)
		var length := 4.0 + (index % 4) * (6.0 if active else 1.0)
		draw_line(from, from + Vector2(signf(wind) * length, length * 0.3), Color(tint, 0.27 if active else 0.19), 1.2, true)

func ink_shape(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	draw_polyline(points + PackedVector2Array([points[0]]), BLACK, 1.5, true)
