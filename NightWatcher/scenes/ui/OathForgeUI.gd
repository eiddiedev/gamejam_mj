extends Control

signal chosen(id: String)

const FONT = preload("res://typeface.tres")
const HEADING = preload("res://heading.tres")
const SILVER := Color("#c9d0c8")
const AMBER := Color("#e1ac68")
const SUN := Color("#ffcc76")
const PAPER := Color("#f3e7d2")
const SOFT := Color("#b5b9ac")
const REROLL_COST := 30
const STANDING_STONES := [
	Rect2(521, 220, 238, 322),
	Rect2(227, 272, 224, 267),
	Rect2(826, 259, 224, 280),
]

var run
var forced := ""
var offers: Array[String] = []
var selected := -1
var reroll_available := false
var forging := false
var frame: Control
var offer_layer: Control
var tool_layer: Control
var message: Label
var slabs: Array[Control] = []
var runes: Array[Button] = []
var forge_sound: AudioStreamPlayer

func _ready() -> void:
	frame = Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(paint_background)
	add_child(frame)
	resized.connect(frame.queue_redraw)
	put_text(frame, "改字铸誓", Rect2(310, 88, 660, 79), 59, PAPER, true, true)
	put_text(frame, "选一块石碑，重刻发光的字母", Rect2(310, 177, 660, 25), 17, SOFT, true)
	offer_layer = Control.new()
	offer_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(offer_layer)
	tool_layer = Control.new()
	tool_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tool_layer)
	forge_sound = AudioStreamPlayer.new()
	add_child(forge_sound)

func configure(state, force_id: String = "", can_reroll: bool = false) -> void:
	run = state
	forced = force_id if OathDatabase.OATHS.has(force_id) and force_id not in run.oaths else ""
	reroll_available = can_reroll
	forging = false
	offers = OathDatabase.draw_oaths(run.oaths, run.reward_rng, forced)
	show_offers()

func show_offers() -> void:
	selected = -1
	slabs.clear()
	runes.clear()
	clear_layer(offer_layer)
	clear_layer(tool_layer)
	if offers.is_empty():
		put_text(offer_layer, "铭文已全部铸成", Rect2(305, 355, 670, 58), 32, PAPER, true, true)
		make_button(tool_layer, "继续守望", Rect2(546, 630, 188, 51), func(): chosen.emit(""))
		return
	for index in offers.size():
		build_stone(index, STANDING_STONES[index])
	update_tools()

func build_stone(index: int, bounds: Rect2) -> void:
	var id := offers[index]
	var oath := OathDatabase.get_oath(id)
	var tint := rarity_color(oath["rarity"])
	var locked := not forced.is_empty() and id != forced
	var stone := Control.new()
	stone.position = bounds.position
	stone.size = bounds.size
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stone.modulate = Color(0.79, 0.83, 0.84) if locked else Color.WHITE
	offer_layer.add_child(stone)
	stone.draw.connect(paint_stone.bind(stone, index, tint))
	slabs.append(stone)

	var opener := Button.new()
	opener.size = stone.size
	opener.flat = true
	opener.disabled = locked
	opener.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	opener.tooltip_text = "%s · %s\n%s" % [oath["base"], oath["title"], oath["effect"]]
	opener.pressed.connect(select_stone.bind(index))
	opener.mouse_entered.connect(stone.queue_redraw)
	opener.mouse_exited.connect(stone.queue_redraw)
	opener.focus_entered.connect(stone.queue_redraw)
	opener.focus_exited.connect(stone.queue_redraw)
	for phase in ["normal", "hover", "pressed", "focus", "disabled"]:
		opener.add_theme_stylebox_override(phase, StyleBoxEmpty.new())
	stone.add_child(opener)

	put_text(stone, rarity_name(oath["rarity"]), Rect2(6, stone.size.y * 0.35, stone.size.x - 28.0, 26),
		14, tint, true)
	var base: String = oath["base"]
	var left := (stone.size.x - base.length() * 37.0) * 0.5 - 7.0
	for letter in base.length():
		var well := Rect2(left + letter * 37.0, stone.size.y * 0.49, 37, 50)
		if letter == oath["letter"]:
			var plate := Control.new()
			plate.position = well.position
			plate.size = well.size
			plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			plate.draw.connect(draw_rune_well.bind(plate, tint, index))
			stone.add_child(plate)
			var rune := make_button(plate, base[letter], Rect2(Vector2.ZERO, well.size),
				select_stone.bind(index), tint, true)
			rune.mouse_entered.connect(plate.queue_redraw)
			rune.mouse_exited.connect(plate.queue_redraw)
			stone.draw.connect(plate.queue_redraw)
			rune.tooltip_text = "可替换的字母"
			rune.disabled = locked
			runes.append(rune)
		else:
			put_text(stone, base[letter], well, 32, Color("#d1ccaf"), true, true)
	put_text(stone, oath["title"], Rect2(12, stone.size.y * 0.74, stone.size.x - 37.0, 30),
		19, SOFT, true, true)

