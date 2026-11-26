extends Control

enum Type { COVER, PAPER, TAB, WATCH, FUEL, WOOD, CARD }

const EDGE := Color("#392e29")
const LEATHER := Color("#25302d")
const SEAM := Color("#928069")
const BRASS := Color("#b19358")
const PALE := Color("#f5e4b6")
const SOOT := Color("#423b31")

var kind: Type
var progress := 0.0
var symbol := 0
var highlighted := false

func _draw() -> void:
	match kind:
		Type.COVER:
			cover()
		Type.PAPER:
			paper()
		Type.TAB:
			tab()
		Type.WATCH:
			watch()
		Type.FUEL:
			fuel()
		Type.WOOD:
			wood()
		Type.CARD:
			card()

func worn_border(inset: float, irregularity: float) -> PackedVector2Array:
	var w := size.x - inset
	var h := size.y - inset
	var k := irregularity
	return PackedVector2Array([
		Vector2(inset + k, inset + 1), Vector2(w * 0.43, inset),
		Vector2(w - k * 0.62, inset + 2.0), Vector2(w - 1, inset + k * 0.8),
		Vector2(w - 3, h * 0.53), Vector2(w, h - k), Vector2(w - k, h - 1),
		Vector2(w * 0.59, h - 4), Vector2(w * 0.29, h - 2), Vector2(inset + k, h),
		Vector2(inset + 1, h - k * 0.6), Vector2(inset + 3, h * 0.61),
		Vector2(inset, inset + k),
	])

func silhouette(page: PackedVector2Array, background: Color, line: Color) -> void:
	draw_colored_polygon(page, background)
	var border := page.duplicate()
	border.append(page[0])
	draw_polyline(border, line, 1.25, true)

func cover() -> void:
	var outside := worn_border(1.5, 13.0)
	var shadow := outside.duplicate()
	for index in range(shadow.size()):
		shadow[index] += Vector2(6, 9)
	draw_colored_polygon(shadow, Color("#080d0bc4"))
	silhouette(outside, Color("#352e26"), Color("#100f0d"))
	silhouette(worn_border(4.5, 11.0), Color("#81735b"), EDGE)
	silhouette(worn_border(8.0, 10.0), LEATHER, Color("#0d1413"))
	speckles(Rect2(16, 14, size.x - 36, size.y - 25), 250, Color("#d8d1a817"), 81)
	var spine := PackedVector2Array([Vector2(12, 12), Vector2(31, 9), Vector2(26, size.y - 10),
		Vector2(12, size.y - 15), Vector2(8, size.y * 0.63)])
	draw_colored_polygon(spine, Color("#1c2421"))
	draw_polyline(PackedVector2Array([Vector2(28, 12), Vector2(26, size.y * 0.44), Vector2(27, size.y - 14)]),
		Color("#767160"), 1, true)
	for y in [33.0, 65.0, size.y - 65.0, size.y - 33.0]:
		draw_circle(Vector2(18, y), 3.0, Color("#141619"), true, -1, true)
		draw_arc(Vector2(17, y + 1.8), 4.4, 0.1, PI * 1.41, 13, SEAM, 1.3, true)
	for corner in [Vector2(size.x - 17.0, 18.0), Vector2(size.x - 18, size.y - 17)]:
		draw_circle(corner, 3, Color("#ceb48d"), true, -1, true)
		draw_circle(corner + Vector2(1.0, 1.0), 2.0, EDGE, true, -1, true)

func paper() -> void:
	var shape := worn_border(3.0, 17.0)
	var offset := shape.duplicate()
	for index in range(offset.size()):
		offset[index] += Vector2(5, 7)
	silhouette(offset, Color("#897251"), Color("#29201a"))
	silhouette(shape, Color("#cfbb8f"), Color("#564935"))
	silhouette(worn_border(11.0, 9.0), Color("#d5c49c"), Color("#9b8964"))
	speckles(Rect2(17, 15, size.x - 34, size.y - 29), 310, Color("#654d2e29"), 39)
	for x in [28.0, size.x - 27.0]:
		draw_arc(Vector2(x, 19), 6.0, 0.2, PI * 1.8, 16, Color("#97815d"), 1.0, true)

func tab() -> void:
	var p := PackedVector2Array([Vector2(5, 3), Vector2(size.x - 6, 3), Vector2(size.x - 2, 9),
		Vector2(size.x - 3, size.y - 7), Vector2(size.x - 10, size.y - 3),
		Vector2(11, size.y - 3), Vector2(3, size.y - 9), Vector2(3, 8)])
	silhouette(p, Color("#444036") if highlighted else Color("#292f2b"), Color("#b09773"))
	for point in [Vector2(11, size.y * 0.50), Vector2(size.x - 11, size.y * 0.50)]:
		draw_circle(point, 1.5, Color("#a99269"), true, -1, true)

