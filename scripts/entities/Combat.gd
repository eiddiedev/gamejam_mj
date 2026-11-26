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
const SLOT_SCENE = preload("res://scenes/entities/BuildSlot.tscn")
const ENEMY_SCENE = preload("res://scenes/entities/EnemyBase.tscn")
const WATCHER_SCENE = preload("res://scenes/entities/Player.tscn")
const FIRE_SCENE = preload("res://scenes/entities/Campfire.tscn")

const TOWERS := {
	"brazier": {
		"name": "烽火盆", "price": Vector2i(13, 4), "health": [95.0, 128.0, 157.0],
		"levels": ["180 范围暖光，照出影潜者。", "240 范围暖光，灼烧近敌。", "与附近火盆连成光束，沿线显形并减速 25%。"],
	},
	"ballista": {
		"name": "骨弩台", "price": Vector2i(23, 14), "health": [87.0, 119.0, 152.0],
		"levels": ["320 射程，1.2 秒一矢。高台射程 +25%。", "骨矢贯穿，同时命中射线上的第二名敌人。", "优先精英与重甲，重甲命中造成 180% 暴击。"],
	},
	"barricade": {
		"name": "誓言路障", "price": Vector2i(12, 8), "health": [158.0, 235.0, 315.0],
		"levels": ["阻挡地面敌人，吸引它们攻击。", "尖刺将近战伤害反弹给攻击者。", "释放微光，并缓慢修复耐久。"],
	},
	"oil": {
		"name": "火油槽", "price": Vector2i(11, 6), "health": [55.0, 68.0, 78.0],
		"levels": ["减速 35%，可用灯火引燃，持续 6 秒。", "火圈更广，燃烧使物理伤害提高 30%。", "引燃时爆发并击退，持续 10 秒。"],
	},
}
const TOWER_ORDER := ["brazier", "ballista", "barricade", "oil"]
const BARRICADE_LURE := 35.0
const BARRICADE_LIGHT := 76.0
const SPECIES := [
	[33.0, 54.0, 5.5, 0.0, Vector2i(3, 2)],
	[27.0, 78.0, 8.0, 0.0, Vector2i(4, 2)],
	[24.0, 96.0, 15.0, 0.0, Vector2i(3, 1)],
	[168.0, 31.0, 11.0, 0.29, Vector2i(12, 8)],
	[51.0, 48.0, 8.0, 0.0, Vector2i(8, 4)],
	[360.0, 34.0, 14.0, 0.13, Vector2i(28, 16)],
]
const FIELD_GOLD := Color("#e8b578")
const PITCH := Color("#101d26")
const STRIKE_XP := [4, 6, 5, 14, 12, 28]
const STRIKE_TIMINGS := [
	Vector3(0.074, 0.076, 0.172),
	Vector3(0.082, 0.082, 0.171),
	Vector3(0.111, 0.094, 0.212),
	Vector3(0.052, 0.113, 0.268),
]
const STRIKE_CROSSING := 0.54
const DASH_TIME := 0.134
const HERALD_INTERVAL := 10.0
const HERALD_WARNING := 0.68

var battle
var oath_book: Oaths
var towers: Array[Slot] = []
var enemies: Array[Enemy] = []
var watcher: Watcher
var campfire: Campfire
var ally: Watcher
var effects: Array[Dictionary] = []
var spirits: Array[Dictionary] = []
var links: Array[Dictionary] = []
var crit_gauge := 0.0
var effects_layer: Node2D
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
var kills := 0
var xp := 0
var last_player := Vector2.ZERO
var ally_attack := 0.0
var first_seen := {}


func setup(level: Node2D) -> void:
	battle = level
	oath_book = get_node("/root/OathDatabase")
	y_sort_enabled = true
	effects_layer = Node2D.new()
	effects_layer.name = "Combat effects"
	effects_layer.z_index = 2
	add_child(effects_layer)
	effects_layer.draw.connect(draw_effects)
	for index: int in range(battle.slot_points.size()):
		var slot := SLOT_SCENE.instantiate() as Slot
		slot.position = battle.slot_points[index]
		slot.high_ground = index in battle.high_slots
		slot.name = "Slot %02d" % (index + 1)
		add_child(slot)
		towers.append(slot)
	watcher = WATCHER_SCENE.instantiate() as Watcher
	watcher.position = battle.player
	add_child(watcher)
	campfire = FIRE_SCENE.instantiate() as Campfire
	campfire.position = battle.fire_point
	add_child(campfire)
	last_player = battle.player
	if battle.run.ally:
		ally = WATCHER_SCENE.instantiate() as Watcher
		ally.modulate = Color("#92b1c4")
		ally.scale = Vector2.ONE * 0.82
		ally.position = battle.fire_point + Vector2(32.0, 22.0)
		ally.lantern_on = false
		add_child(ally)


func owned_oaths() -> Array:
	return battle.run.oaths


func cost(kind: String, level := 1) -> Vector2i:
	var data: Dictionary = TOWERS.get(kind, {})
	if data.is_empty():
		return Vector2i.ZERO
	var base: Vector2i = data.price
	var multiplier := 1.0 + (level - 1) * 0.52
	return Vector2i(ceili(base.x * multiplier), ceili(base.y * multiplier))


func affordable(price: Vector2i) -> bool:
	return battle.run.embers >= price.x and battle.run.bone >= price.y


func price_text(price: Vector2i) -> String:
	return "%d 余烬  /  %d 骨材" % [price.x, price.y]


