extends Node2D

const Terrain = preload("res://terrain.gd")
const FONT = preload("res://typeface.tres")

var game

func _draw() -> void:
	if not is_instance_valid(game):
		return
	var phase: int = game.phase
	var clock: float = game.clock
	if phase in [1, 2, 3]:
		for index in range(Terrain.STASHES.size()):
			if game.wood_available[index]:
				draw_wood(Terrain.STASHES[index], index, clock)
		if game.trap_left > 0.0:
			draw_trap(game.trap_point, clock)
		draw_action_indicator(clock)
	draw_particles()

func draw_wood(at: Vector2, index: int, time: float) -> void:
	var pulse := 0.67 + 0.33 * sin(time * 1.8 + index)
	var diamond := PackedVector2Array([at + Vector2(0, -25), at + Vector2(4, -20),
		at + Vector2(0, -15), at + Vector2(-4, -20), at + Vector2(0, -25)])
	draw_polyline(diamond, Color(1.0, 0.82, 0.51, pulse), 1.0, true)

func draw_trap(at: Vector2, clock: float) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 0.65))
	draw_circle(Vector2.ZERO, 24, Color("#a94d3044"), true, -1, true)
	draw_arc(Vector2.ZERO, 25, 0, TAU, 32, Color("#ed8853"), 1.2, true)
	for index in range(7):
		var angle := index * 2.399
		var at_ring := Vector2.from_angle(angle) * (13 + index % 3 * 3)
		draw_line(at_ring, at_ring + Vector2(0, -8.0 - sin(clock * 13 + index) * 4),
			Color("#ffb46f"), 1.7, true)
	draw_set_transform(Vector2.ZERO)

func draw_action_indicator(clock: float) -> void:
	var target: Dictionary = game.interaction()
	if target.is_empty():
		return
	var point: Vector2 = target["position"]
	var alpha := 0.70 + 0.22 * sin(clock * 4.8)
	draw_set_transform(point, 0.0, Vector2(1.0, 0.52))
	draw_arc(Vector2.ZERO, 17, 0.15, 2.95, 27, Color(1, 0.86, 0.55, alpha), 1.6, true)
	draw_set_transform(Vector2.ZERO)

func draw_particles() -> void:
	for event in game.particles:
		var origin: Vector2 = event["position"]
		var age: float = event["age"]
		var ink: Color = event["color"]
		for index in range(10):
			var offset := Vector2.from_angle(index * 2.399 + 0.6) * age * (13 + index % 4 * 14)
			var point := origin + offset + Vector2(0, -age * (10.0 + index % 5 * 5.0))
			draw_circle(point, 1.8 - age * 0.8, Color(ink, (1.0 - age) * 0.87), true, -1.0, true)
		var value: String = event["text"]
		if not value.is_empty():
			draw_string(FONT, origin + Vector2(-8, -17 - 35 * age), value,
				HORIZONTAL_ALIGNMENT_CENTER, -1.0, 15, Color(ink, 1.0 - age))