func select_stone(index: int) -> void:
	if forging or (not forced.is_empty() and offers[index] != forced):
		return
	selected = index
	for stone in slabs:
		stone.queue_redraw()
	frame.queue_redraw()
	update_tools()

func update_tools() -> void:
	clear_layer(tool_layer)
	message = put_text(tool_layer, "", Rect2(291, 661, 698, 30), 15, SOFT, true)
	if selected < 0 and not forced.is_empty():
		put_text(tool_layer, "选中 %s 石碑，铸成本次誓言。" % OathDatabase.get_oath(forced)["base"],
			Rect2(291, 617, 698, 42), 19, PAPER, true, true)
	elif selected < 0:
		put_text(tool_layer, "选择石碑以查看誓言", Rect2(291, 617, 698, 42), 19, SOFT, true)
	if selected >= 0:
		var oath := OathDatabase.get_oath(offers[selected])
		var required: String = offers[selected][oath["letter"]]
		var detail := put_text(tool_layer, oath["effect"], Rect2(265, 600, 750, 53), 18, PAPER, true)
		detail.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		message.text = "按 %s 或点击石印，将 %s 重铸为 %s。" % [required, oath["base"], offers[selected]]
		var commit := make_button(tool_layer, "刻入  %s" % required, Rect2(548, 703, 184, 48),
			apply_letter.bind(required), rarity_color(oath["rarity"]))
		commit.tooltip_text = "%s → %s" % [oath["base"], offers[selected]]
	if reroll_available:
		var reroll := make_button(tool_layer, "刷新候选 · 30 余烬", Rect2(1024, 703, 206, 48), reroll_oaths)
		reroll.disabled = run.embers < REROLL_COST or run.oaths.size() >= OathDatabase.OATHS.size() - 3
		reroll.tooltip_text = "余烬 %d" % run.embers

func reroll_oaths() -> void:
	if forging or not reroll_available or run.oaths.size() >= OathDatabase.OATHS.size() - 3:
		return
	if not run.spend_embers(REROLL_COST):
		return
	var previous := offers.duplicate()
	offers = OathDatabase.draw_oaths(run.oaths, run.reward_rng, forced, previous)
	reroll_available = false
	show_offers()

func _input(event: InputEvent) -> void:
	if not visible or forging or selected < 0:
		return
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.meta_pressed:
		var letter: String = String.chr(event.unicode).to_upper() if event.unicode > 0 else ""
		if letter.length() == 1 and "ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(letter):
			apply_letter(letter)
			get_viewport().set_input_as_handled()

