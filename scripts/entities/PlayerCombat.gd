class_name PlayerCombat
extends RefCounted

const Enemy = preload("res://scripts/entities/EnemyController.gd")
const Watcher = preload("res://scripts/entities/PlayerController.gd")
const FIELD_GOLD := Color("#e8b578")
const STRIKE_TIMINGS := [
	Vector3(0.074, 0.076, 0.172),
	Vector3(0.082, 0.082, 0.171),
	Vector3(0.111, 0.094, 0.212),
	Vector3(0.052, 0.113, 0.268),
]
const STRIKE_CROSSING := 0.54
const DASH_TIME := 0.134

var combat: Node2D
var battle: Node2D
var oath_book: Node
var watcher: Watcher
var ally: Watcher
var slash_left := 0.0
var dash_left := 0.0
var player_hp_max := 100.0
var player_hp := 100.0
var injury := 0.0
var dash_grace := 0.0
var safety_grace := 0.0
var charge_started := false
var charge_seconds := 0.0
var combo := 0
var combo_left := 0.0
var strike_heavy := false
var strike_facing := Vector2.RIGHT
var strike_clock := -1.0
var strike_timing := Vector3.ZERO
var strike_total := 0.0
var hit_pause := 0.0
var dash_travel := 0.0
var dash_direction := Vector2.RIGHT
var dash_extent := 0.0
var dash_origin := Vector2.ZERO
var queued_strike := -1
var last_player := Vector2.ZERO
var ally_attack := 0.0


func setup(owner_combat: Node2D, level: Node2D, oaths: Node, watcher_node: Watcher, ally_node: Watcher) -> void:
	combat = owner_combat
	battle = level
	oath_book = oaths
	watcher = watcher_node
	ally = ally_node
	last_player = battle.player


func tick(delta: float, enemies: Array[Enemy]) -> void:
	var weighted := delta - minf(delta, hit_pause)
	hit_pause = maxf(0.0, hit_pause - delta)
	slash_left = maxf(0.0, slash_left - weighted)
	dash_left = maxf(0.0, dash_left - delta)
	injury = maxf(0.0, injury - delta)
	dash_grace = maxf(0.0, dash_grace - delta)
	safety_grace = maxf(0.0, safety_grace - delta)
	combo_left = maxf(0.0, combo_left - delta)
	if combo_left == 0.0:
		combo = 0
	if charge_started:
		charge_seconds = minf(1.25, charge_seconds + weighted)
	advance_dash(delta)
	advance_strike(weighted, enemies)
	if injury <= 0.0 and (not battle.night or (battle.player as Vector2).distance_squared_to(battle.fire_point) <= 42.0 ** 2):
		player_hp = minf(player_hp_max, player_hp + delta * (11.0 if not battle.night else 4.0))


func reset_cooldowns() -> void:
	slash_left = 0.0
	dash_left = 0.0


func start_charge() -> void:
	if not charge_started:
		charge_started = true
		charge_seconds = 0.0


func cancel_charge() -> void:
	charge_started = false
	charge_seconds = 0.0


func release_attack() -> bool:
	if not charge_started:
		return false
	var heavy := charge_seconds >= 0.42
	cancel_charge()
	return slash(heavy)


func slash(heavy := false) -> bool:
	if dash_travel > 0.0:
		return false
	if slash_left > 0.0:
		if slash_left <= 0.14:
			queued_strike = int(heavy)
			return true
		return false
	cancel_charge()
	strike_facing = battle.aim.normalized()
	if strike_facing.is_zero_approx():
		strike_facing = Vector2.RIGHT
	strike_heavy = heavy
	combo = 1 if heavy else 1 + combo % 3
	combo_left = 1.18
	var origin: Vector2 = battle.player
	var mods: Dictionary = oath_book.player_modifiers(combat.owned_oaths(), origin.distance_to(battle.fire_point), battle.fire_hp)
	strike_timing = STRIKE_TIMINGS[3 if heavy else combo - 1] / float(mods.attack_speed)
	strike_total = strike_timing.x + strike_timing.y + strike_timing.z
	strike_clock = 0.0
	slash_left = strike_total + 0.026
	watcher.strike_direction = strike_facing
	watcher.strike_duration = strike_total
	return true


func strike_contact_time() -> float:
	return strike_timing.x + strike_timing.y * STRIKE_CROSSING


func blade_is_released() -> bool:
	return strike_clock >= strike_timing.x and strike_clock < strike_timing.x + strike_timing.y * 1.20