func spend(price: Vector2i) -> bool:
	if not affordable(price):
		battle.announce("材料不足 · " + price_text(price))
		return false
	battle.run.embers -= price.x
	battle.run.bone -= price.y
	return true


func build_options(index: int) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for kind: String in TOWER_ORDER:
		var data: Dictionary = TOWERS[kind]
		var price := cost(kind)
		var rank: int = battle.run.blueprints.get(kind, 1)
		var open := index >= 0 and index < towers.size() and towers[index].level == 0
		choices.append({"kind": kind, "name": data.name, "cost": price_text(price),
			"allowed": open and affordable(price) and not battle.night, "description": data.levels[rank - 1]})
	return choices


func upgrade_options(index: int) -> Dictionary:
	if index < 0 or index >= towers.size() or towers[index].level == 0:
		return {}
	var tower := towers[index]
	var data: Dictionary = TOWERS[tower.kind]
	var price := cost(tower.kind, tower.level + 1)
	var allowed: bool = tower.level < 3 and affordable(price) and not battle.night
	return {"kind": TOWER_ORDER.find(tower.kind), "name": data.name, "level": tower.level, "cost": price_text(price),
		"allowed": allowed, "levels": data.levels.duplicate()}


func inspect_radius(index: int, upgrade_preview := false) -> float:
	if index < 0 or index >= towers.size():
		return 0.0
	var slot := towers[index]
	var kind: String = battle.support_kind[index] if slot.level == 0 else slot.kind
	var rank: int = battle.run.blueprints.get(kind, 1) if slot.level == 0 else slot.level
	if upgrade_preview:
		rank += 1
	match kind:
		"ballista":
			return ballista_radius(slot)
		"brazier":
			return brazier_radius(rank) * battle.light_radius_scale()
		"barricade":
			return BARRICADE_LIGHT * battle.light_radius_scale() if rank >= 3 or slot.will_time > 0.0 else BARRICADE_LURE
		"oil":
			return oil_radius(rank)
	return 0.0


func ballista_radius(slot: Slot) -> float:
	return 320.0 * (1.25 if slot.high_ground else 1.0)


func brazier_radius(rank: int) -> float:
	return 180.0 if rank == 1 else 240.0


func build(index: int, kind: String) -> bool:
	if battle.night or index < 0 or index >= towers.size() or not TOWERS.has(kind):
		return false
	var slot := towers[index]
	if slot.level > 0 or not spend(cost(kind)):
		return false
	var data: Dictionary = TOWERS[kind]
	var rank: int = clampi(battle.run.blueprints.get(kind, 1), 1, 3)
	slot.install(kind, rank, data.health[rank - 1])
	refresh_links()
	battle.announce("%s已建造 · Lv.%d" % [data.name, rank])
	add_ring(slot.position, 36.0, FIELD_GOLD, 0.52)
	return true


func upgrade(index: int) -> bool:
	if battle.night or index < 0 or index >= towers.size():
		return false
	var slot := towers[index]
	if slot.level == 0 or slot.level >= 3 or not spend(cost(slot.kind, slot.level + 1)):
		return false
	var data: Dictionary = TOWERS[slot.kind]
	slot.install(slot.kind, slot.level + 1, data.health[slot.level])
	refresh_links()
	battle.announce("%s已升级 · Lv.%d" % [data.name, slot.level])
	add_ring(slot.position, 48.0, FIELD_GOLD, 0.57)
	return true


func slot_hint(index: int, night: bool) -> String:
	var slot := towers[index]
	if not night:
		return "E  建造工事" if slot.level == 0 else "E  %s · Lv.%d" % [TOWERS[slot.kind].name, slot.level]
	if slot.kind == "brazier" and not slot.lit:
		return "E  重新点燃烽火盆（5 余烬）"
	if slot.kind == "oil" and not slot.spent:
		return "E  用提灯引燃火油"
	if slot.health < slot.max_health - 0.01 and slot.health > 0.0:
		return "E  修复 %s（8 余烬）" % TOWERS[slot.kind].name
	return ""


func service_slot(index: int) -> bool:
	var slot := towers[index]
	if slot.kind == "brazier" and not slot.lit:
		return relight(index)
	if slot.kind == "oil" and not slot.spent:
		if not battle.lantern_on or battle.oil <= 0.0:
			battle.announce("引燃火油需要开启提灯")
			return false
		return ignite_oil(index)
	return repair(index)


func repair(index: int) -> bool:
	if index < 0 or index >= towers.size():
		return false
	var slot := towers[index]
	if slot.health <= 0.0 or slot.health >= slot.max_health - 0.01 or not spend(Vector2i(8, 0)):
		return false
	slot.health = minf(slot.max_health, slot.health + 58.0)
	ember_spent("repair")
	battle.announce("工事已修复")
	add_ring(slot.position, 31.0, FIELD_GOLD, 0.48)
	return true


func relight(index: int) -> bool:
	if index < 0 or index >= towers.size():
		return false
	var slot := towers[index]
	if slot.kind != "brazier" or slot.lit or slot.health <= 0.0 or not spend(Vector2i(5, 0)):
		return false
	slot.lit = true
	refresh_links()
	add_ring(slot.position, 37.0, FIELD_GOLD, 0.62)
	battle.announce("烽火盆重新点燃")
	return true


func extinguish_index(index: int) -> bool:
	if index < 0 or index >= towers.size():
		return false
	return extinguish(towers[index])


