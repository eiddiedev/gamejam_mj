extends Node2D

signal completed(won: bool)
signal return_requested

const Maps = preload("res://scripts/battle/BattleMaps.gd")
const Timekeeping = preload("res://scripts/battle/DayNightManager.gd")
const Waves = preload("res://scripts/battle/WaveSpawner.gd")
const Lights = preload("res://scripts/battle/LightManager.gd")
const Scenery = preload("res://scripts/battle/BattleArt.gd")
const Collision = preload("res://scripts/battle/BattleCollision.gd")
const Hazards = preload("res://scripts/battle/BiomeHazardSystem.gd")
const AudioSys = preload("res://scripts/battle/BattleAudio.gd")
const InputSys = preload("res://scripts/battle/BattleInput.gd")
const ViewState = preload("res://scripts/data/BattleViewState.gd")
const Combat = preload("res://scripts/entities/Combat.gd")
const HUD = preload("res://scenes/ui/BattleHUD.tscn")
const NightGift = preload("res://scenes/ui/NightGiftPanel.gd")
const FONT = preload("res://typeface.tres")
const SLOT_REACH := 72.0
const CAMP_REACH := 78.0
const PLAYER_RADIUS := 12.0
const FUEL_COST := 9
const OIL_COST := 6
const TOWER_IDS := ["brazier", "ballista", "barricade", "oil"]

@export_range(0, 3) var biome := 0
@export var elite := false
@export var boss := false

var run: Node
var combat: Node2D
var hud: CanvasLayer
var scenery: Scenery
var collision := Collision.new()
var light_manager: Lights
var shade: CanvasModulate
var hazards := Hazards.new()
var audio_sys: AudioSys
var input_sys := InputSys.new()
var paths: Array[PackedVector2Array] = []
var detours: Array[PackedVector2Array] = []
var slot_points: Array[Vector2] = []
var support_kind: Array[String] = []
var support_name: Array[String] = []
var high_slots: Array = []
var outer_slots: Array = []
var mud: Array[PackedVector2Array] = []
var walls: Array[PackedVector2Array] = []
var water: Array[PackedVector2Array] = []
var supplies: Array[Dictionary] = []
var crystals: Array[Dictionary] = []
var bridges: Array[Vector2] = []
var levers: Array[Vector2] = []
var phases := Timekeeping.new()
var spawner := Waves.new()
var font := FONT
var player := Vector2.ZERO
var aim := Vector2.RIGHT
var fire_point := Vector2.ZERO
var fire_hp := 100.0
var oil := 100.0
var lantern_on := true
var night := false
var night_age := 0.0
var clock := 0.0
var show_routes := false
var paused := false
var ended := false
var won := false
var open_slot := -1
var still := 0.0
var visual_elapsed := 0.0
var ready_to_exit := false
var perks := {"edge": 0, "lamp": 0, "step": 0, "blood": 0}
var night_rank := 1
var rank_previous := 0
var rank_target := 14
var perk_open := false
var perk_pending := false
var gift_panel: NightGift

var weather_age: float:
	get: return hazards.weather_age
	set(value): hazards.weather_age = value
var weather_left: float:
	get: return hazards.weather_left
	set(value): hazards.weather_left = value
var crystal_pulse: float:
	get: return hazards.crystal_pulse
	set(value): hazards.crystal_pulse = value
var crystal_power: float:
	get: return hazards.crystal_power
	set(value): hazards.crystal_power = value
var bridge_closed: int:
	get: return hazards.bridge_closed
	set(value): hazards.bridge_closed = value
var bridge_cooldown: float:
	get: return hazards.bridge_cooldown
	set(value): hazards.bridge_cooldown = value
var attack_held: bool:
	get: return input_sys.attack_held
	set(value): input_sys.attack_held = value
var ambience: AudioStreamPlayer:
	get: return audio_sys.ambience
var cue: AudioStreamPlayer:
	get: return audio_sys.cue


