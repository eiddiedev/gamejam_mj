extends CanvasLayer

signal chosen(id: String)

const HEAD = preload("res://heading.tres")
const BODY = preload("res://typeface.tres")
const INK := Color("#142027")
const GOLD := Color("#e5bb80")
const CREAM := Color("#f3e3bd")
const PALE := Color("#c0c8bf")
const GIFTS := [
	["edge", "猎刃", "挥剑伤害 +22%"],
	["lamp", "烛心", "灯光范围 +16%\n补充 18% 灯油"],
	["step", "影步", "冲刺冷却缩短\n移动速度 +7%"],
	["blood", "温血", "生命上限 +10\n恢复 30 点生命"],
]
const SLATE := Vector2(740, 310)

var offers: Array = []
var locked := false

func show_choices(level_rank: int, unlocked: Dictionary) -> void:
	layer = 26
	var order: Array = GIFTS.duplicate()
	order.sort_custom(func(a, b): return int(unlocked.get(a[0], 0)) < int(unlocked.get(b[0], 0)))
	if level_rank % 2 == 0:
		var last: Array = order.pop_back()
		order.insert(1, last)
	offers.assign(order.slice(0, 3))

	var dim := ColorRect.new()
	dim.size = Vector2(1280, 800)
	dim.color = Color("#071217aa")
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var plate := GiftSlate.new()
	plate.position = dim.size * 0.5 - SLATE * 0.5
	plate.size = SLATE
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.add_child(plate)
	label(plate, "夜战印记", Rect2(31, 20, 392, 45), 32, CREAM, HEAD)
	label(plate, "三选一 · 本关生效", Rect2(34, 67, 393, 24), 15, PALE, BODY)
	var rank := label(plate, "夜阶 %d → %d" % [level_rank, level_rank + 1],
		Rect2(517, 23, 187, 38), 22, GOLD, HEAD)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for index in offers.size():
		add_offer(plate, offers[index], index)
	plate.modulate.a = 0.0
	plate.scale = Vector2.ONE * 0.985
	plate.pivot_offset = SLATE * 0.5
	var rise := create_tween().set_parallel()
	rise.tween_property(plate, "modulate:a", 1.0, 0.13)
	rise.tween_property(plate, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func add_offer(plate: Control, gift: Array, index: int) -> void:
	var action := Button.new()
	action.position = Vector2(31 + 229 * index, 110)
	action.size = Vector2(220, 173)
	action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action.tooltip_text = "%s · 按 %d" % [gift[1], index + 1]
	action.add_theme_stylebox_override("normal", style(Color("#1b282e"), Color("#615b4a")))
	action.add_theme_stylebox_override("hover", style(Color("#3c3630"), GOLD))
	action.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, GOLD))
	action.add_theme_stylebox_override("pressed", style(Color("#56442e"), GOLD))
	action.pressed.connect(choose.bind(index))
	plate.add_child(action)
	var mark := GiftSeal.new()
	mark.symbol = GIFTS.find(gift)
	mark.position = Vector2(110, 46)
	action.add_child(mark)
	label(action, str(index + 1), Rect2(13, 8, 28, 23), 14, GOLD, HEAD)
	var title := label(action, gift[1], Rect2(12, 78, 196, 34), 25, CREAM, HEAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var effect := label(action, gift[2], Rect2(12, 119, 196, 43), 15, PALE, BODY)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_1, KEY_2, KEY_3]:
		get_viewport().set_input_as_handled()
		choose(event.keycode - KEY_1)

func choose(index: int) -> void:
	if locked or index < 0 or index >= offers.size():
		return
	locked = true
	chosen.emit(offers[index][0])

func label(parent: Control, words: String, rect: Rect2, pixels: int, tint: Color, font: Font) -> Label:
	var line := Label.new()
	line.position = rect.position
	line.size = rect.size
	line.text = words
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_override("font", font)
	line.add_theme_font_size_override("font_size", pixels)
	line.add_theme_color_override("font_color", tint)
	parent.add_child(line)
	return line

func style(tone: Color, border: Color) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.bg_color = tone
	plate.border_color = border
	plate.set_border_width_all(1)
	plate.corner_radius_top_right = 5
	plate.corner_radius_bottom_left = 5
	return plate

class GiftSlate extends Control:
	func _draw() -> void:
		var face := PackedVector2Array([Vector2(17, 0), Vector2(719, 0), Vector2(726, 6),
			Vector2(737, 6), Vector2(740, 15), Vector2(740, 289), Vector2(724, 310), Vector2(18, 310),
			Vector2(11, 304), Vector2(3, 304), Vector2(0, 292), Vector2(0, 18)])
		var shadow := face.duplicate()
		for i in shadow.size():
			shadow[i] += Vector2(1, 7)
		draw_colored_polygon(shadow, Color("#020809a8"))
		draw_colored_polygon(face, INK)
		face.append(face[0])
		draw_polyline(face, Color("#a58c65"), 1.35, true)
		draw_line(Vector2(25, 7), Vector2(712, 7), Color("#8e7d5b77"), 1.0, true)
		draw_line(Vector2(7, 23), Vector2(7, 283), Color("#8e7d5b60"), 1.0, true)
		draw_line(Vector2(34, 98), Vector2(706, 98), Color("#88765c71"), 1.0, true)

class GiftSeal extends Node2D:
	var symbol := 0

	func _draw() -> void:
		var face := PackedVector2Array([Vector2(-15, -25), Vector2(13, -25), Vector2(25, -14),
			Vector2(25, 14), Vector2(15, 25), Vector2(-13, 25), Vector2(-25, 13), Vector2(-25, -13)])
		draw_colored_polygon(face, Color("#111d23"))
		face.append(face[0])
		draw_polyline(face, Color("#aa8b60"), 1.1, true)
		draw_arc(Vector2.ZERO, 20, 0.25, PI - 0.1, 25, Color("#a68a5b73"), 1.05, true)
		match symbol:
			0:
				var blade := PackedVector2Array([Vector2(-7, 10), Vector2(7, -11), Vector2(13, -14),
					Vector2(11, -7), Vector2(-5, 12)])
				draw_colored_polygon(blade, CREAM)
				draw_line(Vector2(-13, 2), Vector2(-2, 13), GOLD, 2.1, true)
			1:
				var fire := PackedVector2Array([Vector2(-9, 10), Vector2(-12, 2), Vector2(-6, -4),
					Vector2(-3, 0), Vector2(0, -14), Vector2(6, -6), Vector2(8, -9),
					Vector2(12, 1), Vector2(9, 9), Vector2(2, 13)])
				draw_colored_polygon(fire, GOLD)
				draw_line(Vector2(-4, 7), Vector2(4, 1), CREAM, 1.7, true)
			2:
				draw_polyline(PackedVector2Array([Vector2(-13, 8), Vector2(-4, -8), Vector2(3, 7),
					Vector2(13, -11)]), GOLD, 2.5, true)
			_:
				draw_line(Vector2(-10, 0), Vector2(10, 0), GOLD, 3.7, true)
				draw_line(Vector2(0, -10), Vector2(0, 10), GOLD, 3.7, true)