func extinguish_near(position_value: Vector2, radius: float) -> PackedVector2Array:
	var affected := PackedVector2Array()
	for slot: Slot in towers:
		if slot.position.distance_squared_to(position_value) <= radius * radius and extinguish(slot):
			affected.append(slot.position)
	return affected


func extinguish(slot: Slot) -> bool:
	if slot.kind != "brazier" or not slot.lit:
		return false
	slot.lit = false
	refresh_links()
	light_lost(slot.position)
	add_ring(slot.position, 31.0, Color("#ae91a4"), 0.7)
	return true


func light_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for slot in towers:
		if slot.kind == "brazier" and slot.lit and slot.health > 0.0:
			sources.append({"position": slot.position, "radius": brazier_radius(slot.level), "ignore_occlusion": slot.high_ground,
				"energy": 0.66 if slot.level == 1 else 0.74})
		elif slot.kind == "barricade" and (slot.level >= 3 or slot.will_time > 0.0):
			sources.append({"position": slot.position, "radius": BARRICADE_LIGHT, "energy": 0.50})
		elif slot.kind == "oil" and slot.burn > 0.0:
			sources.append({"position": slot.position, "radius": oil_radius(slot.level), "energy": 0.49})
	return sources


func light_links() -> Array[Dictionary]:
	return links


func refresh_links() -> void:
	links.clear()
	var bond: Dictionary = oath_book.bond_modifiers(owned_oaths())
	if not bond.is_empty():
		for first in range(towers.size()):
			var a := towers[first]
			if a.level == 0:
				continue
			for second in range(first + 1, towers.size()):
				var b := towers[second]
				if b.level != 0 and a.position.distance_to(b.position) <= bond.range:
					links.append({"from": a.position, "to": b.position, "width": bond.width,
						"dps": bond.dps, "slow": bond.slow})
	for a in towers:
		if a.kind != "brazier" or not a.lit or a.level < 3:
			continue
		var adjacent: Slot
		var radius := 400.0
		for b in towers:
			var distance := a.position.distance_to(b.position)
			if b != a and b.kind == "brazier" and b.lit and distance < radius:
				adjacent = b
				radius = distance
		if adjacent != null:
			links.append({"from": a.position, "to": adjacent.position, "width": 16.0, "dps": 0.0, "slow": 0.25})


func spawn(kind: int, lane: int) -> Enemy:
	var data: Array = SPECIES[kind]
	var foe := ENEMY_SCENE.instantiate() as Enemy
	foe.kind = kind
	foe.lane = lane
	foe.path = actor_route(lane, foe.radius)
	if foe.path.size() < 2:
		foe.queue_free()
		return null
	foe.position = foe.path[0]
	foe.elite = battle.elite or kind == Enemy.HERALD
	var cycle: int = maxi(0, battle.run.cycle - 1)
	var inflate := 1.0 + 0.22 * cycle + (0.15 if foe.elite else 0.0) + float(battle.biome) * 0.075
	foe.max_health = data[0] * inflate
	foe.health = foe.max_health
	foe.speed = data[1] * (1.0 + float(battle.run.speed_bonus) + minf(0.38, cycle * 0.06))
	foe.power = data[2] * (1.0 + 0.15 * cycle + (0.13 if foe.elite else 0.0))
	foe.armor = minf(0.62, data[3] + cycle * 0.035)
	if cycle > 0:
		foe.affliction = 1 + (kind * 5 + lane + cycle) % (2 if kind == Enemy.MOTH else 3)
		if foe.affliction == 2:
			foe.armor = minf(0.74, foe.armor + 0.14)
		elif foe.affliction == 3:
			foe.power *= 1.33
	if kind == Enemy.MOTH:
		foe.power = 15.0
	foe.reward = data[4]
	foe.cooldown = 0.72
	foe.special = 5.7
	foe.facing = foe.position.direction_to(foe.path[1])
	add_child(foe)
	enemies.append(foe)
	if not first_seen.has(kind):
		first_seen[kind] = true
		var introductions := ["夜行爬尸在啃咬防线", "影潜者避开了光，扫照使它显形", "噬火蛾正在寻找最近的光源",
			"掘骨巨尸擅长撞毁路障", "灰烬咒术师可遮蔽塔的视野", "永夜先驱会熄灭火盆并召来爬尸"]
		var name: String = Enemy.AFFLICTIONS[foe.affliction]
		battle.announce(introductions[kind] if name.is_empty() else "%s · 永夜词缀「%s」" % [Enemy.NAMES[kind], name])
	return foe


func count_enemies() -> int:
	var live := 0
	for enemy: Enemy in enemies:
		if not enemy.removed:
			live += 1
	return live


func enemy_count() -> int:
	return count_enemies()


func reroute(lane := -1) -> void:
	for foe: Enemy in enemies:
		if foe.removed or foe.kind == Enemy.MOTH or (lane >= 0 and lane != foe.lane):
			continue
		var route := actor_route(foe.lane, foe.radius)
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


func reset_night() -> void:
	for slot in towers:
		slot.will_used = false
		slot.spent = false
		slot.burn = 0.0
		slot.cooldown = 0.0
	refresh_links()


