extends SceneTree

const DayNight = preload("res://scripts/battle/DayNightManager.gd")
const Maps = preload("res://scripts/battle/BattleMaps.gd")
const TOWERS := ["brazier", "ballista", "barricade", "oil"]
const SEED := 51618324
const STEP := 0.5

var checks := 0
var failures := 0
var capture_folder := ""
var campaign
var state

func _initialize() -> void:
	run_test.call_deferred()

func run_test() -> void:
	root.size = Vector2i(1280, 800)
	state = root.get_node("RunState")
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty() and DisplayServer.get_name() != "headless":
		capture_folder = arguments[0]
		DirAccess.make_dir_recursive_absolute(capture_folder)
	state.start_new(SEED)
	campaign = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(campaign)
	await process_frame
	await test_campaign()
	await test_environments()
	campaign.queue_free()
	await create_timer(0.12).timeout
	print("Night Watcher campaign: %d checks, %d failed" % [checks, failures])
	quit(int(failures > 0))

func test_campaign() -> void:
	var first: Dictionary = state.available_nodes()[0]
	var route: Array = state.nodes.duplicate(true)
	var map = campaign.screen
	expect(first.id == map.selected and first.zone == 0 and state.run_seed == SEED,
		"The deterministic map selects its first reachable valley battle")
	await capture("01-world-map")
	await press_button(map.confirm)
	var battle = campaign.screen
	if not expect(battle != map and state.active_node == first.id, "Map confirm enters the valley battle"):
		return
	battle.set_physics_process(false)
	var paths: Array[Node] = battle.find_children("*", "Path2D", false, false)
	expect(paths.size() == 3 and paths.all(func(path): return path.curve.point_count >= 8),
		"First battle instantiates three authored invasion paths")
	expect(battle.slot_points.size() == 8 and DayNight.NIGHTS == 2 and not battle.night,
		"First battle starts at dusk with eight fixed slots and two nights")
	check_modeled_battlefield(battle)
	expect(battle.light_manager.is_position_lit(battle.fire_point + Vector2(15.0, 0.0)),
		"LightManager lights the near side of the hearth")
	expect(not battle.light_manager.is_position_lit(Vector2(14.0, 20.0)),
		"Distant terrain stays outside the active lights")
	await capture("02-valley-dusk")

	var first_supply: Dictionary = battle.supplies[0]
	var prior_embers: int = state.embers
	var prior_bone: int = state.bone
	battle.player = first_supply.position
	send_key(KEY_E)
	expect(not first_supply.available and state.embers == prior_embers + first_supply.embers
		and state.bone == prior_bone + first_supply.bone, "E collects a supply cache and pays each resource once")
	for supply in battle.supplies:
		supply.available = false

	state.embers = 999
	state.bone = 999
	for kind in range(4):
		var index: int = battle.support_kind.find(TOWERS[kind])
		battle.player = battle.slot_points[index]
		send_key(KEY_E)
		if expect(battle.open_slot == index and compatible_count(battle.hud.gear_buttons) == 1
				and is_instance_valid(battle.hud.gear_buttons[kind]),
				"Facing type %d offers only the structure attached to that ruin" % (kind + 1)):
			if kind == 0:
				var before_build: int = state.embers
				send_key(KEY_4)
				expect(state.embers == before_build and battle.open_slot == index,
					"A shortcut cannot install an incompatible support at the ruin")
				await capture("02a-contextual-support")
			await press_button(battle.hud.gear_buttons[kind])
			var structure: Dictionary = battle.combat.upgrade_options(index)
			expect(structure.get("kind", -1) == kind and structure.get("level", 0) == 1,
				"Build choice %d spends resources and creates its Lv.1 structure" % (kind + 1))
	expect(state.embers < 999 and state.bone < 999, "Building consumes both fixture resources")
	var ballista: int = battle.support_kind.find("ballista")
	battle.player = battle.slot_points[ballista]
	send_key(KEY_E)
	if expect(battle.open_slot == ballista and is_instance_valid(battle.hud.upgrade_button),
			"An occupied slot opens the upgrade pane"):
		await press_button(battle.hud.upgrade_button)
		expect(battle.combat.upgrade_options(ballista).get("level", 0) == 2, "Upgrade advances the ballista to Lv.2")

	battle.fire_hp = 53.0
	battle.oil = 32.0
	battle.combat.player_hp = 37.0
	battle.lantern_on = false
	battle.player = battle.fire_point
	prior_embers = state.embers
	send_key(KEY_E)
	send_key(KEY_Q)
	expect(is_equal_approx(battle.fire_hp, 75.0) and is_equal_approx(battle.oil, 84.0)
		and is_equal_approx(battle.combat.player_hp, 72.0) and battle.lantern_on
		and state.embers == prior_embers - 15, "E refuels the hearth and Q restores the lantern and the watcher")
	battle.refresh_view()
	expect(battle.hud.health_label.text.begins_with("72 / "), "HUD displays the watcher's restored health")

	send_key(KEY_ENTER)
	if not expect(battle.night and battle.phases.night_number == 1 and battle.spawner.remaining() > 0,
			"Enter starts the first scheduled night"):
		return
	var first_schedule: Array = battle.spawner.schedule.duplicate(true)
	var prior_fire: float = battle.fire_hp
	battle._physics_process(STEP)
	expect(is_equal_approx(battle.fire_hp, prior_fire - 0.4 * STEP), "Night naturally drains fire at 0.4 per second")
	var unscaled_radius: float = battle.light_manager.sources[0].radius
	battle.tick_environment(40.0)
	battle.refresh_lights()
	expect(is_equal_approx(battle.pace_factor(poly_center(battle.mud[0])), 0.75)
		and battle.is_harsh_weather() and is_equal_approx(battle.light_manager.sources[0].radius, unscaled_radius * 0.70),
		"Valley mud slows and its 40-second fog shrinks active light radii")
	battle.weather_left = 0.0
	battle.weather_age = 0.0
	battle._physics_process(3.0)
	expect(battle.combat.count_enemies() > 0, "The first wave schedule spawns live enemies")
	exercise_charged_strike(battle)
	battle.scenery.puppets.sync(0.0)
	var live: Array = battle.combat.enemies.filter(func(foe): return not foe.removed)
	expect(live.all(func(foe): return battle.scenery.puppets.actors.has(foe) and not foe.draw_body),
		"Live wave enemies use articulated 3D rigs")
	battle.refresh_view()
	await capture("03-valley-night")
	await drain_night(battle)
	if not expect(not battle.night and battle.phases.night_number == 2 and not battle.ended,
			"Clearing the first night naturally opens the second dusk"):
		return
	expect(battle.supplies.any(func(supply): return supply.available), "Second dusk refreshes pickup supplies")
	expect(battle.night_rank > 1 and battle.combat.xp >= battle.rank_previous and battle.combat.kills > 0,
		"Enemy kills advance the watcher's night rank and carry XP into the second dusk")
	send_key(KEY_ENTER)
	expect(battle.night and battle.spawner.schedule != first_schedule and battle.spawner.remaining() > 0,
		"The second dusk leads into a distinct populated schedule")
	await drain_night(battle)
	if not expect(battle.ended and battle.won and battle.phases.phase == DayNight.Phase.DAWN
			and battle.fire_hp > 0.0, "Clearing both nights reaches dawn with fire remaining"):
		return
	var proceed := find_button(battle.hud, "继续行程")
	if not expect(proceed != null, "Dawn shows the normal continue action"):
		return
	await stop_level_audio(battle)
	await press_button(proceed)
	await process_frame
	var forge = campaign.screen
	if not expect(forge.name == &"OathForgeUI" and forge.offers.size() == 3 and forge.offers[0] == "SWORE",
			"First victory presents the three-stone forge with guaranteed SWORE"):
		return
	await press_button(forge.runes[0])
	expect(forge.selected == 0 and forge.runes[0].text == "D", "Clicking the glowing D selects the SWORD engraving")
	await capture("04-sword-oath")
	send_key(KEY_E, 69)
	if not expect(forge.forging and forge.runes[0].text == "E", "Typing E replaces D and forges SWORE"):
		return
	if not capture_folder.is_empty():
		await create_timer(0.25).timeout
		await capture("05-swore")
	await create_timer(0.90).timeout
	await process_frame
	expect(state.oaths == ["SWORE"] and state.visited == [first.id] and state.active_node == -1,
		"The campaign saves SWORE, marks the valley visited and releases the next routes")
	expect(campaign.screen.name == &"WorldMap" and state.available_nodes().size() >= 2,
		"Forging returns to the map with multiple paths available")

	state.upgrade_blueprint("ballista")
	state.relics.append("守火铜环")
	campaign.next_cycle()
	expect(state.cycle == 2 and state.nodes != route and state.visited.is_empty() and state.current_node == -1,
		"Endless cycle reshuffles the route and resets location")
	expect(state.oaths.has("SWORE") and state.blueprints.get("ballista") == 2 and state.relics.has("守火铜环"),
		"Endless cycle preserves the oath, upgraded blueprint and relic")
	await capture("06-endless-route")

