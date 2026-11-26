class_name EnemySystem
extends RefCounted

const Enemy = preload("res://scripts/entities/EnemyController.gd")
const Slot = preload("res://scripts/entities/TowerController.gd")
const Towers = preload("res://scripts/entities/TowerSystem.gd")
const EnemyDef = preload("res://scripts/data/EnemyData.gd")
const ENEMY_SCENE = preload("res://scenes/entities/EnemyBase.tscn")
const HERALD_INTERVAL := 10.0
const HERALD_WARNING := 0.68

var combat: Node2D
var battle: Node2D
var oath_book: Node
var tower_sys: Towers
var enemy_defs: Array[EnemyDef] = []
var enemies: Array[Enemy] = []
var kills := 0
var xp := 0
var first_seen: Dictionary[int, bool] = {}


func _init() -> void:
	enemy_defs = [
		EnemyDef.create(Enemy.CRAWLER, "夜行爬尸", 33.0, 54.0, 5.5, 0.0, Vector2i(3, 2), 4, "夜行爬尸在啃咬防线"),
		EnemyDef.create(Enemy.SHADE, "影潜者", 27.0, 78.0, 8.0, 0.0, Vector2i(4, 2), 6, "影潜者避开了光，扫照使它显形"),
		EnemyDef.create(Enemy.MOTH, "噬火蛾", 24.0, 96.0, 15.0, 0.0, Vector2i(3, 1), 5, "噬火蛾正在寻找最近的光源"),
		EnemyDef.create(Enemy.COLOSSUS, "掘骨巨尸", 168.0, 31.0, 11.0, 0.29, Vector2i(12, 8), 14, "掘骨巨尸擅长撞毁路障"),
		EnemyDef.create(Enemy.HEXER, "灰烬咒术师", 51.0, 48.0, 8.0, 0.0, Vector2i(8, 4), 12, "灰烬咒术师可遮蔽塔的视野"),
		EnemyDef.create(Enemy.HERALD, "永夜先驱", 360.0, 34.0, 14.0, 0.13, Vector2i(28, 16), 28, "永夜先驱会熄灭火盆并召来爬尸"),
	]


func get_def(kind: int) -> EnemyDef:
	return enemy_defs[clampi(kind, 0, enemy_defs.size() - 1)]


func setup(owner_combat: Node2D, level: Node2D, oaths: Node, towers_system: Towers) -> void:
	combat = owner_combat
	battle = level
	oath_book = oaths
	tower_sys = towers_system
	enemies.clear()
	kills = 0
	xp = 0
	first_seen.clear()


func spawn(kind: int, lane: int) -> Enemy:
	var spec := get_def(kind)
	var foe := ENEMY_SCENE.instantiate() as Enemy
	foe.kind = kind
	foe.lane = lane
	foe.path = combat.actor_route(lane, foe.radius)
	if foe.path.size() < 2:
		foe.queue_free()
		return null
	foe.position = foe.path[0]
	foe.elite = battle.elite or kind == Enemy.HERALD
	var cycle: int = maxi(0, battle.run.cycle - 1)
	var inflate := 1.0 + 0.22 * cycle + (0.15 if foe.elite else 0.0) + float(battle.biome) * 0.075
	foe.max_health = spec.base_health * inflate
	foe.health = foe.max_health
	foe.speed = spec.base_speed * (1.0 + float(battle.run.speed_bonus) + minf(0.38, cycle * 0.06))
	foe.power = spec.base_power * (1.0 + 0.15 * cycle + (0.13 if foe.elite else 0.0))
	foe.armor = minf(0.62, spec.base_armor + cycle * 0.035)
	if cycle > 0:
		foe.affliction = 1 + (kind * 5 + lane + cycle) % (2 if kind == Enemy.MOTH else 3)
		if foe.affliction == 2:
			foe.armor = minf(0.74, foe.armor + 0.14)
		elif foe.affliction == 3:
			foe.power *= 1.33
	if kind == Enemy.MOTH:
		foe.power = 15.0
	foe.reward = spec.reward
	foe.cooldown = 0.72
	foe.special = 5.7
	foe.facing = foe.position.direction_to(foe.path[1])
	combat.add_child(foe)
	enemies.append(foe)
	if not first_seen.has(kind):
		first_seen[kind] = true
		var affix_name: String = Enemy.AFFLICTIONS[foe.affliction]
		battle.announce(spec.intro_hint if affix_name.is_empty() else "%s · 永夜词缀「%s」" % [spec.display_name, affix_name])
	return foe


