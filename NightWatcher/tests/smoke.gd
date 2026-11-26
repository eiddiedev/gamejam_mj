extends SceneTree

const Game = preload("res://main.gd")
const Terrain = preload("res://terrain.gd")
const Enemy = preload("res://enemy.gd")
const Fort = preload("res://world/fort.gd")
const Scene = preload("res://main.tscn")
const STEP := 1.0 / 60.0

var game: Game
var checked := 0
var failures := 0
var capture_folder := ""

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		capture_folder = arguments[0]
		DirAccess.make_dir_recursive_absolute(capture_folder)
	root.size = Vector2i(1280, 800)
	game = Scene.instantiate()
	root.add_child(game)
	expect(game.fort.camera.current and game.fort.model.mesh.get_surface_count() == 1,
		"The playable scene renders the fort mesh with its orthographic camera")
	expect(game.fort.model.material_override == game.fort.ink and game.fort.outline.shader != null,
		"The masonry and silhouettes use their ink materials")
	if capture_folder.is_empty():
		game.ambience.stop()
		game.muted = true
	game.set_physics_process(false)
	game.set_process(false)
	await capture("01-title")
	await click("开始守夜    ↵")
	expect(game.phase == Game.Phase.DUSK and game.phase_left == 90.0, "Start button opens 90-second dusk")
	expect(game.camp.hp == 100.0 and game.wood_available.count(true) == 6, "Dusk starts at 100 HP and six piles")
	check_paths()
	var move_key := InputEventKey.new()
	move_key.physical_keycode = KEY_A
	move_key.pressed = true
	Input.parse_input_event(move_key)
	Input.flush_buffered_events()
	game.move_player(0.1)
	expect(game.player.x < Terrain.START.x, "WASD moves the watcher")
	move_key = move_key.duplicate() as InputEventKey
	move_key.pressed = false
	Input.parse_input_event(move_key)
	Input.flush_buffered_events()
	game.player = Terrain.START
	game.paint_terrain()
	expect(game.creatures.watcher.position.is_equal_approx(Fort.space(game.player)), "The 3D watcher follows the gameplay position")
	if DisplayServer.get_name() != "headless":
		var hearth := game.fort.camera.unproject_position(Fort.space(Terrain.FIRE))
		expect(hearth.distance_to(game.field.to_global(game.camp.position)) < 1.0, "Fire overlay matches the projected stone hearth")
		var feet := game.fort.camera.unproject_position(game.creatures.watcher.position)
		expect(feet.distance_to(game.field.to_global(game.player)) < 1.0, "3D movement matches the input plane")
	await capture("02-dusk")
	for point in Terrain.STASHES:
		game.player = point
		send_key(KEY_E)
	expect(game.inventory == 6 and game.wood_available.count(true) == 0, "E picks up each of the six piles once")
	game.player = Terrain.GATES[0]
	send_key(KEY_E)
	expect(game.wall_hp[0] == 1.0 and game.inventory == 5, "Repair consumes one wood")
	game.paint_terrain()
	expect(game.fort.gates[0].visible, "Repair draws masonry in the breach")
	for index in range(155):
		expect_wall_tick(index)
	expect(game.wall_hp[0] > 0.0, "Wall delays breach")
	for index in range(10):
		game.damage_wall(0, STEP)
	expect(game.wall_hp[0] == 0.0, "Repeated enemy pressure breaks a repaired wall")
	game.paint_terrain()
	expect(not game.fort.gates[0].visible, "Destroyed wall clears the breach drawing")
	game.player = Terrain.FIRE
	game.camp.damage(30.0)
	var dimmed: float = game.camp.light_energy
	send_key(KEY_E)
	expect(game.camp.hp == 95.0 and game.inventory == 4, "One wood restores 25 HP")
	expect(game.camp.light_energy > dimmed, "Fuel increases real light energy")
	send_key(KEY_E)
	expect(game.camp.hp == 100.0 and game.inventory == 3, "Healing is capped at 100")
	send_key(KEY_E)
	expect(game.inventory == 3, "Full fire does not consume wood")
	send_key(KEY_ESCAPE)
	expect(game.paused, "Escape pauses")
	game._physics_process(1)
	expect(game.phase_left == 90.0, "Pause holds the countdown")
	send_key(KEY_ESCAPE)
	game.tick_stage(89.0)
	expect(game.phase == Game.Phase.DUSK, "Dusk lasts until its deadline")
	game.tick_stage(1.0)
	expect(game.phase == Game.Phase.WAVE_ONE and game.phase_left == 60.0, "Night begins a 60-second first wave")
	game.tick_stage(STEP)
	expect(game.enemies_remaining() == 4 and game.wave_plan.all(func(arrival): return arrival[1] == Enemy.Kind.SHADOW), "First wave has four shadows")
	game.player = Terrain.FIRE
	var shadow := game.enemies[0]
	game.aim = Vector2.RIGHT
	shadow.position = game.player + Vector2(-65, 0)
	shadow.tick(STEP, game)
	expect(not shadow.lit and shadow.vitality == 1.0, "Shadow outside the cone is hidden and unharmed")
	game.aim = game.player.direction_to(shadow.position)
	shadow.tick(STEP, game)
	expect(shadow.lit and shadow.vitality < 1.0, "Lantern reveals and burns the shadow")
	await capture("03-first-wave")
	simulate_current_wave()
	expect(game.phase == Game.Phase.WAVE_TWO and game.phase_left == 60.0, "Burning all four shadows advances to wave two")
	expect(game.wave_plan.filter(func(arrival): return arrival[1] == Enemy.Kind.MOTH).size() == 3, "Wave two has three moths")
	expect(game.wave_plan.filter(func(arrival): return arrival[1] == Enemy.Kind.SHADOW).size() == 4, "Wave two has four shadows")
	var prior := game.camp.hp
	game.tick_stage(1.0)
	expect(is_equal_approx(game.camp.hp, prior - 1.5), "Wave two burns 1.5 HP per second")
	await capture("04-second-wave")
	simulate_current_wave()
	expect(game.phase == Game.Phase.DAWN and game.camp.hp > 0.0, "Full wave progression reaches dawn with fire alive")
	expect(game.phase_left == 30.0, "Dawn grants a 30-second card phase")
	game._physics_process(2.0)
	expect(game.phase_left == 28.0, "Dawn clock counts down while awaiting a card")
	await capture("05-dawn")
	var cards := game.hud.presentation.find_children("*", "Button", true, false)
	expect(cards.size() == 3, "Dawn presents exactly three cards")
	await press_button(cards[0])
	expect(game.phase == Game.Phase.DUSK and game.night_number == 2 and game.upgrade == Game.Upgrade.MIRROR, "Card starts real second playable night")
	game.player = Terrain.FIRE
	game.aim = Vector2.RIGHT
	expect(game.is_illuminated(game.player + Vector2(-64, 0)), "Mirror adds a rear cone")
	game.start_level(2, Game.Upgrade.LANTERN)
	expect(game.lamp_range() > 164.0 and game.lantern_damage() > 0.89, "Strong lantern increases reach and damage")
	game.start_level(2, Game.Upgrade.OIL)
	game.begin_wave(Game.Phase.WAVE_ONE)
	send_key(KEY_Q)
	expect(game.is_trapped(game.player) and game.trap_used, "Q deploys an active trap once in the wave")
	var hp := game.camp.hp
	var spawned := Enemy.new(Enemy.Kind.SHADOW, PackedVector2Array([game.player, game.player]), 0, 0.0)
	spawned.state = Enemy.State.FEED
	spawned.wait = 0.0
	game.trap_left = 0.0
	spawned.tick(STEP, game)
	expect(game.camp.hp == hp - 15.0, "Shadow reaching the fire strikes for 15 HP")
	var moth := Enemy.new(Enemy.Kind.MOTH, PackedVector2Array([Terrain.FIRE + Vector2(0, -1), Terrain.FIRE]), 0, 0.0)
	moth.tick(0.10, game)
	expect(game.camp.hp == hp - 27.0 and moth.state == Enemy.State.DEAD, "Moth impact takes 12 HP and consumes the moth")
	game.camp.damage(100.0)
	expect(game.phase == Game.Phase.FAILED and not game.camp.flame.visible, "Extinguished fire ends play and shuts off the light")
	await capture("06-extinguished")
	await click("重新守夜")
	game.begin_wave(Game.Phase.WAVE_ONE)
	game.tick_stage(60.1)
	expect(game.phase == Game.Phase.FAILED, "Uncleared wave can fail on timeout")
	print("Night Watcher: %d checks, %d failed" % [checked, failures])
	game.queue_free()
	await create_timer(0.12).timeout
	quit(int(failures > 0))

