extends Node2D

enum Stage { INTRO, ARCHIVE, PRUNE, CONTACT, SCAN, KEEP, SAVED, LOST, NEXT }

const ROOM_ART = preload("res://room_art.gd")
const CAM_ART = preload("res://camera_art.gd")
const CRT = preload("res://crt.gdshader")
const CAMERA_SHADER = preload("res://camera.gdshader")
const WALLPAPER_SHADER = preload("res://wallpaper.gdshader")
const FONTS = preload("res://typeface.tres")
const SIZE := Vector2(1376, 768)
const ICE := Color("#c1cbd0")
const MUTED := Color("#8b9da4")
const GREEN := Color("#a6efbb")
const RED := Color("#fe6156")
const BLACK := Color("#080d10")
const ARCHIVE_TIME := 180.0
const PURGE_TIME := 45.0
const CUT_DURATION := 0.62
const SIGNAL_DELAY := 1.35
const FIRST_LINE := "> 别删我。这里太冷了，你在外面吗？"
const LETTER := "城门还在，灯还亮着。换岗的人若到了，就告诉他们，今夜我在。"

var stage := Stage.INTRO
var total_left := ARCHIVE_TIME
var purge_left := -1.0
var seen: Dictionary = {}
var typed := 0.0
var clock := 0.0
var paused := false
var closing := false
var muted := false
var prune_selected := false
var prune_elapsed := -1.0
var anomaly_view: Texture2D
var clean_view: Texture2D
var guard_view: Texture2D

var ui: Control
var picture: TextureRect
var prune_caption: Label
var prune_button: Button
var deselect_button: Button
var terminal: Panel
var field: LineEdit
var transcript: RichTextLabel
var prompt: Label
var countdown: Label
var purge_clock: Label
var timecode: Label
var camera_snow: Node2D
var target_box: Control
var pause_layer: Control
var effects: Node2D
var sound: AudioStreamPlayer
var ambience: AudioStreamPlayer
var window_locations: Dictionary = {}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_window().min_size = Vector2i(740, 414)
	get_window().title = "跨时空守望 · 零号档案"
	sound = AudioStreamPlayer.new()
	add_child(sound)
	ambience = AudioStreamPlayer.new()
	var loop: AudioStreamWAV = load("res://audio/room.wav").duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = loop.data.size() / 2
	ambience.stream = loop
	ambience.volume_db = -14
	add_child(ambience)
	ambience.play()
	show_intro()

func _process(delta: float) -> void:
	if paused:
		return
	clock += delta
	if stage in [Stage.ARCHIVE, Stage.PRUNE, Stage.CONTACT, Stage.SCAN, Stage.KEEP]:
		total_left = maxf(0.0, total_left - delta)
		if purge_left >= 0.0:
			purge_left = maxf(0.0, purge_left - delta)
		if total_left == 0.0 or purge_left == 0.0:
			finish(false)
			return
	if stage == Stage.PRUNE and prune_elapsed >= 0.0:
		advance_pruning(delta)
		if stage == Stage.CONTACT:
			return
	update_hud()
	if stage == Stage.CONTACT and typed < FIRST_LINE.length():
		var before := int(typed)
		typed = minf(FIRST_LINE.length(), typed + delta * 23.0)
		if int(typed) != before:
			transcript.text = FIRST_LINE.left(int(typed))
			if int(typed) % 4 == 0:
				play_sound("key", -15)
	if is_instance_valid(effects):
		effects.queue_redraw()
	if is_instance_valid(camera_snow):
		camera_snow.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if paused or stage != Stage.INTRO:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
		start_level()

func show_intro() -> void:
	stage = Stage.INTRO
	window_locations.clear()
	rebuild_base()
	ui.add_child(ROOM_ART.new())
	var title := solid(ui, Rect2(84, 205, 546, 346), Color.TRANSPARENT)
	solid(title, Rect2(0, 0, 42, 2), Color("#82a6a7"))
	label(title, "2026  /  23:48  /  旧数据中心", 18, Vector2(0, 23), Color("#adc4c3"))
	label(title, "跨时空守望", 62, Vector2(-4, 64), Color("#edf4ef"))
	label(title, "零号档案：永昌堡的雪夜", 25, Vector2(0, 179), Color("#bfcad0"))
	label(title, "核对档案，剪除雪夜影像里的错位物件。", 16, Vector2(0, 219), Color("#adc4c3"))
	button(title, "接入监视器   ↵", Rect2(0, 254, 211, 50), start_level)
	button(title, "退出", Rect2(226, 254, 93, 50), quit_game)
	add_crt()

