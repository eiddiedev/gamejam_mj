extends Node2D

enum Phase { TITLE, DUSK, WAVE_ONE, WAVE_TWO, DAWN, FAILED, FINISHED }
enum Upgrade { NONE, MIRROR, LANTERN, OIL }

const Terrain = preload("res://terrain.gd")
const Campfire = preload("res://campfire.gd")
const Enemy = preload("res://enemy.gd")
const Actors = preload("res://actors.gd")
const Hud = preload("res://hud.gd")
const Fort = preload("res://world/fort.gd")
const Creatures = preload("res://world/creatures.gd")
const FRAMING = preload("res://framing.gdshader")
const SHADOW := Enemy.Kind.SHADOW
const MOTH := Enemy.Kind.MOTH
const FULL_WAVE_TIME := 60.0
const CONE_DOT := 0.8988
const CARD_NAMES := ["", "铜镜折射", "强光提灯", "火油陷阱"]

# Each arrival is [seconds into the wave, species, approach].
const WAVE_ONE := [[0.0, SHADOW, 0], [5.0, SHADOW, 1], [11.0, SHADOW, 2], [17.0, SHADOW, 0]]
const WAVE_TWO := [[0.0, MOTH, 1], [4.0, SHADOW, 0], [8.0, MOTH, 2], [13.0, SHADOW, 1],
	[17.0, MOTH, 0], [20.0, SHADOW, 2], [24.0, SHADOW, 0]]

var phase := Phase.TITLE
var phase_left := 0.0
var night_number := 1
var upgrade := Upgrade.NONE
var enemies: Array[Enemy] = []
var wave_plan: Array = []
var spawn_cursor := 0
var wood_available: Array[bool] = []
var wall_hp: Array[float] = []
var inventory := 0
var player := Terrain.START
var aim := Vector2(0.9, -0.42).normalized()
var moving := false
var clock := 0.0
var shade := 0.0
var golden := 0.0
var paused := false
var closing := false
var muted := false
var trap_used := false
var trap_left := 0.0
var trap_point := Vector2.ZERO
var particles: Array[Dictionary] = []
var camp: Campfire
var actors: Actors
var field: Node2D
var fort: Fort
var creatures: Creatures
var hud: Hud
var ambience: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var effect_cursor := 0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_window().min_size = Vector2i(768, 480)
	get_window().title = "长夜守望者 · 破败石堡"
	make_world()
	make_audio()
	hud = Hud.new()
	hud.game = self
	hud.z_index = 10
	add_child(hud)
	show_title()

func make_world() -> void:
	fort = Fort.new()
	fort.study_enabled = "--fort-art-study" in OS.get_cmdline_user_args()
	fort.name = "Drawn stone fort"
	add_child(fort)
	creatures = Creatures.new()
	creatures.ink = fort.ink
	fort.add_child(creatures)
	field = Node2D.new()
	field.name = "Gameplay markers"
	field.position = Fort.FIELD_OFFSET
	field.scale = Vector2.ONE * Fort.FIELD_SCALE
	add_child(field)
	camp = Campfire.new()
	camp.position = Terrain.FIRE
	camp.flame_anchor = Fort.space(Terrain.FIRE, 0.10)
	field.add_child(camp)
	camp.extinguished.connect(fail.bind("火灭了。守夜至此终止。"))
	actors = Actors.new()
	actors.game = self
	actors.z_index = 4
	field.add_child(actors)
	var framing := ColorRect.new()
	framing.z_index = 8
	framing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	framing.size = Vector2(1280, 800)
	var frame_material := ShaderMaterial.new()
	frame_material.shader = FRAMING
	framing.material = frame_material
	add_child(framing)

func make_audio() -> void:
	ambience = AudioStreamPlayer.new()
	var loop: AudioStreamWAV = load("res://audio/wind.wav").duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = loop.data.size() / 2
	ambience.stream = loop
	ambience.volume_db = -13
	add_child(ambience)
	ambience.play()
	for index in range(5):
		var speaker := AudioStreamPlayer.new()
		add_child(speaker)
		effects.append(speaker)

func _physics_process(delta: float) -> void:
	if paused:
		return
	if phase in [Phase.DUSK, Phase.WAVE_ONE, Phase.WAVE_TWO]:
		move_player(delta)
		tick_stage(delta)
	elif phase == Phase.DAWN:
		phase_left = maxf(0.0, phase_left - delta)