func exercise_charged_strike(battle) -> void:
	var lane := test_strike_lane(battle, battle.fire_point, 80.0, 118.0, 15.0)
	if not expect(lane.size() == 2, "A clear fixture lane fits an extended sword strike"):
		return
	var foe = battle.combat.spawn(3, 1)
	battle.player = lane[0]
	battle.aim = lane[0].direction_to(lane[1])
	foe.position = lane[1]
	foe.speed = 0.0
	var stroke := InputEventMouseButton.new()
	stroke.button_index = MOUSE_BUTTON_LEFT
	stroke.position = Vector2(1060.0, 506.0)
	stroke.global_position = stroke.position
	stroke.pressed = true
	root.push_input(stroke, true)
	expect(battle.combat.charge_started, "Holding the attack button begins a charge")
	battle.combat.tick(0.45)
	var prior: float = foe.health
	stroke = stroke.duplicate() as InputEventMouseButton
	stroke.pressed = false
	root.push_input(stroke, true)
	expect(battle.combat.strike_heavy and not battle.combat.charge_started and is_equal_approx(foe.health, prior),
		"Release commits a charged strike without dealing damage during its windup")
	tick_to_strike_contact(battle)
	expect(foe.health < prior, "A charged strike reaches a foe beyond ordinary sword range at blade contact")