func start_level() -> void:
	play_sound("boot")
	stage = Stage.ARCHIVE
	total_left = ARCHIVE_TIME
	purge_left = -1.0
	prune_elapsed = -1.0
	prune_selected = false
	typed = 0.0
	seen.clear()
	window_locations.clear()
	if anomaly_view == null:
		anomaly_view = CAM_ART.gate()
		clean_view = CAM_ART.pruned()
		guard_view = CAM_ART.guard()
	show_desktop()

func show_desktop() -> void:
	rebuild_base()
	var dialogue := stage in [Stage.CONTACT, Stage.SCAN, Stage.KEEP]
	var next_level := stage == Stage.NEXT
	solid(ui, Rect2(Vector2.ZERO, SIZE), Color("#060b0d"))
	var bezel := panel(ui, Rect2(20, 20, 1336, 729), Color("#131b20"), Color("#28343a"), 23)
	var screen := panel(bezel, Rect2(19, 18, 1298, 691), Color("#172229"), Color("#090e12"), 17)
	screen.clip_contents = true
	make_wallpaper(screen, dialogue)
	solid(screen, Rect2(0, 0, 1298, 33), Color("#1b252a"))
	solid(screen, Rect2(0, 32, 1298, 1), Color("#52636a"))
	label(screen, "⬡  WATCH OS   /   LOCAL", 16, Vector2(15, 6), MUTED)
	label(screen, "数据中心  /  值班终端", 15, Vector2(1040, 6), MUTED)
	solid(screen, Rect2(0, 661, 1298, 30), Color("#303c40"))
	solid(screen, Rect2(0, 661, 1298, 2), Color("#647276"))
	label(screen, "终端   |   监控   |   档案", 14, Vector2(15, 667), ICE)
	label(screen, "ESC  系统菜单", 14, Vector2(1152, 667), ICE)

	desktop_icon(screen, "▤", "档案", Vector2(17, 54), show_archive_window)
	desktop_icon(screen, "▣", "监控", Vector2(17, 140), show_camera_window)
	desktop_icon(screen, "⌘", "终端", Vector2(17, 226), focus_terminal)

	var files := make_window(screen, "文件系统", Rect2(517, 200, 379, 312), false)
	label(files, "▸  archive\n\n▸  cam\n\n▸  consoles\n\n▸  recovery", 18, Vector2(20, 47), Color("#778c94"))
	create_archive(screen, next_level)
	if dialogue:
		screen.get_node("Archive").hide()
	create_camera(screen, dialogue, next_level)
	if dialogue:
		create_terminal(screen)
	add_timer(screen)
	add_crt()
	update_hud()

func rebuild_base() -> void:
	if is_instance_valid(ui):
		remove_child(ui)
		ui.queue_free()
	ui = Control.new()
	ui.size = SIZE
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	picture = null
	prune_caption = null
	prune_button = null
	deselect_button = null
	terminal = null
	field = null
	transcript = null
	prompt = null
	countdown = null
	purge_clock = null
	timecode = null
	camera_snow = null
	target_box = null
	pause_layer = null
	effects = null
	paused = false

func make_wallpaper(screen: Control, dialogue: bool) -> void:
	var surface := solid(screen, Rect2(0, 33, 1298, 628), Color.WHITE)
	var material := ShaderMaterial.new()
	material.shader = WALLPAPER_SHADER
	material.set_shader_parameter("contact", dialogue)
	surface.material = material

