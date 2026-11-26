extends Node2D

const NAMES := ["夜行爬尸", "影潜者", "噬火蛾", "掘骨巨尸", "灰烬咒术师", "永夜先驱"]
const CRAWLER := 0
const SHADE := 1
const MOTH := 2
const COLOSSUS := 3
const HEXER := 4
const HERALD := 5
const TARGET_NONE := 0
const TARGET_PLAYER := 1
const TARGET_FIRE := 2
const TARGET_WALL := 3
const AFFLICTIONS := ["", "溃走", "坚骨", "噬火"]
const INK := Color("#10161e")
const BONE := Color("#bab1a0")
const GOLD := Color("#ffb65e")

var kind := CRAWLER
var lane := 0
var path := PackedVector2Array()
var waypoint := 1
var health := 1.0
var max_health := 1.0
var armor := 0.0
var speed := 0.0
var power := 0.0
var reward := Vector2i.ZERO
var elite := false
var affliction := 0
var lit := false
var facing := Vector2.DOWN
var age := 0.0
var cooldown := 0.0
var special := 0.0
var rooted := 0.0
var wrapped := 0.0
var marked := 0.0
var burned := 0.0
var sundered := 0.0
var charge := 0.0
var hit := 0.0
var knock := Vector2.ZERO
var removed := false
var acting := false
var draw_body := false
var tell := 0.0
var tell_span := 0.34
var attack_pose := 0.0
var attack_recovery := 0.0
var attack_target := TARGET_NONE
var attack_slot := -1
var hit_hold := 0.0
var flight_plan := PackedVector2Array()
var flight_goal := Vector2.INF
var flight_index := 0
var flight_retry := 0.0
var flight_rejection := Vector2.INF
var flight_rejection_left := 0.0
var lane_detour := PackedVector2Array()
var lane_resume := 1
var lane_stall := 0.0
var lane_retry := 0.0
var stagger := 0.0
var velocity_hit := Vector2.ZERO
var radius: float:
	get:
		if kind == MOTH:
			return 8.0
		return 15.0 if kind in [COLOSSUS, HERALD] else 10.0

