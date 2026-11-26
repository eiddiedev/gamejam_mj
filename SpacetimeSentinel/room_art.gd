extends Node2D

const FRAME := Vector2(1376, 768)
const TEAL := Color("#6bb6b3")
const AMBER := Color("#e4a764")
const SCREEN := Rect2(898, 387, 170, 111)

func _ready() -> void:
	var signal_lamp := SignalLamp.new()
	add_child(signal_lamp)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, FRAME), Color("#080f14"))
	# Hall faces converge on the personnel door.
	face([Vector2(0, 0), Vector2(1376, 0), Vector2(821, 236), Vector2(553, 236)], "#152025")
	face([Vector2(553, 236), Vector2(821, 236), Vector2(821, 432), Vector2(553, 432)], "#213336")
	face([Vector2(0, 768), Vector2(553, 432), Vector2(821, 432), Vector2(1376, 768)], "#20282b")
	face([Vector2(0, 0), Vector2(553, 236), Vector2(553, 432), Vector2(0, 768)], "#131e22")
	face([Vector2(821, 236), Vector2(1376, 0), Vector2(1376, 768), Vector2(821, 432)], "#253135")
	surface_grid()
	doorway()
	for i in range(5):
		var distance := i / 4.0
		var scale_factor := lerpf(0.32, 1.16, distance * distance)
		var base := Vector2(lerpf(806, 1168, distance ** 1.45), lerpf(442, 673, distance ** 1.20))
		rack(base, scale_factor, i)
	rack(Vector2(448, 504), 0.63, 12, true)
	rack(Vector2(224, 643), 1.10, 14, true)
	rack(Vector2(3, 771), 1.56, 19, true)
	ceiling_conduits()
	draw_rect(Rect2(0, 0, 555, 768), Color("#060d152f"))
	console()
	for i in range(2300):
		var point := Vector2(fposmod(i * 109.617, 1376.0), fposmod(i * 71.378, 768.0))
		draw_rect(Rect2(point, Vector2(1.15, 0.78)), Color(0.74, 0.81, 0.77, 0.063 if i % 6 == 0 else 0.032))

func doorway() -> void:
	draw_rect(Rect2(637, 253, 125, 190), Color("#293c3e"))
	draw_rect(Rect2(646, 265, 106, 176), Color("#0e1a21"))
	draw_rect(Rect2(657, 275, 85, 165), Color("#334849"))
	draw_rect(Rect2(661, 278, 77, 162), Color("#25373a"))
	draw_rect(Rect2(674, 288, 50, 76), Color("#121f26"))
	draw_rect(Rect2(678, 292, 42, 67), Color("#577270"))
	draw_rect(Rect2(682, 296, 34, 59), Color("#304344"))
	line([Vector2(682, 353), Vector2(711, 297)], "#86adaa25", 2)
	line([Vector2(662, 279), Vector2(662, 436), Vector2(736, 436)], "#65817c", 1.3)
	draw_rect(Rect2(716, 379, 13, 4), AMBER.darkened(0.46))
	draw_rect(Rect2(670, 245, 55, 12), Color("#284d46"))
	draw_rect(Rect2(674, 248, 47, 4), Color("#75aa90"))
	face([Vector2(654, 437), Vector2(741, 437), Vector2(810, 529), Vector2(620, 529)], "#799d9220")

func surface_grid() -> void:
	for x in [54.0, 220.0, 480.0, 693.0, 996.0, 1303.0]:
		line([Vector2(687, 441), Vector2(x, 768)], "#47534e62", 1.5)
	for y in [454.0, 471.0, 499.0, 546.0, 614.0, 709.0]:
		line([Vector2(0, y), Vector2(1376, y)], "#60706a2c", 1.2)
	for x in [115.0, 305.0, 515.0, 972.0, 1250.0]:
		line([Vector2(x, -10), Vector2(690, 237)], "#55696661", 1.3)
	for i in range(4):
		var start := Vector2(741, 57 + i * 47.0)
		var width := 111.0 - i * 22.0
		rect_glow(Rect2(start - Vector2(width * 0.5, 0), Vector2(width, 4.0)), TEAL, 17 - i * 3)

