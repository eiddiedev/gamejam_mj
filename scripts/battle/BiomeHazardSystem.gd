class_name BiomeHazardSystem
extends RefCounted

const Maps = preload("res://scripts/battle/BattleMaps.gd")
const Combat = preload("res://scripts/entities/Combat.gd")

var battle: Node2D
var weather_age := 0.0
var weather_left := 0.0
var crystal_pulse := 0.0
var crystal_power := 0.0
var bridge_closed := -1
var bridge_cooldown := 0.0


func setup(level: Node2D) -> void:
	battle = level
	reset_weather()
	crystal_pulse = 0.0
	crystal_power = 0.0
	bridge_closed = -1
	bridge_cooldown = 0.0


func reset_weather() -> void:
	weather_age = 0.0
	weather_left = 0.0


func pace_factor(at: Vector2) -> float:
	for shape in battle.mud:
		if Geometry2D.is_point_in_polygon(at, shape):
			return 0.75
	return 1.0


func enemy_path(lane: int) -> PackedVector2Array:
	if battle.biome == 2 and bridge_closed >= 0 and int(lane > 0) == bridge_closed:
		return battle.detours[lane]
	return battle.paths[lane]


func tick(delta: float) -> void:
	weather_left = maxf(0.0, weather_left - delta)
	crystal_pulse = maxf(0.0, crystal_pulse - delta)
	crystal_power = maxf(0.0, crystal_power - delta)
	bridge_cooldown = maxf(0.0, bridge_cooldown - delta)
	if not battle.night or battle.biome == 2:
		return
	weather_age += delta
	var period: float = [40.0, 45.0, 0.0, 30.0][battle.biome]
	if weather_age < period:
		return
	weather_age -= period
	match battle.biome:
		0:
			weather_left = 8.0
			battle.announce("苔沼迷雾升起 · 所有光照半径缩小 30%")
		1:
			weather_left = 7.0
			for index in battle.outer_slots:
				var outer: Vector2 = battle.slot_points[index]
				var shielded: bool = battle.combat.towers.any(func(tower): return tower.kind == "barricade" and tower.health > 0.0 and tower.position.distance_to(outer) <= 110.0)
				if not shielded:
					battle.combat.extinguish_index(index)
			battle.announce("沙暴抵达 · 无路障挡风的外侧火盆熄灭")
		3:
			crystal_pulse = 1.2
			crystal_power = 7.0
			weather_left = 7.0
			battle.announce("裂隙脉冲 · 晶簇附近的怪物得到移速与护甲强化")


func is_harsh_weather() -> bool:
	return (battle.biome == 0 and weather_left > 0.0) or battle.biome == 3


func light_radius_scale() -> float:
	return 0.70 if battle.biome == 0 and weather_left > 0.0 else 1.0


func crystal_buff_at(at: Vector2) -> bool:
	if crystal_power <= 0.0:
		return false
	for crystal in battle.crystals:
		if crystal["hp"] > 0.0 and at.distance_squared_to(crystal["position"]) <= 162.0 ** 2:
			return true
	return false


func damage_crystal(index: int, damage: float) -> void:
	var crystal: Dictionary = battle.crystals[index]
	if crystal["hp"] <= 0.0:
		return
	crystal["hp"] = maxf(0.0, crystal["hp"] - damage)
	if crystal["hp"] == 0.0:
		battle.run.bone += 5
		battle.announce("裂隙晶簇已摧毁")


func damage_crystals_at(origin: Vector2, facing: Vector2, reach: float, damage: float) -> void:
	for index in range(battle.crystals.size()):
		var delta: Vector2 = battle.crystals[index]["position"] - origin
		if delta.length() <= reach and (delta.length() < 20.0 or facing.dot(delta.normalized()) > 0.33):
			damage_crystal(index, damage)


func use_bridge() -> void:
	if battle.biome != 2 or bridge_cooldown > 0.0:
		return
	var lever: int = battle.closest(battle.levers, 68.0)
	if lever < 0:
		return
	var raised := 1 - bridge_closed if bridge_closed >= 0 else lever
	if battle.collision.occupies_bridge(raised, battle.player, battle.PLAYER_RADIUS, 2.0):
		battle.announce("先走下桥面，再拉动机关。")
		return
	for foe in battle.combat.enemies:
		if not foe.removed and foe.kind != Combat.Enemy.MOTH and battle.collision.occupies_bridge(raised, foe.position, foe.radius, 2.0):
			battle.announce("桥面上有敌人，等它离开后再拉动机关。")
			return
	bridge_closed = raised
	bridge_cooldown = 15.0
	var open_routes: Array[PackedVector2Array] = []
	for lane in range(battle.paths.size()):
		open_routes.append(enemy_path(lane))
	battle.collision.set_bridge(raised, open_routes)
	battle.combat.reroute()
	battle.announce("西桥升起，敌人转向东岸" if bridge_closed == 0 else "东桥升起，敌人转向西岸")


func weather_status() -> String:
	if not battle.night:
		return Maps.RULES[battle.biome]
	if battle.biome == 0 and weather_left > 0.0:
		return "苔雾  ·  光照范围 ×0.70"
	if battle.biome == 1 and weather_left > 0.0:
		return "沙暴  ·  外侧火盆需路障挡风"
	if battle.biome == 2:
		return "吊桥机关  ·  %s" % ("可切换" if bridge_cooldown <= 0 else "%d 秒后可切换" % ceili(bridge_cooldown))
	if battle.biome == 3:
		return "极北风雪  ·  篝火衰减 ×2"
	return ""