func apply_letter(letter: String) -> void:
	if forging or selected < 0:
		return
	var id := offers[selected]
	var oath := OathDatabase.get_oath(id)
	var source: String = oath["base"]
	var index: int = oath["letter"]
	var result := source.substr(0, index) + letter + source.substr(index + 1)
	if result != id:
		message.text = "碑上的字未成誓。请刻入 %s。" % id[index]
		message.modulate = Color("#ffbb90")
		return
	forging = true
	clear_layer(tool_layer)
	put_text(tool_layer, "誓言已成  /  %s" % result, Rect2(265, 623, 750, 57), 30,
		rarity_color(oath["rarity"]), true, true)
	for i in slabs.size():
		if i != selected:
			create_tween().tween_property(slabs[i], "modulate", Color(0.51, 0.57, 0.56), 0.25)
	var rune := runes[selected]
	rune.text = letter
	rune.add_theme_color_override("font_disabled_color", rarity_color(oath["rarity"]).lightened(0.26))
	rune.disabled = true
	rune.pivot_offset = rune.size * 0.5
	var stamp := create_tween()
	stamp.tween_property(rune, "scale", Vector2(1.22, 1.22), 0.12)
	stamp.tween_property(rune, "scale", Vector2.ONE, 0.33).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cast_sparks(rune.global_position + rune.size * 0.50, rarity_color(oath["rarity"]))
	forge_sound.stream = cast_chime()
	forge_sound.volume_db = -10.0
	forge_sound.play()
	await get_tree().create_timer(0.90).timeout
	chosen.emit(id)

func cast_sparks(point: Vector2, tint: Color) -> void:
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.emitting = false
	sparks.amount = 44
	sparks.lifetime = 0.71
	sparks.explosiveness = 0.96
	sparks.direction = Vector2.UP
	sparks.spread = 91.0
	sparks.gravity = Vector2(0, 164)
	sparks.initial_velocity_min = 35.0
	sparks.initial_velocity_max = 163.0
	sparks.scale_amount_min = 1.3
	sparks.scale_amount_max = 3.6
	var colors := Gradient.new()
	colors.colors = PackedColorArray([tint.lightened(0.52), Color(tint.darkened(0.78), 0.0)])
	sparks.color_ramp = colors
	add_child(sparks)
	sparks.global_position = point
	sparks.finished.connect(sparks.queue_free)
	sparks.restart()

func cast_chime() -> AudioStreamWAV:
	var rate := 22050
	var samples := PackedByteArray()
	samples.resize(rate * 2 * 7 / 10)
	for i in samples.size() / 2:
		var t := float(i) / rate
		var metal := sin(TAU * 462.0 * t) * 0.31 + sin(TAU * 695.0 * t) * 0.19 + sin(TAU * 1087.0 * t) * 0.11
		var strike := sin(TAU * 1780.0 * t) * 0.16 * exp(-60.0 * t)
		var sound := (metal * exp(-6.8 * t) + strike) * minf(1.0, t * 770.0)
		samples.encode_s16(i * 2, roundi(sound * 32767.0))
	var audio := AudioStreamWAV.new()
	audio.mix_rate = rate
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.data = samples
	return audio