func tick(delta: float) -> void:
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
	advance_strike(weighted)
	if injury <= 0.0 and (not battle.night or (battle.player as Vector2).distance_squared_to(battle.fire_point) <= 42.0 ** 2):
		player_hp = minf(player_hp_max, player_hp + delta * (11.0 if not battle.night else 4.0))
	var lantern_rule: Dictionary = oath_book.lantern_modifiers(owned_oaths(), battle.still)
	var repair_rate: float = lantern_rule.repair if battle.lantern_on and battle.oil > 0.0 else 0.0
	refresh_links()
	for slot: Slot in towers:
		step_slot(slot, delta, repair_rate)
	for foe: Enemy in enemies.duplicate():
		if not foe.removed:
			step_enemy(foe, delta)
	space_ground_enemies(delta)
	step_spirits(delta)
	if ally != null:
		step_ally(delta)
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].removed:
			enemies[i].queue_free()
			enemies.remove_at(i)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].left -= delta
		if effects[i].left <= 0.0:
			effects.remove_at(i)
	refresh_art(delta)


func refresh_art(delta: float) -> void:
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
	campfire.ratio = battle.fire_hp / 100.0
	campfire.clock = battle.clock
	campfire.queue_redraw()
	for tower in towers:
		tower.clock = battle.clock
		tower.focus = tower.position.distance_squared_to(battle.player) <= 47.0 ** 2
		tower.queue_redraw()
	for enemy in enemies:
		enemy.queue_redraw()
	effects_layer.queue_redraw()


func step_slot(slot: Slot, delta: float, repair_rate: float) -> void:
	if slot.level == 0:
		return
	slot.flash = maxf(0.0, slot.flash - delta)
	slot.disabled = maxf(0.0, slot.disabled - delta)
	slot.sworn = maxf(0.0, slot.sworn - delta)
	slot.cooldown = maxf(0.0, slot.cooldown - delta)
	if slot.kind == "ballista":
		slot.idle += delta
	if slot.will_time > 0.0:
		slot.will_time = maxf(0.0, slot.will_time - delta)
		if slot.will_time == 0.0:
			slot.clear()
		return
	var repair := 3.2 if slot.kind == "barricade" and slot.level == 3 else 0.0
	if repair_rate > 0.0 and slot.position.distance_squared_to(battle.player) <= 170.0 ** 2:
		repair += repair_rate
	slot.health = minf(slot.max_health, slot.health + repair * delta)
	if not battle.night:
		return
	match slot.kind:
		"ballista":
			if slot.disabled <= 0.0 and slot.cooldown == 0.0:
				fire_ballista(slot)
		"brazier":
			if slot.lit and slot.level >= 2:
				var radius: float = brazier_radius(slot.level) * battle.light_radius_scale()
				for foe in enemies:
					if not foe.removed and foe.position.distance_squared_to(slot.position) <= radius ** 2 and battle.light_manager.is_position_lit(foe.position, slot.high_ground):
						damage_enemy(foe, 3.5 * delta, true, true)
		"oil":
			update_oil(slot, delta)


func oil_radius(rank: int) -> float:
	return 46.0 if rank == 1 else 61.0


func update_oil(slot: Slot, delta: float) -> void:
	if slot.burn > 0.0:
		slot.burn = maxf(0.0, slot.burn - delta)
		for foe in enemies:
			if not foe.removed and foe.kind != Enemy.MOTH and foe.position.distance_squared_to(slot.position) <= oil_radius(slot.level) ** 2:
				foe.burned = maxf(foe.burned, 1.2)
				if slot.level >= 2:
					foe.sundered = maxf(foe.sundered, 1.3)
				damage_enemy(foe, (16.0 if slot.level == 1 else 19.0) * delta, true, true)
		if slot.burn == 0.0:
			light_lost(slot.position)
	elif not slot.spent and ground_target_in(slot.position, oil_radius(slot.level)):
		var player_pos: Vector2 = battle.player
		var lamp_radius := 152.0 if not battle.is_harsh_weather() or battle.biome != 0 else 106.4
		var near_lamp: bool = battle.lantern_on and battle.oil > 0.0 and player_pos.distance_to(slot.position) <= lamp_radius
		var direction: Vector2 = battle.aim
		if near_lamp and (player_pos.distance_squared_to(slot.position) <= 20.0 ** 2 or direction.dot(player_pos.direction_to(slot.position)) >= 0.72):
			ignite(slot)


func ground_target_in(point: Vector2, radius: float) -> bool:
	for foe in enemies:
		if not foe.removed and foe.kind != Enemy.MOTH and foe.position.distance_squared_to(point) <= radius * radius:
			return true
	return false


func ignite_oil(index: int) -> bool:
	return ignite(towers[index]) if index >= 0 and index < towers.size() else false


func ignite(slot: Slot) -> bool:
	if slot.kind != "oil" or slot.spent:
		return false
	slot.spent = true
	slot.burn = 10.0 if slot.level == 3 else 6.0
	var wrap: Dictionary = oath_book.on_oil_ignite(owned_oaths())
	add_ring(slot.position, oil_radius(slot.level), Color("#fa9c64"), 0.47)
	for foe in enemies:
		if foe.removed or foe.kind == Enemy.MOTH or foe.position.distance_squared_to(slot.position) > oil_radius(slot.level) ** 2:
			continue
		if not wrap.is_empty():
			foe.wrapped = maxf(foe.wrapped, wrap.seconds)
		if slot.level == 3:
			foe.knock += slot.position.direction_to(foe.position) * 39.0
			damage_enemy(foe, 17.0, true, true)
	return true