func count_enemies() -> int:
	var live := 0
	for enemy: Enemy in enemies:
		if not enemy.removed:
			live += 1
	return live


func reroute(lane := -1) -> void:
	for foe: Enemy in enemies:
		if foe.removed or foe.kind == Enemy.MOTH or (lane >= 0 and lane != foe.lane):
			continue
		var route: PackedVector2Array = combat.actor_route(foe.lane, foe.radius)
		if route == foe.path or route.size() < 2:
			continue
		var best_index := 1
		var best_distance := INF
		for i in range(route.size() - 1):
			var nearby := Geometry2D.get_closest_point_to_segment(foe.position, route[i], route[i + 1])
			var distance := nearby.distance_squared_to(foe.position)
			if distance < best_distance:
				best_distance = distance
				best_index = i + 1
		foe.path = route
		foe.waypoint = best_index
		foe.lane_detour.clear()
		foe.lane_stall = 0.0
		foe.lane_retry = 0.0


func tick_all(delta: float) -> void:
	for foe: Enemy in enemies.duplicate():
		if not foe.removed:
			step_enemy(foe, delta)
	space_ground_enemies(delta)


func prune_removed() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].removed:
			enemies[i].queue_free()
			enemies.remove_at(i)


func sync_art() -> void:
	for enemy in enemies:
		enemy.queue_redraw()


func space_ground_enemies(delta: float) -> void:
	if delta <= 0.0:
		return
	var ground: Array[Enemy] = []
	for foe in enemies:
		if not foe.removed and foe.kind != Enemy.MOTH:
			ground.append(foe)
	var correction_limit := minf(6.0, 128.0 * delta)
	for index in range(ground.size()):
		var first := ground[index]
		for next in range(index + 1, ground.size()):
			var second := ground[next]
			var between := second.position - first.position
			var clearance := first.radius + second.radius + 1.4
			if between.length_squared() >= clearance ** 2:
				continue
			var along := between.normalized()
			if along.is_zero_approx():
				along = first.facing.orthogonal()
			var need := minf(correction_limit, clearance - between.length())
			var give_first := footing(first)
			var give_second := footing(second)
			if give_first + give_second <= 0.0:
				continue
			var correction := need * give_first / (give_first + give_second)
			var before := first.position
			first.position = combat.move_in_world(first.position, -along * correction, first.radius)
			var remaining := need - first.position.distance_to(before)
			if give_second > 0.0 and remaining > 0.0:
				second.position = combat.move_in_world(second.position, along * remaining, second.radius)
		if combat.dash_travel <= 0.0 and first.hit_hold <= 0.0:
			var away: Vector2 = first.position - battle.player
			var overlap := first.radius + 9.0 - away.length()
			if overlap > 0.0:
				var direction := away.normalized() if away.length_squared() > 0.01 else -first.facing
				first.position = combat.move_in_world(first.position, direction * minf(overlap, correction_limit * 0.7), first.radius)


func footing(foe: Enemy) -> float:
	if foe.hit_hold > 0.0:
		return 0.0
	var firmness := 0.57 if foe.kind in [Enemy.COLOSSUS, Enemy.HERALD] else 1.0
	return firmness * (0.38 if foe.tell > 0.0 or foe.attack_pose > 0.0 else 1.0)


