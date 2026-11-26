extends Node

const Atlas = preload("res://scripts/campaign/AtlasUI.gd")
const Route = preload("res://scripts/campaign/Route.gd")
const WorldMap = preload("res://scenes/main/WorldMap.tscn")
const MapScreen = preload("res://scripts/campaign/WorldMap.gd")
const VALLEY := "res://scenes/levels/Level01_FallenKing.tscn"
const BATTLE := "res://scenes/levels/BaseBattleLevel.tscn"
const FORGE := "res://scenes/ui/OathForgeUI.tscn"

var screen: Node
var modal: CanvasLayer
var modal_cancel: Callable
var modal_return_focus: Control
var map_focus_behavior := Control.FOCUS_BEHAVIOR_INHERITED

func _ready() -> void:
	if RunState.nodes.is_empty():
		RunState.start_new()
	show_map()

func show_map() -> void:
	var map = WorldMap.instantiate()
	set_screen(map)
	map.node_requested.connect(open_node)
	map.new_run_requested.connect(confirm_restart)
	map.records_requested.connect(show_records)
	map.configure(RunState)

func set_screen(scene: Node) -> void:
	close_modal(false)
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	screen = scene
	add_child(scene)

func open_node(id: int) -> void:
	if not RunState.begin_node(id):
		return
	var site := RunState.get_node_data(id)
	match int(site.kind):
		Route.Kind.BATTLE, Route.Kind.ELITE, Route.Kind.BOSS:
			open_battle(site)
		Route.Kind.CAMP:
			show_camp()
		Route.Kind.ALTAR:
			open_forge("", true, finish_node)
		Route.Kind.EVENT:
			show_encounter(site.event)

