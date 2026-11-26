class_name CombatEffects
extends Node2D

const Enemy = preload("res://scripts/entities/EnemyController.gd")
const PITCH := Color("#101d26")

var combat: Node2D
var effects: Array[Dictionary] = []
var spirits: Array[Dictionary] = []


func setup(owner_combat: Node2D) -> void:
	combat = owner_combat
	name = "Combat effects"
	z_index = 2


func add_ring(origin: Vector2, radius: float, tint: Color, duration: float) -> void:
	effects.append({"a": origin, "radius": radius, "tint": tint, "left": duration, "duration": duration})


func add_shot(from: Vector2, to: Vector2, tint: Color, duration: float) -> void:
	effects.append({"a": from, "b": to, "tint": tint, "left": duration, "duration": duration})


func spawn_spirits(point: Vector2, rule: Dictionary) -> void:
	if rule.is_empty():
		return
	var count: int = rule.count
	for i in range(count):
		var direction := Vector2.from_angle(TAU * i / float(count))
		var start := point + direction * 9.0
		spirits.append({"origin": point, "at": start, "tail": point, "direction": direction,
			"delay": i * 0.03, "left": 1.2, "radius": rule.radius, "damage": rule.damage})


func step(delta: float, enemies: Array[Enemy]) -> void:
	for index in range(spirits.size() - 1, -1, -1):
		var spirit: Dictionary = spirits[index]
		spirit.left -= delta
		if spirit.left <= 0.0:
			spirits.remove_at(index)
			continue
		var from: Vector2 = spirit.at
		var born_at: Vector2 = spirit.origin
		var nearest: Enemy
		var radius_sq: float = float(spirit.radius) ** 2
		var best: float = radius_sq
		spirit.delay -= delta
		if spirit.delay <= 0.0:
			for foe: Enemy in enemies:
				if foe.removed or born_at.distance_squared_to(foe.position) > radius_sq:
					continue
				var distance: float = from.distance_squared_to(foe.position)
				if distance < best:
					nearest = foe
					best = distance
		var direction: Vector2 = spirit.direction
		if nearest != null:
			direction = direction.lerp(from.direction_to(nearest.position), minf(1.0, delta * 15.0)).normalized()
			if best <= 18.0 ** 2:
				nearest.burned = maxf(nearest.burned, 1.1)
				combat.damage_enemy(nearest, spirit.damage, true, true)
				add_ring(nearest.position, 15.0, Color("#f2a174"), 0.23)
				spirits.remove_at(index)
				continue
		spirit.direction = direction
		spirit.tail = (spirit.tail as Vector2).lerp(from, minf(1.0, delta * 32.0))
		spirit.at = from + direction * (325.0 if nearest != null else 54.0) * delta
	for i in range(effects.size() - 1, -1, -1):
		effects[i].left -= delta
		if effects[i].left <= 0.0:
			effects.remove_at(i)


func _draw() -> void:
	for spirit in spirits:
		var tail: Vector2 = spirit.tail
		var tip: Vector2 = spirit.at
		var amber := Color(1.0, 0.59, 0.29, clampf(spirit.left * 2.0, 0.0, 0.95))
		draw_line(tail, tip, amber, 2.4, true)
		draw_circle(tip, 3.5, amber.lightened(0.24), true, -1.0, true)
	for effect in effects:
		var remain: float = clampf(effect.left / effect.duration, 0.0, 1.0)
		var tint := Color(effect.tint, remain * 0.89)
		var a: Vector2 = effect.a
		if effect.has("b"):
			var b: Vector2 = effect.b
			var rise := Vector2(0.0, -9.0)
			var end := a.lerp(b, minf(1.0, (1.0 - remain) * 2.8 + 0.15))
			draw_line(a + rise, end + rise, Color(PITCH, remain * 0.72), 5.3, true)
			draw_line(a + rise, end + rise, tint, 2.5, true)
			draw_circle(end + rise, 3.1, tint, true, -1.0, true)
		else:
			var radius: float = effect.radius * lerpf(1.0, 0.24, remain)
			draw_arc(a, radius, 0.0, TAU, 36, tint, 2.3, true)
