extends CanvasLayer

signal build_requested(kind: int)
signal upgrade_requested
signal advance_requested
signal pause_requested
signal result_requested
signal resume_requested
signal return_requested
signal build_cancelled

const PAPER := Color("#efe1be")
const MIST := Color("#b4c2b8")
const BRASS := Color("#a6875a")
const GOLD := Color("#efc280")
const FIRE := Color("#f6904e")
const FIRE_WARN := Color("#ff9874")
const LOW_FIRE := 0.25
const FIRE_FLASH_TIME := 0.72
const INK := Color("#17201f")
const FONT = preload("res://typeface.tres")
const HEADING = preload("res://heading.tres")
const TOWERS := ["烽火盆", "骨弩台", "誓言路障", "火油槽"]
const DESCRIPTIONS := ["驱散黑暗并显露影潜者", "远程攻击，优先消灭飞蛾", "挡住地面敌人，保护后方工事", "拖慢敌人，可用提灯引燃"]
const WINDOW_SIZE := Vector2(1280, 800)
const WAVE_PLATE := Rect2(521, 12, 238, 64)

var root: Control
var timer: Label
var phase: Label
var fire_label: Label
var fire_warning: Label
var health_label: Label
var rank_label: Label
var slain_label: Label
var resource: Label
var bone_label: Label
var oil_label: Label
var remaining: Label
var notice: Label
var notice_plate: Control
var environment: Label
var hint: Label
var advance: Button
var advance_hint: Label
var menu: Control
var pause_menu: Control
var result_menu: Control
var gear_buttons: Array[Button] = []
var upgrade_button: Button
var fire_fraction := 1.0
var health_fraction := 1.0
var xp_fraction := 0.0
var oil_fraction := 1.0
var time_fraction := 1.0
var nightfall := false
var notice_life := 0.0
var clock := 0.0
var instruments: Control
var action: Control
var fullscreen: Button
var health_flash := 0.0
var fire_flash := 0.0
var xp_flash := 0.0
var shown_kills := 0
var inspection: Control
var inspection_caption: Label
var inspection_panel: Control
var inspect_at := Vector2.ZERO
var inspect_marker := Vector2.ZERO
var inspect_radius := 0.0