func _ready() -> void:
	run = get_node("/root/RunState")
	fire_hp = clampf(run.fire_start, 1.0, 100.0)
	oil = clampf(run.oil_start, 0.0, 100.0)
	install_layout()
	hazards.setup(self)
	input_sys.setup(self)
	shade = CanvasModulate.new()
	shade.color = Color("#cbcbb7")
	add_child(shade)
	scenery = Scenery.new()
	scenery.name = "Hand-inked battlefield"
	add_child(scenery)
	scenery.initialize(self)
	collision.setup(scenery.model, Maps.ART.grow(-8.0), water, bridges, paths)
	var imported: Array[MeshInstance3D] = []
	for candidate in scenery.model.find_children("*", "MeshInstance3D", true, false):
		if candidate.get_meta(&"walk_obstacle", false):
			imported.append(candidate)
	register_environment_collision(imported)
	light_manager = Lights.new()
	add_child(light_manager)
	light_manager.install_walls(walls, scenery.model)
	combat = Combat.new()
	add_child(combat)
	combat.setup(self)
	if combat.has_signal("enemy_slain"):
		combat.enemy_slain.connect(on_enemy_slain)
	scenery.attach_combat()
	hud = HUD.instantiate()
	add_child(hud)
	hud.set_place(Maps.NAMES[biome], Maps.LAND[biome] + ("  /  精英守夜" if elite else "  /  烽火防线"))
	hud.build_requested.connect(build_selected)
	hud.upgrade_requested.connect(upgrade_selected)
	hud.build_cancelled.connect(close_build)
	hud.advance_requested.connect(start_night)
	hud.pause_requested.connect(toggle_pause)
	hud.resume_requested.connect(toggle_pause)
	hud.return_requested.connect(leave_battle)
	hud.result_requested.connect(acknowledge_battle)
	hud.announce("趁天还有光，先搜集余烬和骨材。靠近遗迹可按 E 修缮。")
	audio_sys = AudioSys.new()
	add_child(audio_sys)
	audio_sys.setup()
	refresh_lights()
	refresh_view()


func install_layout() -> void:
	var layout: Dictionary = Maps.MAPS[biome]
	fire_point = Maps.point(layout["fire"])
	player = Maps.point(layout["start"])
	paths = Maps.polygons(layout["routes"])
	detours = Maps.polygons(layout.get("detours", []))
	walls = Maps.polygons(layout["walls"])
	mud = Maps.polygons(layout.get("mud", []))
	water = Maps.polygons(layout.get("water", []))
	for support in Maps.SUPPORTS[biome]:
		slot_points.append(Maps.point(support[0]))
		support_kind.append(support[2])
		support_name.append(support[3])
	bridges.assign(Array(Maps.line(layout.get("bridges", []))))
	levers.assign(Array(Maps.line(layout.get("levers", []))))
	high_slots = layout.get("high", [])
	outer_slots = layout.get("outer", [])
	for pair in layout.get("crystals", []):
		crystals.append({"position": Maps.point(pair), "hp": 90.0})
	for index in range(paths.size()):
		var path := Path2D.new()
		path.name = layout["route_names"][index]
		var curve := Curve2D.new()
		for point in paths[index]:
			curve.add_point(point)
		path.curve = curve
		add_child(path)
	place_supplies(false)


func place_supplies(second: bool) -> void:
	supplies.clear()
	var places: Array = Maps.MAPS[biome]["supply"]
	for index in range(places.size()):
		var at := Maps.point(places[index])
		var bones := (index + int(second)) % 3 != 0
		supplies.append({"position": at, "available": true, "embers": 9 if bones else 14,
			"bone": 7 if bones else 0, "phase": index * 0.43})


func _physics_process(delta: float) -> void:
	if paused or ended:
		return
	clock += delta
	phases.advance(delta)
	aim = player.direction_to(get_global_mouse_position())
	if aim.is_zero_approx():
		aim = Vector2.RIGHT
	move_watcher(delta)
	tick_environment(delta)
	if night:
		night_age += delta
		hurt_fire(delta * (0.8 if biome == 3 else 0.4))
		if ended:
			return
		if lantern_on:
			oil = maxf(0.0, oil - delta * 0.75)
			if oil == 0.0:
				lantern_on = false
				announce("提灯无油。回篝火旁按 Q 借火。")
		spawner.release(night_age, spawn_arrival)
	refresh_lights()
	combat.tick(delta)
	if ended:
		return
	if not night and phases.left == 0.0:
		start_night()
	elif night and spawner.remaining() == 0 and combat.count_enemies() == 0:
		if phases.night_number == Timekeeping.NIGHTS:
			finish_battle(true)
		else:
			next_dusk()
	hud.next_frame(delta)
	visual_elapsed += delta
	if visual_elapsed >= 1.0 / 30.0:
		visual_elapsed = 0.0
		refresh_view()


