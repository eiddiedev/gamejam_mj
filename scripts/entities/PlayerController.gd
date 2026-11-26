extends Node2D

const INK := Color("#101c23")
const CLOTH := Color("#38626a")
const COPPER := Color("#a66b48")
const GOLD := Color("#ffc66c")

var aim := Vector2.RIGHT
var moving := false
var lantern_on := true
var swing := 0.0
var dash := 0.0
var clock := 0.0
var charge := 0.0
var injury := 0.0
var strike_direction := Vector2.RIGHT
var strike_duration := 0.23
var draw_body := false

func _ready() -> void:
	var silhouette := Polygon2D.new()
	silhouette.name = "Paper silhouette shadow"
	silhouette.color = Color("#030a0c94")
	silhouette.z_index = -1
	silhouette.polygon = PackedVector2Array([Vector2(-19.0, 3.0), Vector2(-13.0, -2.0),
		Vector2(8.0, -3.0), Vector2(19.0, 2.0), Vector2(13.0, 9.0), Vector2(-10.0, 11.0)])
	add_child(silhouette)
	make_scarf()

func make_scarf() -> void:
	var stitching := Line2D.new()
	stitching.name = "Scarf hem"
	stitching.width = 1.4
	stitching.default_color = COPPER
	stitching.antialiased = true
	stitching.points = PackedVector2Array([Vector2(-9.0, -23.0), Vector2(-12.0, -17.0), Vector2(-17.0, -18.0)])
	add_child(stitching)

func _draw() -> void:
	if not draw_body:
		for drawing in get_children():
			drawing.hide()
		return
	var facing := -1.0 if aim.x < -0.06 else 1.0
	var stride := sin(clock * 17.0) * 4.0 if moving else 0.0
	draw_set_transform(Vector2(0.0, -absf(stride) * 0.38), 0.0, Vector2(facing, 1.0))
	draw_line(Vector2(-5.0, -12.0), Vector2(-8.0 - stride, 3.0), INK, 6.0, true)
	draw_line(Vector2(4.0, -12.0), Vector2(8.0 + stride, 3.0), INK, 6.0, true)
	shape([Vector2(-7.0, -28.0), Vector2(8.0, -29.0), Vector2(14.0, -10.0), Vector2(9.0, -4.0),
		Vector2(-12.0, -2.0), Vector2(-18.0 - absf(stride), -9.0)], CLOTH)
	draw_line(Vector2(-12.0, -6.0), Vector2(-8.0, -22.0), Color("#5f8a84"), 1.4, true)
	shape([Vector2(-11.0, -28.0), Vector2(-4.0, -35.0), Vector2(8.0, -35.0),
		Vector2(10.0, -29.0), Vector2(4.0, -24.0), Vector2(-9.0, -24.0)], COPPER)
	shape([Vector2(-8.0, -31.0), Vector2(-8.0, -41.0), Vector2(-1.0, -48.0), Vector2(8.0, -43.0),
		Vector2(10.0, -35.0), Vector2(3.0, -30.0)], Color("#687779"))
	draw_line(Vector2(-2.0, -41.0), Vector2(8.0, -39.0), Color("#d2c4a6"), 1.7, true)
	draw_line(Vector2(-7.0, -36.0), Vector2(7.0, -35.0), INK, 2.0, true)
	draw_line(Vector2(6.0, -23.0), Vector2(19.0, -16.0), INK, 5.4, true)
	draw_line(Vector2(6.0, -23.0), Vector2(19.0, -16.0), CLOTH.lightened(0.40), 2.8, true)
	var lamp := Vector2(22.0, -12.0)
	shape([lamp + Vector2(-5.0, -3.0), lamp + Vector2(0.0, -7.0), lamp + Vector2(6.0, -4.0),
		lamp + Vector2(6.0, 4.0), lamp + Vector2(-5.0, 5.0)], GOLD if lantern_on else Color("#62544a"))
	if lantern_on:
		draw_circle(lamp, 14.0, Color("#f2985343"), true, -1.0, true)
		draw_circle(lamp, 3.0, Color("#ffe0a8"), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	draw_strike()

func draw_strike() -> void:
	if swing <= 0.0:
		return
	var progress := 1.0 - swing / strike_duration
	var angle := strike_direction.angle() - 1.2 + progress * 1.15
	var tint := Color(1.0, 0.79, 0.51, swing * 3.3)
	var reach := 38.0 if strike_duration > 0.24 else 28.0
	draw_arc(Vector2(0.0, -21.0), 43.0 + progress * reach, angle, angle + 1.30, 22, tint, 2.8, true)
	draw_arc(Vector2(0.0, -21.0), 40.0 + progress * (reach - 5.0), angle + 0.20, angle + 1.10, 18, tint, 0.8, true)

func shape(points: PackedVector2Array, tint: Color) -> void:
	draw_colored_polygon(points, tint)
	points.append(points[0])
	draw_polyline(points, INK, 2.3, true)
