extends Node2D

const INK := Color("#192023")
const FIRE := Color("#f98b40")

var ratio := 1.0
var clock := 0.0

func _draw() -> void:
	if ratio <= 0.0:
		return
	for tier in range(3):
		var rise := 26.0 + ratio * 39.0 - tier * 8.0
		var sway := sin(clock * 12.4 + tier * 1.7) * (8.0 - tier * 2.0)
		var width := 19.0 - tier * 4.0
		var center := tier * 2.0 - 2.0
		var path := PackedVector2Array([Vector2(-width, -2.0), Vector2(-width - 1.0, -rise * 0.36),
			Vector2(-width * 0.30, -rise * 0.59), Vector2(sway - 4.0 + center, -rise),
			Vector2(sway * 0.42 + width * 0.50 + center, -rise * 0.70),
			Vector2(width, -rise * 0.38), Vector2(width - 1.0, -rise * 0.14),
			Vector2(width * 0.50, 1.0)])
		draw_colored_polygon(path, FIRE.lerp(Color("#fff0a2"), tier * 0.38))
		if tier == 0:
			path.append(path[0])
			draw_polyline(path, INK, 1.6, true)
	for i in range(6):
		var time := fposmod(clock * 1.3 + i * 0.24, 1.0)
		var angle := i * 1.7 + clock * 0.9
		var at := Vector2(sin(angle) * (7.0 + 20.0 * time), -25.0 - 50.0 * time * ratio)
		draw_circle(at, (1.8 - time) * sqrt(ratio), Color(1.0, 0.67, 0.30, 0.92 - time * 0.88), true, -1.0, true)