func step_enemy(foe: Enemy, delta: float) -> void:
	var motion_delta := delta - minf(delta, foe.hit_hold)
	foe.hit_hold = maxf(0.0, foe.hit_hold - delta)
	foe.age += motion_delta
	foe.cooldown = maxf(0.0, foe.cooldown - motion_delta)
	foe.rooted = maxf(0.0, foe.rooted - delta)
	foe.wrapped = maxf(0.0, foe.wrapped - delta)
	foe.marked = maxf(0.0, foe.marked - delta)
	foe.burned = maxf(0.0, foe.burned - delta)
	foe.sundered = maxf(0.0, foe.sundered - delta)
	foe.hit = maxf(0.0, foe.hit - motion_delta)
	foe.stagger = maxf(0.0, foe.stagger - motion_delta)
	foe.attack_pose = maxf(0.0, foe.attack_pose - motion_delta)
	foe.acting = false
	var strength: float = battle.light_manager.strength_at(foe.position)
	var now_lit := strength > 0.0
	var mark: Dictionary = oath_book.on_enemy_lit(combat.owned_oaths(), foe.lit, now_lit)
	foe.lit = now_lit
	if not mark.is_empty():
		foe.marked = maxf(foe.marked, mark.seconds)
	var fire_dps: float = oath_book.light_damage(combat.owned_oaths(), strength)
	if foe.burned > 0.0:
		fire_dps += 2.6
	if fire_dps > 0.0:
		damage_enemy(foe, fire_dps * delta, true, true)
	if foe.removed:
		return
	var slow := 0.0
	for link in tower_sys.links:
		var near := Geometry2D.get_closest_point_to_segment(foe.position, link.from, link.to)
		if near.distance_squared_to(foe.position) <= float(link.width) ** 2:
			slow = maxf(slow, link.slow)
			if link.dps > 0.0:
				damage_enemy(foe, link.dps * delta, false, true)
	if foe.removed:
		return
	if foe.kind != Enemy.MOTH:
		for slot in tower_sys.towers:
			if slot.kind == "oil" and (not slot.spent or slot.burn > 0.0) and slot.position.distance_squared_to(foe.position) <= tower_sys.oil_radius(slot.level) ** 2:
				slow = maxf(slow, 0.35)
	var speed := foe.speed * (1.0 - slow)
	if foe.affliction == 1 and foe.health < foe.max_health * 0.50:
		speed *= 1.44
	if foe.kind != Enemy.MOTH:
		speed *= battle.pace_factor(foe.position)
	if battle.crystal_buff_at(foe.position):
		speed *= 1.28
	if motion_delta <= 0.0:
		return
	if foe.knock.length_squared() > 0.1:
		var knock := foe.knock * minf(1.0, motion_delta * 14.0)
		foe.position = combat.move_in_world(foe.position, knock, foe.radius, foe.kind == Enemy.MOTH)
		foe.knock -= knock
	if foe.stagger > 0.0:
		return
	if foe.rooted > 0.0 or foe.wrapped > 0.0:
		speed = 0.0
	if foe.kind == Enemy.MOTH:
		move_moth(foe, speed, motion_delta)
		return
	if foe.kind == Enemy.HEXER and cast_haze(foe, delta):
		return
	if foe.kind == Enemy.HERALD:
		herald_cycle(foe, delta)
	step_walker(foe, speed, motion_delta)


func step_walker(foe: Enemy, speed: float, delta: float) -> void:
	if update_enemy_attack(foe, delta):
		return
	var origin: Vector2 = battle.fire_point
	if steer_at_watcher(foe, speed, delta):
		return
	if foe.position.distance_squared_to(origin) <= 24.0 ** 2:
		if foe.cooldown <= 0.0:
			prepare_enemy_attack(foe, Enemy.TARGET_FIRE, origin)
		return
	var target := walker_guide(foe)
	var direction := foe.position.direction_to(target)
	var best := -1
	var reach := Towers.BARRICADE_LURE
	for index in range(tower_sys.towers.size()):
		var slot := tower_sys.towers[index]
		if slot.kind != "barricade":
			continue
		var here := foe.position.distance_to(slot.position)
		if here < reach and direction.dot(foe.position.direction_to(slot.position)) > -0.35:
			best = index
			reach = here
	if best >= 0:
		if foe.cooldown <= 0.0:
			prepare_enemy_attack(foe, Enemy.TARGET_WALL, tower_sys.towers[best].position, best)
		return
	if speed <= 0.0:
		return
	if not direction.is_zero_approx():
		foe.facing = direction
	var before := foe.position
	var requested := before.move_toward(target, speed * delta) - before
	var moved: Vector2 = combat.move_in_world(before, requested, foe.radius)
	foe.acting = moved.distance_squared_to(before) > 0.001
	foe.position = moved
	foe.lane_retry = maxf(0.0, foe.lane_retry - delta)
	if moved.distance_to(before) < maxf(0.035, requested.length() * 0.40):
		foe.lane_stall += delta
	else:
		foe.lane_stall = 0.0
	if foe.lane_stall >= 0.24 and foe.lane_retry <= 0.0:
		foe.lane_retry = 0.57
		reconnect_walker(foe)


func walker_guide(foe: Enemy) -> Vector2:
	if not foe.lane_detour.is_empty():
		if foe.position.distance_squared_to(foe.lane_detour[0]) <= 0.25 ** 2:
			foe.lane_detour.remove_at(0)
			if foe.lane_detour.is_empty():
				foe.waypoint = foe.lane_resume
		if not foe.lane_detour.is_empty():
			return foe.lane_detour[0]
	var target := foe.path[foe.waypoint]
	if foe.waypoint < foe.path.size() - 1 and foe.position.distance_squared_to(target) <= 8.0 ** 2:
		var next := foe.path[foe.waypoint + 1]
		if combat.move_in_world(foe.position, next - foe.position, foe.radius).distance_squared_to(next) < 0.25 ** 2:
			foe.waypoint += 1
			return next
	return target


