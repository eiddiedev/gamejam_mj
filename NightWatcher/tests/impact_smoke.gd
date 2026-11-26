extends SceneTree

const ENEMY = preload("res://scripts/entities/EnemyController.gd")
const STEP := 1.0 / 60.0

var level
var fight
var checks := 0
var failures := 0
var cuts := 0
var touches := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 800)
	var run_state := root.get_node("RunState")
	run_state.start_new(4819)
	level = load("res://scenes/levels/Level01_FallenKing.tscn").instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	level.scenery.set_process(false)
	fight = level.combat
	fight.blade_cuts.connect(record_cut)
	fight.melee_contact.connect(record_touch)
	var start := clear_site()
	expect(start != Vector2.ZERO, "first biome has an unobstructed space for the contact fixture")
	if start == Vector2.ZERO:
		await finish()
		return
	level.player = start
	level.aim = Vector2.RIGHT
	level.start_night()
	level.refresh_lights()
	step(0.0)
	for _i in range(18):
		step(STEP)
	test_blade(start)
	test_windup(start)
	test_dash(start)
	test_foot_plant(start)
	test_crowd(start)
	test_tight_lane()
	print("Impact timing: ", checks, " checks, ", failures, " failed")
	await finish()

func clear_site() -> Vector2:
	var fire: Vector2 = level.fire_point
	for y in range(-109, 133, 12):
		for x in range(-115, 121, 12):
			var start := fire + Vector2(x, y)
			if not level.can_walk(start):
				continue
			var finish := start + Vector2(143, 0)
			if level.motion_against_world(start, finish - start, 12.0).distance_to(finish) < 0.8:
				return start
	return Vector2.ZERO

func step(delta: float) -> void:
	level.clock += delta
	level.refresh_lights()
	fight.tick(delta)
	level.scenery.puppets.sync(delta)
	level.scenery.impact.step(delta)

func record_cut(_at: Vector2, _direction: Vector2, _heavy: bool) -> void:
	cuts += 1

func record_touch(_at: Vector2, _direction: Vector2, _weight: float, _armor: bool, _heavy: bool) -> void:
	touches += 1

func test_blade(start: Vector2) -> void:
	var enemy: ENEMY = fight.spawn(ENEMY.CRAWLER, 0)
	enemy.position = start + Vector2(67, 0)
	enemy.health = 425.0
	enemy.max_health = enemy.health
	enemy.speed = 0.0
	var initial := enemy.health
	expect(fight.slash(), "short sword accepts the opening strike")
	expect(enemy.health == initial and touches == 0, "button press does not resolve damage")
	var contact_time: float = fight.strike_contact_time()
	step(contact_time - 0.011)
	expect(cuts == 1 and enemy.health == initial and touches == 0,
		"passing the windup creates one air cue while the target remains undamaged")
	step(0.014)
	expect(enemy.health < initial and touches == 1, "the crossing sample resolves damage exactly once")
	expect(absf(fight.strike_clock - contact_time) < 0.001 and fight.hit_pause >= 0.035,
		"impact holds the short sword at the contact pose")
	var sword: Node3D = level.scenery.puppets.sword_mount
	var tip_guide := sword.to_global(Vector3(0, 0.71, 0)) - sword.global_position
	expect(tip_guide.normalized().dot(Vector3.RIGHT) > 0.86,
		"the drawn sword crosses the actual attack direction at contact")
	var pause_end: float = fight.strike_clock
	step(0.023)
	expect(fight.strike_clock == pause_end and touches == 1, "hitstop freezes the sword without double-hitting")
	expect(level.scenery.impact.camera_offset().length() > 0.1, "confirmed contact drives the presentation impulse")
	enemy.removed = true
	for _i in range(35):
		step(STEP)

func test_windup(start: Vector2) -> void:
	level.player = start
	var enemy: ENEMY = fight.spawn(ENEMY.CRAWLER, 0)
	enemy.position = start + Vector2(37, 0)
	enemy.cooldown = 0.0
	enemy.speed = 0.0
	var health: float = fight.player_hp
	step(STEP)
	expect(enemy.tell > 0.23 and fight.player_hp == health, "melee enemy begins a readable tell without causing damage")
	var remaining: float = enemy.tell
	step(remaining - 0.015)
	expect(fight.player_hp == health and enemy.tell > 0.0, "the warning window does not injure the player")
	step(0.020)
	expect(enemy.attack_pose > 0.20 and fight.player_hp < health,
		"enemy contact applies one hit and enters recovery")
	enemy.removed = true
	step(STEP)