func _ready() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = WINDOW_SIZE
	add_child(root)

	inspection = mount(root, Rect2(Vector2.ZERO, WINDOW_SIZE))
	inspection.draw.connect(draw_inspection)

	instruments = Control.new()
	instruments.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(instruments)
	instruments.draw.connect(draw_instruments)
	advance = button(root, "", WAVE_PLATE, advance_requested.emit, 17, true)
	advance.name = "StartNight"
	advance.tooltip_text = "迎夜 · Enter"
	for variant in ["normal", "disabled", "pressed"]:
		advance.add_theme_stylebox_override(variant, StyleBoxEmpty.new())
	advance.add_theme_stylebox_override("hover", box(Color("#e6a85520"), GOLD))
	advance.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, GOLD))

	label(root, "守夜人", 17, Rect2(77, 686, 106, 25), PAPER, HEADING)
	health_label = label(root, "", 15, Rect2(189, 687, 84, 25), PAPER)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_label.tooltip_text = "守夜人生命"
	health_label.mouse_filter = Control.MOUSE_FILTER_PASS
	rank_label = label(root, "", 13, Rect2(76, 724, 118, 21), GOLD)
	slain_label = label(root, "", 13, Rect2(181, 724, 92, 21), MIST)
	slain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	phase = label(root, "", 15, Rect2(540, 18, 106, 26), GOLD)
	timer = centered(root, "", 22, Rect2(638, 16, 101, 29), PAPER, HEADING)
	advance_hint = centered(root, "迎夜  ↵", 14, Rect2(528, 43, 224, 21), PAPER)
	fire_label = label(root, "100", 17, Rect2(57, 16, 42, 34), PAPER)
	fire_label.tooltip_text = "篝火火势"
	fire_label.mouse_filter = Control.MOUSE_FILTER_PASS
	fire_warning = label(root, "", 14, Rect2(23, 57, 163, 22), FIRE_WARN, HEADING)
	fire_warning.add_theme_color_override("font_outline_color", Color("#12171a"))
	fire_warning.add_theme_constant_override("outline_size", 3)
	fire_warning.hide()
	resource = label(root, "", 16, Rect2(139, 16, 44, 34), PAPER)
	bone_label = label(root, "", 16, Rect2(216, 16, 44, 34), PAPER)
	oil_label = label(root, "", 16, Rect2(1179, 16, 62, 34), PAPER)
	resource.tooltip_text = "余烬"
	bone_label.tooltip_text = "骨材"
	oil_label.tooltip_text = "提灯油量"
	for indicator in [resource, bone_label, oil_label]:
		indicator.mouse_filter = Control.MOUSE_FILTER_PASS
	label(root, "提灯", 15, Rect2(1119, 16, 55, 33), MIST, HEADING)
	fullscreen = button(root, "全屏", Rect2(1138, 750, 56, 37), toggle_fullscreen, 13)
	fullscreen.tooltip_text = "全屏 / 窗口"
	button(root, "Ⅱ", Rect2(1206, 750, 49, 37), pause_requested.emit, 18).tooltip_text = "暂停 · Esc"

	var banner := mount(root, Rect2(463, 84, 354, 44))
	banner.name = "Location"
	centered(banner, "", 19, Rect2(15, 0, 324, 30), PAPER, HEADING).name = "Place"
	centered(banner, "", 12, Rect2(15, 26, 324, 24), MIST).name = "Land"
	for location_text in banner.get_children():
		location_text.add_theme_color_override("font_shadow_color", Color("#071011"))
		location_text.add_theme_constant_override("shadow_offset_y", 2)
	remaining = centered(root, "", 13, Rect2(528, 43, 224, 21), MIST)
	environment = label(root, "", 12, Rect2(21, 63, 348, 36), MIST)
	environment.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	environment.add_theme_color_override("font_shadow_color", Color("#050f10"))
	environment.add_theme_constant_override("shadow_offset_x", 1)
	environment.add_theme_constant_override("shadow_offset_y", 2)
	environment.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	notice_plate = mount(root, Rect2(369, 139, 542, 29))
	notice = centered(notice_plate, "", 14, Rect2(8, 0, 526, 27), PAPER)
	notice.add_theme_color_override("font_shadow_color", Color("#0b1314"))
	notice.add_theme_constant_override("shadow_offset_y", 2)
	notice.add_theme_constant_override("outline_size", 2)
	notice_plate.hide()

	var controls := mount(root, Rect2(20, 761, 540, 28))
	controls.draw.connect(draw_control_rail.bind(controls))
	label(controls, "WASD 移动    左键 挥剑 / 蓄力    Shift 冲刺    E 交互    F 提灯", 12,
		Rect2(10, 0, 469, 26), MIST)

	action = mount(root, Rect2(422, 715, 436, 37))
	action.draw.connect(draw_quiet_plate.bind(action))
	hint = centered(action, "", 14, Rect2(9, 0, 418, 36), PAPER)
	action.hide()
	inspection_panel = mount(root, Rect2(0, 0, 180, 34))
	inspection_panel.draw.connect(draw_quiet_plate.bind(inspection_panel))
	inspection_caption = centered(inspection_panel, "", 14, Rect2(7, 0, 166, 32), PAPER, HEADING)
	inspection_panel.hide()

func set_place(place: String, landscape: String) -> void:
	root.get_node("Location/Place").text = place
	root.get_node("Location/Land").text = landscape

func update_status(level) -> void:
	var seconds := ceili(level.phases.left)
	nightfall = level.night
	phase.text = "第%d夜 · %s" % [level.phases.night_number, "深夜" if nightfall else "黄昏"]
	timer.text = "清理余敌" if nightfall and seconds == 0 else "%02d:%02d" % [seconds / 60, seconds % 60]
	fire_fraction = clampf(level.fire_hp / 100.0, 0.0, 1.0)
	fire_label.text = str(ceili(level.fire_hp))
	update_fire_warning()
	resource.text = str(level.run.embers)
	bone_label.text = str(level.run.bone)
	oil_label.text = "%d%%" % ceili(level.oil)
	remaining.text = "待来袭  %d" % level.spawner.remaining() if level.spawner.remaining() > 0 \
		else "场内  %d" % level.combat.count_enemies()
	remaining.visible = nightfall and not level.ended
	var maximum := maxf(1.0, read_number(level.combat, &"player_hp_max", 100.0))
	var hp := clampf(read_number(level.combat, &"player_hp", maximum), 0.0, maximum)
	var new_fraction := clampf(hp / maximum, 0.0, 1.0)
	if new_fraction < health_fraction - 0.005:
		health_flash = 0.22
	health_fraction = new_fraction
	health_label.text = "%d / %d" % [ceili(hp), ceili(maximum)]
	health_label.modulate = Color("#ff9874") if health_fraction < 0.35 else Color.WHITE
	var earned := read_number(level.combat, &"xp", 0.0)
	var last := read_number(level, &"rank_previous", 0.0)
	var threshold := read_number(level, &"rank_target", 14.0)
	var need := maxf(1.0, threshold - last)
	var toward := clampf(earned - last, 0.0, need)
	xp_fraction = toward / need
	rank_label.text = "夜阶 %d  ·  %d/%d" % [int(read_number(level, &"night_rank", 1.0)), int(toward), int(need)]
	var kills := int(read_number(level.combat, &"kills", 0.0))
	if kills > shown_kills:
		xp_flash = 0.27
	shown_kills = kills
	slain_label.text = "击杀 %d" % kills
	oil_fraction = clampf(level.oil / 100.0, 0.0, 1.0)
	time_fraction = level.phases.progress()
	advance.visible = not nightfall and not level.ended
	advance_hint.visible = advance.visible
	environment.text = level.weather_status()
	var guidance: String = level.action_hint()
	hint.text = guidance
	action.visible = not guidance.is_empty() and not is_instance_valid(menu) and not level.ended
	update_inspection(level)
	instruments.queue_redraw()

