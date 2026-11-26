extends Control

signal node_requested(id: int)
signal new_run_requested(seed_value: int, use_random_seed: bool)
signal records_requested

const Route = preload("res://scripts/campaign/Route.gd")
const Atlas = preload("res://scripts/campaign/AtlasUI.gd")
const Marker = preload("res://scripts/campaign/AtlasMarker.gd")
const Folio = preload("res://scripts/campaign/AtlasFolio.gd")
const OVERVIEW = preload("res://assets/maps/00_world_overview_ink.png")
const ATLAS_BRUSH = preload("res://scripts/campaign/atlas_ink.gdshader")
const MAP_RECT := Rect2(14, 27, 990, 739.2)
const SIDEBAR_X := 989.0
const ATLAS_COORDINATES := Vector2(1200, 896)
const REGION_LABELS := [Vector2(118, 821), Vector2(325, 260), Vector2(936, 378), Vector2(690, 42)]

var run
var selected := -1
var markers: Dictionary = {}
var selection: Label
var description: Label
var confirm: Button
var seed_input: LineEdit
var seed_error: Label
var route_layer: Control
var chart: Control
var paper: TextureRect
var region_tags: Array[Panel] = []
var zoom_meter: Button
var locate_site: Button
var chart_scale := 1.0
var chart_offset := Vector2.ZERO
var drag_chart := false
var left_button_down := false

func configure(state) -> void:
	run = state
	var sites: Array[Dictionary] = run.available_nodes()
	if not sites.is_empty():
		selected = sites[0].id
	Atlas.fill(self, Rect2(0, 0, 1280, 800), Color("#0b1313"))
	make_chart()
	make_sidebar()
	update_selection()