func test_strike_lane(battle, anchor: Vector2, distance: float, strike: float, foe_radius: float) -> PackedVector2Array:
	for radial in 8:
		var offset := Vector2.from_angle(radial * TAU / 8.0)
		var origin := anchor + offset * distance
		if not battle.can_walk(origin):
			continue
		for heading in 8:
			var motion := Vector2.from_angle(heading * TAU / 8.0) * strike
			var endpoint := origin + motion
			if not battle.collision.can_stand(endpoint, foe_radius):
				continue
			var lunge: Vector2 = battle.motion_against_world(origin, motion.normalized() * 10.0, 12.0)
			var blade_path: Vector2 = battle.motion_against_world(origin, motion, 1.5)
			if lunge.distance_squared_to(origin + motion.normalized() * 10.0) < 2.0 \
					and blade_path.distance_squared_to(endpoint) < 2.0:
				return PackedVector2Array([origin, endpoint])
	return PackedVector2Array()

func tick_to_strike_contact(battle) -> void:
	var frames := ceili(battle.combat.strike_contact_time() * 60.0) + 1
	for frame in frames:
		battle.combat.tick(1.0 / 60.0)

func drain_night(battle) -> void:
	# Defeat spawned fixtures through the same damage path as weapons.
	for tick in 160:
		if not battle.night or battle.ended:
			return
		for enemy in battle.combat.enemies.duplicate():
			battle.combat.damage_enemy(enemy, 10000.0)
		if battle.perk_pending:
			await process_frame
		if battle.perk_open:
			var before: int = battle.night_rank
			var id: String = battle.gift_panel.offers[0][0]
			var prior: int = battle.perks[id]
			expect(battle.hud.xp_fraction == 1.0 and battle.hud.slain_label.text == "击杀 %d" % battle.combat.kills,
				"HUD refreshes XP and kills before the night gift pauses combat")
			if before == 1 and not capture_folder.is_empty():
				await create_timer(0.18).timeout
				await capture("03a-night-gift")
			send_key(KEY_1)
			expect(not battle.perk_open and battle.night_rank == before + 1 and battle.perks[id] == prior + 1,
				"The active night gift applies its perk and resumes the battle")
			expect(battle.hud.rank_label.text.begins_with("夜阶 %d" % (before + 1)),
				"The combat HUD displays the new night rank")
			await process_frame
		battle._physics_process(STEP)