func watch() -> void:
	var center := size * 0.5
	var radius := size.x * 0.44
	draw_circle(center + Vector2(0, 3), radius + 6, Color("#111514"), true, -1, true)
	draw_circle(center, radius + 4, Color("#746244"), true, -1, true)
	draw_circle(center, radius, Color("#36382e"), true, -1, true)
	draw_circle(center, radius - 7, Color("#262e29"), true, -1, true)
	draw_arc(center, radius + 3.5, -PI * 0.88, PI * 0.89, 52, Color("#c5a475"), 1.1, true)
	draw_arc(center, radius - 6, 0, TAU, 56, Color("#544c3b"), 1, true)
	var first := PI * 0.72
	var arc := TAU * 0.78
	for index in range(25):
		var unit := Vector2.from_angle(first + arc * float(index) / 24.0)
		var length := 6.0 if index % 6 == 0 else 3.0
		draw_line(center + unit * (radius - 1.8), center + unit * (radius - 1.8 - length),
			Color("#ccb589") if index % 6 == 0 else Color("#86765a"), 1.05, true)
	if progress > 0.0:
		var tip := first + arc * progress
		var tint := Color("#f3be78") if progress > 0.17 else Color("#ed7765")
		draw_arc(center, radius - 10, first, tip, 52, tint.darkened(0.24), 3.0, true)
		draw_circle(center + Vector2.from_angle(tip) * (radius - 10), 2.6, tint, true, -1, true)
	var mark := center + Vector2(0, -20)
	if symbol == 1:
		draw_arc(mark, 6, PI, TAU, 18, BRASS, 1.3, true)
		draw_line(mark + Vector2(-9, 1), mark + Vector2(9, 1), BRASS, 1.1, true)
	else:
		draw_circle(mark, 6, BRASS, true, -1, true)
		draw_circle(mark + Vector2(3, -2), 5, Color("#262e29"), true, -1, true)

func fuel() -> void:
	var count := 9
	var spacing := (size.x - 5.0) / count
	for index in range(count):
		var x := index * spacing
		var fill_amount := clampf(progress * count - index, 0.0, 1.0)
		var outline := PackedVector2Array([Vector2(x + 4, 2), Vector2(x + spacing - 0.5, 4),
			Vector2(x + spacing - 3, 19), Vector2(x + 2, 17)])
		silhouette(outline, Color("#171f1c"), Color("#766851"))
		if fill_amount > 0.0:
			var tint := Color("#da9b59") if progress > 0.27 else Color("#ca6857")
			draw_colored_polygon(outline, tint.darkened((1.0 - fill_amount) * 0.63))
			draw_line(Vector2(x + 6, 5), Vector2(x + spacing - 4, 6), tint.lightened(0.35), 1.15, true)
			draw_line(Vector2(x + 7, 14), Vector2(x + 11, 10), Color("#55372e91"), 0.9, true)

func wood() -> void:
	var a := Vector2(2, 17)
	var b := Vector2(20, 6)
	draw_line(a, b, SOOT, 6.6, true)
	draw_line(a, b, Color("#b28a5e"), 4.7, true)
	draw_circle(b, 2.4, Color("#d8bc88"), true, -1, true)
	draw_line(a + Vector2(3, 5), b + Vector2(6, 2), Color("#986b49"), 4.2, true)
	draw_circle(b + Vector2(6, 2), 2.2, Color("#c8ac75"), true, -1, true)

func card() -> void:
	var template := worn_border(3.0, 12.0)
	var behind := template.duplicate()
	for index in range(behind.size()):
		behind[index] += Vector2(3, 5)
	draw_colored_polygon(behind, Color("#372c21c4"))
	var front := Color("#dbc79c") if highlighted else Color("#cbba95")
	silhouette(template, front, Color("#745839"))
	silhouette(worn_border(10.0, 7.0), front.lightened(0.055), Color("#886c47"))
	speckles(Rect2(17, 14, size.x - 33, size.y - 24), 160, Color("#503b2d25"), 17 + symbol)
	var center := Vector2(size.x * 0.5, 82.0)
	draw_circle(center, 56, Color("#9d835c40"), true, -1, true)
	draw_arc(center, 57, 0, TAU, 59, Color("#74583995"), 1.0, true)
	for index in range(18):
		var unit := Vector2.from_angle(float(index) * TAU / 18.0)
		draw_line(center + unit * 56, center + unit * (60.0 + index % 4), Color("#806345c0"), 0.9, true)
	match symbol:
		0:
			mirror(center)
		1:
			lantern(center)
		2:
			oil(center)