func fire_ballista(slot: Slot, is_salvo := false) -> bool:
	if slot.disabled > 0.0:
		return false
	var radius := ballista_radius(slot)
	var chosen: Enemy
	var best := INF
	for foe: Enemy in enemies:
		if foe.removed or foe.position.distance_squared_to(slot.position) > radius * radius:
			continue
		if foe.kind == Enemy.SHADE and not foe.lit:
			continue
		if not battle.light_manager.is_position_lit(foe.position, slot.high_ground):
			continue
		var threat: float = foe.position.distance_squared_to(battle.fire_point)
		if foe.kind == Enemy.MOTH:
			threat -= 10500.0
		if slot.level == 3 and (foe.elite or foe.kind == Enemy.COLOSSUS):
			threat -= 31000.0
		if threat < best:
			chosen = foe
			best = threat
	var is_lit: bool = battle.light_manager.is_position_lit(slot.position, slot.high_ground)
	var modifiers: Dictionary = oath_book.tower_modifiers(owned_oaths(), is_lit, slot.sworn > 0.0, slot.idle, battle.fire_hp)
	var damage := 16.0 + (slot.level - 1) * 5.0
	var muzzle := slot.position
	if battle.has_method("support_muzzle"):
		muzzle = battle.support_muzzle(towers.find(slot))
	if chosen == null:
		for i in range(battle.crystals.size()):
			var crystal: Dictionary = battle.crystals[i]
			if crystal.hp <= 0.0 or slot.position.distance_squared_to(crystal.position) > radius * radius:
				continue
			if not battle.light_manager.is_position_lit(crystal.position, slot.high_ground):
				continue
			slot.look = slot.position.direction_to(crystal.position)
			battle.damage_crystal(i, damage * modifiers.power)
			add_shot(muzzle, crystal.position - Vector2(0.0, 7.0), FIELD_GOLD, 0.19)
			record_attack(slot, modifiers, false, is_lit, is_salvo)
			return true
		return false
	var heavy := slot.level == 3 and chosen.armor >= 0.13
	var critical := heavy
	if not critical and modifiers.crit > 0.0:
		crit_gauge += modifiers.crit
		if crit_gauge >= 1.0:
			crit_gauge -= 1.0
			critical = true
	if critical:
		damage *= 1.8
	damage *= modifiers.power
	slot.look = slot.position.direction_to(chosen.position)
	add_shot(muzzle, chosen.position - Vector2(0.0, 15.0), Color("#ffc582") if critical else Color("#ddc3a0"), 0.20)
	damage_enemy(chosen, damage)
	if modifiers.power > 1.0:
		add_ring(chosen.position, 65.0, Color("#ffbc6a"), 0.58)
		for foe in enemies:
			if foe != chosen and not foe.removed and foe.position.distance_squared_to(chosen.position) <= 65.0 ** 2:
				damage_enemy(foe, damage)
	elif slot.level >= 2:
		pierce(slot, chosen, damage, radius)
	record_attack(slot, modifiers, critical, is_lit, is_salvo)
	return true


func pierce(slot: Slot, chosen: Enemy, damage: float, radius: float) -> void:
	var direction := slot.position.direction_to(chosen.position)
	var near := slot.position.distance_to(chosen.position)
	var next: Enemy
	var best := radius
	for foe in enemies:
		if foe == chosen or foe.removed or not battle.light_manager.is_position_lit(foe.position, slot.high_ground):
			continue
		if foe.kind == Enemy.SHADE and not foe.lit:
			continue
		var distance := foe.position - slot.position
		var along := distance.dot(direction)
		if along > near and along < best and absf(distance.cross(direction)) <= 19.0:
			next = foe
			best = along
	if next != null:
		damage_enemy(next, damage * 0.72)
		add_shot(chosen.position, next.position, FIELD_GOLD, 0.22)


func record_attack(slot: Slot, modifiers: Dictionary, critical: bool, is_lit: bool, is_salvo: bool) -> void:
	slot.flash = 0.14
	slot.idle = 0.0
	if not is_salvo:
		slot.cooldown = 1.2 * modifiers.attack_interval / modifiers.attack_speed
	var effects_rule: Dictionary = oath_book.on_tower_attack(owned_oaths(), is_lit, critical)
	battle.run.embers += effects_rule.embers


func ember_spent(reason: String) -> void:
	var rule: Dictionary = oath_book.on_ember_spend(owned_oaths(), reason)
	if rule.is_empty():
		return
	slash_left = 0.0
	dash_left = 0.0
	for slot in towers:
		if slot.kind == "ballista":
			fire_ballista(slot, true)


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
	var mods: Dictionary = oath_book.player_modifiers(owned_oaths(), origin.distance_to(battle.fire_point), battle.fire_hp)
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


func advance_strike(delta: float) -> void:
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
		blade_cuts.emit(battle.player, strike_facing, strike_heavy)
	var unloading := maxf(0.0, minf(crossing, advanced) - maxf(strike_timing.x, prior))
	if unloading > 0.0:
		var motion := strike_facing * unloading * (185.0 if strike_heavy else 112.0)
		battle.player = move_in_world(battle.player, motion, 12.0)
	strike_clock = advanced
	if prior < crossing and advanced >= crossing:
		strike_clock = crossing
		resolve_cut()
		if hit_pause <= 0.0:
			strike_clock = advanced
	if strike_clock >= strike_total:
		strike_clock = -1.0