func read_number(source: Object, field: StringName, fallback: float) -> float:
	var value: Variant = source.get(field)
	return float(value) if value != null else fallback

func toggle_fullscreen() -> void:
	if fullscreen.has_focus():
		fullscreen.release_focus()
	var window := get_window()
	window.mode = Window.MODE_WINDOWED if window.mode in [Window.MODE_FULLSCREEN,
		Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN

func update_inspection(level) -> void:
	inspection_panel.hide()
	if level.paused or level.ended:
		inspection.hide()
		level.scenery.hide_support_range()
		return
	var selecting := is_instance_valid(menu)
	var selected: int = level.open_slot if selecting else hovered_support(level)
	if selected < 0:
		inspection.hide()
		level.scenery.hide_support_range()
		return
	var tower = level.combat.towers[selected]
	inspect_at = level.slot_points[selected]
	inspect_marker = level.get_global_transform_with_canvas() * level.support_muzzle(selected)
	inspect_radius = level.combat.inspect_radius(selected)
	var current := inspect_radius
	var planned := 0.0
	var title: String = level.support_name[selected]
	if tower.level == 0 or (tower.kind == "brazier" and not tower.lit) or (tower.kind == "oil" and tower.spent and tower.burn <= 0.0):
		planned = current
		current = 0.0
	elif selecting and tower.level < 3:
		planned = level.combat.inspect_radius(selected, true)
	level.scenery.show_support_range(inspect_at, current, planned)
	inspection.show()
	inspection.queue_redraw()
	if not selecting:
		if tower.level == 0:
			inspection_caption.text = "%s · 未修缮" % title
		else:
			inspection_caption.text = "%s · Lv.%d" % [title, tower.level]
		inspection_panel.position = (inspect_marker + Vector2(-90, -54)).clamp(Vector2(12, 107), Vector2(1088, 675))
		inspection_panel.show()

func hovered_support(level) -> int:
	var cursor: Vector2 = level.get_global_mouse_position()
	var points: Array[Vector2] = level.slot_points
	var selected := -1
	var nearest := 25.0 ** 2
	for index in points.size():
		var distance := cursor.distance_squared_to(points[index])
		distance = minf(distance, cursor.distance_squared_to(level.support_muzzle(index)))
		if distance < nearest:
			nearest = distance
			selected = index
	return selected

func draw_inspection() -> void:
	var at := inspect_marker
	inspection.draw_arc(at, 18.0, 0, TAU, 34, Color("#e9c586b8"), 1.25, true)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		inspection.draw_line(at + direction * 14.0, at + direction * 22.0, GOLD, 1.0, true)

func next_frame(delta: float) -> void:
	clock += delta
	health_flash = maxf(0.0, health_flash - delta)
	fire_flash = maxf(0.0, fire_flash - delta)
	xp_flash = maxf(0.0, xp_flash - delta)
	notice_life = maxf(0, notice_life - delta)
	notice_plate.modulate.a = minf(notice_life * 2.0, 1.0)
	notice_plate.visible = notice_life > 0.0

func flash_fire() -> void:
	fire_flash = FIRE_FLASH_TIME
	update_fire_warning()
	instruments.queue_redraw()

func update_fire_warning() -> void:
	var low := fire_fraction <= LOW_FIRE
	var attacked := fire_flash > 0.0
	fire_warning.visible = low or attacked
	fire_warning.text = "篝火受袭" if attacked else "火势将熄"
	fire_label.modulate = Color.WHITE.lerp(FIRE_WARN, 0.85 if low or attacked else 0.0)
	environment.position.y = 83.0 if fire_warning.visible else 63.0

func announce(message: String) -> void:
	notice.text = message
	notice_plate.modulate.a = 1.0
	notice_plate.show()
	notice_life = 3.6

func open_build(items: Array[Dictionary], current: Dictionary, slot_index: int,
		anchor := Vector2(923, 380)) -> void:
	close_build()
	action.hide()
	inspection_panel.hide()
	inspection.hide()
	var shown: Array[int] = []
	for index in items.size():
		if items[index].get("compatible", true):
			shown.append(index)
	var width := 275.0
	var height := 190.0 if not current.is_empty() else maxf(144.0, 70.0 + shown.size() * 66.0)
	var open_right := anchor.x + width + 49.0 < 1280.0
	var x := anchor.x + 27.0 if open_right else anchor.x - width - 27.0
	var y := clampf(anchor.y - height * 0.46, 111.0, 742.0 - height)
	menu = mount(root, Rect2(clampf(x, 20.0, 1260.0 - width), y, width, height), true)
	menu.draw.connect(draw_context_tail.bind(menu, anchor, open_right))
	menu.draw.connect(draw_plate.bind(menu, true))
	menu.tooltip_text = "遗迹工事 %02d" % (slot_index + 1)
	var site: String = items[0].get("site", "遗迹工事") if not items.is_empty() else "遗迹工事"
	label(menu, site, 19, Rect2(22, 12, 194, 29), PAPER, HEADING)
	button(menu, "×", Rect2(226, 13, 30, 27), request_build_close, 17).tooltip_text = "关闭 · Esc"
	gear_buttons.clear()
	gear_buttons.resize(TOWERS.size())
	if current.is_empty():
		if shown.is_empty():
			centered(menu, "此处没有可修复的工事", 14, Rect2(20, 46, 235, 48), MIST)
		for row in shown.size():
			var index := shown[row]
			var top := 46.0 + row * 66.0
			var item: Dictionary = items[index]
			var option := button(menu, "", Rect2(16, top, 243, 63), build_requested.emit.bind(index), 14)
			option.disabled = not item["allowed"]
			option.tooltip_text = "%s · %s" % [TOWERS[index], item.get("description", DESCRIPTIONS[index])]
			gear_buttons[index] = option
			var emblem := mount(option, Rect2(0, 0, 45, 45))
			emblem.scale = Vector2.ONE * 0.82
			emblem.position = Vector2(6, 4)
			emblem.draw.connect(draw_tower_emblem.bind(emblem, index))
			label(option, TOWERS[index], 16, Rect2(52, 1, 157, 24), PAPER, HEADING)
			label(option, str(item["cost"]), 12, Rect2(52, 24, 169, 17), GOLD)
			label(option, DESCRIPTIONS[index], 12, Rect2(52, 41, 182, 17), MIST)
			var shortcut := label(option, str(index + 1), 13, Rect2(211, 5, 21, 22), MIST)
			shortcut.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		var kind: int = current["kind"]
		var level: int = current["level"]
		var emblem := mount(menu, Rect2(22, 49, 45, 45))
		emblem.draw.connect(draw_tower_emblem.bind(emblem, kind))
		label(menu, "%s · Lv.%d" % [TOWERS[kind], level], 18, Rect2(74, 45, 178, 33), PAPER, HEADING)
		var details: Array = current["levels"]
		var detail := label(menu, details[mini(level, details.size() - 1)], 13,
			Rect2(75, 76, 167, 47), MIST)
		detail.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		var cost := "已达上限" if level >= 3 else "升级 · " + str(current["cost"])
		upgrade_button = button(menu, cost, Rect2(23, 132, 228, 36), upgrade_requested.emit, 15, true)
		upgrade_button.disabled = not current["allowed"]

func draw_context_tail(pane: Control, anchor: Vector2, right: bool) -> void:
	var local_anchor := anchor - pane.position
	var edge_y := clampf(local_anchor.y, 37.0, pane.size.y - 39.0)
	var edge_x := 13.0 if right else pane.size.x - 13.0
	var reach := Vector2(-13.0 if right else pane.size.x + 13.0, edge_y)
	silhouette(pane, PackedVector2Array([Vector2(edge_x, edge_y - 10.0),
		reach, Vector2(edge_x, edge_y + 11.0)]), Color("#172426fc"), BRASS, 1.1)

func request_build_close() -> void:
	close_build()
	build_cancelled.emit()

func close_build() -> void:
	if is_instance_valid(menu):
		menu.hide()
		menu.queue_free()
	menu = null

func show_pause() -> void:
	pause_menu = mount(root, Rect2(450, 222, 380, 334), true)
	pause_menu.draw.connect(draw_plate.bind(pause_menu, true))
	var medallion := mount(pause_menu, Rect2(163, 22, 54, 54))
	medallion.draw.connect(draw_tower_emblem.bind(medallion, 0))
	centered(pause_menu, "守夜暂停", 35, Rect2(25, 78, 330, 61), PAPER, HEADING)
	button(pause_menu, "继续守夜", Rect2(57, 161, 266, 49), resume_requested.emit, 19, true)
	button(pause_menu, "返回行图", Rect2(57, 229, 266, 47), return_requested.emit, 17)

func hide_pause() -> void:
	if is_instance_valid(pause_menu):
		pause_menu.hide()
		pause_menu.queue_free()
	pause_menu = null

func show_result(won: bool, reason := "") -> void:
	close_build()
	var curtain := ColorRect.new()
	curtain.size = Vector2(1280, 800)
	curtain.color = Color("#071012c9")
	root.add_child(curtain)
	result_menu = mount(curtain, Rect2(407, 235, 466, 330), true)
	result_menu.draw.connect(draw_plate.bind(result_menu, true))
	var medallion := mount(result_menu, Rect2(206, 25, 54, 54))
	medallion.draw.connect(draw_tower_emblem.bind(medallion, 0 if won else 2))
	centered(result_menu, "烽火仍明" if won else "守夜未成", 37,
		Rect2(24, 89, 418, 69), PAPER, HEADING)
	var text := reason if not reason.is_empty() else "长夜已过，收起火种再向北。" if won else "黑暗吞没了这条防线。"
	centered(result_menu, text, 17,
		Rect2(28, 158, 410, 36), MIST)
	button(result_menu, "继续行程" if won else "返回行图", Rect2(101, 222, 264, 50), result_requested.emit, 18, true)

func draw_instruments() -> void:
	var ui := instruments
	draw_bezel(ui, Rect2(16, 13, 255, 42), Color("#101a20f2"), BRASS.darkened(0.20))
	var fire_seal := Vector2(39, 34)
	var low := fire_fraction <= LOW_FIRE
	var flash := ease(fire_flash / FIRE_FLASH_TIME, 2.0)
	if flash > 0.0 or low:
		var tint := Color("#e87859").lerp(FIRE_WARN, flash)
		var strength := maxf(flash, 0.41 if low else 0.0)
		ui.draw_rect(Rect2(24, 19, 72, 29), Color(tint, strength * 0.13))
		ui.draw_arc(fire_seal, 14.7 + 3.4 * (1.0 - flash), 0, TAU, 36, Color(tint, strength * 0.86), 1.5, true)
		ui.draw_line(Vector2(22, 54), Vector2(98, 54), Color(tint, strength), 1.6, true)
	ui.draw_circle(fire_seal, 13, Color("#352925").lerp(Color("#592a24"), flash), true, -1.0, true)
	ui.draw_arc(fire_seal, 13.2, PI * 0.80, PI * 2.18, 30, Color("#695344").lerp(FIRE_WARN, flash), 1.2, true)
	if fire_fraction > 0.0:
		var heat := FIRE_WARN if low else FIRE
		ui.draw_arc(fire_seal, 13.2, PI * 0.80, PI * (0.80 + 1.38 * fire_fraction), 30, heat, 1.55, true)
	draw_flame(ui, fire_seal, 0.57, GOLD.darkened(0.70 if fire_fraction == 0.0 else 0.0),
		sin(clock * 4.2) * 1.1)
	for x in [101.0, 178.0]:
		ui.draw_line(Vector2(x, 22), Vector2(x, 46), Color("#9281675a"), 1.0, true)
	var ember := PackedVector2Array([Vector2(112, 32), Vector2(117, 26), Vector2(123, 27),
		Vector2(128, 34), Vector2(123, 41), Vector2(116, 40)])
	silhouette(ui, ember, Color("#d78353"), Color("#6c4535"), 1.0)
	ui.draw_polyline(PackedVector2Array([Vector2(114, 34), Vector2(119, 32), Vector2(121, 35),
		Vector2(126, 33)]), Color("#ffd18f"), 1.15, true)
	draw_bone(ui, Vector2(196, 34), 0.70, Color("#d2c1a3"))

	draw_bezel(ui, WAVE_PLATE, Color("#121c22f5"), Color("#a07c4c") if not nightfall else Color("#637382"))
	draw_channel(ui, Vector2(WAVE_PLATE.position.x + 8.0, WAVE_PLATE.end.y - 8.0), WAVE_PLATE.size.x - 16.0,
		2.5, time_fraction, GOLD if not nightfall else Color("#86b5b7"))
	for x in [WAVE_PLATE.position.x + 10.0, WAVE_PLATE.end.x - 10.0]:
		ui.draw_circle(Vector2(x, 45.0), 1.65, Color("#a08152"), true, -1.0, true)

	draw_bezel(ui, Rect2(1081, 13, 179, 43), Color("#101a20f2"), Color("#695e4b"))
	draw_drop(ui, Vector2(1103, 33), 0.59, Color("#9bc6ba").darkened((1.0 - oil_fraction) * 0.57))
	draw_channel(ui, Vector2(1120.0, 48.0), 122.0, 1.6, oil_fraction, Color("#81b2a8"))

	draw_bezel(ui, Rect2(18, 681, 267, 74), Color("#101a20f4"), Color("#74654e"))
	draw_watcher_seal(ui, Vector2(46, 715))
	var red := Color("#b95e54").lerp(Color("#ffb186"), health_flash * 3.1)
	draw_channel(ui, Vector2(76, 714), 197.0, 7.0, health_fraction, red)
	for index in [1, 2, 3]:
		var x: float = 76.0 + index * 197.0 / 4.0
		ui.draw_line(Vector2(x, 714), Vector2(x, 721), Color("#24272466"), 1.0, true)
	var experience := GOLD.lerp(Color("#f9e8bb"), xp_flash * 2.4)
	draw_channel(ui, Vector2(76, 746), 197.0, 2.0, xp_fraction, experience)
	if xp_flash > 0.0 and xp_fraction > 0.0:
		var tip := Vector2(76.0 + 197.0 * xp_fraction, 747.0)
		var spark := Color(experience, minf(1.0, xp_flash * 4.6))
		ui.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -3), tip + Vector2(3, 0),
			tip + Vector2(0, 3), tip + Vector2(-3, 0)]), spark)