func _process(delta: float) -> void:
	if paused:
		return
	clock += delta
	shade = move_toward(shade, target_darkness(), delta * 0.47)
	golden = move_toward(golden, 1.0 if phase in [Phase.DAWN, Phase.FINISHED] else 0.0, delta * 0.56)
	for index in range(particles.size() - 1, -1, -1):
		particles[index]["age"] += delta
		if particles[index]["age"] >= 1.0:
			particles.remove_at(index)
	camp.animate(delta)
	paint_terrain()
	actors.queue_redraw()
	hud.update_status()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			hud.toggle_pause()
		KEY_ENTER, KEY_SPACE:
			if phase == Phase.TITLE and not paused:
				start_level()
		KEY_E:
			if not paused:
				interact()
		KEY_Q:
			if not paused:
				lay_trap()

func show_title() -> void:
	paused = false
	phase = Phase.TITLE
	enemies.clear()
	particles.clear()
	camp.reset()
	upgrade = Upgrade.NONE
	night_number = 1
	hud.show_title()

func start_level(new_night: int = 1, chosen: Upgrade = Upgrade.NONE) -> void:
	phase = Phase.DUSK
	phase_left = 90.0
	paused = false
	night_number = new_night
	upgrade = chosen
	camp.reset()
	enemies.clear()
	particles.clear()
	player = Terrain.START
	aim = Vector2(1.0, -0.21).normalized()
	inventory = 0
	trap_used = false
	trap_left = 0.0
	wood_available.resize(Terrain.STASHES.size())
	wood_available.fill(true)
	wall_hp.resize(Terrain.GATES.size())
	wall_hp.fill(0.0)
	hud.show_play()
	if night_number == 2:
		hud.flash("第二夜 · " + CARD_NAMES[upgrade], "强化已装备")
	else:
		hud.flash("破败石堡的第一夜", "黄昏 · 收集木柴，准备守夜")
	play_sound("dusk", -7)

func move_player(delta: float) -> void:
	var motion := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
		- float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	).normalized()
	moving = motion.length_squared() > 0.02
	var stride := motion * delta * 108.0
	var across := player + Vector2(stride.x, 0)
	if Terrain.walkable(across):
		player = across
	var forward := player + Vector2(0, stride.y)
	if Terrain.walkable(forward):
		player = forward
	var cursor := field.get_local_mouse_position()
	if get_viewport().get_mouse_position().x > 170.0 and cursor.distance_to(player) > 5.0:
		aim = player.direction_to(cursor)

func tick_stage(delta: float) -> void:
	phase_left = maxf(0.0, phase_left - delta)
	if phase == Phase.DUSK:
		if phase_left <= 0.0:
			begin_wave(Phase.WAVE_ONE)
		return
	if phase == Phase.WAVE_TWO:
		camp.decay(delta)
		if phase == Phase.FAILED:
			return
	trap_left = maxf(0.0, trap_left - delta)
	while spawn_cursor < wave_plan.size() and FULL_WAVE_TIME - phase_left >= wave_plan[spawn_cursor][0]:
		spawn_monster(wave_plan[spawn_cursor], spawn_cursor)
		spawn_cursor += 1
	for index in range(enemies.size() - 1, -1, -1):
		enemies[index].tick(delta, self)
		if phase == Phase.FAILED:
			return
		if enemies[index].state == Enemy.State.DEAD:
			enemies.remove_at(index)
	if spawn_cursor == wave_plan.size() and enemies.is_empty():
		if phase == Phase.WAVE_ONE:
			begin_wave(Phase.WAVE_TWO)
		else:
			reach_dawn()
	elif phase_left == 0.0:
		fail("巡夜时限已过。石堡仍有异兽。")

func begin_wave(next: Phase) -> void:
	phase = next
	phase_left = FULL_WAVE_TIME
	spawn_cursor = 0
	trap_used = false
	trap_left = 0.0
	wave_plan = WAVE_ONE if next == Phase.WAVE_ONE else WAVE_TWO
	if next == Phase.WAVE_ONE:
		hud.flash("夜幕降临，异兽来袭！", "第一波 · 潜行影魔")
	else:
		hud.flash("长夜深处", "第二波 · 优先拦截噬火蛾")
	play_sound("wave", -5)