func create_archive(screen: Control, next_level: bool) -> void:
	var archive := make_window(screen, "▤  LOG-042.txt" if next_level else "▤  LOG-041.txt",
		Rect2(72, 47, 493, 579), true)
	archive.name = "Archive"
	var body := panel(archive, Rect2(10, 38, 473, 530), Color("#0d171d"), Color("#3b4a51"))
	label(body, "01  核对档案" if stage == Stage.ARCHIVE else "巡检档案 / 夜班记录", 16, Vector2(20, 18), MUTED)
	solid(body, Rect2(20, 52, 430, 1), Color("#40575f"))
	if next_level:
		label(body, "下一关 · 未知回波", 27, Vector2(20, 74), ICE)
		wrapped_label(body, "零号档案已封存。清除指令结束后，监控线路再次接通。\n\n另一段回波来自城门外。那里还有一盏灯。", 21,
			Rect2(20, 128, 426, 200), ICE)
		button(body, "重玩零号档案", Rect2(20, 430, 170, 45), start_level)
		return
	label(body, "历史档案 / 温州龙湾", 27, Vector2(20, 74), ICE)
	wrapped_label(body, "明代海防城堡。雪夜巡检图应有石砌城门、木门楼和守军。先确认档案地点。", 20,
		Rect2(20, 124, 418, 93), ICE)
	var place := button(body, "永昌堡", Rect2(20, 227, 181, 42), choose_clue.bind("永昌堡"))
	style_clue(place, seen.has("永昌堡"))
	wrapped_label(body, "CAM-08 的影像由档案重建。系统报码 0x8041_ERR，说明画面里混入了一件时代不符的物品。", 20,
		Rect2(20, 292, 413, 106), ICE)
	var code := button(body, "0x8041_ERR", Rect2(20, 415, 181, 42), choose_clue.bind("0x8041_ERR"))
	style_clue(code, seen.has("0x8041_ERR"))
	var hint := "已核对 2 / 2 · 转到右侧监控剪枝" if seen.size() == 2 else "已核对 %d / 2 · 点击两个高亮词条" % seen.size()
	var progress := label(body, hint, 15, Vector2(20, 485), MUTED)
	progress.name = "Progress"

func choose_clue(value: String) -> void:
	if stage != Stage.ARCHIVE or seen.has(value):
		return
	seen[value] = true
	play_sound("key")
	if seen.size() == 2:
		stage = Stage.PRUNE
		show_desktop()
		raise_window("Camera")
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button:
			style_clue(focused, true)
		var progress := ui.find_child("Progress", true, false) as Label
		progress.text = "已核对 1 / 2 · 点击另一个高亮词条"

func create_camera(screen: Control, dialogue: bool, next_level: bool) -> void:
	var camera_rect := Rect2(626, 103, 650, 526)
	if dialogue:
		camera_rect = Rect2(134, 79, 707, 531)
	var window := make_window(screen, "▣  CAM-08  SECURITY" if not dialogue else "▣  CCTV / CAM-08",
		camera_rect, true)
	window.name = "Camera"
	var frame := panel(window, Rect2(11, 38, camera_rect.size.x - 22, camera_rect.size.y - 52),
		Color("#0b1216"), Color("#98a4a8"))
	frame.clip_contents = true
	var shot_size := frame.size - Vector2(4, 4)
	var shot := guard_view if dialogue or stage == Stage.SAVED else clean_view if next_level or prune_elapsed >= CUT_DURATION else anomaly_view
	picture = add_image(frame, shot, Rect2(Vector2(2, 2), shot_size))
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	material.shader = CAMERA_SHADER
	material.set_shader_parameter("preserved", stage == Stage.SAVED or next_level)
	material.set_shader_parameter("contact", dialogue)
	picture.material = material
	if stage == Stage.PRUNE:
		material.set_shader_parameter("clean_view", clean_view)
		picture.mouse_filter = Control.MOUSE_FILTER_STOP
		picture.mouse_default_cursor_shape = Control.CURSOR_CROSS
		picture.gui_input.connect(select_anomaly)
		add_target_box(frame, shot_size)
	if next_level:
		solid(frame, Rect2(2, 2, shot_size.x, shot_size.y), Color("#14242b72"))
		label(frame, "第二路回波 / 已接收", 22, Vector2(26, shot_size.y - 64), GREEN)
	camera_snow = Node2D.new()
	frame.add_child(camera_snow)
	camera_snow.draw.connect(draw_snow.bind(camera_snow, shot_size))

	var tag := solid(frame, Rect2(6, 6, 199, 35), Color("#081017db"))
	label(tag, "CAM-08   •   REC", 18, Vector2(10, 6), GREEN if stage == Stage.SAVED or next_level else RED)
	var time_tag := solid(frame, Rect2(shot_size.x - 138, shot_size.y - 37, 134, 32), Color("#081017e4"))
	timecode = label(time_tag, "00:00:00", 17, Vector2(15, 4), ICE)
	if stage == Stage.SAVED:
		var status_box := solid(frame, Rect2(shot_size.x - 287, 6, 278, 36), Color("#091911eb"))
		label(status_box, "守军信号  /  已保留", 18, Vector2(11, 6), GREEN)
	if stage in [Stage.ARCHIVE, Stage.PRUNE]:
		add_prune_controls(frame, shot_size)

