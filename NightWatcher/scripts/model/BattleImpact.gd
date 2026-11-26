extends Node3D

const SPARKS := 48
const SPARK_COLORS := [Color("#ffe2a3"), Color("#ffc271"), Color("#df703e")]
const SHARD_COLORS := [Color("#d7c1a1"), Color("#987959"), Color("#545854")]
const STREAK_TIME := 0.13
const CONTACT_EDGE_TIME := 0.086
const WAVE_TIME := 0.20
const JOLT_LIMIT := 4.6
const SAMPLE_RATE := 22050

class Fragment:
	var body: MeshInstance3D
	var velocity := Vector3.ZERO
	var tumble := Vector3.ZERO
	var size := Vector3.ONE
	var life := 0.0
	var duration := 1.0
	var spark := false

class BladeMark:
	var center: Vector3
	var rim: Vector3
	var life := STREAK_TIME

var landscape: Node3D
var combat: Node2D
var fragments: Array[Fragment] = []
var warm_materials: Array[StandardMaterial3D] = []
var chalk_materials: Array[StandardMaterial3D] = []
var random := RandomNumberGenerator.new()
var glint: OmniLight3D
var ribbon := ImmediateMesh.new()
var ribbon_view: MeshInstance3D
var blade_marks: Array[BladeMark] = []
var light_contacts := PackedVector3Array()
var contact_edge_start := Vector3.ZERO
var contact_edge_end := Vector3.ZERO
var contact_edge_left := 0.0
var wave := ImmediateMesh.new()
var wave_view: MeshInstance3D
var wave_origin := Vector2.ZERO
var wave_direction := 0.0
var wave_left := 0.0
var flare_left := 0.0
var cursor := 0
var camera_displacement := Vector2.ZERO
var camera_velocity := Vector2.ZERO
var feedback_left := 0.0
var air: AudioStreamPlayer
var contact: AudioStreamPlayer
var sounds: Dictionary = {}

func setup(model: Node3D, fight: Node2D) -> void:
	landscape = model
	combat = fight
	var wedge := PrismMesh.new()
	wedge.size = Vector3.ONE
	for index in range(SPARK_COLORS.size()):
		var amber := StandardMaterial3D.new()
		amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		amber.albedo_color = SPARK_COLORS[index]
		warm_materials.append(amber)
		var chalk := StandardMaterial3D.new()
		chalk.albedo_color = SHARD_COLORS[index]
		chalk.roughness = 0.85
		chalk_materials.append(chalk)
	for index in range(SPARKS):
		var fragment := Fragment.new()
		fragment.body = MeshInstance3D.new()
		fragment.body.mesh = wedge
		fragment.body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fragment.body.hide()
		add_child(fragment.body)
		fragments.append(fragment)
	glint = OmniLight3D.new()
	glint.light_color = Color("#ffb471")
	glint.omni_range = 2.1
	glint.light_specular = 0.2
	glint.hide()
	add_child(glint)
	ribbon_view = MeshInstance3D.new()
	ribbon_view.name = "Sword trail"
	ribbon_view.mesh = ribbon
	ribbon_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gleam := StandardMaterial3D.new()
	gleam.cull_mode = BaseMaterial3D.CULL_DISABLED
	gleam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gleam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gleam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gleam.vertex_color_use_as_albedo = true
	gleam.render_priority = 91
	ribbon_view.material_override = gleam
	ribbon_view.hide()
	add_child(ribbon_view)
	wave_view = MeshInstance3D.new()
	wave_view.name = "Charged cutting wave"
	wave_view.mesh = wave
	wave_view.material_override = gleam
	wave_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave_view.hide()
	add_child(wave_view)
	combat.enemy_struck.connect(strike)
	combat.enemy_slain.connect(shatter)
	combat.charged_cut.connect(cut)
	combat.blade_cuts.connect(shear)
	combat.melee_contact.connect(melee_touch)
	combat.enemy_contact.connect(enemy_touch)
	air = AudioStreamPlayer.new()
	air.volume_db = -14.0
	add_child(air)
	contact = AudioStreamPlayer.new()
	contact.volume_db = -9.5
	add_child(contact)
	for voice in ["swish","shear","bone","iron","thud"]:
		sounds[voice] = texture_of_sound(voice)