func paint_background() -> void:
	frame.draw_rect(Rect2(Vector2.ZERO, frame.size), Color("#0b171d"))
	for index in range(28, 0, -1):
		var radius := 28.0 * index
		frame.draw_set_transform(Vector2(637, 473), 0.0, Vector2(1.0, 0.71))
		frame.draw_circle(Vector2.ZERO, radius, Color(0.30, 0.39, 0.34, 0.029), true, -1, true)
	frame.draw_set_transform(Vector2.ZERO)
	var vault := PackedVector2Array([Vector2(0, 630), Vector2(175, 489)])
	for i in 35:
		var turn := PI + PI * i / 34.0
		var unit := Vector2.from_angle(turn)
		var ripple := 1.0 + sin(i * 2.6) * 0.013
		vault.append(Vector2(640, 457) + unit * Vector2(482, 428) * ripple)
	vault.append_array(PackedVector2Array([Vector2(1114, 482), Vector2(1280, 631)]))
	for index in range(4):
		var ribs := vault.duplicate()
		for i in ribs.size():
			var scale := 1.0 + index * 0.047
			ribs[i] = Vector2(640, 466) + (ribs[i] - Vector2(640, 466)) * scale
		frame.draw_polyline(ribs, Color("#47747b66") if index == 0 else Color("#162b30"),
			1.2 if index == 0 else 9.0, true)
	frame.draw_colored_polygon(PackedVector2Array([Vector2(0, 8), Vector2(169, 0), Vector2(159, 157),
		Vector2(143, 211), Vector2(110, 269), Vector2(107, 349), Vector2(69, 440),
		Vector2(180, 515), Vector2(175, 590), Vector2(0, 654)]), Color("#0b151b"))
	frame.draw_colored_polygon(PackedVector2Array([Vector2(1155, 0), Vector2(1280, 0), Vector2(1280, 667),
		Vector2(1124, 592), Vector2(1141, 525), Vector2(1183, 485), Vector2(1145, 423),
		Vector2(1148, 312), Vector2(1109, 253), Vector2(1145, 203)]), Color("#0b151b"))
	frame.draw_polyline(PackedVector2Array([Vector2(153, 126), Vector2(150, 190), Vector2(124, 232),
		Vector2(132, 263), Vector2(107, 292), Vector2(114, 346), Vector2(89, 384)]), Color("#22393d"), 2, true)
	frame.draw_polyline(PackedVector2Array([Vector2(1131, 261), Vector2(1155, 306), Vector2(1151, 376),
		Vector2(1183, 422), Vector2(1172, 452)]), Color("#253b40"), 2, true)

	# These courses of slate converge toward the three plinths.
	var floor_line := PackedVector2Array([Vector2(1, 618), Vector2(160, 551), Vector2(372, 486),
		Vector2(503, 471), Vector2(777, 471), Vector2(924, 486), Vector2(1122, 553),
		Vector2(1280, 618), Vector2(1280, 800), Vector2(0, 800)])
	frame.draw_colored_polygon(floor_line, Color("#162324"))
	for row in 7:
		var y := 510.0 + row * row * 6.8
		var length := 317.0 + row * 54.0
		frame.draw_polyline(PackedVector2Array([Vector2(640 - length, y + 28), Vector2(391, y + 8),
			Vector2(543, y + 5), Vector2(750, y + 7), Vector2(923, y + 13),
			Vector2(640 + length, y + 28)]), Color("#2c3b36"), 1, true)
	for i in 12:
		var x := 45.0 + i * 108.0
		var far := Vector2(640, 482).lerp(Vector2(x, 494), 0.33)
		var vein := far.lerp(Vector2(x, 800), 0.49) + Vector2(sin(i * 2.26) * 12.0, cos(i) * 10.0)
		frame.draw_polyline(PackedVector2Array([far, vein, vein.lerp(Vector2(x, 800), 0.75)]),
			Color("#2c3b3686"), 1.1, true)
	var rise := Vector2(640, 516)
	var amber_center := Vector2(640, 500) if selected < 0 else slabs[selected].position + Vector2(110, slabs[selected].size.y)
	for index in range(14, 0, -1):
		frame.draw_set_transform(amber_center, 0.0, Vector2(1.0, 0.28))
		frame.draw_circle(Vector2.ZERO, 15.0 * index, Color(0.75, 0.40, 0.18, 0.019), true, -1, true)
	frame.draw_set_transform(rise, 0.0, Vector2(1.0, 0.217))
	for radius in [348.0, 392.0, 422.0]:
		frame.draw_arc(Vector2.ZERO, radius, -0.20, TAU - 0.36, 86, Color("#ae875270"), 3.0, true)
	for i in 51:
		var arm := Vector2.from_angle(i * TAU / 51.0)
		var at := arm * 401.0
		var tang := arm.orthogonal()
		frame.draw_line(at - tang * 3.0, at + arm * (9.0 if i % 3 == 0 else 5.0), Color("#b58f5a8c"), 2.3, true)
	frame.draw_set_transform(Vector2.ZERO)
	for i in 64:
		var x := 77.0 + fposmod(i * 173.67, 1123.0)
		var y := 137.0 + fposmod(i * 43.73, 453.0)
		var at := Vector2(x, y)
		frame.draw_line(at, at + Vector2(1.0, -2.0), Color("#bda46d55"), 1.0, true)
	for i in 47:
		var at := Vector2(79.0 + fposmod(i * 257.33, 1123.0), 546.0 + fposmod(i * 85.27, 251.0))
		var wake := Vector2(2.0 + i % 7, 1.0 + i % 2)
		frame.draw_colored_polygon(PackedVector2Array([at - wake, at + Vector2(-2, -3), at + wake,
			at + Vector2(3, 3)]), Color("#66716040"))
	var seal := Vector2(640, 65)
	frame.draw_arc(seal, 12.0, 0, TAU, 32, Color("#b78951"), 1.0, true)
	frame.draw_colored_polygon(PackedVector2Array([seal + Vector2(0, -7), seal + Vector2(4, 1),
		seal + Vector2(0, 7), seal + Vector2(-4, 1)]), Color("#d7a667"))
	for sign in [-1.0, 1.0]:
		var point := Vector2(640 + sign * 173.0, 131)
		frame.draw_colored_polygon(PackedVector2Array([point + Vector2(-6, 0), point + Vector2(0, -5),
			point + Vector2(6, 0), point + Vector2(0, 5)]), Color("#a9875c"))