func add_target_box(frame: Control, shot_size: Vector2) -> void:
	var bounds: Rect2 = CAM_ART.MACHINE_BOUNDS.grow(0.01)
	var box_size := shot_size * bounds.size
	var location := Vector2(2, 2) + shot_size * bounds.position
	var tint := RED
	target_box = solid(frame, Rect2(location, box_size), Color(tint, 0.08))
	target_box.hide()
	var arm := 18.0
	for x in [0.0, box_size.x - 2.0]:
		for y in [0.0, box_size.y - 2.0]:
			solid(target_box, Rect2(x, y if y == 0.0 else y - arm, 2, arm + 2), tint)
			solid(target_box, Rect2(x if x == 0.0 else x - arm, y, arm + 2, 2), tint)
	var tag := solid(target_box, Rect2(-34, -29, box_size.x + 68, 23), Color("#091016d6"))
	var caption := wrapped_label(tag, "时代错位 · 现代机柜", 13, Rect2(0, 2, tag.size.x, 19), tint)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func add_prune_controls(frame: Control, shot_size: Vector2) -> void:
	var shelf := panel(frame, Rect2(6, shot_size.y - 46, shot_size.x - 149, 42), Color("#111d22ef"), Color("#536c72"))
	prune_caption = label(shelf, "先核对左侧的两个档案词条", 16, Vector2(10, 9), ICE)
	if stage != Stage.PRUNE:
		return
	label(frame, "02  异常剪枝", 14, Vector2(shot_size.x - 114, 12), Color("#fff1cc"))
	prune_button = button(shelf, "确认剪除", Rect2(shelf.size.x - 176, 4, 103, 33), confirm_pruning)
	deselect_button = button(shelf, "取消", Rect2(shelf.size.x - 66, 4, 59, 33), reset_selection)
	prune_button.add_theme_font_size_override("font_size", 15)
	prune_button.add_theme_color_override("font_color", Color("#ffe2cb"))
	prune_button.add_theme_stylebox_override("normal", style(Color("#55352d"), Color("#b9745d")))
	prune_button.add_theme_stylebox_override("hover", style(Color("#784a39"), Color("#ffc18f")))
	deselect_button.add_theme_font_size_override("font_size", 15)
	reset_selection()

func select_anomaly(event: InputEvent) -> void:
	if paused or stage != Stage.PRUNE or prune_elapsed >= 0.0:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var point: Vector2 = event.position / picture.size
	if not CAM_ART.MACHINE_BOUNDS.grow(0.007).has_point(point):
		reset_selection()
		prune_caption.text = "保留这部分。找一个不属于明代的物件。"
		return
	prune_selected = true
	target_box.show()
	prune_button.show()
	deselect_button.show()
	prune_caption.text = "现代机柜 · 可剪除"
	play_sound("scan", -8)

func reset_selection() -> void:
	prune_selected = false
	target_box.hide()
	prune_button.hide()
	deselect_button.hide()
	prune_caption.text = "点击监控里与档案不符的物件"