func make_chart() -> void:
	Atlas.panel(self, MAP_RECT.grow(5), Color("#0f1716"), Color("#666955"))
	chart = Control.new()
	chart.position = MAP_RECT.position
	chart.size = MAP_RECT.size
	chart.clip_contents = true
	chart.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(chart)
	paper = TextureRect.new()
	paper.texture = OVERVIEW
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var ink := ShaderMaterial.new()
	ink.shader = ATLAS_BRUSH
	paper.material = ink
	paper.mouse_filter = MOUSE_FILTER_IGNORE
	chart.add_child(paper)
	Atlas.fill(chart, Rect2(Vector2.ZERO, MAP_RECT.size), Color("#10181510"))
	route_layer = Control.new()
	route_layer.mouse_filter = MOUSE_FILTER_IGNORE
	chart.add_child(route_layer)
	route_layer.draw.connect(draw_connections)
	for index in range(REGION_LABELS.size()):
		var tag := Atlas.panel(chart, Rect2(0, 0, 113, 25), Color("#12201de7"), Color("#777055"))
		region_tags.append(tag)
		var caption := Atlas.label(tag, Route.ZONES[index], Rect2(0, 2, 113, 23), 13, Atlas.CREAM, true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ready: Array[Dictionary] = run.available_nodes()
	for node in run.nodes:
		var marker := Marker.new()
		marker.kind = node.kind
		marker.name = "Site%d" % node.id
		marker.size = Vector2(47, 47)
		marker.visited = run.visited.has(node.id)
		marker.reachable = node in ready
		marker.tooltip_text = "%s · %s" % [Route.ZONES[node.zone], Route.KIND_NAMES[node.kind]]
		if marker.reachable:
			marker.pressed.connect(pick.bind(node.id))
			marker.focus_entered.connect(focus_site.bind(node.id))
		chart.add_child(marker)
		markers[node.id] = marker
	Atlas.label(self, "旧烽火道 · 从南向北", Rect2(24, 769, 380, 20), 13, Atlas.MUTED)
	var key := Atlas.label(self, "金环  可前往       绿环  已抵达", Rect2(558, 769, 295, 20), 13, Atlas.MUTED)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Atlas.button(self, "−", Rect2(871, 768, 26, 24), func(): zoom_chart(1.0 / 1.24, MAP_RECT.size * 0.5), false, 13)
	zoom_meter = Atlas.button(self, "100%", Rect2(901, 768, 52, 24), reset_chart, false, 12)
	zoom_meter.tooltip_text = "滚轮缩放，右键拖动，点击恢复全图"
	Atlas.button(self, "+", Rect2(957, 768, 26, 24), func(): zoom_chart(1.24, MAP_RECT.size * 0.5), false, 13)
	refresh_chart()

func screen_point(at: Vector2) -> Vector2:
	return MAP_RECT.position + chart_point(at)

func chart_point(at: Vector2) -> Vector2:
	return chart_offset + at * (MAP_RECT.size * chart_scale / ATLAS_COORDINATES)

func set_chart_input_enabled(enabled: bool) -> void:
	drag_chart = false
	left_button_down = false
	set_process_input(enabled)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(chart) or not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var inside := MAP_RECT.has_point(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			left_button_down = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not event.pressed and drag_chart:
				drag_chart = false
				get_viewport().set_input_as_handled()
			elif event.pressed and inside and chart_scale > 1.0:
				drag_chart = true
				get_viewport().set_input_as_handled()
		elif event.pressed and inside and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_chart(1.24 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.24,
				event.position - MAP_RECT.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and drag_chart:
		chart_offset += event.relative
		refresh_chart()
		get_viewport().set_input_as_handled()

func zoom_chart(factor: float, pivot: Vector2) -> void:
	var target := clampf(chart_scale * factor, 1.0, 2.25)
	chart_offset = pivot - (pivot - chart_offset) * (target / chart_scale)
	chart_scale = target
	refresh_chart()

func reset_chart() -> void:
	chart_scale = 1.0
	chart_offset = Vector2.ZERO
	drag_chart = false
	refresh_chart()

func refresh_chart() -> void:
	paper.size = MAP_RECT.size * chart_scale
	chart_offset = chart_offset.clamp(MAP_RECT.size - paper.size, Vector2.ZERO)
	paper.position = chart_offset
	zoom_meter.text = "%d%%" % roundi(chart_scale * 100.0)
	for index in range(region_tags.size()):
		region_tags[index].position = chart_point(REGION_LABELS[index])
	for node in run.nodes:
		var marker: Marker = markers[node.id]
		marker.position = chart_point(node.position) - marker.size * 0.5
	route_layer.queue_redraw()
	update_locate_site()

func visible_chart() -> Rect2:
	return Rect2(0, 0, SIDEBAR_X - MAP_RECT.position.x, MAP_RECT.size.y)

func focus_site(id: int) -> void:
	pick(id)
	if left_button_down or chart_scale <= 1.0:
		return
	var marker: Marker = markers[id]
	var center := marker.get_rect().get_center()
	var frame := visible_chart().grow(-32.0)
	var shift := center.clamp(frame.position, frame.end) - center
	if not shift.is_zero_approx():
		chart_offset += shift
		refresh_chart()

func center_selected_site() -> void:
	var marker: Marker = markers.get(selected)
	if marker == null:
		return
	chart_offset += visible_chart().get_center() - marker.get_rect().get_center()
	refresh_chart()
	marker.grab_focus()

func update_locate_site() -> void:
	if not is_instance_valid(locate_site):
		return
	var marker: Marker = markers.get(selected)
	locate_site.visible = marker != null and not visible_chart().encloses(marker.get_rect())

func draw_connections() -> void:
	var ready: Array[Dictionary] = run.available_nodes()
	for source in run.nodes:
		for id in source.next:
			var target: Dictionary = run.get_node_data(id)
			var walked: bool = run.visited.has(source.id) and run.visited.has(id)
			var reachable: bool = source.id == run.current_node and target in ready
			var active: bool = reachable and id == selected
			var at := chart_point(source.position)
			var to := chart_point(target.position)
			var color := Color("#ecd39c") if active else Color("#caa66bba") if reachable else Color("#b4c9a786") if walked else Color("#c3cabc72")
			route_layer.draw_line(at, to, Color("#0d1413bd"), 3.4 if active else 2.5, true)
			route_layer.draw_dashed_line(at, to, color, 2.0 if active else 1.45, 6.2, true, true)

func make_sidebar() -> void:
	var side := Control.new()
	side.position = Vector2(SIDEBAR_X, 19)
	side.size = Vector2(275, 750)
	side.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(side)
	var folio := Folio.new()
	side.add_child(folio)
	Atlas.label(side, "长夜守望者", Rect2(26, 33, 224, 61), 39, Atlas.CREAM, true)
	Atlas.label(side, "永夜轮回  %d" % run.cycle, Rect2(31, 94, 218, 26), 16, Atlas.GOLD)
	Atlas.label(side, "余烬 %d" % run.embers, Rect2(62, 149, 78, 26), 14, Atlas.CREAM)
	Atlas.label(side, "骨材 %d" % run.bone, Rect2(165, 149, 91, 26), 14, Atlas.CREAM)
	Atlas.label(side, "下战火势  %d / 100" % roundi(run.fire_start), Rect2(32, 199, 218, 23), 15, Atlas.MUTED)
	var next_night: Array[String] = []
	if run.ally:
		next_night.append("守夜人助战")
	if run.oil_start < 100.0:
		next_night.append("油量 %d" % roundi(run.oil_start))
	if run.speed_bonus > 0.0:
		next_night.append("敌速 +%d%%" % roundi(run.speed_bonus * 100.0))
	Atlas.label(side, " · ".join(next_night), Rect2(31, 217, 223, 25), 13, Atlas.GOLD)
	locate_site = Atlas.button(side, "回到所选", Rect2(153, 245, 92, 25), center_selected_site, false, 13)
	locate_site.hide()
	selection = Atlas.label(side, "", Rect2(30, 271, 214, 91), 28, Atlas.CREAM, true)
	description = Atlas.label(side, "", Rect2(31, 367, 213, 113), 16, Atlas.MUTED)
	confirm = Atlas.button(side, "前往", Rect2(30, 478, 215, 54), enter_selected, true, 18)
	Atlas.button(side, "誓言与行囊", Rect2(30, 550, 215, 39), func(): records_requested.emit(), false, 15)
	Atlas.label(side, "路线种子", Rect2(31, 631, 91, 24), 13, Atlas.MUTED)
	seed_input = LineEdit.new()
	seed_input.name = "RouteSeed"
	seed_input.text = str(run.run_seed)
	seed_input.placeholder_text = "留空则随机"
	seed_input.position = Vector2(123, 627)
	seed_input.size = Vector2(121, 33)
	seed_input.max_length = 20
	seed_input.add_theme_font_override("font", Atlas.BODY)
	seed_input.add_theme_font_size_override("font_size", 15)
	seed_input.add_theme_color_override("font_color", Atlas.CREAM)
	seed_input.add_theme_stylebox_override("normal", Atlas.box(Color("#172420"), Atlas.EDGE))
	side.add_child(seed_input)
	Atlas.button(side, "开始新巡夜", Rect2(30, 676, 214, 33), request_new_run, false, 15)
	seed_error = Atlas.label(side, "", Rect2(31, 712, 214, 22), 13, Atlas.GOLD)

func pick(id: int) -> void:
	selected = id
	update_selection()

func update_selection() -> void:
	for id in markers:
		var marker: Marker = markers[id]
		marker.selected = selected == id
		marker.queue_redraw()
	route_layer.queue_redraw()
	update_locate_site()
	var node: Dictionary = run.get_node_data(selected)
	confirm.disabled = node.is_empty()
	if not node.is_empty():
		selection.text = "%s\n%s" % [Route.ZONES[node.zone], Route.KIND_NAMES[node.kind]]
		description.text = Route.KIND_DETAILS[node.kind]
		confirm.text = Route.KIND_ACTIONS[node.kind]

func enter_selected() -> void:
	if selected >= 0:
		node_requested.emit(selected)

func request_new_run() -> void:
	var value := seed_input.text.strip_edges()
	if not value.is_empty() and not value.is_valid_int():
		seed_error.text = "请输入整数或留空"
		return
	new_run_requested.emit(int(value), value.is_empty())