func resolve_cut() -> void:
	var origin: Vector2 = battle.player
	var aim := strike_facing
	var mods: Dictionary = oath_book.player_modifiers(owned_oaths(), origin.distance_to(battle.fire_point), battle.fire_hp)
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
		if move_in_world(origin, offset, 1.5).distance_squared_to(foe.position) > 14.0 ** 2:
			continue
		var push := offset.normalized()
		if push.is_zero_approx():
			push = aim
		var armored := foe.kind in [Enemy.COLOSSUS, Enemy.HERALD] or foe.armor > 0.18
		var flank: bool = foe.kind == Enemy.COLOSSUS and foe.facing.dot(foe.position.direction_to(origin)) < -0.25
		damage_enemy(foe, damage * (1.35 if flank else 1.0), false, flank, true)
		var pause := 0.067 if strike_heavy else 0.050 if armored or combo == 3 else 0.038
		hit_pause = maxf(hit_pause, pause)
		foe.hit_hold = maxf(foe.hit_hold, pause)
		foe.knock += push * (38.0 if strike_heavy else 18.0) * (0.38 if armored else 1.0)
		foe.stagger = 0.29 if strike_heavy else 0.15
		foe.tell = 0.0
		foe.attack_pose = 0.0
		foe.attack_target = Enemy.TARGET_NONE
		foe.velocity_hit = push
		melee_contact.emit(foe.position - push * 8.0, push, 1.0 if armored else 0.67, armored, strike_heavy)
		if foe.kind == Enemy.HEXER:
			foe.charge = 0.0
			foe.special = 2.4
		connected = true
	battle.damage_crystals_at(origin, aim, reach, damage)
	if connected:
		var moment: Dictionary = oath_book.on_player_slash(owned_oaths())
		if not moment.is_empty():
			for tower in towers:
				if tower.level > 0 and tower.position.distance_squared_to(origin) <= float(moment.radius) ** 2:
					tower.sworn = maxf(tower.sworn, moment.seconds)
			add_ring(origin, moment.radius, FIELD_GOLD, 0.43)
	if strike_heavy:
		charged_cut.emit(origin, aim)


func dash() -> bool:
	if dash_left > 0.0 or hit_pause > 0.0:
		return false
	var start: Vector2 = battle.player
	var direction: Vector2 = battle.aim.normalized()
	var destination := move_in_world(start, direction * 112.0, 12.0)
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
	add_shot(start, destination, Color("#94b1bf"), 0.13)
	var rule: Dictionary = oath_book.on_dash(owned_oaths())
	if not rule.is_empty():
		add_ring(start, rule.radius, Color("#c6a9cc"), 0.74)
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
	battle.player = move_in_world(battle.player, wanted - battle.player, 12.0)


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
	if delta <= 0.0:
		return
	var ground: Array[Enemy] = []
	for foe in enemies:
		if not foe.removed and foe.kind != Enemy.MOTH:
			ground.append(foe)
	var correction_limit := minf(6.0, 128.0 * delta)
	for index in range(ground.size()):
		var first := ground[index]
		for next in range(index+1, ground.size()):
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
			first.position = move_in_world(first.position, -along * correction, first.radius)
			var remaining := need - first.position.distance_to(before)
			if give_second > 0.0 and remaining > 0.0:
				second.position = move_in_world(second.position, along * remaining, second.radius)
		if dash_travel <= 0.0 and first.hit_hold <= 0.0:
			var away: Vector2 = first.position - battle.player
			var overlap := first.radius + 9.0 - away.length()
			if overlap > 0.0:
				var direction := away.normalized() if away.length_squared() > 0.01 else -first.facing
				first.position = move_in_world(first.position, direction * minf(overlap, correction_limit * 0.7), first.radius)


func footing(foe: Enemy) -> float:
	if foe.hit_hold > 0.0:
		return 0.0
	var firmness := 0.57 if foe.kind in [Enemy.COLOSSUS, Enemy.HERALD] else 1.0
	return firmness * (0.38 if foe.tell > 0.0 or foe.attack_pose > 0.0 else 1.0)


func hurt_player(amount: float, attacker: Vector2) -> bool:
	if not battle.night or dash_grace > 0.0 or safety_grace > 0.0:
		return false
	player_hp = maxf(0.0, player_hp - amount)
	injury = 1.85
	safety_grace = 0.46
	var origin: Vector2 = battle.player
	add_ring(origin, 25.0, Color("#e67261"), 0.28)
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
		battle.player = move_in_world(origin, attacker.direction_to(origin) * 9.0, 12.0)
	return true