func confirm_pruning() -> void:
	if paused or stage != Stage.PRUNE or not prune_selected or prune_elapsed >= 0.0:
		return
	prune_elapsed = 0.0
	prune_button.hide()
	deselect_button.hide()
	prune_caption.text = "正在从重建影像中剪除机柜…"
	play_sound("scan")

func advance_pruning(delta: float) -> void:
	prune_elapsed += delta
	if prune_elapsed >= CUT_DURATION:
		if picture.texture != clean_view:
			picture.texture = clean_view
			picture.material.set_shader_parameter("cut_progress", 0.0)
			target_box.hide()
			prune_caption.text = "机柜已剪除。监控收到新的回声。"
	else:
		picture.material.set_shader_parameter("cut_progress", prune_elapsed / CUT_DURATION)
		target_box.modulate.a = 1.0 - prune_elapsed / CUT_DURATION
	if prune_elapsed >= SIGNAL_DELAY:
		stage = Stage.CONTACT
		window_locations.clear()
		show_desktop()
		terminal.modulate = Color(0.6, 1, 0.78, 0.25)
		create_tween().tween_property(terminal, "modulate", Color.WHITE, 0.32)
		play_sound("boot", -8)

func create_terminal(screen: Control) -> void:
	terminal = make_window(screen, "⌘  TERMINAL   /   TTY-01", Rect2(644, 208, 534, 345), true)
	terminal.name = "Terminal"
	var inner := panel(terminal, Rect2(9, 37, 516, 296), Color("#030a08"), Color("#687772"))
	transcript = RichTextLabel.new()
	transcript.add_theme_font_override("normal_font", FONTS)
	transcript.add_theme_font_size_override("normal_font_size", 21)
	transcript.add_theme_color_override("default_color", GREEN)
	transcript.scroll_following = true
	transcript.position = Vector2(17, 17)
	transcript.size = Vector2(483, 166)
	transcript.mouse_filter = Control.MOUSE_FILTER_PASS
	inner.add_child(transcript)
	field = LineEdit.new()
	field.position = Vector2(35, 187)
	field.size = Vector2(460, 45)
	field.placeholder_text = "输入指令，按 Enter 发送"
	field.max_length = 90
	field.keep_editing_on_text_submit = true
	field.add_theme_font_override("font", FONTS)
	field.add_theme_font_size_override("font_size", 20)
	field.add_theme_color_override("font_color", GREEN)
	field.add_theme_color_override("font_placeholder_color", Color("#8bb398"))
	field.add_theme_color_override("caret_color", GREEN)
	field.add_theme_stylebox_override("normal", style(Color("#0b1511"), Color("#284537")))
	field.add_theme_stylebox_override("focus", style(Color("#101b15"), Color("#77ac89")))
	field.text_submitted.connect(submit_command)
	inner.add_child(field)
	label(inner, ">", 22, Vector2(13, 191), GREEN)
	prompt = label(inner, "回应   who are you  /  status", 17, Vector2(17, 251), Color("#84b899"))
	field.call_deferred("grab_focus")

func submit_command(value: String) -> void:
	var command := " ".join(value.to_lower().strip_edges().split(" ", false))
	if command.is_empty():
		return
	field.clear()
	play_sound("key")
	if stage == Stage.CONTACT and typed < FIRST_LINE.length():
		typed = FIRST_LINE.length()
		transcript.text = FIRST_LINE
	transcript.add_text("\n\n$ " + command)
	if stage == Stage.CONTACT and command in ["who are you", "status"]:
		stage = Stage.SCAN
		purge_left = PURGE_TIME
		append_line("[AV-SYS] Threat PID: 8041 will be purged in 45s!", RED)
		append_line("守军：帮我把这道信号锁住。", GREEN)
		prompt.text = "锁定 CAM-08   scan --cam 08"
		play_sound("alert")
	elif stage == Stage.SCAN and command == "scan --cam 08":
		stage = Stage.KEEP
		append_line("CAM-08 已锁定。目标与 PID 8041 匹配。", GREEN)
		prompt.text = "保留目标   keep --pid 8041"
		play_sound("scan")
	elif stage == Stage.KEEP and command == "keep --pid 8041":
		finish(true)
	elif command == "keep --pid 8041" and stage == Stage.SCAN:
		append_line("目标尚未锁定。请先扫描 CAM-08。", RED)
	else:
		append_line("未识别或当前不可用。请查看终端底部指引。", Color("#edb19c"))