func camera_offset() -> Vector2:
	return camera_displacement

func kick(direction: Vector2, force: float) -> void:
	camera_displacement = (camera_displacement - direction * force).limit_length(JOLT_LIMIT)
	camera_velocity += direction * force * 15.0

func shear(_where: Vector2, _direction: Vector2, heavy: bool) -> void:
	play_voice(air,"shear" if heavy else "swish")

func melee_touch(where: Vector2, direction: Vector2, weight: float, armored: bool, heavy: bool) -> void:
	var origin: Vector3 = landscape.screen_floor(where, 0.55 if armored else 0.42)
	var axis := Vector3(direction.x,0.0,direction.y).normalized()
	var count := 10 if heavy else 8 if armored else 5
	for index in range(count):
		emit_fragment(origin,index, true, axis * (1.9 if heavy else 0.95))
	if feedback_left <= 0.0:
		kick(direction, (3.8 if heavy else 2.45) * weight)
		play_voice(contact,"thud" if heavy else "iron" if armored else "bone")
		feedback_left = 0.054
	glint.position = origin + Vector3.UP * 0.11
	if not heavy:
		light_contacts.append(glint.position)
	glint.show()
	flare_left = maxf(flare_left, 0.082 if heavy else 0.057)

func enemy_touch(where: Vector2, direction: Vector2, heavy: bool) -> void:
	var origin: Vector3 = landscape.screen_floor(where,0.2)
	for index in range(5 if heavy else 3):
		emit_fragment(origin,index,false,Vector3(direction.x,0.0,direction.y)*0.52)
	if feedback_left <= 0.0:
		kick(direction,2.7 if heavy else 0.92)
		play_voice(contact,"thud" if heavy else "bone")
		feedback_left = 0.052

func play_voice(player: AudioStreamPlayer, title: String) -> void:
	player.stream = sounds[title]
	player.pitch_scale = random.randf_range(0.95,1.09)
	player.play()

func texture_of_sound(title: String) -> AudioStreamWAV:
	var swoosh := title in ["swish","shear"]
	var hollow := title in ["bone","thud"]
	var duration := 0.14 if title == "swish" else 0.23 if title == "shear" else 0.26 if title == "thud" else 0.18
	var count := roundi(duration * SAMPLE_RATE)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var source := RandomNumberGenerator.new()
	source.seed = 31429 + title.hash()
	var low := 0.0
	var phase := 0.0
	for sample in range(count):
		var t := float(sample)/SAMPLE_RATE
		var fraction := float(sample)/count
		var raw := source.randf_range(-1.0,1.0)
		low += (raw-low) * (0.12 if swoosh else 0.28)
		var output := 0.0
		if swoosh:
			var swell := sin(PI*fraction) ** 1.45
			var crisp := 0.39 if title == "swish" else 0.27
			output = (low*1.85 + (raw-low)*crisp)*swell*0.68
		elif hollow:
			var drift := (130.0 if title == "bone" else 105.0) * (0.59+0.41*exp(-t*24.0))
			phase += TAU*drift/SAMPLE_RATE
			var skin := sin(phase)*exp(-t*(43.0 if title == "bone" else 30.0))
			var crack := (raw*0.29 + low*1.05)*exp(-t*112.0)
			output = (skin*0.51 + crack + sin(TAU*485.0*t)*exp(-t*80.0)*0.14)*0.86
		else:
			var clang := (sin(TAU*1368.0*t)*0.26 + sin(TAU*1893.0*t)*0.16 + sin(TAU*2461.0*t)*0.14)*exp(-t*39.0)
			output = (clang + raw*exp(-t*156.0)*0.32 + sin(TAU*212.0*t)*exp(-t*93.0)*0.23)*0.87
		var onset := minf(1.0,t*1000.0)*(1.0-smoothstep(0.82,1.0,fraction))
		bytes.encode_s16(sample*2,roundi(clampf(output*onset,-0.90,0.90)*32767.0))
	stream.data = bytes
	return stream