func spawn_monster(arrival: Array, order: int) -> void:
	var kind: Enemy.Kind = arrival[1]
	var gate: int = (arrival[2] + night_number - 1) % Terrain.GATES.size()
	var path := Terrain.route(gate, order + night_number)
	if kind == MOTH:
		path = PackedVector2Array([path[0], path[path.size() - 1]])
	enemies.append(Enemy.new(kind, path, gate, order * 1.1))
	play_sound("moth" if kind == MOTH else "shadow", -13)

func interaction() -> Dictionary:
	if phase not in [Phase.DUSK, Phase.WAVE_ONE, Phase.WAVE_TWO]:
		return {}
	var candidates: Array[Dictionary] = []
	for index in range(Terrain.STASHES.size()):
		if wood_available[index]:
			candidates.append({"key": "wood", "index": index, "position": Terrain.STASHES[index], "label": "拾取木柴"})
	for index in range(Terrain.GATES.size()):
		if wall_hp[index] <= 0.0:
			candidates.append({"key": "wall", "index": index, "position": Terrain.GATES[index], "label": "修补断墙"})
	candidates.append({"key": "fire", "index": -1, "position": Terrain.FIRE, "label": "给篝火添柴"})
	var nearest: Dictionary = {}
	var limit := 31.0
	for candidate in candidates:
		var distance := player.distance_to(candidate["position"])
		if distance < limit:
			nearest = candidate
			limit = distance
	return nearest

func interact() -> void:
	var target := interaction()
	if target.is_empty():
		return
	var index: int = target["index"]
	var point: Vector2 = target["position"]
	if target["key"] == "wood":
		wood_available[index] = false
		inventory += 1
		particle(point, "+1 木柴", Color("#e7c38a"))
		play_sound("wood")
		return
	if inventory <= 0:
		hud.notify("需要 1 份木柴")
		return
	if target["key"] == "fire":
		if camp.hp == Campfire.MAX_HP:
			hud.notify("篝火已旺盛")
			return
		var before := camp.hp
		camp.add_fuel()
		particle(point, "+%d" % roundi(camp.hp - before), Color("#ffa457"))
		play_sound("fuel")
	else:
		wall_hp[index] = 1.0
		particle(point, "已修补", Color("#f2cf9a"))
		play_sound("wall")
	inventory -= 1

func damage_wall(index: int, delta: float) -> bool:
	if wall_hp[index] <= 0.0:
		return false
	wall_hp[index] = maxf(0.0, wall_hp[index] - delta * 0.38)
	if wall_hp[index] == 0.0:
		play_sound("wall", -2)
		particle(Terrain.GATES[index], "断墙失守", Color("#ec936b"))
	return true

func fire_struck(damage: float) -> void:
	camp.damage(damage)
	particle(Terrain.FIRE, "-%d" % roundi(damage), Color("#f98777"))
	play_sound("hit")
	hud.fire_hit()

func enemy_burned(enemy: Enemy) -> void:
	particle(enemy.position, "", Color("#ffb96d"))
	play_sound("burn", -4)

func particle(point: Vector2, text: String, color: Color) -> void:
	particles.append({"position": point, "text": text, "age": 0.0, "color": color})

func is_illuminated(point: Vector2) -> bool:
	var offset := point - player
	var limit := lamp_range()
	var distance := offset.length()
	if distance <= 11.0:
		return true
	var facing := offset.dot(aim) / distance
	var in_beam := distance <= limit and facing >= CONE_DOT
	var in_reflection := upgrade == Upgrade.MIRROR and distance <= 105.0 and -facing >= CONE_DOT
	return (in_beam or in_reflection) and light_distance(offset / distance, distance + 1.0) >= distance

func light_distance(direction: Vector2, radius: float) -> float:
	var furthest := player + direction * radius
	var closest := radius
	for region in Terrain.static_occluders:
		for index in range(region.size()):
			var hit: Variant = Geometry2D.segment_intersects_segment(player, furthest, region[index], region[(index + 1) % region.size()])
			if hit != null:
				closest = minf(closest, player.distance_to(hit))
	for index in range(wall_hp.size()):
		if wall_hp[index] <= 0.0:
			continue
		var center: Vector2 = Terrain.GATES[index]
		var edge := Vector2.from_angle(Terrain.GATE_ANGLES[index]) * 17.0
		var hit: Variant = Geometry2D.segment_intersects_segment(player, furthest, center - edge, center + edge)
		if hit != null:
			closest = minf(closest, player.distance_to(hit))
	return closest