func draw_bezel(ui: Control, rect: Rect2, base: Color, patina: Color) -> void:
	var p := rect.position
	var w := rect.size.x
	var h := rect.size.y
	var lip := PackedVector2Array([p + Vector2(6, 0), p + Vector2(w - 12, 0),
		p + Vector2(w - 9, 3), p + Vector2(w - 3, 3), p + Vector2(w, 7),
		p + Vector2(w, h - 6), p + Vector2(w - 6, h), p + Vector2(11, h),
		p + Vector2(8, h - 3), p + Vector2(3, h - 3), p + Vector2(0, h - 7), p + Vector2(0, 6)])
	var shadow := lip.duplicate()
	for index in shadow.size():
		shadow[index] += Vector2(0, 3)
	ui.draw_colored_polygon(shadow, Color("#05090bb0"))
	silhouette(ui, lip, base, patina, 1.05)
	ui.draw_line(p + Vector2(10, 3), p + Vector2(w - 16, 3), Color(patina, 0.35), 1, true)
	ui.draw_line(p + Vector2(5, 7), p + Vector2(5, h - 9), Color(patina, 0.45), 1, true)

func draw_channel(ui: Control, at: Vector2, width: float, height: float, amount: float, tint: Color) -> void:
	ui.draw_rect(Rect2(at, Vector2(width, height)), Color("#383e38"))
	ui.draw_rect(Rect2(at, Vector2(width * amount, height)), tint)
	if height >= 5.0 and amount > 0.0:
		ui.draw_line(at, at + Vector2(width * amount, 0), tint.lightened(0.24), 1.2, true)