func _draw() -> void:
	if removed or (kind == SHADE and not lit):
		return
	if draw_body and kind != MOTH:
		draw_set_transform(Vector2(0.0, 4.0), 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, 16.0 if kind <= SHADE else 23.0, Color("#0a1114a6"), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
	if draw_body:
		if kind == MOTH:
			draw_moth()
		else:
			draw_walker()
	if marked > 0.0:
		var at := Vector2(0.0, -49.0 if kind == COLOSSUS or kind == HERALD else -34.0)
		draw_polyline([at + Vector2(-3.0, 0.0), at + Vector2(0.0, -3.0), at + Vector2(3.0, 0.0),
			at + Vector2(0.0, 3.0), at + Vector2(-3.0, 0.0)], GOLD, 1.4, true)
	if affliction > 0:
		draw_affliction()
	if rooted > 0.0 or wrapped > 0.0:
		draw_arc(Vector2(0.0, 1.0), 16.0, 0.05, PI - 0.10, 12, Color("#e3a97baa"), 1.8, true)
	if charge > 0.0:
		draw_arc(Vector2(0.0, -12.0), 24.0, -PI * 0.8, TAU * minf(1.0, charge) - PI * 0.8, 20,
			Color("#df82af"), 2.0, true)
	if hit > 0.0 or kind in [COLOSSUS, HERALD]:
		var rise := -48.0 if kind in [COLOSSUS, HERALD] else -32.0
		draw_line(Vector2(-16.0, rise), Vector2(16.0, rise), INK, 4.0, true)
		draw_line(Vector2(-15.0, rise), Vector2(-15.0 + 30.0 * clampf(health / max_health, 0.0, 1.0), rise),
			Color("#a65a4d") if kind != HERALD else GOLD, 2.0, true)

func draw_affliction() -> void:
	var tint := Color("#b0a0c3") if affliction == 2 else Color("#cb7862")
	for index in range(affliction):
		var x := -16.0 + index * 4.0
		draw_line(Vector2(x - 1.0, 5.0), Vector2(x + 2.0, 1.0), tint, 1.5, true)

func draw_moth() -> void:
	draw_set_transform(Vector2(0.0, -10.0 + sin(age * 6.2) * 5.0), facing.angle() + PI * 0.5)
	var span := 20.0 + sin(age * 23.0) * 7.0
	for sign_value in [-1.0, 1.0]:
		var s: float = sign_value
		paint([Vector2(s * 3.0, 3.0), Vector2(s * span, -12.0), Vector2(s * (span + 4.0), -1.0),
			Vector2(s * (span * 0.8), 8.0), Vector2(s * 6.0, 11.0)], Color("#a4544e") if lit else Color("#564453"))
		draw_line(Vector2(s * 4.0, 2.0), Vector2(s * span, -8.0), Color("#ea9670"), 1.3, true)
		draw_circle(Vector2(s * 11.0, 2.0), 2.7, GOLD, true, -1.0, true)
	paint([Vector2(-4.0, 7.0), Vector2(-5.0, -4.0), Vector2(0.0, -10.0),
		Vector2(5.0, -4.0), Vector2(4.0, 7.0), Vector2(0.0, 12.0)], Color("#423241"))
	draw_set_transform(Vector2.ZERO)

func draw_walker() -> void:
	var large := kind in [COLOSSUS, HERALD]
	var scale_factor := 1.45 if large else 1.0
	var sway := sin(age * (5.0 if large else 11.0)) * (2.0 if acting else 0.65)
	var forward := signf(facing.x) if absf(facing.x) > 0.12 else 1.0
	draw_set_transform(Vector2(0.0, sway), 0.0, Vector2(forward, 1.0) * scale_factor)
	var tint := BONE
	match kind:
		SHADE:
			tint = Color("#654d79")
		COLOSSUS:
			tint = Color("#a49a7c")
		HEXER:
			tint = Color("#7b586e")
		HERALD:
			tint = Color("#83576b")
	if hit > 0.0:
		tint = tint.lerp(Color("#f5a582"), minf(hit * 3.1, 0.75))
	if large or kind == HEXER or kind == SHADE:
		paint([Vector2(-8.0, -18.0), Vector2(9.0, -19.0), Vector2(15.0, 1.0), Vector2(2.0, 6.0),
			Vector2(-13.0, 2.0)], tint.darkened(0.43))
	else:
		draw_line(Vector2(-6.0, -12.0), Vector2(-8.0 - sway, 2.0), INK, 5.0, true)
		draw_line(Vector2(1.0, -12.0), Vector2(5.0 + sway, 3.0), INK, 5.0, true)
		draw_line(Vector2(-6.0, -12.0), Vector2(-8.0 - sway, 2.0), tint, 2.2, true)
		draw_line(Vector2(1.0, -12.0), Vector2(5.0 + sway, 3.0), tint, 2.2, true)
	paint([Vector2(-10.0, -24.0), Vector2(6.0, -25.0), Vector2(12.0, -18.0), Vector2(5.0, -11.0),
		Vector2(-6.0, -12.0), Vector2(-12.0, -18.0)], tint)
	if kind == CRAWLER or kind == COLOSSUS:
		for i in range(3):
			var y := -22.0 + i * 3.0
			draw_line(Vector2(-5.0, y), Vector2(4.0, y + 1.0), INK, 1.5, true)
	var head := Color("#bdad8a") if kind in [CRAWLER, COLOSSUS] else tint.lightened(0.18)
	paint([Vector2(-4.0, -25.0), Vector2(-8.0, -32.0), Vector2(-2.0, -37.0), Vector2(7.0, -35.0),
		Vector2(10.0, -28.0), Vector2(5.0, -24.0)], head)
	draw_line(Vector2(1.0, -30.0), Vector2(6.0, -30.0),
		Color("#ed9468") if lit else Color("#f4c080"), 2.0, true)
	if kind == HEXER:
		draw_line(Vector2(12.0, 3.0), Vector2(19.0, -35.0), Color("#aa7b72"), 2.7, true)
		draw_circle(Vector2(19.0, -35.0), 3.5, Color("#e395cd"), true, -1.0, true)
	if kind == COLOSSUS:
		paint([Vector2(-13.0, -24.0), Vector2(-21.0, -27.0), Vector2(-22.0, -14.0),
			Vector2(-10.0, -10.0)], head.darkened(0.18))
	if kind == HERALD:
		draw_polyline([Vector2(-9.0, -32.0), Vector2(-11.0, -42.0), Vector2(-2.0, -38.0),
			Vector2(5.0, -45.0), Vector2(9.0, -33.0)], GOLD, 2.3, true)
	if elite and kind != HERALD:
		draw_arc(Vector2(1.0, -33.0), 10.0, PI, TAU, 12, GOLD, 1.1, true)
	draw_set_transform(Vector2.ZERO)

func paint(points: PackedVector2Array, tint: Color) -> void:
	draw_colored_polygon(points, tint)
	points.append(points[0])
	draw_polyline(points, INK, 2.0, true)
