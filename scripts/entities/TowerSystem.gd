class_name TowerSystem
extends RefCounted

const Slot = preload("res://scripts/entities/TowerController.gd")
const Enemy = preload("res://scripts/entities/EnemyController.gd")
const TowerDef = preload("res://scripts/data/TowerData.gd")
const SLOT_SCENE = preload("res://scenes/entities/BuildSlot.tscn")
const FIELD_GOLD := Color("#e8b578")
const BARRICADE_LURE := 35.0
const BARRICADE_LIGHT := 76.0
const TOWER_ORDER := ["brazier", "ballista", "barricade", "oil"]

var combat: Node2D
var battle: Node2D
var oath_book: Node
var tower_defs: Dictionary[String, TowerDef] = {}
var towers: Array[Slot] = []
var links: Array[Dictionary] = []
var crit_gauge := 0.0


func _init() -> void:
	tower_defs["brazier"] = TowerDef.create("brazier", "烽火盆", Vector2i(13, 4), [95.0, 128.0, 157.0],
		["180 范围暖光，照出影潜者。", "240 范围暖光，灼烧近敌。", "与附近火盆连成光束，沿线显形并减速 25%。"])
	tower_defs["ballista"] = TowerDef.create("ballista", "骨弩台", Vector2i(23, 14), [87.0, 119.0, 152.0],
		["320 射程，1.2 秒一矢。高台射程 +25%。", "骨矢贯穿，同时命中射线上的第二名敌人。", "优先精英与重甲，重甲命中造成 180% 暴击。"])
	tower_defs["barricade"] = TowerDef.create("barricade", "誓言路障", Vector2i(12, 8), [158.0, 235.0, 315.0],
		["阻挡地面敌人，吸引它们攻击。", "尖刺将近战伤害反弹给攻击者。", "释放微光，并缓慢修复耐久。"])
	tower_defs["oil"] = TowerDef.create("oil", "火油槽", Vector2i(11, 6), [55.0, 68.0, 78.0],
		["减速 35%，可用灯火引燃，持续 6 秒。", "火圈更广，燃烧使物理伤害提高 30%。", "引燃时爆发并击退，持续 10 秒。"])


func get_def(kind: String) -> TowerDef:
	return tower_defs[kind] if tower_defs.has(kind) else null


func setup(owner_combat: Node2D, level: Node2D, oaths: Node) -> void:
	combat = owner_combat
	battle = level
	oath_book = oaths
	towers.clear()
	links.clear()
	crit_gauge = 0.0
	for index: int in range(battle.slot_points.size()):
		var slot := SLOT_SCENE.instantiate() as Slot
		slot.position = battle.slot_points[index]
		slot.high_ground = index in battle.high_slots
		slot.name = "Slot %02d" % (index + 1)
		combat.add_child(slot)
		towers.append(slot)


func cost(kind: String, level := 1) -> Vector2i:
	var data := get_def(kind)
	return data.cost_at(level) if data != null else Vector2i.ZERO


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
		var data := get_def(kind)
		var price := data.cost_at(1)
		var rank: int = battle.run.blueprints.get(kind, 1)
		var open := index >= 0 and index < towers.size() and towers[index].level == 0
		choices.append({"kind": kind, "name": data.display_name, "cost": price_text(price),
			"allowed": open and affordable(price) and not battle.night, "description": data.description_at(rank)})
	return choices


func upgrade_options(index: int) -> Dictionary:
	if index < 0 or index >= towers.size() or towers[index].level == 0:
		return {}
	var tower := towers[index]
	var data := get_def(tower.kind)
	var price := data.cost_at(tower.level + 1)
	var allowed: bool = tower.level < 3 and affordable(price) and not battle.night
	return {"kind": TOWER_ORDER.find(tower.kind), "name": data.display_name, "level": tower.level, "cost": price_text(price),
		"allowed": allowed, "levels": data.descriptions_array()}


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


func oil_radius(rank: int) -> float:
	return 46.0 if rank == 1 else 61.0


func build(index: int, kind: String) -> bool:
	var data := get_def(kind)
	if battle.night or index < 0 or index >= towers.size() or data == null:
		return false
	var slot := towers[index]
	if slot.level > 0 or not spend(data.cost_at(1)):
		return false
	var rank: int = clampi(battle.run.blueprints.get(kind, 1), 1, 3)
	slot.install(kind, rank, data.health_at(rank))
	refresh_links()
	battle.announce("%s已建造 · Lv.%d" % [data.display_name, rank])
	combat.add_ring(slot.position, 36.0, FIELD_GOLD, 0.52)
	return true