func draw_watcher_seal(ui: Control, center: Vector2) -> void:
	ui.draw_circle(center, 24, Color("#0a1718"), true, -1.0, true)
	ui.draw_arc(center, 24.0, 0, TAU, 32, Color("#887554"), 1.1, true)
	ui.draw_arc(center, 19.0, -1.9, 0.6, 15, Color("#985f4d84"), 1.0, true)
	var hood := PackedVector2Array([center + Vector2(-13, 11), center + Vector2(-11, -4),
		center + Vector2(-7, -12), center + Vector2(1, -15), center + Vector2(10, -9),
		center + Vector2(13, 3), center + Vector2(17, 12), center + Vector2(2, 15)])
	silhouette(ui, hood, Color("#657f74"), Color("#101b1b"), 1.3)
	ui.draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -4), center + Vector2(8, -5),
		center + Vector2(9, 6), center + Vector2(1, 12), center + Vector2(-5, 9)]), Color("#1a2927"))
	ui.draw_line(center + Vector2(-2, 1), center + Vector2(6, 0), Color("#edc486"), 1.4, true)
	ui.draw_line(center + Vector2(-9, 11), center + Vector2(11, 13), Color("#a38f6b"), 1.1, true)

func draw_flame(ui: Control, center: Vector2, scale_value: float, tint: Color, wave: float) -> void:
	var form := PackedVector2Array([Vector2(-8, 10), Vector2(-13, 2), Vector2(-9, -7), Vector2(-4, -2),
		Vector2(wave + 2, -15), Vector2(4, -7), Vector2(10, -10), Vector2(12, 0),
		Vector2(9, 8), Vector2(3, 12)])
	for index in form.size():
		form[index] = center + form[index] * scale_value
	silhouette(ui, form, tint, Color("#402c22"), 0.85)
	ui.draw_line(center + Vector2(-3, 6) * scale_value, center + Vector2(3 + wave * 0.4, -3) * scale_value,
		tint.lightened(0.36), maxf(1.0, scale_value * 2.0), true)