func open_battle(site: Dictionary) -> void:
	var level := load(VALLEY if site.zone == 0 else BATTLE) as PackedScene
	var battle = level.instantiate()
	battle.biome = site.zone
	battle.elite = site.kind == Route.Kind.ELITE
	battle.boss = site.kind == Route.Kind.BOSS
	RunState.prepare_battle()
	battle.completed.connect(battle_finished.bind(battle), CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	if battle.has_signal(&"return_requested"):
		battle.return_requested.connect(return_from_battle.bind(battle), CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	set_screen(battle)

func return_from_battle(battle: Node) -> void:
	if screen == battle:
		RunState.abandon_node()
		show_map()

func battle_finished(won: bool, battle: Node) -> void:
	if screen != battle:
		return
	var site := RunState.get_node_data(RunState.active_node)
	if not won:
		RunState.abandon_node()
		show_map()
		show_defeat(site.id)
		return
	var health = battle.get("fire_hp")
	var reward := RunState.settle_battle(float(health) if health != null else RunState.fire_start, site.kind == Route.Kind.ELITE)
	var first := RunState.cycle == 1 and RunState.victories == 1
	var boss: bool = site.kind == Route.Kind.BOSS
	var after: Callable = finish_cycle if boss else finish_node
	if not reward.is_empty():
		show_map()
		var panel := make_modal("守夜遗物", reward, RunState.RELICS[reward])
		Atlas.button(panel, "继续铸誓", Rect2(72, 279, 405, 48), func(): open_forge("", false, after), true)
	else:
		open_forge("SWORE" if first else "", false, after)

func open_forge(force_id: String, reroll: bool, after: Callable) -> void:
	var forge_scene := load(FORGE) as PackedScene
	var forge = forge_scene.instantiate()
	forge.chosen.connect(oath_chosen.bind(after), CONNECT_ONE_SHOT)
	set_screen(forge)
	forge.configure(RunState, force_id, reroll)

func oath_chosen(id: String, after: Callable) -> void:
	RunState.add_oath(id)
	after.call_deferred()

func finish_node() -> void:
	RunState.complete_node()
	show_map()

func finish_cycle() -> void:
	finish_node()
	var panel := make_modal("黑曜长墙", "黎明照上极北", "永夜先驱已倒下。踏入下一轮时将保留誓言、蓝图与遗物，前方道路重新展开，永夜怪物也会变强。")
	Atlas.button(panel, "进入永夜轮回 %d" % (RunState.cycle + 1), Rect2(72, 257, 405, 48), next_cycle, true)
	Atlas.button(panel, "重新开始", Rect2(72, 321, 405, 44), restart)

func next_cycle() -> void:
	RunState.start_next_cycle()
	show_map()

func show_camp() -> void:
	var panel := make_modal("余烬营地", "在石檐下歇一夜", "下场守夜的基准火势为 %d/100。添柴可以补回四十点，或重铸一张蓝图。" % roundi(RunState.fire_start))
	Atlas.button(panel, "添柴休整 · 火势 +40", Rect2(72, 247, 405, 45), rest_at_camp, true)
	Atlas.button(panel, "挑选要重铸的蓝图", Rect2(72, 310, 405, 45), show_blueprints)

func rest_at_camp() -> void:
	RunState.rest_fire()
	finish_node()

func show_blueprints() -> void:
	var panel := make_modal("重铸蓝图", "挑选一项工事", "初次建造将直接从蓝图等级开始。蓝图最高可升到三级，并可带入下轮。", show_camp)
	var index := 0
	for kind in RunState.TOWERS:
		var prior: int = RunState.blueprints.get(kind, 1)
		var caption := "%s  ·  Lv.%d → Lv.%d" % [RunState.TOWERS[kind], prior, prior + 1]
		if prior >= 3:
			caption = "%s  ·  已达三级" % RunState.TOWERS[kind]
		var button := Atlas.button(panel, caption, Rect2(26 + (index % 2) * 252, 225 + floori(index / 2.0) * 58, 244, 42), upgrade_at_camp.bind(kind), false, 15)
		button.disabled = prior >= 3
		index += 1
	Atlas.button(panel, "返回营火", Rect2(72, 347, 405, 39), show_camp)

func upgrade_at_camp(kind: String) -> void:
	if RunState.upgrade_blueprint(kind):
		finish_node()

func show_encounter(kind: int) -> void:
	if kind == 0:
		var panel := make_modal("夜话奇遇", "冻僵的逃兵", "石槛背后坐着一个冻僵的逃兵。他想借提灯火油撑到黎明，也愿替你守一晚的烽火。")
		Atlas.button(panel, "分出 30% 提灯油 · 下战获得助战", Rect2(42, 243, 465, 49), shelter_deserter, true)
		Atlas.button(panel, "夺走他的干粮 · 余烬 +60", Rect2(42, 307, 465, 49), take_supplies)
		return
	var panel := make_modal("夜话奇遇", "巨骨低语", "一道裂纹从巨剑锋刃钻进骸骨。触碰它将唤来一枚史诗铭文，也会令下战敌人移速增加 15%。")
	var accept := Atlas.button(panel, "触碰剑痕 · 领受史诗铭文", Rect2(42, 243, 465, 49), listen_to_bones, true)
	accept.disabled = OathDatabase.epic_unowned(RunState.oaths).is_empty()
	Atlas.button(panel, "离开骸骨", Rect2(42, 307, 465, 49), finish_node)

func shelter_deserter() -> void:
	RunState.ally = true
	RunState.oil_start = 70.0
	finish_node()

func take_supplies() -> void:
	RunState.embers += 60
	finish_node()

func listen_to_bones() -> void:
	var choices := OathDatabase.epic_unowned(RunState.oaths)
	if not choices.is_empty():
		var id: String = choices[0]
		RunState.speed_bonus = 0.15
		open_forge(id, false, finish_node)

func confirm_restart() -> void:
	if RunState.visited.is_empty():
		restart()
		return
	var panel := make_modal("烽火路线", "重开这一程？", "开始新的巡夜将清空本轮誓言、行囊与道路进度。", close_modal)
	Atlas.button(panel, "重开巡夜", Rect2(72, 249, 405, 47), restart, true)
	Atlas.button(panel, "继续当前巡夜", Rect2(72, 315, 405, 43), close_modal).grab_focus.call_deferred()

func restart() -> void:
	RunState.start_new()
	show_map()

func show_defeat(id: int) -> void:
	var panel := make_modal("守夜结束", "这处火种熄灭了", "这轮共守成 %d 场夜战。可以回到这场开始时的状态，或返回行图改选前路。" % RunState.victories, close_modal)
	Atlas.button(panel, "重试本场", Rect2(72, 222, 405, 44), open_node.bind(id), true)
	Atlas.button(panel, "返回行图", Rect2(72, 278, 405, 44), close_modal)
	Atlas.button(panel, "重新开始", Rect2(72, 334, 405, 44), restart)

func show_records() -> void:
	var panel := make_modal("守夜人的行囊", "誓言与行囊", "", close_modal)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 103)
	scroll.size = Vector2(492, 235)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.add_theme_constant_override("separation", 9)
	scroll.add_child(entries)
	add_record(entries, "已铸誓言", Atlas.GOLD)
	if RunState.oaths.is_empty():
		add_record(entries, "首次守夜胜利后可改字铸誓。")
	for id in RunState.oaths:
		var oath := OathDatabase.get_oath(id)
		if not oath.is_empty():
			add_record(entries, "%s → %s  ·  %s\n%s" % [oath.base, id, oath.title, oath.effect])
	add_record(entries, "初建蓝图", Atlas.GOLD)
	var towers: Array[String] = []
	for kind in RunState.TOWERS:
		towers.append("%s Lv.%d" % [RunState.TOWERS[kind], RunState.blueprints.get(kind, 1)])
	add_record(entries, "   ·   ".join(towers))
	add_record(entries, "守夜遗物", Atlas.GOLD)
	if RunState.relics.is_empty():
		add_record(entries, "击败精英后可获得遗物。")
	for relic in RunState.relics:
		add_record(entries, "%s  ·  %s" % [relic, RunState.RELICS[relic]])
	Atlas.button(panel, "返回大陆", Rect2(72, 352, 405, 38), close_modal)

func add_record(parent: Control, text: String, color: Color = Atlas.CREAM) -> void:
	var entry := Atlas.label(parent, text, Rect2(0, 0, 467, 20), 16, color)
	entry.custom_minimum_size.x = 467

func make_modal(tag: String, title: String, description: String, cancel := Callable()) -> Panel:
	var prior := modal_return_focus if is_instance_valid(modal) else get_viewport().gui_get_focus_owner()
	close_modal(false)
	if screen is MapScreen:
		map_focus_behavior = screen.focus_behavior_recursive
		if is_instance_valid(prior) and screen.is_ancestor_of(prior):
			modal_return_focus = prior
			prior.release_focus()
		screen.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
		screen.set_chart_input_enabled(false)
	modal_cancel = cancel
	modal = CanvasLayer.new()
	modal.layer = 30
	add_child(modal)
	var curtain := ColorRect.new()
	curtain.size = Vector2(1280, 800)
	curtain.color = Color("#080f10ae")
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(curtain)
	var panel := Atlas.panel(curtain, Rect2(365, 192, 550, 416), Color("#15201e"), Color("#ad966e"))
	Atlas.fill(panel, Rect2(27, 96, 496, 1), Atlas.EDGE)
	Atlas.label(panel, tag, Rect2(27, 21, 496, 23), 15, Atlas.GOLD)
	Atlas.label(panel, title, Rect2(27, 48, 496, 43), 33, Atlas.CREAM, true)
	if not description.is_empty():
		var body := Atlas.label(panel, description, Rect2(27, 124, 496, 94), 18, Atlas.MUTED)
		body.size = Vector2(496, 94)
	focus_modal.call_deferred(modal)
	return panel

func focus_modal(overlay: CanvasLayer) -> void:
	if not is_instance_valid(overlay) or overlay != modal:
		return
	var choices: Array[Button] = []
	for button: Button in overlay.find_children("*", "Button", true, false):
		if not button.disabled and button.is_visible_in_tree():
			choices.append(button)
	for index in choices.size():
		var button := choices[index]
		button.focus_next = button.get_path_to(choices[(index + 1) % choices.size()])
		button.focus_previous = button.get_path_to(choices[posmod(index - 1, choices.size())])
	if not choices.is_empty():
		choices[0].grab_focus()

func _input(event: InputEvent) -> void:
	if is_instance_valid(modal) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if modal_cancel.is_valid():
			modal_cancel.call()

func close_modal(restore_focus := true) -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
		if screen is MapScreen:
			screen.focus_behavior_recursive = map_focus_behavior
			screen.set_chart_input_enabled(true)
			if restore_focus and is_instance_valid(modal_return_focus):
				modal_return_focus.grab_focus()
		modal = null
	modal_return_focus = null
	modal_cancel = Callable()