func player_move_factor() -> float:
	if hit_pause > 0.0 or dash_travel > 0.0:
		return 0.0
	if charge_started:
		return 0.64
	if strike_clock >= 0.0:
		return 0.32 if strike_clock <= strike_timing.x + strike_timing.y else 0.72
	return 1.0


func advance_strike(delta: float, enemies: Array[Enemy]) -> void:
	if strike_clock < 0.0:
		if queued_strike >= 0 and slash_left <= 0.0:
			var next := queued_strike
			queued_strike = -1
			slash(next == 1)
		return
	if delta <= 0.0:
		return
	var prior := strike_clock
	var advanced := minf(strike_total, strike_clock + delta)
	var crossing := strike_contact_time()
	if prior < strike_timing.x and advanced >= strike_timing.x:
		combat.blade_cuts.emit(battle.player, strike_facing, strike_heavy)
	var unloading := maxf(0.0, minf(crossing, advanced) - maxf(strike_timing.x, prior))
	if unloading > 0.0:
		var motion := strike_facing * unloading * (185.0 if strike_heavy else 112.0)
		battle.player = combat.move_in_world(battle.player, motion, 12.0)
	strike_clock = advanced
	if prior < crossing and advanced >= crossing:
		strike_clock = crossing
		resolve_cut(enemies)
		if hit_pause <= 0.0:
			strike_clock = advanced
	if strike_clock >= strike_total:
		strike_clock = -1.0


func resolve_cut(enemies: Array[Enemy]) -> void:
	var origin: Vector2 = battle.player
	var aim := strike_facing
	var mods: Dictionary = oath_book.player_modifiers(combat.owned_oaths(), origin.distance_to(battle.fire_point), battle.fire_hp)
	var perk: int = battle.perks.get("edge", 0)
	var hits := [41.0, 49.0, 68.0]
	var damage: float = (96.0 if strike_heavy else hits[combo - 1]) * mods.melee * (1.0 + 0.22 * perk)
	var reach := 132.0 if strike_heavy else 102.0
	var cone := -0.12 if strike_heavy else 0.24
	var connected := false
	for foe: Enemy in enemies.duplicate():
		if foe.removed or (foe.kind == Enemy.SHADE and not foe.lit):
			continue
		var offset := foe.position - origin
		var distance := offset.length_squared()
		if distance > reach ** 2 or (distance > 21.0 ** 2 and offset.normalized().dot(aim) < cone):
			continue
		if combat.move_in_world(origin, offset, 1.5).distance_squared_to(foe.position) > 14.0 ** 2:
			continue
		var push := offset.normalized()
		if push.is_zero_approx():
			push = aim
		var armored := foe.kind in [Enemy.COLOSSUS, Enemy.HERALD] or foe.armor > 0.18
		var flank: bool = foe.kind == Enemy.COLOSSUS and foe.facing.dot(foe.position.direction_to(origin)) < -0.25
		combat.damage_enemy(foe, damage * (1.35 if flank else 1.0), false, flank, true)
		var pause := 0.067 if strike_heavy else 0.050 if armored or combo == 3 else 0.038
		hit_pause = maxf(hit_pause, pause)
		foe.hit_hold = maxf(foe.hit_hold, pause)
		foe.knock += push * (38.0 if strike_heavy else 18.0) * (0.38 if armored else 1.0)
		foe.stagger = 0.29 if strike_heavy else 0.15
		foe.tell = 0.0
		foe.attack_pose = 0.0
		foe.attack_target = Enemy.TARGET_NONE
		foe.velocity_hit = push
		combat.melee_contact.emit(foe.position - push * 8.0, push, 1.0 if armored else 0.67, armored, strike_heavy)
		if foe.kind == Enemy.HEXER:
			foe.charge = 0.0
			foe.special = 2.4
		connected = true
	battle.damage_crystals_at(origin, aim, reach, damage)
	if connected:
		var moment: Dictionary = oath_book.on_player_slash(combat.owned_oaths())
		if not moment.is_empty():
			for tower in combat.towers:
				if tower.level > 0 and tower.position.distance_squared_to(origin) <= float(moment.radius) ** 2:
					tower.sworn = maxf(tower.sworn, moment.seconds)
			combat.add_ring(origin, moment.radius, FIELD_GOLD, 0.43)
	if strike_heavy:
		combat.charged_cut.emit(origin, aim)