func draw_bone(ui: Control, center: Vector2, scale_value: float, tint: Color) -> void:
	var a := center + Vector2(-8, -5) * scale_value
	var b := center + Vector2(7, 5) * scale_value
	ui.draw_line(a, b, tint, 4.0 * scale_value, true)
	for p in [a, b]:
		ui.draw_circle(p + Vector2(1, -2), 3.3 * scale_value, tint, true, -1, true)
		ui.draw_circle(p + Vector2(-1, 2), 3.1 * scale_value, tint, true, -1, true)

func draw_drop(ui: Control, center: Vector2, scale_value: float, tint: Color) -> void:
	var shape := PackedVector2Array([Vector2(0, -14), Vector2(8, -3), Vector2(9, 4),
		Vector2(5, 9), Vector2(-3, 10), Vector2(-9, 5), Vector2(-8, -2)])
	for index in shape.size():
		shape[index] = center + shape[index] * scale_value
	silhouette(ui, shape, tint, Color("#365952"), 0.9)
	ui.draw_line(center + Vector2(-3, -3) * scale_value, center + Vector2(-5, 3) * scale_value,
		tint.lightened(0.4), 1.3, true)

func draw_tower_emblem(ui: Control, tower: int) -> void:
	var at := ui.size * 0.5
	ui.draw_circle(at, 21.5, Color("#10191a"), true, -1, true)
	ui.draw_arc(at, 20.5, 0, TAU, 24, Color("#99805d"), 1.05, true)
	ui.draw_arc(at, 17.2, 0.2, PI - 0.15, 18, Color("#685a44"), 1.0, true)
	match tower:
		0:
			draw_flame(ui, at - Vector2(0, 1), 0.92, GOLD, 0.0)
			ui.draw_line(at + Vector2(-9, 10), at + Vector2(9, 10), BRASS, 1.5, true)
		1:
			ui.draw_line(at + Vector2(-10, 9), at + Vector2(11, -9), GOLD, 1.6, true)
			ui.draw_arc(at + Vector2(0, -2), 11, -2.9, 0.85, 12, GOLD, 1.4, true)
			draw_bone(ui, at + Vector2(-3, 4), 0.39, PAPER)
		2:
			for n in range(3):
				var p := at + Vector2(-9 + n * 9, -1)
				silhouette(ui, PackedVector2Array([p + Vector2(-3, 11), p + Vector2(-4, -6),
					p + Vector2(0, -12), p + Vector2(4, -6), p + Vector2(3, 11)]), BRASS, GOLD.darkened(0.23), 1.0)
		3:
			draw_drop(ui, at - Vector2(0, 3), 0.83, GOLD.darkened(0.20))
			ui.draw_arc(at + Vector2(0, 2), 13, 0.09, PI - 0.1, 16, BRASS, 1.2, true)