func reconnect_walker(foe: Enemy) -> void:
	if not battle.has_method("find_motion_path"):
		return
	var from := foe.position
	for next_index in range(foe.waypoint, mini(foe.waypoint + 4, foe.path.size())):
		var target := foe.path[next_index]
		if target.distance_squared_to(from) < 0.30 ** 2:
			continue
		var route: PackedVector2Array = battle.find_motion_path(from, target, foe.radius)
		if not route.is_empty():
			foe.lane_detour = route
			foe.lane_resume = next_index
			foe.lane_stall = 0.0
			return


func steer_at_watcher(foe: Enemy, speed: float, delta: float) -> bool:
	var origin: Vector2 = battle.player
	if foe.kind == Enemy.SHADE and not foe.lit:
		return false
	var distance := foe.position.distance_squared_to(origin)
	if foe.cooldown <= 0.0 and distance <= 41.0 ** 2:
		var across: Vector2 = combat.move_in_world(foe.position, origin - foe.position, 1.5)
		if across.distance_squared_to(origin) <= 10.0 ** 2:
			prepare_enemy_attack(foe, Enemy.TARGET_PLAYER, origin)
			return true
	if distance <= 77.0 ** 2 and distance > 25.0 ** 2 and foe.position.distance_squared_to(battle.fire_point) > 28.0 ** 2:
		var desired := foe.position.move_toward(origin, speed * 0.86 * delta)
		var motion := desired - foe.position
		var destination: Vector2 = combat.move_in_world(foe.position, motion, foe.radius)
		if destination.is_equal_approx(foe.position):
			destination = combat.move_in_world(foe.position, Vector2(motion.x, 0.0), foe.radius)
			destination = combat.move_in_world(destination, Vector2(0.0, motion.y), foe.radius)
		if not destination.is_equal_approx(foe.position):
			foe.facing = foe.position.direction_to(origin)
			foe.position = destination
			foe.acting = true
			return true
	return false


func prepare_enemy_attack(foe: Enemy, target: int, focus: Vector2, slot := -1) -> void:
	var heavy := foe.kind in [Enemy.COLOSSUS, Enemy.HERALD]
	var direct := foe.position.direction_to(focus)
	if not direct.is_zero_approx():
		foe.facing = direct
	foe.tell_span = 0.50 if heavy else 0.295 if foe.kind == Enemy.SHADE else 0.35
	foe.tell = foe.tell_span
	foe.attack_recovery = 0.41 if heavy else 0.27
	foe.attack_target = target
	foe.attack_slot = slot
	if target == Enemy.TARGET_PLAYER:
		combat.add_ring(foe.position, 37.0 if heavy else 28.0, Color("#ce705c"), foe.tell)


func update_enemy_attack(foe: Enemy, delta: float) -> bool:
	if foe.attack_pose > 0.0:
		return true
	if foe.tell <= 0.0:
		return false
	if foe.kind == Enemy.SHADE and not foe.lit and foe.attack_target == Enemy.TARGET_PLAYER:
		foe.tell = 0.0
		foe.attack_target = Enemy.TARGET_NONE
		return false
	var prior := foe.tell
	foe.tell = maxf(0.0, foe.tell - delta)
	var rush := maxf(0.0, minf(prior, 0.075) - foe.tell)
	if rush > 0.0 and foe.attack_target == Enemy.TARGET_PLAYER and foe.rooted <= 0.0 and foe.wrapped <= 0.0:
		foe.position = combat.move_in_world(foe.position, foe.facing * rush * 140.0, foe.radius)
	if foe.tell > 0.0:
		return true
	var heavy := foe.kind in [Enemy.COLOSSUS, Enemy.HERALD]
	foe.attack_pose = foe.attack_recovery
	foe.cooldown = 1.02 if not heavy else 1.44
	match foe.attack_target:
		Enemy.TARGET_PLAYER:
			var origin: Vector2 = battle.player
			var reach := 61.0 if heavy else 44.0
			var toward := foe.position.direction_to(origin)
			var close := foe.position.distance_squared_to(origin) <= reach * reach
			var visible: bool = combat.move_in_world(foe.position, origin - foe.position, 1.5).distance_squared_to(origin) <= 10.0 ** 2
			if close and visible and foe.facing.dot(toward) > 0.13:
				var damage := 11.0 if foe.kind <= Enemy.SHADE else 19.0
				if combat.hurt_player(damage * (1.0 + 0.08 * float(battle.run.cycle - 1)), foe.position):
					combat.enemy_contact.emit(origin, foe.facing, heavy)
		Enemy.TARGET_FIRE:
			battle.hurt_fire(foe.power, true)
			var fire: Vector2 = battle.fire_point
			combat.add_ring(fire, 23.0, Color("#fb8b62"), 0.27)
			combat.enemy_contact.emit(fire, foe.facing, heavy)
		Enemy.TARGET_WALL:
			var slot := tower_sys.towers[foe.attack_slot]
			if slot.kind == "barricade" and foe.position.distance_to(slot.position) <= 47.0:
				tower_sys.hit_barricade(slot, foe)
				combat.enemy_contact.emit(slot.position, foe.facing, heavy)
	foe.attack_target = Enemy.TARGET_NONE
	return true