func test_dash(start: Vector2) -> void:
	level.player = start
	level.aim = Vector2.RIGHT
	expect(fight.dash(), "dash starts in the clear")
	expect(level.player == start, "dash movement is temporal")
	step(0.045)
	var partial: float = start.distance_to(level.player)
	expect(partial > 18.0 and partial < 100.0, "dash has a distinct intermediate state")
	step(0.100)
	var distance: float = start.distance_to(level.player)
	expect(distance > 108.0 and distance <= 112.5, "dash reaches its 112 pixel cap without overshoot")

func test_foot_plant(start: Vector2) -> void:
	level.player = start
	for _i in range(21):
		step(STEP)
	var rig: Dictionary = level.scenery.puppets.actors[fight.watcher]
	var last := [Vector3.ZERO, Vector3.ZERO]
	var stayed := [false, false]
	var began := [0, 0]
	var swing_frames := 0
	var grounded_frames := 0
	var drift := 0.0
	for _i in range(48):
		level.player += Vector2(2.55, 0.0)
		step(STEP)
		for side in range(2):
			var pin = rig.feet[side]
			var ankle: Vector3 = rig.boots[side].global_position
			var planted: bool = pin.age < 0.0
			if planted and stayed[side]:
				drift = maxf(drift, ankle.distance_to(last[side]))
				grounded_frames += 1
			elif not planted:
				swing_frames += 1
				if stayed[side]:
					began[side] += 1
			stayed[side] = planted
			last[side] = ankle
	expect(began[0] > 0 and began[1] > 0 and swing_frames > 20,
		"both legs take actual swing steps during traversal")
	expect(grounded_frames >= 40 and drift < 0.024,
		"the support ankle remains pinned during the walking phase")
	print("Planted stance: ", grounded_frames, " samples, worst ankle drift ", snappedf(drift,0.0001), " m per step")

func test_crowd(start: Vector2) -> void:
	level.player = start
	var walkers: Array[ENEMY] = []
	var group := start + Vector2(78.0, 0.0)
	for _i in range(4):
		var foe: ENEMY = fight.spawn(ENEMY.CRAWLER, 0)
		foe.position = group
		foe.facing = Vector2.RIGHT
		walkers.append(foe)
	for _i in range(25):
		fight.space_ground_enemies(STEP)
	var closest := INF
	for side in range(walkers.size()):
		for other in range(side+1, walkers.size()):
			closest = minf(closest, walkers[side].position.distance_to(walkers[other].position))
		walkers[side].removed = true
	expect(closest >= 17.0, "ground bodies spread into readable positions instead of sharing a center")
	step(STEP)

func test_tight_lane() -> void:
	var foe: ENEMY = fight.spawn(ENEMY.CRAWLER, 0)
	for lane in range(level.paths.size()):
		var path: PackedVector2Array = level.route_for_actor(lane, foe.radius)
		for index in range(1, path.size() - 1):
			var corner := path[index]
			var approach := corner.move_toward(path[index - 1], 7.0)
			var next := path[index + 1]
			if level.motion_against_world(approach, next - approach, foe.radius).distance_to(next) < 0.5:
				continue
			foe.lane = lane
			foe.path = path
			foe.waypoint = index
			foe.position = approach
			expect(fight.walker_guide(foe) == corner, "a tight bend cannot be shortcut through a wall")
			foe.waypoint = index + 1
			fight.reconnect_walker(foe)
			var detour: PackedVector2Array = foe.lane_detour
			expect(not detour.is_empty() and detour[-1] == path[foe.lane_resume],
				"a walker that has left the path reconnects to the same lane")
			foe.removed = true
			return
	foe.removed = true
	expect(false, "first biome includes a tight bend for the lane regression fixture")

func finish() -> void:
	level.ambience.stop()
	level.cue.stop()
	level.scenery.impact.air.stop()
	level.scenery.impact.contact.stop()
	level.queue_free()
	await create_timer(0.45).timeout
	quit(1 if failures > 0 else 0)

func expect(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
