extends Control

const FONT = preload("res://typeface.tres")
const HEADING = preload("res://heading.tres")
const FRAMING = preload("res://framing.gdshader")
const Art = preload("res://journal_art.gd")
const SIZE := Vector2(1280, 800)
const PALE := Color("#f0e1bd")
const MIST := Color("#cac2a1")
const AMBER := Color("#e3b47b")
const RED := Color("#ff9681")
const INK := Color("#382f25")
const SECONDARY_INK := Color("#594935")
const CARD_NAMES := ["铜镜折射", "强光提灯", "火油陷阱"]
const CARD_COPY := ["提灯背后多一道短光束。\n前后两侧都能照出影魔。",
	"提灯照得更远。\n异兽在光中更快灼尽。",
	"每波按 Q 在脚下布下陷阱。\n火油灼烧经过的异兽。"]

var game
var presentation: Control
var play_layer: Control
var pause_layer: Control
var phase_title: Label
var time_label: Label
var hp_label: Label
var hp_meter: Art
var supplies: Label
var instruction: Label
var phase_track: Art
var wave_line: Label
var alert: Label
var prompt: Label
var announcement: Control
var dawn_time: Label
var alert_tween: Tween
var banner_tween: Tween
var hit_fade: Tween
var danger: ColorRect

func _ready() -> void:
	size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	var vignette := fill(self, Rect2(Vector2.ZERO, SIZE), Color.WHITE)
	var material := ShaderMaterial.new()
	material.shader = FRAMING
	vignette.material = material
	danger = fill(self, Rect2(Vector2.ZERO, SIZE), Color("#a5271400"))
	presentation = Control.new()
	presentation.size = SIZE
	presentation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(presentation)

func show_title() -> void:
	clear()
	var shade := fill(presentation, Rect2(Vector2.ZERO, SIZE), Color("#101c1827"))
	var crest := art(shade, Art.Type.COVER, Rect2(59, 161, 293, 422))
	text(crest, "长夜\n守望者", 58, Vector2(37, 33), PALE, true)
	text(crest, "破败石堡的第一夜", 21, Vector2(37, 213), MIST, true)
	button(crest, "开始守夜    ↵", Rect2(33, 286, 215, 53), game.start_level)
	button(crest, "退出", Rect2(33, 349, 107, 44), quit_game)
	text(shade, "WASD / 方向键  移动\n鼠标  照明方向    E  交互", 16, Vector2(74, 686), MIST)

func show_play() -> void:
	clear()
	play_layer = Control.new()
	play_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_layer.size = SIZE
	presentation.add_child(play_layer)
	var journal := art(play_layer, Art.Type.COVER, Rect2(23, 24, 243, 353))
	text(journal, "巡夜簿", 25, Vector2(39, 19), PALE, true)
	text(journal, "第一夜" if game.night_number == 1 else "第二夜",
		15, Vector2(163, 27), AMBER, true)
	phase_track = art(journal, Art.Type.WATCH, Rect2(40, 69, 99, 99))
	time_label = centered(phase_track, "01:30", 22, Rect2(4, 36, 91, 33), PALE, true)
	phase_title = text(journal, "黄昏", 21, Vector2(146, 88), PALE, true)
	wave_line = text(journal, "", 14, Vector2(147, 120), AMBER)
	text(journal, "篝火", 18, Vector2(40, 187), PALE, true)
	hp_label = text(journal, "100 / 100", 17, Vector2(145, 188), AMBER)
	hp_meter = art(journal, Art.Type.FUEL, Rect2(37, 220, 180, 22))
	art(journal, Art.Type.WOOD, Rect2(40, 251, 28, 24))
	supplies = text(journal, "", 16, Vector2(73, 253), PALE)
	instruction = copy(journal, "", 15, Rect2(39, 292, 179, 49), MIST)
	if game.upgrade != 0:
		var note := art(play_layer, Art.Type.TAB, Rect2(1024, 29, 221, 62))
		centered(note, CARD_NAMES[game.upgrade - 1], 22, Rect2(16, 13, 188, 35), PALE, true)
		if game.upgrade == 3:
			text(play_layer, "Q  布置陷阱", 15, Vector2(1129, 101), PALE)
	var menu := button(play_layer, "ESC  暂停", Rect2(1117, 728, 127, 42), toggle_pause)
	menu.focus_mode = Control.FOCUS_NONE
	text(play_layer, "WASD / 方向键   移动\n鼠标   提灯照明", 15, Vector2(34, 720), MIST)
	var action := art(play_layer, Art.Type.TAB, Rect2(529, 725, 221, 45))
	var key_cap := art(action, Art.Type.TAB, Rect2(21, 5, 36, 35))
	centered(key_cap, "E", 17, Rect2(0, 1, 36, 30), PALE, true)
	prompt = text(action, "", 17, Vector2(69, 10), PALE)
	alert = centered(play_layer, "", 17, Rect2(473, 679, 333, 38), AMBER)
	update_status()