func draw_quiet_plate(ui: Control) -> void:
	var bounds := Rect2(Vector2(2, 2), ui.size - Vector2(4, 5))
	draw_bezel(ui, bounds, Color("#121c21eb"), Color("#7a6d53"))

func draw_control_rail(ui: Control) -> void:
	var ribbon := PackedVector2Array([Vector2(0, 2), Vector2(116, 1), Vector2(414, 4),
		Vector2(419, 2), Vector2(483, 9), Vector2(515, 19), Vector2(474, 29),
		Vector2(298, 30), Vector2(79, 29), Vector2(0, 30)])
	silhouette(ui, ribbon, Color("#0a1516c4"), Color("#70847455"), 1.0)
	ui.draw_line(Vector2(7, 3), Vector2(39, 3), Color("#ad917066"), 1.0, true)

func draw_plate(ui: Control, engraved: bool) -> void:
	var w := ui.size.x
	var h := ui.size.y
	var shape := PackedVector2Array([Vector2(2, 27), Vector2(23, 12), Vector2(112, 5), Vector2(w - 31, 9),
		Vector2(w - 7, 34), Vector2(w - 4, h - 31), Vector2(w - 31, h - 11),
		Vector2(w - 91, h - 8), Vector2(23, h - 9), Vector2(6, h - 27)])
	var shadow := shape.duplicate()
	for index in shape.size():
		shadow[index] += Vector2(3, 8)
	ui.draw_colored_polygon(shadow, Color("#060e10c0"))
	silhouette(ui, shape, Color("#172426fc"), Color("#847052"), 1.4)
	if engraved:
		for row in 47:
			var p := Vector2(19.0 + fposmod(row * 49.47, w - 40.0), 27.0 + fposmod(row * 68.89, h - 51.0))
			ui.draw_line(p, p + Vector2(4 + row % 6, sin(row) * 1.9), Color("#c4bc9b19"), 1.0, true)
	for point in [Vector2(18, 43), Vector2(w - 17, 43), Vector2(18, h - 39), Vector2(w - 18, h - 39)]:
		ui.draw_circle(point, 3.5, Color("#6f5b43"), true, -1, true)
		ui.draw_line(point + Vector2(-1.6, 1), point + Vector2(2, -1), GOLD.darkened(0.2), 1.0, true)
	var seam := 41.0 if h < 265.0 else 65.0
	ui.draw_line(Vector2(34, seam), Vector2(w - 35, seam), Color("#8f775344"), 1.0, true)