func move_watcher(delta: float) -> void:
	var direction := input_sys.read_move_direction()
	still = still + delta if direction.is_zero_approx() else 0.0
	if not direction.is_zero_approx():
		var modifiers: Dictionary = OathDatabase.player_modifiers(run.oaths, player.distance_to(fire_point), fire_hp)
		var speed: float = 194.0 * modifiers["move"] * pace_factor(player) * (1.0 + perks["step"] * 0.07)
		if combat.has_method(&"player_move_factor"):
			speed *= combat.player_move_factor()
		var motion := speed * delta * direction
		var next := motion_against_world(player, motion, PLAYER_RADIUS)
		var remainder := player + motion - next
		player = next
		if remainder.length_squared() > 0.1:
			player = motion_against_world(player, Vector2(remainder.x, 0.0), PLAYER_RADIUS)
			player = motion_against_world(player, Vector2(0.0, remainder.y), PLAYER_RADIUS)
	if open_slot >= 0 and player.distance_to(slot_points[open_slot]) > SLOT_REACH + 16.0:
		close_build()


func can_walk(at: Vector2) -> bool:
	return collision.can_stand(at, PLAYER_RADIUS)


func motion_against_world(start: Vector2, motion: Vector2, radius: float, airborne := false) -> Vector2:
	return collision.sweep(start, motion, radius, airborne)


func route_for_actor(lane: int, radius := 15.0) -> PackedVector2Array:
	return collision.route(lane, enemy_path(lane), radius)


func find_motion_path(from: Vector2, to: Vector2, radius: float, airborne := false) -> PackedVector2Array:
	return collision.search(from, to, radius, airborne)


func register_environment_collision(instances: Array[MeshInstance3D]) -> void:
	if not instances.is_empty():
		collision.register_meshes(instances)


func pace_factor(at: Vector2) -> float:
	return hazards.pace_factor(at)


func start_night() -> void:
	if ended or paused or night:
		return
	close_build()
	phases.start_night()
	night = true
	night_age = 0.0
	hazards.reset_weather()
	show_routes = false
	spawner.prepare(biome, phases.night_number, elite, boss, run.cycle)
	combat.reset_night()
	play_cue("wave")
	announce("夜幕合拢。提灯扫暗处，挥剑护住篝火。")
	refresh_view()


func next_dusk() -> void:
	phases.next_dusk()
	night = false
	night_age = 0.0
	hazards.reset_weather()
	place_supplies(true)
	run.embers += 16
	run.bone += 9
	show_routes = false
	play_cue("dusk")
	announce("天将再暗。趁喘息之际，搜补给、添火、修营。")


func spawn_arrival(kind: int, lane: int) -> void:
	var enemy = combat.spawn(kind, lane)
	if enemy != null and night_age < 5.5 and kind != 5:
		var waypoint: int = maxi(1, enemy.path.size() - 4)
		enemy.position = enemy.path[waypoint]
		enemy.waypoint = waypoint + 1


func on_enemy_slain(_species: int, _experience: int, _where: Vector2) -> void:
	if not ended and not perk_open and not perk_pending and night_rank < 5 and combat.xp >= rank_target:
		perk_pending = true
		open_night_perks.call_deferred()


func open_night_perks() -> void:
	perk_pending = false
	if ended or perk_open or paused or night_rank >= 5 or combat.xp < rank_target:
		return
	perk_open = true
	cancel_pointer_attack()
	paused = true
	sync_hud()
	gift_panel = NightGift.new()
	add_child(gift_panel)
	gift_panel.chosen.connect(choose_night_perk, CONNECT_ONE_SHOT)
	gift_panel.show_choices(night_rank, perks)


func choose_night_perk(id: String) -> void:
	if not perk_open or not perks.has(id):
		return
	perks[id] += 1
	match id:
		"lamp":
			oil = minf(100.0, oil + 18.0)
		"blood":
			combat.player_hp_max += 10.0
			combat.player_hp = minf(combat.player_hp_max, combat.player_hp + 30.0)
	rank_previous = rank_target
	night_rank += 1
	rank_target += 13 + night_rank * 7
	gift_panel.queue_free()
	gift_panel = null
	perk_open = false
	paused = false
	play_cue("fuel")
	refresh_view()