func dash(enemies: Array[Enemy]) -> bool:
	if dash_left > 0.0 or hit_pause > 0.0:
		return false
	var start: Vector2 = battle.player
	var direction: Vector2 = battle.aim.normalized()
	var destination: Vector2 = combat.move_in_world(start, direction * 112.0, 12.0)
	if destination.distance_squared_to(start) < 8.0 ** 2:
		return false
	cancel_charge()
	strike_clock = -1.0
	queued_strike = -1
	dash_origin = start
	dash_extent = 112.0
	dash_direction = direction
	dash_travel = DASH_TIME
	var perk: int = battle.perks.get("step", 0)
	dash_left = 1.9 / (1.0 + 0.17 * perk)
	dash_grace = 0.26
	watcher.dash = DASH_TIME + 0.10
	combat.add_shot(start, destination, Color("#94b1bf"), 0.13)
	var rule: Dictionary = oath_book.on_dash(combat.owned_oaths())
	if not rule.is_empty():
		combat.add_ring(start, rule.radius, Color("#c6a9cc"), 0.74)
		for enemy in enemies:
			if not enemy.removed and enemy.position.distance_squared_to(start) <= float(rule.radius) ** 2:
				enemy.rooted = maxf(enemy.rooted, rule.seconds)
	return true


func advance_dash(delta: float) -> void:
	if dash_travel <= 0.0:
		return
	dash_travel = maxf(0.0, dash_travel - delta)
	var fraction := 1.0 - dash_travel / DASH_TIME
	var swept := 1.0 - pow(1.0 - fraction, 1.72)
	var wanted := dash_origin + dash_direction * dash_extent * swept
	battle.player = combat.move_in_world(battle.player, wanted - battle.player, 12.0)


func hurt_player(amount: float, attacker: Vector2) -> bool:
	if not battle.night or dash_grace > 0.0 or safety_grace > 0.0:
		return false
	player_hp = maxf(0.0, player_hp - amount)
	injury = 1.85
	safety_grace = 0.46
	var origin: Vector2 = battle.player
	combat.add_ring(origin, 25.0, Color("#e67261"), 0.28)
	if strike_clock >= 0.0 and strike_clock < strike_contact_time():
		strike_clock = -1.0
		queued_strike = -1
		cancel_charge()
	if player_hp == 0.0:
		player_hp = 62.0
		battle.run.embers = maxi(0, battle.run.embers - 7)
		var hearth: Vector2 = battle.fire_point
		for offset in [Vector2(-24, 21), Vector2(24, 20), Vector2(0, 32), Vector2.ZERO]:
			var rest: Vector2 = hearth + offset
			if battle.can_walk(rest):
				battle.player = rest
				break
		safety_grace = 2.0
		battle.announce("受伤退回篝火 · 损失 7 余烬")
	else:
		battle.player = combat.move_in_world(origin, attacker.direction_to(origin) * 9.0, 12.0)
	return true


func step_ally(delta: float, enemies: Array[Enemy]) -> void:
	if ally == null:
		return
	var angle: float = battle.clock * 0.54
	var desired: Vector2 = battle.fire_point + Vector2(cos(angle), sin(angle) * 0.8) * 78.0
	ally.aim = ally.position.direction_to(desired)
	ally.position = ally.position.move_toward(desired, delta * 92.0)
	ally.swing = maxf(0.0, ally.swing - delta)
	ally.moving = true
	ally.clock = battle.clock
	ally.queue_redraw()
	ally_attack = maxf(0.0, ally_attack - delta)
	if ally_attack > 0.0:
		return
	for foe in enemies:
		if not foe.removed and foe.lit and foe.position.distance_squared_to(ally.position) <= 64.0 ** 2:
			ally.aim = ally.position.direction_to(foe.position)
			ally.strike_direction = ally.aim
			ally.swing = 0.23
			ally_attack = 0.8
			combat.damage_enemy(foe, 19.0)
			break


func sync_art(delta: float) -> void:
	watcher.position = battle.player
	watcher.aim = battle.aim
	watcher.moving = last_player.distance_squared_to(battle.player) > 0.05
	watcher.lantern_on = battle.lantern_on and battle.oil > 0.0
	watcher.clock = battle.clock
	watcher.charge = charge_seconds if charge_started else 0.0
	watcher.injury = injury
	watcher.swing = maxf(0.0, strike_total - strike_clock) if strike_clock >= 0.0 else 0.0
	watcher.dash = maxf(0.0, watcher.dash - delta)
	watcher.queue_redraw()
	last_player = battle.player