func append_line(message: String, ink: Color) -> void:
	transcript.push_color(ink)
	transcript.add_text("\n" + message)
	transcript.pop()

func finish(success: bool) -> void:
	stage = Stage.SAVED if success else Stage.LOST
	window_locations.clear()
	show_desktop()
	play_sound("save" if success else "fault")
	var filter := solid(ui, Rect2(Vector2.ZERO, SIZE), Color("#0206087d") if success else Color("#052252b7"))
	filter.mouse_filter = Control.MOUSE_FILTER_STOP
	effects = Node2D.new()
	filter.add_child(effects)
	effects.draw.connect(draw_static.bind(effects))
	var box := make_window(ui, "AV-SYS   /   ARCHIVE RESULT", Rect2(390, 251, 596, 311), false)
	label(box, "档案已锁存" if success else "数据已抹除", 35, Vector2(25, 66), GREEN if success else Color("#bfdcff"))
	wrapped_label(box, "守军遗言\n" + LETTER if success else "系统已清除 PID 8041。CAM-08 失去信号。",
		21, Rect2(25, 127, 544, 86), ICE)
	button(box, "RETRY", Rect2(26, 236, 141, 44), start_level)
	if success:
		button(box, "NEXT LEVEL", Rect2(179, 236, 173, 44), open_next_level)
	else:
		button(box, "返回标题", Rect2(179, 236, 173, 44), show_intro)
	add_crt()

func open_next_level() -> void:
	stage = Stage.NEXT
	window_locations.clear()
	play_sound("boot")
	show_desktop()

func draw_static(layer: Node2D) -> void:
	if stage != Stage.LOST:
		return
	var random := RandomNumberGenerator.new()
	random.seed = int(clock * 14.0) + 8041
	for index in range(565):
		var dot := Vector2(random.randf_range(0, SIZE.x), random.randf_range(0, SIZE.y))
		layer.draw_rect(Rect2(dot, Vector2(random.randf_range(1, 13), random.randf_range(1, 3))),
			Color(0.7, 0.83, 1, random.randf_range(0.06, 0.37)))
	for index in range(8):
		var y := random.randf_range(20, 748)
		layer.draw_rect(Rect2(0, y, SIZE.x, random.randf_range(1, 5)), Color(0.43, 0.69, 1, 0.18))

func add_timer(screen: Control) -> void:
	var block := panel(screen, Rect2(1063, 44, 208, 55), Color("#070d10"), Color("#6d8187"))
	label(block, "任务剩余", 13, Vector2(11, 6), MUTED)
	countdown = label(block, "03:00", 26, Vector2(107, 8), ICE)
	purge_clock = label(block, "", 13, Vector2(11, 30), RED)

func update_hud() -> void:
	if is_instance_valid(countdown):
		countdown.text = "—:—" if stage == Stage.NEXT else time_text(total_left)
		countdown.modulate = RED if total_left < 25.0 and stage not in [Stage.SAVED, Stage.NEXT] else Color.WHITE
		purge_clock.text = "清除 " + time_text(purge_left) if purge_left >= 0.0 and stage in [Stage.SCAN, Stage.KEEP] else ""
	if is_instance_valid(timecode):
		var seconds := clampi(int(ARCHIVE_TIME - total_left), 0, 180)
		timecode.text = "23:%02d:%02d" % [48 + seconds / 60, seconds % 60]
	if is_instance_valid(picture):
		picture.material.set_shader_parameter("signal_clock", clock)

func time_text(seconds: float) -> String:
	var whole := ceili(seconds)
	return "%02d:%02d" % [whole / 60, whole % 60]

func show_archive_window() -> void:
	raise_window("Archive")

func show_camera_window() -> void:
	raise_window("Camera")

func focus_terminal() -> void:
	if is_instance_valid(field):
		raise_window("Terminal")
		field.grab_focus()