func update_status() -> void:
	if is_instance_valid(dawn_time):
		dawn_time.text = "抽牌  " + clock_text(game.phase_left)
	if not is_instance_valid(play_layer):
		return
	var limit := 90.0 if game.phase == 1 else 60.0
	match game.phase:
		1:
			phase_title.text = "黄昏"
			wave_line.text = "拾柴备夜"
			instruction.text = "靠近木柴或断墙按 E。\n留些柴，夜里能添火。"
		2:
			phase_title.text = "第一波"
			wave_line.text = "异兽  %d" % game.enemies_remaining()
			instruction.text = "移动鼠标照出影魔。\n在光内持续灼烧。"
		3:
			phase_title.text = "第二波"
			wave_line.text = "异兽  %d" % game.enemies_remaining()
			instruction.text = "篝火正在衰减。\n优先拦截噬火蛾。"
	time_label.text = clock_text(game.phase_left)
	time_label.modulate = RED if game.phase_left <= 12.0 else Color.WHITE
	phase_track.progress = clampf(game.phase_left / limit, 0.0, 1.0)
	phase_track.symbol = game.phase
	phase_track.queue_redraw()
	hp_label.text = "%d / 100" % ceili(game.camp.hp)
	hp_label.modulate = RED if game.camp.hp <= 28.0 else Color.WHITE
	hp_meter.progress = game.camp.ratio()
	hp_meter.queue_redraw()
	supplies.text = "木柴 %d  ·  地上 %d" % [game.inventory, game.wood_available.count(true)]
	var focus: Dictionary = game.interaction()
	prompt.get_parent().visible = not focus.is_empty()
	if not focus.is_empty():
		prompt.text = focus["label"]

func flash(words: String, subtitle: String) -> void:
	if is_instance_valid(announcement):
		announcement.queue_free()
	if is_instance_valid(banner_tween):
		banner_tween.kill()
	announcement = art(presentation, Art.Type.PAPER, Rect2(406, 46, 468, 92))
	centered(announcement, words, 28, Rect2(15, 12, 438, 42), INK, true)
	centered(announcement, subtitle, 15, Rect2(18, 52, 432, 29), SECONDARY_INK)
	announcement.modulate.a = 0.0
	banner_tween = create_tween()
	banner_tween.tween_property(announcement, "modulate:a", 1.0, 0.25)
	banner_tween.tween_interval(1.75)
	banner_tween.tween_property(announcement, "modulate:a", 0.0, 0.55)
	banner_tween.tween_callback(announcement.queue_free)

func notify(words: String) -> void:
	if not is_instance_valid(alert):
		return
	if is_instance_valid(alert_tween):
		alert_tween.kill()
	alert.text = words
	alert.modulate.a = 1.0
	alert_tween = create_tween()
	alert_tween.tween_interval(1.3)
	alert_tween.tween_property(alert, "modulate:a", 0.0, 0.32)

func fire_hit() -> void:
	if is_instance_valid(hit_fade):
		hit_fade.kill()
	danger.color.a = 0.23
	hit_fade = create_tween()
	hit_fade.tween_property(danger, "color:a", 0.0, 0.42)

func show_cards() -> void:
	clear()
	var dim := fill(presentation, Rect2(Vector2.ZERO, SIZE), Color("#1018168c"))
	var board := art(dim, Art.Type.COVER, Rect2(179, 164, 921, 468))
	text(board, "破晓", 46, Vector2(44, 24), PALE, true)
	text(board, "选一项强化，带进第二夜。", 19, Vector2(169, 52), MIST)
	dawn_time = text(board, "", 20, Vector2(726, 55), AMBER, true)
	for index in range(3):
		var card := button(board, "", Rect2(47 + index * 288, 118, 247, 305), game.choose_card.bind(index + 1), Art.Type.CARD, index)
		centered(card, CARD_NAMES[index], 28, Rect2(16, 156, 215, 49), INK, true)
		var details := copy(card, CARD_COPY[index], 16, Rect2(16, 219, 215, 64), SECONDARY_INK)
		details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.modulate.a = 0.0
		var arrival := create_tween()
		arrival.tween_interval(0.058 * index)
		arrival.tween_property(card, "modulate:a", 1.0, 0.21)
	update_status()

