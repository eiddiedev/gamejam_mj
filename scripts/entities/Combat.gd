extends Node2D

signal enemy_slain(species: int, xp: int, where: Vector2)
signal enemy_struck(where: Vector2, species: int, flame: bool)
signal charged_cut(where: Vector2, direction: Vector2)
signal blade_cuts(where: Vector2, direction: Vector2, heavy: bool)
signal melee_contact(where: Vector2, direction: Vector2, weight: float, armored: bool, heavy: bool)
signal enemy_contact(where: Vector2, direction: Vector2, heavy: bool)
signal herald_cast(where: Vector2, extinguished: PackedVector2Array)
signal moth_contact(where: Vector2, direction: Vector2, destination: int, moth: Node2D)

enum MothDestination { HEARTH, BRAZIER, LANTERN }

const Slot = preload("res://scripts/entities/TowerController.gd")
const Enemy = preload("res://scripts/entities/EnemyController.gd")
const Watcher = preload("res://scripts/entities/PlayerController.gd")
const Campfire = preload("res://scripts/entities/CampfireController.gd")
const Oaths = preload("res://scripts/autoload/OathDatabase.gd")
const Effects = preload("res://scripts/entities/CombatEffects.gd")
const Towers = preload("res://scripts/entities/TowerSystem.gd")
const PlayerSys = preload("res://scripts/entities/PlayerCombat.gd")
const Enemies = preload("res://scripts/entities/EnemySystem.gd")
const WATCHER_SCENE = preload("res://scenes/entities/Player.tscn")
const FIRE_SCENE = preload("res://scenes/entities/Campfire.tscn")
const HERALD_INTERVAL := Enemies.HERALD_INTERVAL
const HERALD_WARNING := Enemies.HERALD_WARNING

var battle: Node2D
var oath_book: Oaths
var watcher: Watcher
var campfire: Campfire
var ally: Watcher
var effects_layer: Effects
var tower_sys := Towers.new()
var player_sys := PlayerSys.new()
var enemy_sys := Enemies.new()

var towers: Array[Slot]:
	get: return tower_sys.towers
var enemies: Array[Enemy]:
	get: return enemy_sys.enemies
var links: Array[Dictionary]:
	get: return tower_sys.links
var player_hp: float:
	get: return player_sys.player_hp
	set(value): player_sys.player_hp = value
var player_hp_max: float:
	get: return player_sys.player_hp_max
	set(value): player_sys.player_hp_max = value
var kills: int:
	get: return enemy_sys.kills
var xp: int:
	get: return enemy_sys.xp
var hit_pause: float:
	get: return player_sys.hit_pause
var strike_facing: Vector2:
	get: return player_sys.strike_facing
var combo: int:
	get: return player_sys.combo
var strike_heavy: bool:
	get: return player_sys.strike_heavy
var strike_clock: float:
	get: return player_sys.strike_clock
var strike_timing: Vector3:
	get: return player_sys.strike_timing
var strike_total: float:
	get: return player_sys.strike_total
var charge_started: bool:
	get: return player_sys.charge_started
var dash_travel: float:
	get: return player_sys.dash_travel


func setup(level: Node2D) -> void:
	battle = level
	oath_book = get_node("/root/OathDatabase")
	y_sort_enabled = true
	effects_layer = Effects.new()
	effects_layer.setup(self)
	add_child(effects_layer)
	tower_sys.setup(self, battle, oath_book)
	watcher = WATCHER_SCENE.instantiate() as Watcher
	watcher.position = battle.player
	add_child(watcher)
	campfire = FIRE_SCENE.instantiate() as Campfire
	campfire.position = battle.fire_point
	add_child(campfire)
	if battle.run.ally:
		ally = WATCHER_SCENE.instantiate() as Watcher
		ally.modulate = Color("#92b1c4")
		ally.scale = Vector2.ONE * 0.82
		ally.position = battle.fire_point + Vector2(32.0, 22.0)
		ally.lantern_on = false
		add_child(ally)
	player_sys.setup(self, battle, oath_book, watcher, ally)
	enemy_sys.setup(self, battle, oath_book, tower_sys)


func owned_oaths() -> Array:
	return battle.run.oaths


func build_options(index: int) -> Array[Dictionary]:
	return tower_sys.build_options(index)


func upgrade_options(index: int) -> Dictionary:
	return tower_sys.upgrade_options(index)


func inspect_radius(index: int, upgrade_preview := false) -> float:
	return tower_sys.inspect_radius(index, upgrade_preview)


func build(index: int, kind: String) -> bool:
	return tower_sys.build(index, kind)


func upgrade(index: int) -> bool:
	return tower_sys.upgrade(index)


func slot_hint(index: int, night: bool) -> String:
	return tower_sys.slot_hint(index, night)