func upgrade(index: int) -> bool:
	if battle.night or index < 0 or index >= towers.size():
		return false
	var slot := towers[index]
	var data := get_def(slot.kind)
	if slot.level == 0 or slot.level >= 3 or data == null or not spend(data.cost_at(slot.level + 1)):
		return false
	slot.install(slot.kind, slot.level + 1, data.health_at(slot.level + 1))
	refresh_links()
	battle.announce("%s已升级 · Lv.%d" % [data.display_name, slot.level])
	combat.add_ring(slot.position, 48.0, FIELD_GOLD, 0.57)
	return true


func slot_hint(index: int, night: bool) -> String:
	var slot := towers[index]
	var data := get_def(slot.kind)
	var label := data.display_name if data != null else ""
	if not night:
		return "E  建造工事" if slot.level == 0 else "E  %s · Lv.%d" % [label, slot.level]
	if slot.kind == "brazier" and not slot.lit:
		return "E  重新点燃烽火盆（5 余烬）"
	if slot.kind == "oil" and not slot.spent:
		return "E  用提灯引燃火油"
	if slot.health < slot.max_health - 0.01 and slot.health > 0.0:
		return "E  修复 %s（8 余烬）" % label
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
	combat.ember_spent("repair")
	battle.announce("工事已修复")
	combat.add_ring(slot.position, 31.0, FIELD_GOLD, 0.48)
	return true


func relight(index: int) -> bool:
	if index < 0 or index >= towers.size():
		return false
	var slot := towers[index]
	if slot.kind != "brazier" or slot.lit or slot.health <= 0.0 or not spend(Vector2i(5, 0)):
		return false
	slot.lit = true
	refresh_links()
	combat.add_ring(slot.position, 37.0, FIELD_GOLD, 0.62)
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
	combat.light_lost(slot.position)
	combat.add_ring(slot.position, 31.0, Color("#ae91a4"), 0.7)
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


func refresh_links() -> void:
	links.clear()
	var bond: Dictionary = oath_book.bond_modifiers(combat.owned_oaths())
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


func reset_night() -> void:
	for slot in towers:
		slot.will_used = false
		slot.spent = false
		slot.burn = 0.0
		slot.cooldown = 0.0
	refresh_links()


func step_all(delta: float, repair_rate: float, enemies: Array[Enemy]) -> void:
	refresh_links()
	for slot: Slot in towers:
		step_slot(slot, delta, repair_rate, enemies)


func step_slot(slot: Slot, delta: float, repair_rate: float, enemies: Array[Enemy]) -> void:
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
	var repair_amount := 3.2 if slot.kind == "barricade" and slot.level == 3 else 0.0
	if repair_rate > 0.0 and slot.position.distance_squared_to(battle.player) <= 170.0 ** 2:
		repair_amount += repair_rate
	slot.health = minf(slot.max_health, slot.health + repair_amount * delta)
	if not battle.night:
		return
	match slot.kind:
		"ballista":
			if slot.disabled <= 0.0 and slot.cooldown == 0.0:
				fire_ballista(slot, enemies)
		"brazier":
			if slot.lit and slot.level >= 2:
				var radius: float = brazier_radius(slot.level) * battle.light_radius_scale()
				for foe in enemies:
					if not foe.removed and foe.position.distance_squared_to(slot.position) <= radius ** 2 and battle.light_manager.is_position_lit(foe.position, slot.high_ground):
						combat.damage_enemy(foe, 3.5 * delta, true, true)
		"oil":
			update_oil(slot, delta, enemies)


func update_oil(slot: Slot, delta: float, enemies: Array[Enemy]) -> void:
	if slot.burn > 0.0:
		slot.burn = maxf(0.0, slot.burn - delta)
		for foe in enemies:
			if not foe.removed and foe.kind != Enemy.MOTH and foe.position.distance_squared_to(slot.position) <= oil_radius(slot.level) ** 2:
				foe.burned = maxf(foe.burned, 1.2)
				if slot.level >= 2:
					foe.sundered = maxf(foe.sundered, 1.3)
				combat.damage_enemy(foe, (16.0 if slot.level == 1 else 19.0) * delta, true, true)
		if slot.burn == 0.0:
			combat.light_lost(slot.position)
	elif not slot.spent and ground_target_in(slot.position, oil_radius(slot.level), enemies):
		var player_pos: Vector2 = battle.player
		var lamp_radius := 152.0 if not battle.is_harsh_weather() or battle.biome != 0 else 106.4
		var near_lamp: bool = battle.lantern_on and battle.oil > 0.0 and player_pos.distance_to(slot.position) <= lamp_radius
		var direction: Vector2 = battle.aim
		if near_lamp and (player_pos.distance_squared_to(slot.position) <= 20.0 ** 2 or direction.dot(player_pos.direction_to(slot.position)) >= 0.72):
			ignite(slot, enemies)