func move_moth(foe: Enemy, speed: float, delta: float) -> void:
	var target: Vector2 = battle.fire_point
	var nearest := foe.position.distance_squared_to(target)
	var lamp := false
	var vessel: Slot
	foe.flight_retry = maxf(0.0, foe.flight_retry - delta)
	foe.flight_rejection_left = maxf(0.0, foe.flight_rejection_left - delta)
	for slot in tower_sys.towers:
		if slot.kind != "brazier" or not slot.lit:
			continue
		var distance := foe.position.distance_squared_to(slot.position)
		if distance < nearest and flight_allowed(foe, slot.position):
			vessel = slot
			nearest = distance
			target = slot.position
	if battle.lantern_on and battle.oil > 0.0 and foe.position.distance_squared_to(battle.player) < nearest and flight_allowed(foe, battle.player):
		lamp = true
		target = battle.player
	if speed > 0.0 and not advance_moth_flight(foe, target, speed * delta) and (lamp or vessel != null):
		foe.flight_rejection = target
		foe.flight_rejection_left = 0.8
		lamp = false
		vessel = null
		target = battle.fire_point
	var remaining := foe.position.distance_squared_to(target)
	var heading := foe.position.direction_to(target)
	var committed := speed > 0.0 and foe.flight_index >= foe.flight_plan.size() - 1 and foe.facing.dot(heading) > 0.72
	foe.set_meta(&"moth_dive", 1.0 - smoothstep(14.0, 45.0, sqrt(remaining)) if committed else 0.0)
	if remaining > 14.0 ** 2:
		return
	foe.removed = true
	combat.add_ring(target, 34.0, Color("#f48759"), 0.52)
	var destination: int = combat.MothDestination.HEARTH
	if lamp:
		destination = combat.MothDestination.LANTERN
		battle.oil = maxf(0.0, battle.oil - 20.0)
		battle.announce("噬火蛾撞上提灯，灯油 -20")
	elif vessel != null:
		destination = combat.MothDestination.BRAZIER
		tower_sys.extinguish(vessel)
		battle.announce("噬火蛾扑灭了一座烽火盆")
	else:
		battle.hurt_fire(15.0, true)
		battle.announce("噬火蛾撞上篝火，火势 -15")
	combat.moth_contact.emit(target, foe.facing, destination, foe)


func flight_allowed(foe: Enemy, target: Vector2) -> bool:
	return foe.flight_rejection_left <= 0.0 or target.distance_squared_to(foe.flight_rejection) > 32.0 ** 2


func advance_moth_flight(foe: Enemy, target: Vector2, travel: float) -> bool:
	if foe.flight_goal.distance_squared_to(target) > 32.0 ** 2:
		foe.flight_goal = target
		foe.flight_plan.clear()
		foe.flight_index = 0
		foe.flight_retry = 0.0
	var guide := target
	if foe.flight_index < foe.flight_plan.size():
		while foe.flight_index < foe.flight_plan.size() and foe.position.distance_squared_to(foe.flight_plan[foe.flight_index]) <= 6.0 ** 2:
			foe.flight_index += 1
		if foe.flight_index < foe.flight_plan.size():
			guide = foe.flight_plan[foe.flight_index]
	var prior := foe.position
	var motion := prior.move_toward(guide, travel) - prior
	var moved: Vector2 = combat.move_in_world(prior, motion, foe.radius, true)
	var nearly_stopped := prior.distance_to(moved) < motion.length() * 0.36
	if nearly_stopped and foe.flight_retry <= 0.0 and battle.has_method("find_motion_path"):
		var route: PackedVector2Array = battle.find_motion_path(prior, target, foe.radius, true)
		foe.flight_retry = 0.35
		foe.flight_plan = route
		foe.flight_index = 0
		if route.is_empty():
			return false
		guide = route[0]
		motion = prior.move_toward(guide, travel) - prior
		moved = combat.move_in_world(prior, motion, foe.radius, true)
	foe.position = moved
	var heading := prior.direction_to(guide)
	if not heading.is_zero_approx():
		foe.facing = heading
	return true