func lamp_range() -> float:
	return 221.0 if upgrade == Upgrade.LANTERN else 164.0

func lantern_damage() -> float:
	return 1.29 if upgrade == Upgrade.LANTERN else 0.89

func lay_trap() -> void:
	if upgrade != Upgrade.OIL or phase not in [Phase.WAVE_ONE, Phase.WAVE_TWO]:
		return
	if trap_used:
		hud.notify("本波火油陷阱已使用")
		return
	trap_used = true
	trap_left = 18.0
	trap_point = player
	particle(player, "火油陷阱", Color("#ff914d"))
	play_sound("fuel")

func is_trapped(point: Vector2) -> bool:
	return trap_left > 0.0 and point.distance_squared_to(trap_point) <= 27.0 ** 2

func reach_dawn() -> void:
	play_sound("dawn")
	if night_number == 2:
		phase = Phase.FINISHED
		hud.show_result(true, "第二夜也结束了。篝火还亮着。")
	else:
		phase = Phase.DAWN
		phase_left = 30.0
		hud.show_cards()

func choose_card(card: Upgrade) -> void:
	if phase == Phase.DAWN:
		start_level(2, card)

func fail(reason: String) -> void:
	if phase == Phase.FAILED:
		return
	phase = Phase.FAILED
	enemies.clear()
	hud.show_result(false, reason)
	play_sound("lost")

func enemies_remaining() -> int:
	return enemies.size() + wave_plan.size() - spawn_cursor

func target_darkness() -> float:
	match phase:
		Phase.WAVE_ONE:
			return 0.67
		Phase.WAVE_TWO:
			return 0.93
		Phase.FAILED:
			return 0.96
		Phase.DAWN, Phase.FINISHED:
			return 0.14
	return 0.0

func paint_terrain() -> void:
	var beam := sample_light(aim, lamp_range())
	var mirror := upgrade == Upgrade.MIRROR
	var reflection := sample_light(-aim, 105.0) if mirror else PackedFloat32Array()
	var beam_power := 0.0 if phase == Phase.TITLE else 0.72 if upgrade == Upgrade.LANTERN else lerpf(0.13, 0.52, shade)
	for material in fort.ink_materials:
		material.set_shader_parameter("fuel", camp.ratio())
		material.set_shader_parameter("fire_energy", camp.light_energy)
		material.set_shader_parameter("night", shade)
		material.set_shader_parameter("dawn", golden)
		material.set_shader_parameter("time_elapsed", clock)
		material.set_shader_parameter("watcher", player)
		material.set_shader_parameter("aim", aim)
		material.set_shader_parameter("cone_dot", CONE_DOT)
		material.set_shader_parameter("mirror", mirror)
		material.set_shader_parameter("beam_power", beam_power)
		material.set_shader_parameter("beam_distances", beam)
		if mirror:
			material.set_shader_parameter("mirror_distances", reflection)
	var active := phase in [Phase.DUSK, Phase.WAVE_ONE, Phase.WAVE_TWO]
	for index in range(fort.gates.size()):
		fort.gates[index].visible = active and wall_hp[index] > 0.0
	creatures.sync(self)

func sample_light(direction: Vector2, radius: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(49)
	var angle := acos(CONE_DOT)
	for index in range(samples.size()):
		samples[index] = light_distance(direction.rotated(lerpf(-angle, angle, index / 48.0)), radius)
	return samples

func toggle_audio() -> void:
	muted = not muted
	ambience.stream_paused = muted

func play_sound(clip: String, volume: float = -7.0) -> void:
	if muted:
		return
	var speaker := effects[effect_cursor]
	effect_cursor = (effect_cursor + 1) % effects.size()
	speaker.stream = load("res://audio/%s.wav" % clip)
	speaker.volume_db = volume
	speaker.play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func quit_game() -> void:
	if closing:
		return
	closing = true
	ambience.stop()
	for speaker in effects:
		speaker.stop()
	await get_tree().create_timer(0.15, true, false, true).timeout
	get_tree().quit()