func ground_target_in(point: Vector2, radius: float, enemies: Array[Enemy]) -> bool:
	for foe in enemies:
		if not foe.removed and foe.kind != Enemy.MOTH and foe.position.distance_squared_to(point) <= radius * radius:
			return true
	return false


func ignite_oil(index: int) -> bool:
	return ignite(towers[index], combat.enemies) if index >= 0 and index < towers.size() else false


func ignite(slot: Slot, enemies: Array[Enemy]) -> bool:
	if slot.kind != "oil" or slot.spent:
		return false
	slot.spent = true
	slot.burn = 10.0 if slot.level == 3 else 6.0
	var wrap: Dictionary = oath_book.on_oil_ignite(combat.owned_oaths())
	combat.add_ring(slot.position, oil_radius(slot.level), Color("#fa9c64"), 0.47)
	for foe in enemies:
		if foe.removed or foe.kind == Enemy.MOTH or foe.position.distance_squared_to(slot.position) > oil_radius(slot.level) ** 2:
			continue
		if not wrap.is_empty():
			foe.wrapped = maxf(foe.wrapped, wrap.seconds)
		if slot.level == 3:
			foe.knock += slot.position.direction_to(foe.position) * 39.0
			combat.damage_enemy(foe, 17.0, true, true)
	return true


func fire_ballista(slot: Slot, enemies: Array[Enemy], is_salvo := false) -> bool:
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
	var modifiers: Dictionary = oath_book.tower_modifiers(combat.owned_oaths(), is_lit, slot.sworn > 0.0, slot.idle, battle.fire_hp)
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
			combat.add_shot(muzzle, crystal.position - Vector2(0.0, 7.0), FIELD_GOLD, 0.19)
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
	combat.add_shot(muzzle, chosen.position - Vector2(0.0, 15.0), Color("#ffc582") if critical else Color("#ddc3a0"), 0.20)
	combat.damage_enemy(chosen, damage)
	if modifiers.power > 1.0:
		combat.add_ring(chosen.position, 65.0, Color("#ffbc6a"), 0.58)
		for foe in enemies:
			if foe != chosen and not foe.removed and foe.position.distance_squared_to(chosen.position) <= 65.0 ** 2:
				combat.damage_enemy(foe, damage)
	elif slot.level >= 2:
		pierce(slot, chosen, damage, radius, enemies)
	record_attack(slot, modifiers, critical, is_lit, is_salvo)
	return true


func pierce(slot: Slot, chosen: Enemy, damage: float, radius: float, enemies: Array[Enemy]) -> void:
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
		combat.damage_enemy(next, damage * 0.72)
		combat.add_shot(chosen.position, next.position, FIELD_GOLD, 0.22)


func record_attack(slot: Slot, modifiers: Dictionary, critical: bool, is_lit: bool, is_salvo: bool) -> void:
	slot.flash = 0.14
	slot.idle = 0.0
	if not is_salvo:
		slot.cooldown = 1.2 * modifiers.attack_interval / modifiers.attack_speed
	var effects_rule: Dictionary = oath_book.on_tower_attack(combat.owned_oaths(), is_lit, critical)
	battle.run.embers += effects_rule.embers


func salvo(enemies: Array[Enemy]) -> void:
	for slot in towers:
		if slot.kind == "ballista":
			fire_ballista(slot, enemies, true)


func hit_barricade(slot: Slot, foe: Enemy) -> void:
	if slot.level >= 2:
		combat.damage_enemy(foe, 10.0)
	if slot.will_time > 0.0 or foe.removed:
		return
	slot.health = maxf(0.0, slot.health - foe.power * (3.0 if foe.kind == Enemy.COLOSSUS else 1.0))
	combat.add_shot(foe.position, slot.position, Color("#be8a6f"), 0.12)
	if slot.health <= 0.0:
		var will: Dictionary = oath_book.on_barricade_break(combat.owned_oaths(), slot.will_used)
		if will.is_empty():
			slot.clear()
			refresh_links()
		else:
			slot.will_time = will.seconds
			slot.will_used = true
			combat.add_ring(slot.position, 48.0, FIELD_GOLD, 0.58)


func sync_art() -> void:
	for tower in towers:
		tower.clock = battle.clock
		tower.focus = tower.position.distance_squared_to(battle.player) <= 47.0 ** 2
		tower.queue_redraw()
