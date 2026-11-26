extends Button

const Route = preload("res://scripts/campaign/Route.gd")
const PALE := Color("#e6c795")
const JADE := Color("#adbea0")
const LOCKED := Color("#a8b5a8")

var kind := 0
var reachable := false
var visited := false
var selected := false
var breathing := 0.0

func _ready() -> void:
	var invisible := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, invisible)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if reachable else Control.CURSOR_ARROW
	# Locked sites still have a tooltip explaining what's ahead.
	focus_mode = Control.FOCUS_ALL if reachable else Control.FOCUS_NONE
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	set_process(reachable)

func _process(delta: float) -> void:
	breathing += delta
	queue_redraw()

func _draw() -> void:
	var origin := size * 0.5
	var radius := 16.0
	var ink := PALE if reachable else JADE if visited else LOCKED
	var highlight := selected or reachable and (is_hovered() or has_focus())
	var stroke := 1.9 if reachable else 1.45
	if highlight:
		draw_circle(origin, 24.0, Color("#edbc5c28"), true, -1.0, true)
	if reachable:
		var bloom := 0.18 + (sin(breathing * 2.6) * 0.5 + 0.5) * 0.34
		draw_arc(origin, 21.0, 0.0, TAU, 32, Color(PALE, bloom), 1.1, true)
	draw_circle(origin + Vector2(0, 1.5), radius + 2.0, Color("#0a100ff0"), true, -1.0, true)
	draw_circle(origin, radius, Color("#3b3123") if highlight else Color("#131d1c"), true, -1.0, true)
	draw_arc(origin, radius, 0, TAU, 32, Color(ink, 0.92 if reachable or visited else 0.50), stroke, true)
	draw_set_transform(origin)
	var symbol := Color(ink, 1.0 if reachable or visited else 0.68)
	match kind:
		Route.Kind.BATTLE:
			_mark([Vector2(-8, 7), Vector2(5, -6), Vector2(9, -8), Vector2(7, -2), Vector2(-5, 8)], symbol)
			_mark([Vector2(-7, 1), Vector2(0, 8)], symbol)
		Route.Kind.ELITE:
			_mark([Vector2(-8, 7), Vector2(6, -7), Vector2(8, -8), Vector2(7, -4)], symbol)
			_mark([Vector2(8, 7), Vector2(-6, -7), Vector2(-8, -8), Vector2(-7, -4)], symbol)
			_mark([Vector2(-8, 1), Vector2(-1, 8)], symbol)
			_mark([Vector2(8, 1), Vector2(1, 8)], symbol)
		Route.Kind.CAMP:
			_mark([Vector2(-5, 5), Vector2(-7, 0), Vector2(-3, -6), Vector2(0, -2), Vector2(2, -9),
				Vector2(7, -2), Vector2(6, 3), Vector2(3, 6)], symbol)
			_mark([Vector2(-8, 8), Vector2(8, 8)], symbol)
		Route.Kind.ALTAR:
			_mark([Vector2(-7, 8), Vector2(-5, -6), Vector2(0, -9), Vector2(6, -6), Vector2(7, 8), Vector2(-7, 8)], symbol)
			_mark([Vector2(-3, 3), Vector2(0, -4), Vector2(3, 3)], symbol)
		Route.Kind.EVENT:
			draw_arc(Vector2(0, -2), 5.0, PI, TAU + 1.2, 17, symbol, 1.6, true)
			draw_circle(Vector2(0, 8), 1.45, symbol, true, -1.0, true)
		Route.Kind.BOSS:
			_mark([Vector2(-9, -5), Vector2(-6, 7), Vector2(6, 7), Vector2(9, -5), Vector2(3, -2),
				Vector2(0, -8), Vector2(-3, -2), Vector2(-9, -5)], symbol)
	draw_set_transform(Vector2.ZERO)

func _mark(points: Array[Vector2], color: Color) -> void:
	draw_polyline(PackedVector2Array(points), color, 1.65, true)