func compatible_count(buttons: Array[Button]) -> int:
	var count := 0
	for option in buttons:
		if is_instance_valid(option):
			count += 1
	return count

func test_environments() -> void:
	var model = load("res://scripts/model/BattleModel.gd")
	expect(Maps.NAMES.size() == 4 and Maps.RULES.size() == 4 and model.REGIONS.size() == 4,
		"All four biomes provide a place, environment rule and modeled art")
	var sand = create_environment(1)
	await physics_frame
	await process_frame
	state.embers = 999
	state.bone = 999
	var exposed: int = sand.support_kind.find("brazier")
	var source: Vector2 = sand.slot_points[exposed]
	sand.open_build(exposed)
	sand.build_selected(0)
	var high: int = sand.support_kind.find("ballista")
	var adjacent: int = sand.support_kind.rfind("brazier")
	state.add_oath("BOND")
	sand.open_build(high)
	sand.build_selected(1)
	sand.open_build(adjacent)
	sand.build_selected(0)
	sand.refresh_lights()
	expect(sand.combat.towers[high].high_ground and has_source(sand, source),
		"Canyon has high ground and an active exposed brazier")
	var links: Array[Dictionary] = sand.combat.light_links()
	var connection: Vector2 = sand.slot_points[high].lerp(sand.slot_points[adjacent], 0.5)
	expect(not links.is_empty() and links[0].has("width") and links[0].has("dps")
		and sand.light_manager.strength_at(connection) >= 0.65, "BOND supplies structured lit links to the LightManager")
	sand.start_night()
	var lane := test_strike_lane(sand, connection, 55.0, 43.0, 10.0)
	if expect(lane.size() == 2, "A clear canyon fixture lane fits a sword strike near the tower"):
		sand.player = lane[0]
		sand.aim = lane[0].direction_to(lane[1])
		var target = sand.combat.spawn(0, 0)
		target.position = lane[1]
		target.speed = 0.0
		var prior_health: float = target.health
		send_key(KEY_SPACE)
		tick_to_strike_contact(sand)
		expect(target.health < prior_health and sand.combat.towers[high].sworn > 3.8,
			"An actual melee hit with forged SWORE grants the timed tower oath")
	sand.tick_environment(45.0)
	sand.refresh_lights()
	expect(sand.weather_left > 0.0 and not has_source(sand, source),
		"Canyon sandstorm extinguishes an unprotected outer brazier")
	state.oaths.erase("BOND")
	await stop_level_audio(sand)
	sand.queue_free()
	await process_frame

	var keep = create_environment(2)
	var main_path: PackedVector2Array = keep.enemy_path(0)
	keep.player = keep.bridges[0]
	send_key(KEY_R)
	expect(keep.bridge_closed < 0, "The lever cannot raise the bridge under the watcher")
	keep.player = lever_bank(keep, 0)
	send_key(KEY_R)
	expect(keep.bridge_closed == 0 and keep.enemy_path(0) != main_path and keep.bridge_cooldown == 15.0,
		"R raises the west bridge, diverts the corresponding lane and starts a cooldown")
	keep.player = lever_bank(keep, 1)
	send_key(KEY_R)
	expect(keep.bridge_closed == 0, "Bridge input respects its cooldown")
	keep.tick_environment(15.0)
	send_key(KEY_R)
	expect(keep.bridge_closed == 1 and keep.enemy_path(0) == main_path,
		"After cooldown the bridge can switch to the other route")
	await stop_level_audio(keep)
	keep.queue_free()
	await process_frame

	var wall = create_environment(3)
	wall.start_night()
	var baseline: float = wall.fire_hp
	wall._physics_process(STEP)
	expect(wall.is_harsh_weather() and is_equal_approx(wall.fire_hp, baseline - 0.8 * STEP),
		"Obsidian blizzard doubles the natural fire decay")
	wall.tick_environment(30.0)
	var crystal: Dictionary = wall.crystals[0]
	expect(wall.crystal_pulse > 0.0 and wall.crystal_buff_at(crystal.position),
		"Rift crystals briefly strengthen the enemies around their pulse")
	wall.damage_crystal(0, 1000.0)
	expect(crystal.hp == 0.0 and not wall.crystal_buff_at(crystal.position),
		"Destroying a crystal removes its local buff")
	await stop_level_audio(wall)
	wall.queue_free()
	await process_frame