func enemy_path(lane: int) -> PackedVector2Array:
	return hazards.enemy_path(lane)


func tick_environment(delta: float) -> void:
	hazards.tick(delta)


func is_harsh_weather() -> bool:
	return hazards.is_harsh_weather()


func night_fraction() -> float:
	return clampf(night_age / Timekeeping.NIGHT_TIME, 0.0, 1.0)


func crystal_buff_at(at: Vector2) -> bool:
	return hazards.crystal_buff_at(at)


func damage_crystal(index: int, damage: float) -> void:
	hazards.damage_crystal(index, damage)


func damage_crystals_at(origin: Vector2, facing: Vector2, reach: float, damage: float) -> void:
	hazards.damage_crystals_at(origin, facing, reach, damage)


func use_bridge() -> void:
	hazards.use_bridge()


func light_radius_scale() -> float:
	return hazards.light_radius_scale()


func weather_status() -> String:
	return hazards.weather_status()


func refresh_lights() -> void:
	var active: Array[Dictionary] = []
	var radius_scale := light_radius_scale()
	if fire_hp > 0.0:
		active.append({"position": fire_point, "radius": lerpf(62.0, 219.0, fire_hp / 100.0) * radius_scale,
			"energy": 1.33, "height": scenery.model.hearth_light.position.y})
	if lantern_on and oil > 0.0:
		var rule: Dictionary = OathDatabase.lantern_modifiers(run.oaths, still)
		var lamp := {"position": player, "radius": 152.0 * radius_scale * rule["radius"] * (1.0 + perks["lamp"] * 0.16), "energy": 0.70,
			"color": Color("#ffcb81"), "height": 0.8}
		if rule["radius"] < 2.0:
			lamp["aim"] = aim
		active.append(lamp)
	for source in combat.light_sources():
		var scaled: Dictionary = source.duplicate()
		scaled["radius"] *= radius_scale
		var support := slot_points.find(source["position"])
		if support >= 0:
			scaled["height"] = float(Maps.SUPPORTS[biome][support][1]) + 0.59
		active.append(scaled)
	var chains: Array[Dictionary] = []
	for link in combat.light_links():
		chains.append(link)
	light_manager.set_sources(active, chains)


func build_view_state() -> ViewState:
	var state := ViewState.new()
	state.night = night
	state.night_number = phases.night_number
	state.phase_left = phases.left
	state.phase_progress = phases.progress()
	state.fire_hp = fire_hp
	state.oil = oil
	state.embers = run.embers
	state.bone = run.bone
	state.spawner_remaining = spawner.remaining()
	state.live_enemies = combat.count_enemies()
	state.player_hp = combat.player_hp
	state.player_hp_max = combat.player_hp_max
	state.xp = combat.xp
	state.rank_previous = rank_previous
	state.rank_target = rank_target
	state.night_rank = night_rank
	state.kills = combat.kills
	state.ended = ended
	state.paused = paused
	state.weather_text = weather_status()
	state.action_hint = action_hint()
	populate_inspection(state)
	return state


func populate_inspection(state: ViewState) -> void:
	if paused or ended:
		return
	var selecting: bool = open_slot >= 0 and hud.is_menu_open()
	var selected: int = open_slot if selecting else hovered_support()
	if selected < 0:
		return
	var tower = combat.towers[selected]
	var radius: float = combat.inspect_radius(selected)
	var current := radius
	var planned := 0.0
	if tower.level == 0 or (tower.kind == "brazier" and not tower.lit) or (tower.kind == "oil" and tower.spent and tower.burn <= 0.0):
		planned = current
		current = 0.0
	elif selecting and tower.level < 3:
		planned = combat.inspect_radius(selected, true)
	state.inspect_visible = true
	state.inspect_selecting = selecting
	state.inspect_at = slot_points[selected]
	state.inspect_marker = get_global_transform_with_canvas() * support_muzzle(selected)
	state.inspect_radius = radius
	state.inspect_current = current
	state.inspect_planned = planned
	state.inspect_title = support_name[selected]
	state.inspect_level = tower.level