func paint_stone(stone: Control, index: int, tint: Color) -> void:
	var active := index == selected
	var hover := stone.get_rect().has_point(offer_layer.get_local_mouse_position())
	var outline := tint if active else tint.darkened(0.26 if hover else 0.64)
	var summit: Vector2 = [Vector2(0.46, 0.024), Vector2(0.36, 0.04), Vector2(0.57, 0.080)][index]
	var face := stone_points(stone, [Vector2(0.04, 0.83), Vector2(0.08, 0.41), Vector2(0.08, 0.28),
		Vector2(0.16, 0.20), Vector2(0.19, 0.13), summit,
		Vector2(0.71, 0.100 + index * 0.011), Vector2(0.82, 0.18), Vector2(0.85, 0.37),
		Vector2(0.90, 0.45), Vector2(0.90, 0.79), Vector2(0.86, 0.89), Vector2(0.064, 0.91)])
	var bottom := Vector2(stone.size.x * 0.46, stone.size.y * 0.95)
	stone.draw_set_transform(bottom, 0.0, Vector2(1.0, 0.16))
	stone.draw_circle(Vector2.ZERO, stone.size.x * 0.59, Color("#070d10ab"), true, -1, true)
	stone.draw_set_transform(Vector2.ZERO)
	var steps := stone_points(stone, [Vector2(-0.015, 0.88), Vector2(0.17, 0.83),
		Vector2(0.96, 0.85), Vector2(1.036, 0.91), Vector2(0.921, 0.974),
		Vector2(0.06, 0.98), Vector2(-0.04, 0.927)])
	draw_cut(stone, steps, Color("#263638"), Color("#101d22"), 1.9)
	draw_cut(stone, stone_points(stone, [Vector2(0.04, 0.905), Vector2(0.90, 0.902),
		Vector2(0.988, 0.884), Vector2(0.94, 0.94), Vector2(0.011, 0.943)]),
		Color("#344345"), Color("#17282d"), 1.4)
	var facet := PackedVector2Array([face[5], face[6], face[7], face[8], face[9], face[10], face[11]])
	facet.append_array(stone_points(stone, [Vector2(0.957, 0.847), Vector2(0.983, 0.694),
		Vector2(0.969, 0.448), Vector2(0.913, 0.189), Vector2(0.797, 0.078), summit + Vector2(0.10, -0.012)]))
	draw_cut(stone, facet, Color("#2e464e") if active else Color("#20343d"), Color("#101e24"), 1.4)
	draw_cut(stone, face, Color("#455653") if active else Color("#344649"), Color("#121e23"), 2.1)
	var planes := stone_points(stone, [Vector2(0.07, 0.85), Vector2(0.13, 0.67), Vector2(0.18, 0.39),
		Vector2(0.20, 0.22), summit + Vector2(0.017, 0.021), Vector2(0.61, 0.122),
		Vector2(0.57, 0.31), Vector2(0.52, 0.53), Vector2(0.43, 0.65), Vector2(0.54, 0.90)])
	stone.draw_colored_polygon(planes, Color("#56675c76") if active else Color("#58707162"))
	stone.draw_polyline(PackedVector2Array([face[0], face[1], face[2], face[3], face[4], face[5], face[6]]),
		Color("#85938a78"), 1.3, true)
	stone.draw_polyline(PackedVector2Array([face[11] + Vector2(0, -3), face[10] + Vector2(-5, -3),
		face[9] + Vector2(-8, 4)]), outline, 1.6, true)
	for line in 48:
		var p := Vector2(0.14 + fposmod(line * 11.19, 0.70), 0.24 + fposmod(line * 6.38, 0.62))
		var a := p * stone.size
		stone.draw_line(a, a + Vector2(1.0 + line % 7, sin(line * 3.1) * 2.4), Color("#bbbd9d26"), 1.0, true)
	var edge_ink := Color("#162629")
	stone.draw_polyline(stone_points(stone, [Vector2(0.08, 0.37), Vector2(0.182, 0.40),
		Vector2(0.207, 0.43), Vector2(0.203, 0.466), Vector2(0.264, 0.487)]), edge_ink, 1.25, true)
	stone.draw_polyline(stone_points(stone, [Vector2(0.898, 0.657), Vector2(0.81, 0.681), Vector2(0.786, 0.709),
		Vector2(0.80, 0.744), Vector2(0.757, 0.80), Vector2(0.777, 0.885)]), edge_ink, 1.45, true)
	stone.draw_polyline(stone_points(stone, [Vector2(0.80, 0.744), Vector2(0.819, 0.802),
		Vector2(0.855, 0.818)]), Color(outline, 0.73 if active else 0.24), 1.15, true)
	stone.draw_polyline(stone_points(stone, [Vector2(0.075, 0.852), Vector2(0.162, 0.84),
		Vector2(0.23, 0.802), Vector2(0.23, 0.758), Vector2(0.275, 0.743)]),
		Color(outline, 0.81 if active else 0.32), 1.3, true)
	var word_y := stone.size.y * 0.477
	var engraving := PackedVector2Array([Vector2(13, word_y), Vector2(stone.size.x - 24.0, word_y),
		Vector2(stone.size.x - 22.0, word_y + 56), Vector2(11, word_y + 54)])
	draw_cut(stone, engraving, Color("#13252576"), Color("#253738"), 1.1)
	stone.draw_line(engraving[3], engraving[2], Color(outline, 0.64), 1.1, true)
	draw_oath_etching(stone, stone.size * Vector2(0.461, 0.252), outline, offers[index])