func silhouette(ui: Control, points: PackedVector2Array, tint: Color, edge: Color, width: float) -> void:
	ui.draw_colored_polygon(points, tint)
	var outline := points.duplicate()
	outline.append(points[0])
	ui.draw_polyline(outline, edge, width, true)

func mount(parent: Control, rect: Rect2, modal := false) -> Control:
	var node := Control.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_STOP if modal else Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func label(parent: Control, words: String, pixels: int, rect: Rect2, ink: Color, font = FONT) -> Label:
	var node := Label.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	node.text = words
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", pixels)
	node.add_theme_color_override("font_color", ink)
	parent.add_child(node)
	return node

func centered(parent: Control, words: String, pixels: int, rect: Rect2, ink: Color, font = FONT) -> Label:
	var node := label(parent, words, pixels, rect, ink, font)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node

func button(parent: Control, words: String, rect: Rect2, action: Callable, pixels: int, important := false) -> Button:
	var node := Button.new()
	node.position = rect.position
	node.size = rect.size
	node.text = words
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", HEADING if important else FONT)
	node.add_theme_font_size_override("font_size", pixels)
	node.add_theme_color_override("font_color", Color("#30231b") if important else PAPER)
	node.add_theme_color_override("font_hover_color", Color("#261e18") if important else Color.WHITE)
	node.add_theme_color_override("font_pressed_color", Color("#261e18") if important else PAPER)
	node.add_theme_stylebox_override("normal", box(Color("#dab879") if important else Color("#21302e"), BRASS))
	node.add_theme_stylebox_override("hover", box(Color("#f1cb87") if important else Color("#40534a"), GOLD))
	node.add_theme_stylebox_override("pressed", box(Color("#b48d53") if important else Color("#455047"), GOLD))
	node.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, GOLD))
	node.add_theme_stylebox_override("disabled", box(Color("#1b2627"), Color("#4b5b50")))
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func box(tint: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = edge
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	return style