func rack(base: Vector2, scale_factor: float, tag: int, left_side := false) -> void:
	var direction := -1.0 if left_side else 1.0
	draw_set_transform(base, 0.0, Vector2(direction, 1.0) * scale_factor)
	face([Vector2(0, -430), Vector2(56, -375), Vector2(56, 9), Vector2(0, -17)], "#334245")
	face([Vector2(56, -375), Vector2(198, -394), Vector2(198, -19), Vector2(56, 9)], "#2b353b")
	face([Vector2(0, -430), Vector2(134, -449), Vector2(198, -394), Vector2(56, -375)], "#3f4f4f")
	face([Vector2(65, -354), Vector2(189, -372), Vector2(189, -47), Vector2(65, -22)], "#121c21")
	line([Vector2(56, 0), Vector2(56, -374), Vector2(196, -393)], "#81938a70", 1.8)
	line([Vector2(66, -350), Vector2(66, -30), Vector2(189, -55)], "#62757460", 1.4)
	for row in range(10):
		var y := -351.0 + row * 32.0
		face([Vector2(72, y), Vector2(182, y - 16), Vector2(182, y + 7), Vector2(72, y + 24)], "#2d3a3d" if row % 4 == 0 else "#1b292d")
		line([Vector2(76, y + 17), Vector2(178, y + 2)], "#66777250", 1.0)
		for vent in range(7):
			var at := Vector2(84.0 + vent * 7.0, y + 4 - vent * 0.95)
			draw_line(at, at + Vector2(0, 9), Color("#111b20"), 2.1)
		var light := AMBER if (tag + row) % 7 == 0 else TEAL
		var level := 0.89 if (tag * 3 + row) % 4 == 0 else 0.46
		draw_rect(Rect2(157, y - 4, 4, 3), light.darkened(1.0 - level))
		draw_rect(Rect2(164, y - 5, 3, 2), light.darkened(0.68))
	for y in [-360.0, -82.0, -59.0]:
		line([Vector2(14, y - 26), Vector2(43, y)], "#899e9360", 1.6)
	draw_set_transform(Vector2.ZERO)

func ceiling_conduits() -> void:
	for index in range(3):
		var offset := index * 6.0
		line([Vector2(1016 + offset, -6), Vector2(1014 + offset, 89), Vector2(995 + offset, 137),
			Vector2(964 + offset, 156), Vector2(885 + offset, 152), Vector2(823 + offset, 174),
			Vector2(800 + offset, 226)], "#080e16", 2.5)
	line([Vector2(1138, 0), Vector2(1138, 65), Vector2(1110, 111), Vector2(1047, 133),
		Vector2(1016, 181), Vector2(1014, 248)], "#b7845552", 1.8)