func simulate_current_wave() -> void:
	var starting_phase := game.phase
	var target: Enemy = null
	for frame in range(3620):
		if game.phase != starting_phase:
			return
		if target == null or target.state == Enemy.State.DEAD:
			var nearest := 9999.0
			target = null
			for enemy in game.enemies:
				var distance := game.player.distance_to(enemy.position)
				if distance < nearest and distance <= game.lamp_range() and game.light_distance(
						game.player.direction_to(enemy.position), distance + 1.0) >= distance:
					nearest = distance
					target = enemy
		if target != null:
			game.aim = game.player.direction_to(target.position)
		if game.camp.hp <= 74.0 and game.inventory > 0:
			game.interact()
		game.tick_stage(STEP)

func check_paths() -> void:
	var open := [Vector2i(Terrain.START)]
	var visited: Dictionary = {}
	var step := 5
	while not open.is_empty():
		var point: Vector2i = open.pop_back()
		if visited.has(point) or not Terrain.walkable(Vector2(point)):
			continue
		visited[point] = true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			open.append(point + direction * step)
	for target in Terrain.STASHES + Terrain.GATES:
		var closest_grid: Vector2 = Terrain.START + ((target - Terrain.START) / step).round() * step
		expect(visited.has(Vector2i(closest_grid)), "Playable route reaches %s" % [target])

func expect_wall_tick(index: int) -> void:
	var blocked := game.damage_wall(0, STEP)
	if index == 0:
		expect(blocked, "Repaired wall blocks a shadow before it enters")

func send_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	root.push_input(event, true)

func click(words: String) -> void:
	for node in game.hud.find_children("*", "Button", true, false):
		if node.text == words:
			await press_button(node)
			return
	expect(false, "Button exists: " + words)

func press_button(target: Button) -> void:
	await process_frame
	var where := target.get_global_transform_with_canvas() * (target.size * 0.5)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = where
	event.global_position = where
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func capture(name: String) -> void:
	if capture_folder.is_empty():
		return
	for index in range(9):
		game._process(0.21)
		await process_frame
	await RenderingServer.frame_post_draw
	if name == "05-dawn":
		await create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(capture_folder.path_join(name + ".png"))
	expect(error == OK, "Visual capture saved: " + name)

func expect(result: bool, detail: String) -> void:
	checked += 1
	if not result:
		failures += 1
		push_error(detail)