func show_result(success: bool, explanation: String) -> void:
	clear()
	var dim := fill(presentation, Rect2(Vector2.ZERO, SIZE), Color("#080d10a0"))
	var note := art(dim, Art.Type.PAPER, Rect2(349, 228, 582, 342))
	text(note, "巡夜记录", 17, Vector2(38, 32), SECONDARY_INK, true)
	text(note, "两夜终明" if success else "守夜失败", 51, Vector2(36, 71), INK, true)
	copy(note, explanation, 21, Rect2(40, 160, 493, 64), SECONDARY_INK)
	button(note, "重新守夜", Rect2(39, 243, 178, 50), game.start_level)
	button(note, "返回标题", Rect2(231, 243, 178, 50), game.show_title)

func toggle_pause() -> void:
	if game.paused:
		game.paused = false
		remove_child(pause_layer)
		pause_layer.queue_free()
		pause_layer = null
		return
	game.paused = true
	pause_layer = fill(self, Rect2(Vector2.ZERO, SIZE), Color("#081011ca"))
	pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var journal := art(pause_layer, Art.Type.COVER, Rect2(400, 174, 481, 451))
	var page := art(journal, Art.Type.PAPER, Rect2(28, 26, 426, 393))
	text(page, "夜巡暂停", 38, Vector2(23, 24), INK, true)
	text(page, "WASD / 方向键  移动\n鼠标  决定提灯方向\nE  拾木柴、修墙或给篝火添柴", 18, Vector2(24, 106), SECONDARY_INK)
	var resume := button(page, "继续守夜   ESC", Rect2(21, 218, 185, 49), toggle_pause)
	button(page, "返回标题", Rect2(212, 218, 188, 49), game.show_title)
	var audio := button(page, "声音：关" if game.muted else "声音：开", Rect2(21, 290, 185, 49), toggle_sound)
	audio.name = "Audio"
	button(page, "退出", Rect2(212, 290, 188, 49), quit_game)
	resume.grab_focus()

func toggle_sound() -> void:
	game.toggle_audio()
	var audio := pause_layer.find_child("Audio", true, false) as Button
	audio.text = "声音：关" if game.muted else "声音：开"

func clear() -> void:
	for tween in [banner_tween, alert_tween]:
		if is_instance_valid(tween):
			tween.kill()
	for child in presentation.get_children():
		presentation.remove_child(child)
		child.queue_free()
	if is_instance_valid(pause_layer):
		remove_child(pause_layer)
		pause_layer.queue_free()
	pause_layer = null
	dawn_time = null
	play_layer = null
	alert = null
	announcement = null

func quit_game() -> void:
	game.quit_game()

func clock_text(seconds: float) -> String:
	var ticks := ceili(seconds)
	return "%02d:%02d" % [floori(ticks / 60.0), ticks % 60]

func fill(parent: Control, rect: Rect2, ink: Color) -> ColorRect:
	var node := ColorRect.new()
	node.color = ink
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node

func art(parent: Control, kind: Art.Type, rect: Rect2) -> Art:
	var node := Art.new()
	node.kind = kind
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node

func text(parent: Control, words: String, pixels: int, origin: Vector2, ink: Color, heading := false) -> Label:
	var node := Label.new()
	node.text = words
	node.add_theme_font_override("font", HEADING if heading else FONT)
	node.add_theme_font_size_override("font_size", pixels)
	node.add_theme_color_override("font_color", ink)
	node.add_theme_constant_override("line_spacing", 5)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = origin
	return node

func centered(parent: Control, words: String, pixels: int, rect: Rect2, ink: Color, heading := false) -> Label:
	var line := text(parent, words, pixels, rect.position, ink, heading)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.size = rect.size
	return line

func copy(parent: Control, words: String, pixels: int, rect: Rect2, ink: Color) -> Label:
	var line := text(parent, "", pixels, rect.position, ink)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size = rect.size
	line.text = words
	return line

func button(parent: Control, words: String, rect: Rect2, action: Callable, kind := Art.Type.TAB, symbol := 0) -> Button:
	var node := Button.new()
	node.text = words
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", 17)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		node.add_theme_color_override(state, PALE)
	for skin in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		node.add_theme_stylebox_override(skin, StyleBoxEmpty.new())
	node.pressed.connect(action)
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	var plate := art(node, kind, Rect2(Vector2.ZERO, rect.size))
	plate.symbol = symbol
	plate.show_behind_parent = true
	if kind == Art.Type.CARD:
		node.set_meta("rest_position", rect.position)
	node.mouse_entered.connect(highlight.bind(node, plate, true))
	node.mouse_exited.connect(highlight.bind(node, plate, false))
	node.focus_entered.connect(highlight.bind(node, plate, true))
	node.focus_exited.connect(highlight.bind(node, plate, false))
	return node

func highlight(node: Button, plate: Art, active: bool) -> void:
	var selected := active or node.has_focus()
	plate.highlighted = selected
	if plate.kind == Art.Type.CARD:
		var origin: Vector2 = node.get_meta("rest_position")
		node.position = origin + Vector2(0, -5 if selected else 0)
	plate.queue_redraw()