func cut(where: Vector2, direction: Vector2) -> void:
	wave_origin = where
	wave_direction = direction.angle()
	wave_left = WAVE_TIME

func step_wave(delta: float) -> void:
	if wave_left <= 0.0:
		wave_view.hide()
		return
	var lifetime := wave_left / WAVE_TIME
	wave_left -= delta
	var progress := 1.0 - lifetime
	var reach := lerpf(52.0, 132.0, 1.0 - lifetime * lifetime)
	wave.clear_surfaces()
	wave.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for sample in range(23):
		var blend := float(sample) / 22.0
		var angle := wave_direction + lerpf(-1.03, 1.12, blend)
		var point := wave_origin + Vector2.from_angle(angle) * reach
		var broad := sin(PI * blend)
		var lift := 0.36 + broad * (0.26 - progress * 0.2)
		wave.surface_set_color(Color(0.93, 0.39, 0.10, lifetime * broad * 0.07))
		wave.surface_add_vertex(landscape.screen_floor(point.lerp(wave_origin, broad * 0.24), lift - 0.16))
		wave.surface_set_color(Color(1.0, 0.78, 0.41, lifetime * broad * 0.74))
		wave.surface_add_vertex(landscape.screen_floor(point, lift))
	wave.surface_end()
	wave_view.show()

func trace_blade(delta: float, grip: Node3D, swinging: bool, heavy: bool) -> void:
	swinging = swinging and combat.blade_is_released()
	contact_edge_left = maxf(0.0, contact_edge_left - delta)
	for index in range(blade_marks.size() - 1, -1, -1):
		blade_marks[index].life -= delta
		if blade_marks[index].life <= 0.0:
			blade_marks.remove_at(index)
	if swinging:
		var root := grip.to_global(Vector3(0.0, 0.33, 0.0))
		var edge := grip.to_global(Vector3(0.0, 0.73, 0.0))
		if not light_contacts.is_empty() and not heavy:
			capture_contact_edge(edge)
		var rim := edge + (edge - root) * (0.30 if heavy else 0.12)
		rim.y = maxf(0.06, rim.y)
		if blade_marks.is_empty() or rim.distance_squared_to(blade_marks[-1].rim) > 0.002:
			var mark := BladeMark.new()
			mark.center = root
			mark.rim = rim
			blade_marks.append(mark)
			if blade_marks.size() > 9:
				blade_marks.pop_front()
	light_contacts.clear()
	if blade_marks.size() < 2 and contact_edge_left <= 0.0:
		ribbon_view.hide()
		return
	ribbon.clear_surfaces()
	if blade_marks.size() >= 2:
		ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for mark in blade_marks:
			var alpha := pow(mark.life / STREAK_TIME, 1.35)
			ribbon.surface_set_color(Color(0.83, 0.36, 0.13, alpha * 0.03))
			ribbon.surface_add_vertex(mark.center)
			ribbon.surface_set_color(Color(1.0, 0.76, 0.46, alpha * 0.75))
			ribbon.surface_add_vertex(mark.rim)
		ribbon.surface_end()
	if contact_edge_left > 0.0:
		draw_contact_edge()
	ribbon_view.show()

func capture_contact_edge(tip: Vector3) -> void:
	var camera: Camera3D = landscape.camera
	var tip_on_screen := camera.unproject_position(tip)
	var player: Vector2 = combat.watcher.position
	var furthest := 75.0 ** 2
	for target in light_contacts:
		var ground := camera.unproject_position(Vector3(target.x, 0.0, target.z))
		var distance := player.distance_squared_to(ground)
		var gap := tip_on_screen.distance_to(camera.unproject_position(target))
		if distance <= furthest or gap < 14.0 or gap > 56.0:
			continue
		furthest = distance
		contact_edge_start = tip.move_toward(target, -0.04)
		contact_edge_end = target
		contact_edge_left = CONTACT_EDGE_TIME