func stop_level_audio(battle) -> void:
	for speaker: AudioStreamPlayer in [battle.cue, battle.ambience]:
		speaker.stop()
		speaker.stream = null
	await create_timer(0.075).timeout

func create_environment(id: int) -> Node2D:
	var battle = load("res://scenes/levels/BaseBattleLevel.tscn").instantiate()
	battle.biome = id
	root.add_child(battle)
	battle.set_physics_process(false)
	check_modeled_battlefield(battle)
	return battle

func check_modeled_battlefield(battle) -> void:
	var region = battle.scenery.model
	var terrain = region.get_node_or_null("Terrain, ruins and landmarks")
	expect(battle.scenery.texture is ViewportTexture and region.camera is Camera3D
		and terrain is MeshInstance3D and terrain.mesh.get_surface_count() > 0,
		"Biome %d presents live modeled terrain through a Camera3D" % battle.biome)
	var rigs = battle.scenery.puppets
	var actor = battle.combat.watcher
	expect(is_instance_valid(rigs) and rigs.actors.has(actor) and not actor.draw_body
		and rigs.actors[actor].root.find_children("*", "MeshInstance3D", true, false).size() > 0,
		"Biome %d presents the watcher as an articulated 3D actor" % battle.biome)

func lever_bank(battle, index: int) -> Vector2:
	var lever: Vector2 = battle.levers[index]
	var bridge: Vector2 = battle.bridges[index]
	return lever + bridge.direction_to(lever) * 26.0

func has_source(battle, position: Vector2) -> bool:
	return battle.light_manager.sources.any(func(source): return source.position.is_equal_approx(position))

func poly_center(shape: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in shape:
		sum += point
	return sum / shape.size()

func send_key(code: Key, unicode := 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	root.push_input(event, true)

func find_button(parent: Node, label: String) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if node.text == label:
			return node
	return null

func press_button(target: Button) -> void:
	await process_frame
	var center := target.get_global_transform_with_canvas() * (target.size * 0.5)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = center
	event.global_position = center
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func capture(stem: String) -> void:
	if capture_folder.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	expect(image.save_png(capture_folder.path_join(stem + ".png")) == OK, "Captured " + stem)

func expect(holds: bool, description: String) -> bool:
	checks += 1
	if not holds:
		failures += 1
		push_error(description)
	return holds