func raise_window(window_name: String) -> void:
	var target := ui.find_child(window_name, true, false) as Control
	if is_instance_valid(target):
		target.show()
		target.move_to_front()
		play_sound("key", -12)

func toggle_pause() -> void:
	if paused:
		pause_layer.queue_free()
		pause_layer = null
		paused = false
		if is_instance_valid(field):
			field.grab_focus()
		return
	paused = true
	pause_layer = solid(ui, Rect2(Vector2.ZERO, SIZE), Color("#050b10b9"))
	pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := make_window(pause_layer, "WATCH OS   /   系统菜单", Rect2(478, 255, 420, 258), false)
	label(box, "已暂停", 32, Vector2(26, 57), ICE)
	var resume := button(box, "继续   ESC", Rect2(26, 114, 171, 44), toggle_pause)
	button(box, "返回标题", Rect2(213, 114, 181, 44), show_intro)
	var audio := button(box, "声音：关" if muted else "声音：开", Rect2(26, 174, 171, 44), toggle_audio)
	audio.name = "Audio"
	button(box, "退出", Rect2(213, 174, 181, 44), quit_game)
	resume.grab_focus()

func toggle_audio() -> void:
	muted = not muted
	ambience.stream_paused = muted
	var audio := pause_layer.find_child("Audio", true, false) as Button
	audio.text = "声音：关" if muted else "声音：开"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func quit_game() -> void:
	if closing:
		return
	closing = true
	ambience.stop()
	sound.stop()
	await get_tree().create_timer(0.15, true, false, true).timeout
	get_tree().quit()

func play_sound(clip: String, volume: float = -4.0) -> void:
	if muted:
		return
	sound.stream = load("res://audio/%s.wav" % clip)
	sound.volume_db = volume
	sound.play()

func add_crt() -> void:
	var glass := solid(ui, Rect2(Vector2.ZERO, SIZE), Color.WHITE)
	var material := ShaderMaterial.new()
	material.shader = CRT
	glass.material = material

func draw_snow(layer: Node2D, extent: Vector2) -> void:
	if stage == Stage.NEXT:
		return
	for index in range(72):
		var x := fposmod(index * 53.31 - clock * (12.0 + index % 7 * 5.6), extent.x)
		var y := fposmod(index * 83.71 + clock * (24.0 + index % 6 * 7.3), extent.y)
		var weight := 0.50 + float(index % 4) * 0.34
		var tint := Color(0.86, 0.94, 1.0, 0.09 + 0.034 * (index % 5))
		layer.draw_line(Vector2(x, y), Vector2(x - 0.8, y + 1.4), tint, weight, true)

func add_image(parent: Control, texture: Texture2D, rect: Rect2) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_SCALE
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	result.position = rect.position
	result.size = rect.size
	return result

func style(background: Color, edge: Color, radius: int = 2) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = edge
	result.set_border_width_all(1)
	result.set_corner_radius_all(radius)
	result.content_margin_left = 10
	result.content_margin_right = 10
	return result

func panel(parent: Control, rect: Rect2, fill: Color, edge: Color, radius: int = 2) -> Panel:
	var result := Panel.new()
	result.add_theme_stylebox_override("panel", style(fill, edge, radius))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	result.position = rect.position
	result.size = rect.size
	return result

