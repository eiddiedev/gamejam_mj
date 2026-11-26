extends Node2D

const INK := Color("#101b23")
const EDGE := Color("#608589")
const FIRE := Color("#ff9a48")
const STONE := Color("#607271")
const HIDE := Color("#724c39")

var kind := ""
var level := 0
var max_health := 0.0
var health := 0.0
var lit := false
var high_ground := false
var disabled := 0.0
var burn := 0.0
var spent := false
var will_time := 0.0
var will_used := false
var sworn := 0.0
var cooldown := 0.0
var idle := 0.0
var flash := 0.0
var look := Vector2.UP
var clock := 0.0
var focus := false

func install(type: String, rank: int, vitality: float) -> void:
	kind = type
	level = rank
	max_health = vitality
	health = vitality
	lit = type == "brazier"
	burn = 0.0
	spent = false
	disabled = 0.0
	cooldown = 0.0
	idle = 0.0
	will_time = 0.0
	queue_redraw()

func clear() -> void:
	kind = ""
	level = 0
	lit = false
	health = 0.0
	will_time = 0.0
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.58))
	draw_circle(Vector2.ZERO, 29.0, Color("#091b2173"), true, -1.0, true)
	draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 18, Color("#e7b779") if focus else Color("#8bafac9d"), 1.6, true)
	if high_ground:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 18, Color("#72949a75"), 1.1, true)
	draw_set_transform(Vector2.ZERO)
	match kind:
		"brazier":
			draw_brazier()
		"ballista":
			draw_ballista()
		"barricade":
			draw_barricade()
		"oil":
			draw_oil()
		_:
			draw_line(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), EDGE, 1.3, true)
			draw_line(Vector2(0.0, -3.0), Vector2(0.0, 3.0), EDGE, 1.3, true)
	if not kind.is_empty():
		draw_rank()
	if sworn > 0.0:
		draw_arc(Vector2(0.0, -7.0), 31.0, 0.2, 2.9, 16, Color("#edaf4dcc"), 1.3, true)
	if disabled > 0.0:
		for i in range(3):
			var haze := Vector2(sin(clock * 4.0 + i * 1.8) * 13.0, -17.0 - i * 6.0)
			draw_circle(haze, 9.0 + i * 3.0, Color("#1d183799"), true, -1.0, true)

func draw_rank() -> void:
	for i in range(level):
		var at := Vector2(-6.0 * (level - 1) + i * 12.0, 18.0)
		paint([at + Vector2(0.0, -3.5), at + Vector2(4.2, 0.0), at + Vector2(0.0, 3.0),
			at + Vector2(-4.2, 0.0)], Color("#cfa979"), 1.0)
	if health < max_health and health > 0.0 and kind != "oil":
		draw_line(Vector2(-14.0, 24.0), Vector2(14.0, 24.0), INK, 3.1, true)
		draw_line(Vector2(-14.0, 24.0), Vector2(-14.0 + 28.0 * health / max_health, 24.0),
			Color("#ba8b59"), 1.5, true)

func draw_brazier() -> void:
	paint([Vector2(-20.0, 8.0), Vector2(-13.0, -2.0), Vector2(-7.0, -31.0), Vector2(8.0, -31.0),
		Vector2(12.0, -2.0), Vector2(21.0, 7.0), Vector2(6.0, 13.0)], STONE.darkened(0.15))
	draw_line(Vector2(-3.0, -29.0), Vector2(-3.0, 8.0), Color("#91a4a1"), 2.0, true)
	paint([Vector2(-23.0, -34.0), Vector2(-14.0, -44.0), Vector2(14.0, -44.0),
		Vector2(22.0, -34.0), Vector2(14.0, -27.0), Vector2(-15.0, -27.0)], Color("#7d6863"))
	draw_arc(Vector2(0.0, -35.0), 17.0, PI * 0.08, PI * 0.90, 10, Color("#d2a273"), 2.0, true)
	if level >= 2:
		draw_line(Vector2(-16.0, -28.0), Vector2(-22.0, -17.0), Color("#b28657"), 2.0, true)
		draw_line(Vector2(16.0, -28.0), Vector2(22.0, -17.0), Color("#b28657"), 2.0, true)
	if level == 3:
		paint([Vector2(15.0, -37.0), Vector2(23.0, -51.0), Vector2(26.0, -66.0),
			Vector2(33.0, -55.0), Vector2(23.0, -43.0)], Color("#d6b185"))
	if not lit:
		draw_arc(Vector2(2.0, -42.0), 11.0, PI, TAU - 0.4, 12, Color("#6d8383c0"), 1.7, true)
		return
	var sway := sin(clock * 13.0) * 5.0 + sin(clock * 7.0) * 2.0
	paint([Vector2(-13.0, -35.0), Vector2(-14.0, -49.0), Vector2(-3.0, -45.0),
		Vector2(sway - 4.0, -69.0), Vector2(sway + 6.0, -57.0), Vector2(13.0, -50.0),
		Vector2(14.0, -40.0), Vector2(8.0, -34.0)], FIRE, 1.3)
	paint([Vector2(-7.0, -35.0), Vector2(-4.0, -48.0), Vector2(sway, -58.0),
		Vector2(8.0, -44.0), Vector2(6.0, -35.0)], Color("#ffdb98"), 0.0)