func draw_contact_edge() -> void:
	var camera: Camera3D = landscape.camera
	var tangent := contact_edge_end - contact_edge_start
	var across := tangent.cross(camera.global_basis.z).normalized()
	if across.y < 0.0:
		across = -across
	var alpha := pow(contact_edge_left / CONTACT_EDGE_TIME, 1.7)
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in range(7):
		var along := float(index) / 6.0
		var point := contact_edge_start.lerp(contact_edge_end, along) + across * sin(PI * along) * 0.08
		var width := lerpf(0.060, 0.006, along)
		ribbon.surface_set_color(Color(0.83, 0.36, 0.13, alpha * 0.12))
		ribbon.surface_add_vertex(point - across * width)
		ribbon.surface_set_color(Color(1.0, 0.76, 0.46, alpha * lerpf(0.67, 0.37, along)))
		ribbon.surface_add_vertex(point)
	ribbon.surface_end()

func strike(where: Vector2, species: int, flame: bool) -> void:
	var origin: Vector3 = landscape.screen_floor(where, 0.47 if species == 1 else 0.31)
	if flare_left <= 0.045:
		glint.position = origin + Vector3.UP * 0.15
		flare_left = 0.11 if flame else 0.085
		glint.show()
		glint.light_energy = 0.85
	for index in range(5 if flame else 4):
		emit_fragment(origin, index, true)

func shatter(_species: int, _xp: int, where: Vector2) -> void:
	var origin: Vector3 = landscape.screen_floor(where, 0.32)
	for index in range(7):
		emit_fragment(origin, index, index < 2)

func emit_fragment(origin: Vector3, index: int, spark: bool, directional := Vector3.ZERO) -> void:
	var fragment := fragments[cursor]
	cursor = (cursor + 1) % fragments.size()
	var angle := float(index) * 2.399 + random.randf_range(-0.37, 0.37)
	var spread := random.randf_range(1.7, 3.5) if spark else random.randf_range(0.6, 1.9)
	fragment.velocity = Vector3(cos(angle) * spread, random.randf_range(1.1, 2.9), sin(angle) * spread) + directional
	fragment.tumble = Vector3(random.randf_range(-8.0, 8.0), 1.4, random.randf_range(-9.0, 9.0))
	fragment.spark = spark
	fragment.duration = random.randf_range(0.12, 0.25) if spark else random.randf_range(0.36, 0.66)
	fragment.life = fragment.duration
	var width := random.randf_range(0.022, 0.041) if spark else random.randf_range(0.043, 0.102)
	fragment.size = Vector3(width, width * 0.9, width * (3.5 if spark else 1.2))
	fragment.body.position = origin + Vector3(cos(angle), 0.0, sin(angle)) * 0.08
	fragment.body.look_at(fragment.body.position + fragment.velocity)
	fragment.body.scale = fragment.size
	fragment.body.material_override = (warm_materials if spark else chalk_materials)[index % SPARK_COLORS.size()]
	fragment.body.show()

func step(delta: float) -> void:
	feedback_left = maxf(0.0,feedback_left - delta)
	camera_velocity += -camera_displacement*490.0*delta
	camera_velocity *= exp(-delta*25.0)
	camera_displacement = (camera_displacement + camera_velocity*delta).limit_length(JOLT_LIMIT)
	if camera_velocity.length_squared() + camera_displacement.length_squared() < 0.004:
		camera_displacement = Vector2.ZERO
		camera_velocity = Vector2.ZERO
	step_wave(delta)
	if flare_left > 0.0:
		flare_left = maxf(0.0, flare_left - delta)
		glint.light_energy = flare_left * 8.0
		glint.visible = flare_left > 0.0
	for fragment in fragments:
		if fragment.life <= 0.0:
			continue
		fragment.life -= delta
		if fragment.life <= 0.0:
			fragment.body.hide()
			continue
		fragment.velocity.y -= delta * (4.2 if fragment.spark else 11.0)
		fragment.body.position += fragment.velocity * delta
		if not fragment.spark:
			if fragment.body.position.y < 0.042:
				fragment.body.position.y = 0.042
				fragment.velocity = Vector3(fragment.velocity.x * 0.39, 0.0, fragment.velocity.z * 0.39)
			else:
				fragment.body.rotation += fragment.tumble * delta
		fragment.body.scale = fragment.size * clampf(fragment.life / fragment.duration * 3.6, 0.02, 1.0)