func make_window(parent: Control, title: String, rect: Rect2, draggable: bool) -> Panel:
	var result := panel(parent, rect, Color("#151e22"), Color("#77888c"), 4)
	var frame := result.get_theme_stylebox("panel") as StyleBoxFlat
	frame.shadow_color = Color("#00000090")
	frame.shadow_size = 9
	frame.shadow_offset = Vector2(4, 7)
	if window_locations.has(title):
		result.position = window_locations[title]
	var header := solid(result, Rect2(2, 2, rect.size.x - 4, 29), Color("#38464e"))
	solid(header, Rect2(0, 0, rect.size.x - 4, 1), Color("#71848b"))
	solid(header, Rect2(0, 27, rect.size.x - 4, 1), Color("#0c1217"))
	label(header, title, 17, Vector2(9, 3), Color("#d4dee1"))
	if draggable:
		for index in range(3):
			var chrome := Button.new()
			var base := style(Color("#2b3c42"), Color("#10171a"), 0)
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				base.set_content_margin(side, 0.0)
			var hover := base.duplicate() as StyleBoxFlat
			hover.bg_color = Color("#527275")
			chrome.add_theme_stylebox_override("normal", base)
			chrome.add_theme_stylebox_override("hover", hover)
			chrome.add_theme_stylebox_override("pressed", hover)
			chrome.focus_mode = Control.FOCUS_NONE
			chrome.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			chrome.tooltip_text = ["最小化", "切换窗口大小", "关闭窗口"][index]
			chrome.pressed.connect(window_action.bind(result, index))
			header.add_child(chrome)
			chrome.position = Vector2(rect.size.x - 74 + index * 22, 5)
			chrome.size = Vector2(19, 18)
			label(chrome, ["–", "□", "×"][index], 13, Vector2(5, -4), ICE)
		header.mouse_filter = Control.MOUSE_FILTER_STOP
		header.mouse_default_cursor_shape = Control.CURSOR_MOVE
		header.gui_input.connect(drag_window.bind(result, title))

	return result

func window_action(window: Panel, action: int) -> void:
	play_sound("key", -12)
	if action != 1:
		window.hide()
		return
	if window.has_meta("before_zoom"):
		window.position = window.get_meta("before_zoom")
		window.scale = Vector2.ONE
		window.remove_meta("before_zoom")
	else:
		window.set_meta("before_zoom", window.position)
		var fit := minf(612.0 / window.size.y, 1110.0 / window.size.x)
		window.scale = Vector2.ONE * fit
		window.position = (Vector2(1298, 695) - window.size * fit) * 0.5
		window.move_to_front()

func drag_window(event: InputEvent, window: Panel, title: String) -> void:
	if paused or window.has_meta("before_zoom"):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		window.move_to_front()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		window.position = (window.position + event.relative).clamp(
			Vector2(57, 34), Vector2(1298, 661) - window.size)
		window_locations[title] = window.position

func solid(parent: Control, rect: Rect2, fill: Color) -> ColorRect:
	var result := ColorRect.new()
	result.color = fill
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	result.position = rect.position
	result.size = rect.size
	return result

func label(parent: Control, words: String, font_size: int, start: Vector2, ink: Color) -> Label:
	var result := Label.new()
	result.text = words
	result.add_theme_font_override("font", FONTS)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", ink)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	result.position = start
	return result

func wrapped_label(parent: Control, words: String, font_size: int, rect: Rect2, ink: Color) -> Label:
	var result := label(parent, words, font_size, rect.position, ink)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_constant_override("line_spacing", 5)
	result.size = rect.size
	return result

func button(parent: Control, words: String, rect: Rect2, action: Callable) -> Button:
	var result := Button.new()
	result.text = words
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_font_override("font", FONTS)
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_color_override("font_color", ICE)
	result.add_theme_color_override("font_hover_color", Color.WHITE)
	result.add_theme_stylebox_override("normal", style(Color("#202d32"), Color("#52696d")))
	result.add_theme_stylebox_override("hover", style(Color("#2f4649"), Color("#9fc5c4")))
	result.add_theme_stylebox_override("pressed", style(Color("#101c21"), Color("#a4cdcf")))
	result.add_theme_stylebox_override("focus", style(Color("00000000"), GREEN))
	result.pressed.connect(action)
	parent.add_child(result)
	result.position = rect.position
	result.size = rect.size
	return result

func style_clue(target: Button, visited: bool) -> void:
	var ink := GREEN if visited else Color("#dfc491")
	target.add_theme_color_override("font_color", ink)
	target.add_theme_stylebox_override("normal", style(Color("#162327"), ink))

func desktop_icon(screen: Control, character: String, words: String, start: Vector2, action: Callable) -> void:
	var item := button(screen, "", Rect2(start, Vector2(54, 69)), action)
	item.add_theme_stylebox_override("normal", style(Color("00000000"), Color("00000000")))
	label(item, character, 31, Vector2(11, 0), Color("#b2c5c8"))
	label(item, words, 15, Vector2(11, 44), ICE)