func step_ally(delta: float) -> void:
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
			damage_enemy(foe, 19.0)
			break


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
	var mark: Dictionary = oath_book.on_enemy_lit(owned_oaths(), foe.lit, now_lit)
	foe.lit = now_lit
	if not mark.is_empty():
		foe.marked = maxf(foe.marked, mark.seconds)
	var fire_dps: float = oath_book.light_damage(owned_oaths(), strength)
	if foe.burned > 0.0:
		fire_dps += 2.6
	if fire_dps > 0.0:
		damage_enemy(foe, fire_dps * delta, true, true)
	if foe.removed:
		return
	var slow := 0.0
	for link in links:
		var near := Geometry2D.get_closest_point_to_segment(foe.position, link.from, link.to)
		if near.distance_squared_to(foe.position) <= float(link.width) ** 2:
			slow = maxf(slow, link.slow)
			if link.dps > 0.0:
				damage_enemy(foe, link.dps * delta, false, true)
	if foe.removed:
		return
	if foe.kind != Enemy.MOTH:
		for slot in towers:
			if slot.kind == "oil" and (not slot.spent or slot.burn > 0.0) and slot.position.distance_squared_to(foe.position) <= oil_radius(slot.level) ** 2:
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
		foe.position = move_in_world(foe.position, knock, foe.radius, foe.kind == Enemy.MOTH)
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
	var reach := BARRICADE_LURE
	for index in range(towers.size()):
		var slot := towers[index]
		if slot.kind != "barricade":
			continue
		var here := foe.position.distance_to(slot.position)
		if here < reach and direction.dot(foe.position.direction_to(slot.position)) > -0.35:
			best = index
			reach = here
	if best >= 0:
		if foe.cooldown <= 0.0:
			prepare_enemy_attack(foe, Enemy.TARGET_WALL, towers[best].position, best)
		return
	if speed <= 0.0:
		return
	if not direction.is_zero_approx():
		foe.facing = direction
	var before := foe.position
	var requested := before.move_toward(target, speed * delta) - before
	var moved := move_in_world(before, requested, foe.radius)
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
		if move_in_world(foe.position, next - foe.position, foe.radius).distance_squared_to(next) < 0.25 ** 2:
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
		var across := move_in_world(foe.position, origin - foe.position, 1.5)
		if across.distance_squared_to(origin) <= 10.0 ** 2:
			prepare_enemy_attack(foe, Enemy.TARGET_PLAYER, origin)
			return true
	if distance <= 77.0 ** 2 and distance > 25.0 ** 2 and foe.position.distance_squared_to(battle.fire_point) > 28.0 ** 2:
		var desired := foe.position.move_toward(origin, speed * 0.86 * delta)
		var motion := desired - foe.position
		var destination := move_in_world(foe.position, motion, foe.radius)
		if destination.is_equal_approx(foe.position):
			destination = move_in_world(foe.position, Vector2(motion.x, 0.0), foe.radius)
			destination = move_in_world(destination, Vector2(0.0, motion.y), foe.radius)
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
		add_ring(foe.position, 37.0 if heavy else 28.0, Color("#ce705c"), foe.tell)


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
		foe.position = move_in_world(foe.position, foe.facing * rush * 140.0, foe.radius)
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
			var visible := move_in_world(foe.position, origin - foe.position, 1.5).distance_squared_to(origin) <= 10.0 ** 2
			if close and visible and foe.facing.dot(toward) > 0.13:
				var damage := 11.0 if foe.kind <= Enemy.SHADE else 19.0
				if hurt_player(damage * (1.0 + 0.08 * float(battle.run.cycle - 1)), foe.position):
					enemy_contact.emit(origin, foe.facing, heavy)
		Enemy.TARGET_FIRE:
			battle.hurt_fire(foe.power, true)
			var fire: Vector2 = battle.fire_point
			add_ring(fire, 23.0, Color("#fb8b62"), 0.27)
			enemy_contact.emit(fire, foe.facing, heavy)
		Enemy.TARGET_WALL:
			var slot := towers[foe.attack_slot]
			if slot.kind == "barricade" and foe.position.distance_to(slot.position) <= 47.0:
				hit_barricade(slot, foe)
				enemy_contact.emit(slot.position, foe.facing, heavy)
	foe.attack_target = Enemy.TARGET_NONE
	return true


func hit_barricade(slot: Slot, foe: Enemy) -> void:
	if slot.level >= 2:
		damage_enemy(foe, 10.0)
	if slot.will_time > 0.0 or foe.removed:
		return
	slot.health = maxf(0.0, slot.health - foe.power * (3.0 if foe.kind == Enemy.COLOSSUS else 1.0))
	add_shot(foe.position, slot.position, Color("#be8a6f"), 0.12)
	if slot.health <= 0.0:
		var will: Dictionary = oath_book.on_barricade_break(owned_oaths(), slot.will_used)
		if will.is_empty():
			slot.clear()
			refresh_links()
		else:
			slot.will_time = will.seconds
			slot.will_used = true
			add_ring(slot.position, 48.0, FIELD_GOLD, 0.58)


func move_moth(foe: Enemy, speed: float, delta: float) -> void:
	var target: Vector2 = battle.fire_point
	var nearest := foe.position.distance_squared_to(target)
	var lamp := false
	var vessel: Slot
	foe.flight_retry = maxf(0.0, foe.flight_retry - delta)
	foe.flight_rejection_left = maxf(0.0, foe.flight_rejection_left - delta)
	for slot in towers:
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
	add_ring(target, 34.0, Color("#f48759"), 0.52)
	var destination := MothDestination.HEARTH
	if lamp:
		destination = MothDestination.LANTERN
		battle.oil = maxf(0.0, battle.oil - 20.0)
		battle.announce("噬火蛾撞上提灯，灯油 -20")
	elif vessel != null:
		destination = MothDestination.BRAZIER
		extinguish(vessel)
		battle.announce("噬火蛾扑灭了一座烽火盆")
	else:
		battle.hurt_fire(15.0, true)
		battle.announce("噬火蛾撞上篝火，火势 -15")
	moth_contact.emit(target, foe.facing, destination, foe)


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
	var moved := move_in_world(prior, motion, foe.radius, true)
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
		moved = move_in_world(prior, motion, foe.radius, true)
	foe.position = moved
	var heading := prior.direction_to(guide)
	if not heading.is_zero_approx():
		foe.facing = heading
	return true


func cast_haze(foe: Enemy, delta: float) -> bool:
	foe.special = maxf(0.0, foe.special - delta)
	var tower: Slot
	var nearest := 195.0 ** 2
	for slot in towers:
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
		add_shot(foe.position, tower.position, Color("#af769e"), 0.62)
	return true