func mirror(center: Vector2) -> void:
	draw_set_transform(center + Vector2(-2, -4), -0.31)
	draw_line(Vector2(0, 20), Vector2(0, 49), SOOT, 13, true)
	draw_line(Vector2(0, 20), Vector2(0, 46), Color("#ad7b4b"), 8.5, true)
	draw_circle(Vector2.ZERO, 34, SOOT, true, -1, true)
	draw_circle(Vector2.ZERO, 31, Color("#ac8555"), true, -1, true)
	draw_circle(Vector2.ZERO, 26, Color("#616e6c"), true, -1, true)
	draw_arc(Vector2.ZERO, 23, -2.95, -0.37, 34, Color("#bfcec5"), 2.0, true)
	draw_line(Vector2(-17, 12), Vector2(12, -16), Color("#d3cdab"), 2.3, true)
	draw_line(Vector2(-5, 18), Vector2(16, -4), Color("#a9baae"), 1.2, true)
	for index in range(7):
		var angle := 0.49 + index * 0.23
		var surface := Vector2.from_angle(angle)
		draw_line(surface * 27.0, surface.rotated(0.13) * 30.0, Color("#574532"), 0.92, true)
	draw_line(Vector2(-2, 34), Vector2(3, 43), Color("#5e4932"), 1.2, true)
	draw_set_transform(Vector2.ZERO)

func lantern(center: Vector2) -> void:
	draw_set_transform(center)
	draw_arc(Vector2(0, -34), 12, PI, TAU, 26, SOOT, 4, true)
	glyph_shape([Vector2(-24,-20),Vector2(-13,-36),Vector2(13,-36),Vector2(24,-20)], Color("#524b39"))
	glyph_shape([Vector2(-21,-18),Vector2(22,-18),Vector2(26,30),Vector2(-26,30)], Color("#c18c52"))
	glyph_shape([Vector2(-17,-13),Vector2(17,-13),Vector2(19,24),Vector2(-19,24)], Color("#e7b36e"))
	glyph_shape([Vector2(-11,17),Vector2(-9,7),Vector2(-1,-13),Vector2(1,0),Vector2(9,-3),
		Vector2(7,6),Vector2(12,10),Vector2(8,17),Vector2(2,21),Vector2(-5,20)], Color("#ab5234"))
	draw_arc(Vector2(2, 11), 5, -2.7, 1.5, 17, Color("#f5cf85"), 1.4, true)
	for index in range(6):
		var x := -12.0 + index * 4.5
		draw_line(Vector2(x, -24), Vector2(x + 1.1, -30.0 - (index % 2) * 1.4), Color("#9c8255"), 0.85, true)
	draw_line(Vector2(-19,-18), Vector2(19,28), SOOT, 2.8, true)
	draw_line(Vector2(19,-18), Vector2(-19,28), SOOT, 2.8, true)
	draw_line(Vector2(-25,31), Vector2(25,31), SOOT, 5, true)
	draw_set_transform(Vector2.ZERO)

func oil(center: Vector2) -> void:
	draw_set_transform(center + Vector2(-6, -3), -0.30)
	glyph_shape([Vector2(-10,-32),Vector2(13,-32),Vector2(14,-18),Vector2(22,-7),
		Vector2(32,22),Vector2(23,35),Vector2(-19,34),Vector2(-28,23),Vector2(-22,1),
		Vector2(-13,-15)], Color("#a96345"))
	glyph_shape([Vector2(-14,-36),Vector2(15,-36),Vector2(17,-27),Vector2(-14,-26)], Color("#625339"))
	draw_arc(Vector2(4, 2), 22, 0.27, 2.68, 27, Color("#713f37"), 2, true)
	draw_line(Vector2(-13, -4), Vector2(-5, 15), Color("#d39966"), 2.3, true)
	draw_line(Vector2(-8, -6), Vector2(0, 12), Color("#d39966"), 1, true)
	draw_set_transform(Vector2.ZERO)
	var spill := center + Vector2(29, 38)
	glyph_shape([spill + Vector2(-18, 2), spill + Vector2(-10, -4), spill + Vector2(9, -5),
		spill + Vector2(16, -2), spill + Vector2(19, 4), spill + Vector2(6, 8),
		spill + Vector2(-16, 7)], Color("#6c4c39"))
	draw_line(spill + Vector2(-1, -1), spill + Vector2(12, 2), Color("#c08c61"), 0.92, true)

func glyph_shape(points: Array[Vector2], fill: Color) -> void:
	silhouette(PackedVector2Array(points), fill, SOOT)

func speckles(bounds: Rect2, total: int, color: Color, seed_value: int) -> void:
	var seeded := RandomNumberGenerator.new()
	seeded.seed = seed_value
	for index in range(total):
		var point := bounds.position + Vector2(seeded.randf() * bounds.size.x, seeded.randf() * bounds.size.y)
		var trace := Vector2(seeded.randf_range(0.3, 1.8), seeded.randf_range(-0.5, 0.8))
		draw_line(point, point + trace, color, 1.0, true)
