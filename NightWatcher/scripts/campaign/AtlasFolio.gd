extends Node2D

const INK := Color("#101512")
const GOLD := Color("#9c8154")
const DUST := Color("#3f3e2f")

func _draw() -> void:
	var outline := PackedVector2Array([
		Vector2(13,1),Vector2(257,2),Vector2(275,14),Vector2(274,725),Vector2(260,748),
		Vector2(15,750),Vector2(0,732),Vector2(1,53),Vector2(4,14)
	])
	draw_colored_polygon(outline, INK)
	var vellum := PackedVector2Array([
		Vector2(18,13),Vector2(253,10),Vector2(263,20),Vector2(264,717),Vector2(254,737),
		Vector2(22,739),Vector2(11,723),Vector2(11,54),Vector2(11,22)
	])
	draw_colored_polygon(vellum, Color("#211f17"))
	draw_polyline(outline + PackedVector2Array([outline[0]]), Color("#74644b"), 1.5,true)
	draw_polyline(vellum + PackedVector2Array([vellum[0]]), Color("#4e452d"), 1.0,true)
	for index in range(217):
		var p := Vector2(15+fposmod(index*53.61,246.0), 16+fposmod(index*87.31,713.0))
		var grain := (0.045 if index % 3 == 0 else 0.022) + sin(index*18.2)*0.013
		draw_line(p,p+Vector2(1.8+index%4,0.90),Color(Color("#e4c88e"),grain),1.0)
	for index in range(2):
		var y := 240.0 + float(index)*377.0
		draw_line(Vector2(24,y), Vector2(253,y), Color("#564a31"), 1.0,true)
		diamond(Vector2(139,y),4.5,GOLD)
	draw_border_flourish(Vector2(19,21),Vector2(1,1))
	draw_border_flourish(Vector2(256,21),Vector2(-1,1))
	draw_border_flourish(Vector2(19,727),Vector2(1,-1))
	draw_border_flourish(Vector2(256,727),Vector2(-1,-1))
	coin(Vector2(43,169),true)
	coin(Vector2(147,169),false)

func diamond(at: Vector2, width: float, tint: Color) -> void:
	var form := PackedVector2Array([at+Vector2(-width,0),at+Vector2(0,-width),at+Vector2(width,0),at+Vector2(0,width)])
	draw_colored_polygon(form,tint)

func draw_border_flourish(at: Vector2, axis: Vector2) -> void:
	var steps := PackedVector2Array()
	for local_point in [Vector2(1,30),Vector2(3,13),Vector2(9,5),Vector2(24,3),Vector2(38,1)]:
		steps.append(at+local_point*axis)
	draw_polyline(steps,GOLD,0.76,true)
	diamond(at + Vector2(11,12)*axis,2.3,DUST.lightened(0.30))

func coin(at: Vector2, ember: bool) -> void:
	draw_circle(at,14,Color("#171810"),true,-1,true)
	draw_arc(at,13.0,0,TAU,28,Color("#827049"),1.13,true)
	if ember:
		var spark := PackedVector2Array([at+Vector2(-5,4),at+Vector2(-2,-3),at+Vector2(1,-8),at+Vector2(4,-2),
			at+Vector2(6,3),at+Vector2(2,6),at+Vector2(-2,6)])
		draw_colored_polygon(spark,Color("#c78c53"))
		draw_line(at+Vector2(-2,4),at+Vector2(1,-3),Color("#f2c980"),1.1,true)
	else:
		draw_line(at+Vector2(-4,-4),at+Vector2(5,5),Color("#a9b19b"),3.1,true)
		draw_circle(at+Vector2(-5,-5),2.7,Color("#c4c6ad"),true,-1,true)
		draw_circle(at+Vector2(5,5),2.7,Color("#c4c6ad"),true,-1,true)