func draw_ballista() -> void:
	paint([Vector2(-24.0, 7.0), Vector2(-15.0, -7.0), Vector2(-12.0, -28.0),
		Vector2(11.0, -28.0), Vector2(16.0, -8.0), Vector2(24.0, 7.0), Vector2(3.0, 14.0)],
		STONE.darkened(0.23))
	var shoulder := Vector2(0.0, -23.0)
	var turn := (look * Vector2(1.0, 0.63)).normalized()
	var baseline := turn.orthogonal()
	var arms := 23.0 + level * 2.2
	var back := shoulder - turn * 13.0
	var front := shoulder + turn * (24.0 + level * 4.5)
	draw_line(back, front, INK, 8.0, true)
	draw_line(back, front, Color("#9a734f"), 4.5, true)
	var end_left := shoulder + baseline * arms
	var end_right := shoulder - baseline * arms
	draw_polyline([end_left - turn * 7.0, end_left, shoulder + turn * 8.0, end_right, end_right - turn * 7.0], INK, 7.2, true)
	draw_polyline([end_left - turn * 7.0, end_left, shoulder + turn * 8.0, end_right, end_right - turn * 7.0],
		Color("#d3baa0") if level == 3 else Color("#a9a08b"), 3.5, true)
	draw_polyline([end_left - turn * 7.0, back, end_right - turn * 7.0], Color("#cab49d"), 1.2, true)
	if level >= 2:
		draw_line(back + baseline * 5.0, front + baseline * 5.0, Color("#766a54"), 2.0, true)
	draw_line(back.lerp(front, 0.20), front + turn * 8.0, Color("#efc897"), 2.0, true)
	if flash > 0.0:
		draw_circle(front, 9.0 + flash * 20.0, Color(1.0, 0.64, 0.31, minf(flash * 7.0, 0.92)), true, -1.0, true)

func draw_barricade() -> void:
	paint([Vector2(-29.0, 9.0), Vector2(-26.0, -4.0), Vector2(-13.0, -13.0),
		Vector2(12.0, -13.0), Vector2(27.0, -2.0), Vector2(29.0, 10.0),
		Vector2(7.0, 15.0), Vector2(-9.0, 13.0)], STONE.darkened(0.22))
	for i in range(5):
		var x := -21.0 + 10.3 * i
		var top := -23.0 - float((i * 9) % 13) - (4.0 if level >= 2 else 0.0)
		paint([Vector2(x - 5.0, 5.0), Vector2(x - 5.0, top + 7.0), Vector2(x + 1.0, top),
			Vector2(x + 7.0, top + 9.0), Vector2(x + 6.0, 4.0)], FIRE.lightened(0.22) if will_time > 0.0 else HIDE.lightened(i * 0.06))
		if level >= 2:
			draw_line(Vector2(x, top + 10.0), Vector2(x - 8.0, top + 5.0), Color("#c0abad"), 2.0, true)
	draw_line(Vector2(-22.0, -9.0), Vector2(22.0, -8.0), Color("#a08668"), 2.8, true)
	if level == 3 or will_time > 0.0:
		draw_arc(Vector2(0.0, -12.0), 29.0, 0.25, PI - 0.2, 16, Color("#edbb64"), 2.0, true)

func draw_oil() -> void:
	paint([Vector2(-27.0, -4.0), Vector2(-12.0, -14.0), Vector2(15.0, -13.0), Vector2(28.0, -1.0),
		Vector2(19.0, 11.0), Vector2(-16.0, 12.0)], Color("#504344"))
	paint([Vector2(-18.0, -2.0), Vector2(-10.0, -7.0), Vector2(13.0, -7.0), Vector2(19.0, -2.0),
		Vector2(11.0, 7.0), Vector2(-14.0, 6.0)], Color("#272331" if spent else "#7c4350"), 1.1)
	if level == 3:
		draw_line(Vector2(-16.0, 3.0), Vector2(14.0, -5.0), Color("#cb6b73"), 1.5, true)
	if burn > 0.0:
		for i in range(4):
			var x := -18.0 + i * 12.0
			var peak := -16.0 - 8.0 * (0.5 + 0.5 * sin(clock * 12.0 + i * 2.0))
			paint([Vector2(x - 6.0, 4.0), Vector2(x - 7.0, -6.0), Vector2(x + 1.0, peak),
				Vector2(x + 7.0, -5.0), Vector2(x + 6.0, 5.0)], FIRE.lerp(Color("#d44c42"), i * 0.17), 1.1)

func paint(points: PackedVector2Array, fill: Color, width := 2.3) -> void:
	draw_colored_polygon(points, fill)
	if width > 0.0:
		points.append(points[0])
		draw_polyline(points, INK, width, true)