func stone_points(stone: Control, normalized: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Vector2 in normalized:
		points.append(point * stone.size)
	return points

func draw_cut(stone: Control, shape: PackedVector2Array, fill: Color, ink: Color, weight: float) -> void:
	stone.draw_colored_polygon(shape, fill)
	var edge := shape.duplicate()
	edge.append(shape[0])
	stone.draw_polyline(edge, ink, weight, true)

func draw_oath_etching(stone: Control, center: Vector2, tint: Color, id: String) -> void:
	stone.draw_circle(center, 17, Color("#22363c"), true, -1, true)
	stone.draw_arc(center, 19, -0.2, TAU - 0.44, 39, Color(tint, 0.8), 1.0, true)
	stone.draw_arc(center + Vector2(0, 1.4), 15.5, 0.26, PI - 0.23, 16, Color("#8c88735f"), 0.9, true)
	if id in ["SWORE", "STOP", "NEAR", "POWER"]:
		stone.draw_polyline(PackedVector2Array([center + Vector2(-8, 8), center + Vector2(6, -9),
			center + Vector2(8, -10), center + Vector2(7, -5), center + Vector2(-5, 7)]), tint, 1.15, true)
		stone.draw_line(center + Vector2(-10, 1), center + Vector2(-2, 9), tint, 1.5, true)
	elif id in ["CAMP", "MIGHT", "FIGHT", "SHARK", "GOLD"]:
		stone.draw_polyline(PackedVector2Array([center + Vector2(-7, 5), center + Vector2(-6, -2),
			center + Vector2(-2, 0), center + Vector2(-1, -10), center + Vector2(5, -4),
			center + Vector2(4, -1), center + Vector2(9, -3), center + Vector2(7, 6),
			center + Vector2(0, 9), center + Vector2(-7, 5)]), tint, 1.35, true)
	else:
		var cut := PackedVector2Array([center + Vector2(0, -10), center + Vector2(8, 0),
			center + Vector2(0, 10), center + Vector2(-8, 0), center + Vector2(0, -10)])
		stone.draw_polyline(cut, tint, 1.35, true)
		stone.draw_line(center + Vector2(-8, 0), center + Vector2(8, 0), tint, 1.0, true)

func draw_rune_well(plate: Control, tint: Color, index: int) -> void:
	var active := index == selected
	var hover := Rect2(Vector2.ZERO, plate.size).has_point(plate.get_local_mouse_position())
	var shape := PackedVector2Array([Vector2(2, 0), Vector2(26, 0), Vector2(35, 8),
		Vector2(34, 45), Vector2(25, 50), Vector2(6, 49), Vector2(1, 42)])
	draw_cut(plate, shape, Color("#372b22") if active else Color("#262b2b"),
		tint if active or hover else tint.darkened(0.49), 1.1)
	plate.draw_line(Vector2(7, 44), Vector2(29, 43), Color(tint, 0.65 if active else 0.33), 1.0, true)
	if active:
		plate.draw_line(Vector2(3, 16), Vector2(3, 32), tint.lightened(0.16), 1.2, true)
		plate.draw_circle(Vector2(30, 5), 1.6, tint, true, -1, true)

func rarity_color(rarity: String) -> Color:
	match rarity:
		OathDatabase.EPIC:
			return SUN
		OathDatabase.RARE:
			return AMBER
		_:
			return SILVER

func rarity_name(rarity: String) -> String:
	match rarity:
		OathDatabase.EPIC:
			return "史诗 · 烈阳铭文"
		OathDatabase.RARE:
			return "稀有 · 琥珀铭文"
		_:
			return "普通 · 白银铭文"

func put_text(parent: Control, words: String, rect: Rect2, pixels: int, ink: Color,
		centered := false, heading := false) -> Label:
	var line := Label.new()
	line.position = rect.position
	line.size = rect.size
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.text = words
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_theme_font_override("font", HEADING if heading else FONT)
	line.add_theme_font_size_override("font_size", pixels)
	line.add_theme_color_override("font_color", ink)
	parent.add_child(line)
	return line

func make_button(parent: Control, words: String, rect: Rect2, action: Callable, tint := AMBER,
		rune := false) -> Button:
	var control := Button.new()
	control.position = rect.position
	control.size = rect.size
	control.text = words
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_font_override("font", HEADING if rune else FONT)
	control.add_theme_font_size_override("font_size", 35 if rune else 19)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color.TRANSPARENT if rune else Color("#473d2f") if state in ["hover", "pressed"] else Color("#322e25")
		plate.border_color = tint if state in ["hover", "focus", "pressed"] else tint.darkened(0.37)
		plate.set_border_width_all(0 if rune and state != "focus" else 1)
		plate.set_corner_radius_all(2 if rune else 4)
		control.add_theme_stylebox_override(state, plate)
	for role in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(role, tint)
	control.add_theme_color_override("font_disabled_color", tint.darkened(0.32))
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func clear_layer(layer: Control) -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.queue_free()