func hovered_support() -> int:
	var cursor: Vector2 = get_global_mouse_position()
	var selected := -1
	var nearest := 25.0 ** 2
	for index in slot_points.size():
		var distance := cursor.distance_squared_to(slot_points[index])
		distance = minf(distance, cursor.distance_squared_to(support_muzzle(index)))
		if distance < nearest:
			nearest = distance
			selected = index
	return selected


func sync_hud() -> void:
	var state := build_view_state()
	if state.inspect_visible:
		scenery.show_support_range(state.inspect_at, state.inspect_current, state.inspect_planned)
	else:
		scenery.hide_support_range()
	hud.apply_state(state)


func sync_inspection() -> void:
	var state := build_view_state()
	if state.inspect_visible:
		scenery.show_support_range(state.inspect_at, state.inspect_current, state.inspect_planned)
	else:
		scenery.hide_support_range()
	hud.apply_inspection(state)


func refresh_view() -> void:
	var dark := Color("#647791") if night else Color("#d0d3bb")
	if weather_left > 0.0 and biome == 0:
		dark = dark.lerp(Color("#5e7c73"), 0.36)
	shade.color = shade.color.lerp(dark, 0.23)
	light_manager.refresh_visuals(clock)
	scenery.update_art()
	sync_hud()


func hurt_fire(amount: float, enemy_hit := false) -> void:
	if ended:
		return
	fire_hp = maxf(0.0, fire_hp - amount)
	if enemy_hit and amount > 0.0:
		hud.flash_fire()
	if fire_hp <= 0.0:
		finish_battle(false)


func heal_fire(amount: float) -> void:
	if not ended:
		fire_hp = minf(100.0, fire_hp + amount)


func announce(words: String) -> void:
	hud.announce(words)


func closest(points: Array[Vector2], reach: float) -> int:
	return input_sys.closest(points, reach)


func support_muzzle(index: int) -> Vector2:
	var fixture: Node3D = scenery.reliquary.contents[index]
	return scenery.model.camera.unproject_position(fixture.to_global(Vector3(0.0, 0.23, 0.0)))


func available_supply() -> int:
	return input_sys.available_supply()


func action_hint() -> String:
	return input_sys.action_hint()


func interact() -> void:
	input_sys.interact()


func borrow_fire() -> void:
	input_sys.borrow_fire()


func needs_preparation() -> bool:
	return input_sys.needs_preparation()


func open_build(index: int) -> void:
	cancel_pointer_attack()
	open_slot = index
	var options: Array[Dictionary] = combat.build_options(index)
	for item in options:
		item["compatible"] = item["kind"] == support_kind[index]
		item["site"] = support_name[index]
	hud.open_build(options, combat.upgrade_options(index), index, support_muzzle(index))
	sync_inspection()


func close_build() -> void:
	open_slot = -1
	hud.close_build()
	sync_inspection()


func build_selected(kind: int) -> void:
	if not night and not ended and open_slot >= 0 and support_kind[open_slot] == TOWER_IDS[kind] and combat.build(open_slot, TOWER_IDS[kind]):
		close_build()


func upgrade_selected() -> void:
	if not night and not ended and open_slot >= 0 and combat.upgrade(open_slot):
		close_build()


func _input(event: InputEvent) -> void:
	input_sys.handle_input(event)


func _unhandled_input(event: InputEvent) -> void:
	input_sys.handle_unhandled_input(event)


func cancel_pointer_attack() -> void:
	input_sys.cancel_pointer_attack()


func toggle_pause() -> void:
	if ended or perk_open:
		return
	if open_slot >= 0:
		close_build()
		return
	paused = not paused
	sync_inspection()
	if paused:
		cancel_pointer_attack()
		hud.show_pause()
	else:
		hud.hide_pause()
		if night and combat.xp >= rank_target:
			open_night_perks.call_deferred()


func leave_battle() -> void:
	return_requested.emit()


func finish_battle(success: bool) -> void:
	if ended:
		return
	won = success
	ended = true
	cancel_pointer_attack()
	phases.finish(success)
	if won:
		run.fire_start = fire_hp
	play_cue("dawn" if won else "lost")
	refresh_view()
	hud.show_result(won)


func acknowledge_battle() -> void:
	if ended and not ready_to_exit:
		ready_to_exit = true
		completed.emit(won)


func play_cue(cue_name: String) -> void:
	audio_sys.play_cue(cue_name)