func herald_cycle(foe: Enemy, delta: float) -> void:
	foe.special -= delta
	if foe.special > 0.0:
		return
	foe.special = HERALD_INTERVAL
	var affected := extinguish_near(foe.position, 225.0)
	add_ring(foe.position, 225.0, Color("#ab6197"), 0.92)
	for i in range(2):
		var minion := spawn(Enemy.CRAWLER, foe.lane)
		if minion != null:
			minion.position = foe.position + Vector2(16.0 * (i * 2 - 1), 12.0)
			minion.waypoint = mini(foe.waypoint, minion.path.size() - 1)
	herald_cast.emit(foe.position, affected)


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
			enemy_struck.emit(foe.position, foe.kind, flame)
	if foe.health <= 0.0:
		enemy_defeated(foe)


func enemy_defeated(foe: Enemy) -> void:
	foe.removed = true
	kills += 1
	var reward_xp: int = STRIKE_XP[foe.kind]
	xp += reward_xp
	enemy_slain.emit(foe.kind, reward_xp, foe.position)
	var rule: Dictionary = oath_book.on_enemy_killed(owned_oaths(), battle.fire_hp,
		battle.night_fraction(), battle.is_harsh_weather(), foe.burned > 0.0)
	battle.run.embers += foe.reward.x * rule.loot_scale
	battle.run.bone += foe.reward.y * rule.loot_scale
	if rule.fire_heal > 0.0:
		battle.heal_fire(rule.fire_heal)
	add_ring(foe.position, 19.0, Color("#edc488"), 0.36)
	var dust: Dictionary = rule.dust
	if dust.is_empty():
		return
	add_ring(foe.position, dust.radius, Color("#c98256"), 0.44)
	for nearby in enemies:
		if not nearby.removed and nearby.position.distance_squared_to(foe.position) <= float(dust.radius) ** 2:
			nearby.burned = maxf(nearby.burned, dust.burn_seconds)
			damage_enemy(nearby, dust.damage, false, true)


func light_lost(point: Vector2) -> void:
	var rule: Dictionary = oath_book.on_light_gone(owned_oaths())
	if rule.is_empty():
		return
	for i in range(rule.count):
		var direction := Vector2.from_angle(TAU * i / float(rule.count))
		var start := point + direction * 9.0
		spirits.append({"origin": point, "at": start, "tail": point, "direction": direction,
			"delay": i * 0.03, "left": 1.2, "radius": rule.radius, "damage": rule.damage})


func step_spirits(delta: float) -> void:
	for index in range(spirits.size() - 1, -1, -1):
		var spirit := spirits[index]
		spirit.left -= delta
		if spirit.left <= 0.0:
			spirits.remove_at(index)
			continue
		var from: Vector2 = spirit.at
		var born_at: Vector2 = spirit.origin
		var nearest: Enemy
		var best: float = spirit.radius ** 2
		spirit.delay -= delta
		if spirit.delay <= 0.0:
			for foe in enemies:
				if foe.removed or born_at.distance_squared_to(foe.position) > float(spirit.radius) ** 2:
					continue
				var distance := from.distance_squared_to(foe.position)
				if distance < best:
					nearest = foe
					best = distance
		var direction: Vector2 = spirit.direction
		if nearest != null:
			direction = direction.lerp(from.direction_to(nearest.position), minf(1.0, delta * 15.0)).normalized()
			if best <= 18.0 ** 2:
				nearest.burned = maxf(nearest.burned, 1.1)
				damage_enemy(nearest, spirit.damage, true, true)
				add_ring(nearest.position, 15.0, Color("#f2a174"), 0.23)
				spirits.remove_at(index)
				continue
		spirit.direction = direction
		spirit.tail = (spirit.tail as Vector2).lerp(from, minf(1.0, delta * 32.0))
		spirit.at = from + direction * (325.0 if nearest != null else 54.0) * delta


func add_ring(origin: Vector2, radius: float, tint: Color, duration: float) -> void:
	effects.append({"a": origin, "radius": radius, "tint": tint, "left": duration, "duration": duration})


func add_shot(from: Vector2, to: Vector2, tint: Color, duration: float) -> void:
	effects.append({"a": from, "b": to, "tint": tint, "left": duration, "duration": duration})


func draw_effects() -> void:
	for spirit in spirits:
		var tail: Vector2 = spirit.tail
		var tip: Vector2 = spirit.at
		var amber := Color(1.0, 0.59, 0.29, clampf(spirit.left * 2.0, 0.0, 0.95))
		effects_layer.draw_line(tail, tip, amber, 2.4, true)
		effects_layer.draw_circle(tip, 3.5, amber.lightened(0.24), true, -1.0, true)
	for effect in effects:
		var remain: float = clampf(effect.left / effect.duration, 0.0, 1.0)
		var tint: Color = Color(effect.tint, remain * 0.89)
		var a: Vector2 = effect.a
		if effect.has("b"):
			var b: Vector2 = effect.b
			var rise := Vector2(0.0, -9.0)
			var end := a.lerp(b, minf(1.0, (1.0 - remain) * 2.8 + 0.15))
			effects_layer.draw_line(a + rise, end + rise, Color(PITCH, remain * 0.72), 5.3, true)
			effects_layer.draw_line(a + rise, end + rise, tint, 2.5, true)
			effects_layer.draw_circle(end + rise, 3.1, tint, true, -1.0, true)
		else:
			var radius: float = effect.radius * lerpf(1.0, 0.24, remain)
			effects_layer.draw_arc(a, radius, 0.0, TAU, 36, tint, 2.3, true)