func service_slot(index: int) -> bool:
	return tower_sys.service_slot(index)


func repair(index: int) -> bool:
	return tower_sys.repair(index)


func relight(index: int) -> bool:
	return tower_sys.relight(index)


func extinguish_index(index: int) -> bool:
	return tower_sys.extinguish_index(index)


func extinguish_near(position_value: Vector2, radius: float) -> PackedVector2Array:
	return tower_sys.extinguish_near(position_value, radius)


func extinguish(slot: Slot) -> bool:
	return tower_sys.extinguish(slot)


func light_sources() -> Array[Dictionary]:
	return tower_sys.light_sources()


func light_links() -> Array[Dictionary]:
	return tower_sys.links


func refresh_links() -> void:
	tower_sys.refresh_links()


func ember_spent(reason: String) -> void:
	var rule: Dictionary = oath_book.on_ember_spend(owned_oaths(), reason)
	if rule.is_empty():
		return
	player_sys.reset_cooldowns()
	tower_sys.salvo(enemy_sys.enemies)


func spawn(kind: int, lane: int) -> Enemy:
	return enemy_sys.spawn(kind, lane)


func count_enemies() -> int:
	return enemy_sys.count_enemies()


func enemy_count() -> int:
	return enemy_sys.count_enemies()


func reroute(lane := -1) -> void:
	enemy_sys.reroute(lane)


func reset_night() -> void:
	tower_sys.reset_night()


func tick(delta: float) -> void:
	player_sys.tick(delta, enemy_sys.enemies)
	var lantern_rule: Dictionary = oath_book.lantern_modifiers(owned_oaths(), battle.still)
	var repair_rate: float = lantern_rule.repair if battle.lantern_on and battle.oil > 0.0 else 0.0
	tower_sys.step_all(delta, repair_rate, enemy_sys.enemies)
	enemy_sys.tick_all(delta)
	effects_layer.step(delta, enemy_sys.enemies)
	player_sys.step_ally(delta, enemy_sys.enemies)
	enemy_sys.prune_removed()
	refresh_art(delta)


func refresh_art(delta: float) -> void:
	player_sys.sync_art(delta)
	campfire.ratio = battle.fire_hp / 100.0
	campfire.clock = battle.clock
	campfire.queue_redraw()
	tower_sys.sync_art()
	enemy_sys.sync_art()
	effects_layer.queue_redraw()


func start_charge() -> void:
	player_sys.start_charge()


func cancel_charge() -> void:
	player_sys.cancel_charge()


func release_attack() -> bool:
	return player_sys.release_attack()


func slash(heavy := false) -> bool:
	return player_sys.slash(heavy)


func strike_contact_time() -> float:
	return player_sys.strike_contact_time()


func blade_is_released() -> bool:
	return player_sys.blade_is_released()


func player_move_factor() -> float:
	return player_sys.player_move_factor()


func dash() -> bool:
	return player_sys.dash(enemy_sys.enemies)


func hurt_player(amount: float, attacker: Vector2) -> bool:
	return player_sys.hurt_player(amount, attacker)


func move_in_world(origin: Vector2, motion: Vector2, radius: float, airborne := false) -> Vector2:
	if battle.has_method("motion_against_world"):
		return battle.motion_against_world(origin, motion, radius, airborne)
	if motion.length_squared() <= 0.001:
		return origin
	var steps := maxi(1, ceili(motion.length() / 4.0))
	var at := origin
	for index in range(1, steps + 1):
		var next := origin + motion * (float(index) / steps)
		if not airborne and not battle.can_walk(next):
			break
		at = next
	return at


func actor_route(lane: int, radius: float) -> PackedVector2Array:
	if battle.has_method("route_for_actor"):
		return battle.route_for_actor(lane, radius)
	return battle.enemy_path(lane)


func space_ground_enemies(delta: float) -> void:
	enemy_sys.space_ground_enemies(delta)


func walker_guide(foe: Enemy) -> Vector2:
	return enemy_sys.walker_guide(foe)


func reconnect_walker(foe: Enemy) -> void:
	enemy_sys.reconnect_walker(foe)


func damage_enemy(foe: Enemy, amount: float, flame := false, ignores_armor := false, from_melee := false) -> void:
	enemy_sys.damage_enemy(foe, amount, flame, ignores_armor, from_melee)


func light_lost(point: Vector2) -> void:
	effects_layer.spawn_spirits(point, oath_book.on_light_gone(owned_oaths()))


func add_ring(origin: Vector2, radius: float, tint: Color, duration: float) -> void:
	effects_layer.add_ring(origin, radius, tint, duration)


func add_shot(from: Vector2, to: Vector2, tint: Color, duration: float) -> void:
	effects_layer.add_shot(from, to, tint, duration)