func console() -> void:
	# Near edge of the desk and instrument chassis.
	face([Vector2(688, 581), Vector2(1184, 523), Vector2(1356, 648), Vector2(837, 730)], "#49524d")
	face([Vector2(837, 730), Vector2(1356, 648), Vector2(1356, 680), Vector2(837, 761)], "#202a2b")
	line([Vector2(689, 580), Vector2(837, 729), Vector2(1352, 647)], "#adb7997a", 2.2)
	line([Vector2(688, 582), Vector2(688, 608), Vector2(836, 760)], "#203132", 8.0)
	face([Vector2(843, 536), Vector2(1098, 526), Vector2(1168, 589), Vector2(955, 619)], "#131c20")
	face([Vector2(866, 383), Vector2(914, 338), Vector2(1091, 327), Vector2(1135, 364),
		Vector2(1129, 512), Vector2(1092, 553), Vector2(863, 555)], "#344046")
	face([Vector2(914, 338), Vector2(1091, 327), Vector2(1135, 364), Vector2(1083, 366), Vector2(870, 382)], "#657369")
	face([Vector2(1085, 368), Vector2(1135, 364), Vector2(1129, 514), Vector2(1092, 553)], "#2b383b")
	face([Vector2(870, 381), Vector2(1085, 369), Vector2(1092, 553), Vector2(862, 555)], "#526159")
	line([Vector2(862, 551), Vector2(871, 380), Vector2(1085, 369)], "#a3aa92", 2)
	draw_rect(Rect2(887, 381, 190, 128), Color("#101b20"))
	draw_rect(Rect2(891, 383, 182, 120), Color("#20343a"))
	draw_rect(SCREEN, Color("#337171"))
	for i in range(16):
		var y := SCREEN.position.y + i * 6.0
		var tint := Color("#a4d8c55e").lerp(Color("#1a3c4700"), i / 18.0)
		draw_rect(Rect2(SCREEN.position.x, y, SCREEN.size.x, 4), tint)
	face([Vector2(900, 456), Vector2(919, 442), Vector2(934, 443), Vector2(958, 425),
		Vector2(982, 431), Vector2(1003, 416), Vector2(1034, 422), Vector2(1066, 412),
		Vector2(1066, 496), Vector2(900, 496)], "#28505a")
	line([Vector2(907, 472), Vector2(932, 472), Vector2(940, 451), Vector2(947, 478),
		Vector2(956, 460), Vector2(969, 472), Vector2(992, 472), Vector2(1001, 436),
		Vector2(1010, 481), Vector2(1020, 469), Vector2(1058, 469)], "#bbebc2", 1.4)
	draw_rect(Rect2(900, 514, 130, 5), Color("#1e2e30"))
	for x in [1025.0, 1037.0, 1049.0, 1061.0]:
		draw_circle(Vector2(x, 532), 3.4, Color("#172e32"), true, -1.0, true)
	for row in range(5):
		var y := 407.0 + row * 12.0
		line([Vector2(1101, y), Vector2(1123, y - 9)], "#162326", 2.4)
	keyboard()
	line([Vector2(1139, 560), Vector2(1206, 573), Vector2(1240, 591), Vector2(1231, 610), Vector2(1182, 623)], "#182326", 3.5)
	face([Vector2(1151, 626), Vector2(1182, 620), Vector2(1201, 639), Vector2(1169, 644)], "#222d2e")
	line([Vector2(1170, 626), Vector2(1181, 636)], "#6e8a7a", 1.1)
	for i in range(4):
		var cord := Curve2D.new()
		cord.add_point(Vector2(902 + i * 15.0, 733 - i * 2.0), Vector2.ZERO, Vector2(17, 52))
		cord.add_point(Vector2(935 + i * 27.0, 801), Vector2(30, -25))
		draw_polyline(cord.tessellate(), Color("#101b1c"), 2.8, true)

func keyboard() -> void:
	face([Vector2(874, 614), Vector2(1059, 585), Vector2(1137, 624), Vector2(930, 660)], "#bdac83")
	face([Vector2(930, 660), Vector2(1137, 624), Vector2(1137, 633), Vector2(930, 670)], "#665d4a")
	for row in range(4):
		for key in range(14):
			var at := Vector2(888 + row * 12 + key * 12.8, 616 + row * 8.5 - key * 2.02)
			face([at, at + Vector2(9, -1.4), at + Vector2(17, 3.2), at + Vector2(7, 4.9)],
				"#4b4a3e" if (key + row) % 8 < 3 else "#797761")

func rect_glow(rect: Rect2, color: Color, ring: int) -> void:
	for step in range(ring, 0, -1):
		draw_rect(rect.grow(step), Color(color, 0.009))
	draw_rect(rect, color.lightened(0.55))

func face(points: PackedVector2Array, ink: String) -> void:
	draw_colored_polygon(points, Color(ink))

func line(points: PackedVector2Array, ink: String, thickness: float) -> void:
	draw_polyline(points, Color(ink), thickness, true)

class SignalLamp extends Node2D:
	var tick := 0.0

	func _process(delta: float) -> void:
		tick += delta
		queue_redraw()

	func _draw() -> void:
		var y := SCREEN.position.y + fposmod(tick * 26.0, SCREEN.size.y - 2.0)
		draw_rect(Rect2(SCREEN.position.x, y, SCREEN.size.x, 2.0), Color("#a0ffce42"))
		var pulse := 0.5 + sin(tick * 3.5) * 0.33
		draw_circle(Vector2(1062, 532), 7.0, Color(AMBER, pulse * 0.22), true, -1.0, true)
		draw_circle(Vector2(1062, 532), 2.5, Color(AMBER, pulse + 0.14), true, -1.0, true)