func cast_haze(foe: Enemy, delta: float) -> bool:
	foe.special = maxf(0.0, foe.special - delta)
	var tower: Slot
	var nearest := 195.0 ** 2
	for slot in tower_sys.towers:
		if slot.kind != "ballista" or slot.disabled > 0.0:
			continue
		var distance := foe.position.distance_squared_to(slot.position)
		if distance < nearest:
			tower = slot
			nearest = distance
	if tower == null or foe.special > 0.0:
		foe.charge = 0.0
		return false
	if foe.rooted > 0.0 or foe.wrapped > 0.0:
		return true
	foe.charge += delta / 1.25
	foe.facing = foe.position.direction_to(tower.position)
	if foe.charge >= 1.0:
		tower.disabled = 4.5
		foe.special = 6.5
		foe.charge = 0.0
		combat.add_shot(foe.position, tower.position, Color("#af769e"), 0.62)
	return true


func herald_cycle(foe: Enemy, delta: float) -> void:
	foe.special -= delta
	if foe.special > 0.0:
		return
	foe.special = HERALD_INTERVAL
	var affected: PackedVector2Array = tower_sys.extinguish_near(foe.position, 225.0)
	combat.add_ring(foe.position, 225.0, Color("#ab6197"), 0.92)
	for i in range(2):
		var minion := spawn(Enemy.CRAWLER, foe.lane)
		if minion != null:
			minion.position = foe.position + Vector2(16.0 * (i * 2 - 1), 12.0)
			minion.waypoint = mini(foe.waypoint, minion.path.size() - 1)
	combat.herald_cast.emit(foe.position, affected)


func damage_enemy(foe: Enemy, amount: float, flame := false, ignores_armor := false, from_melee := false) -> void:
	if foe == null or foe.removed or amount <= 0.0:
		return
	var armor := foe.armor if not flame and not ignores_armor else 0.0
	if not flame and not ignores_armor and battle.crystal_buff_at(foe.position):
		armor = minf(0.78, armor + 0.16)
	var sunder := 1.30 if foe.sundered > 0.0 and not flame else 1.0
	var multiplier: float = oath_book.damage_modifier(foe.marked > 0.0, foe.wrapped > 0.0, flame)
	foe.health -= amount * sunder * multiplier * (1.0 - armor)
	if amount >= 2.0:
		foe.hit = 0.13
		if not from_melee:
			combat.enemy_struck.emit(foe.position, foe.kind, flame)
	if foe.health <= 0.0:
		enemy_defeated(foe)


func enemy_defeated(foe: Enemy) -> void:
	foe.removed = true
	kills += 1
	var reward_xp: int = get_def(foe.kind).xp
	xp += reward_xp
	combat.enemy_slain.emit(foe.kind, reward_xp, foe.position)
	var rule: Dictionary = oath_book.on_enemy_killed(combat.owned_oaths(), battle.fire_hp,
		battle.night_fraction(), battle.is_harsh_weather(), foe.burned > 0.0)
	battle.run.embers += foe.reward.x * rule.loot_scale
	battle.run.bone += foe.reward.y * rule.loot_scale
	if rule.fire_heal > 0.0:
		battle.heal_fire(rule.fire_heal)
	combat.add_ring(foe.position, 19.0, Color("#edc488"), 0.36)
	var dust: Dictionary = rule.dust
	if dust.is_empty():
		return
	combat.add_ring(foe.position, dust.radius, Color("#c98256"), 0.44)
	for nearby in enemies:
		if not nearby.removed and nearby.position.distance_squared_to(foe.position) <= float(dust.radius) ** 2:
			nearby.burned = maxf(nearby.burned, dust.burn_seconds)
			damage_enemy(nearby, dust.damage, false, true)
