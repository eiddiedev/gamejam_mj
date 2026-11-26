extends SceneTree

const Game = preload("res://main.gd")
const Scene = preload("res://main.tscn")

var game: Game
var checked := 0
var failures := 0
var capture_folder := ""

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		capture_folder = arguments[0]
		DirAccess.make_dir_recursive_absolute(capture_folder)
	root.size = Vector2i(1376, 768)
	game = Scene.instantiate()
	root.add_child(game)
	if capture_folder.is_empty():
		game.ambience.stop()
		game.muted = true
	game.set_process(false)
	await capture("01-machine-room")
	await click("接入监视器   ↵")
	expect(game.stage == Game.Stage.ARCHIVE, "Intro button opens the live desktop")
	expect(game.total_left == 180.0, "Initial clock is 180 seconds")
	await capture("02-archive")
	var archive := game.ui.find_child("Archive", true, false) as Panel
	game.window_action(archive, 1)
	expect(archive.scale.x > 1.0, "Archive can be enlarged")
	game.window_action(archive, 1)
	expect(archive.scale == Vector2.ONE, "Enlarged archive can restore its original scale")
	game.window_action(archive, 0)
	expect(not archive.visible, "Windows can be minimized")
	game.show_archive_window()
	expect(archive.visible, "Desktop icon restores minimized archive")
	await click("永昌堡")
	expect(game.stage == Game.Stage.ARCHIVE and game.seen.size() == 1, "One clue does not unlock the terminal")
	await click("永昌堡")
	expect(game.seen.size() == 1, "Same clue does not count twice")
	await click("0x8041_ERR")
	expect(game.stage == Game.Stage.PRUNE and game.field == null, "Both clues unlock pruning while the terminal stays closed")
	var anomalous_picture := game.picture.texture
	await click_picture(Vector2(0.45, 0.45))
	var confirm := find_button(game.ui, "确认剪除")
	expect(game.stage == Game.Stage.PRUNE and not game.prune_selected and game.prune_elapsed < 0.0
		and game.picture.texture == anomalous_picture, "Clicking the fortress leaves the historical feed intact")
	expect(confirm == null or not confirm.is_visible_in_tree() or confirm.disabled,
		"Confirmation is unavailable until the anomaly is selected")
	await click_picture(Game.CAM_ART.MACHINE_BOUNDS.get_center())
	expect(game.stage == Game.Stage.PRUNE and game.prune_selected and game.prune_elapsed < 0.0
		and game.picture.texture == anomalous_picture, "Selecting the machine keeps it visible for review")
	await capture("02a-prune-selected")
	var time_before_confirmation := game.total_left
	await click("确认剪除")
	game._process(0.72)
	expect(game.stage == Game.Stage.PRUNE and game.prune_elapsed >= 0.0 and game.field == null,
		"Confirmed pruning completes visually before the terminal opens")
	expect(game.picture.texture != anomalous_picture, "Confirmed pruning shows the cleaned camera plate")
	expect(game.total_left < time_before_confirmation and game.purge_left < 0.0,
		"Pruning consumes overall time before the purge starts")
	await capture("02b-pruned")
	game._process(0.68)
	expect(game.stage == Game.Stage.CONTACT, "Completed pruning unlocks dialogue")
	game._process(0.23)
	expect(game.transcript.text.length() > 0 and game.transcript.text.length() < Game.FIRST_LINE.length(), "Dialogue types in progressively")
	game._process(3.0)
	if not capture_folder.is_empty():
		await create_timer(0.4).timeout
	await capture("03-contact")
	await enter("unknown")
	expect(game.stage == Game.Stage.CONTACT and game.purge_left < 0.0, "Unknown command does not start purge")
	await enter("who are you")
	expect(game.stage == Game.Stage.SCAN and game.purge_left == 45.0, "Initial answer starts the 45-second purge")
	var menu := InputEventKey.new()
	menu.keycode = KEY_ESCAPE
	menu.pressed = true
	root.push_input(menu, true)
	game._process(0.5)
	expect(game.paused and game.purge_left == 45.0, "Escape pauses the purge clock inside terminal")
	root.push_input(menu, true)
	await enter("keep --pid 8041")
	expect(game.stage == Game.Stage.SCAN, "Keep requires prior scan")
	await enter("scan --cam 08")
	expect(game.stage == Game.Stage.KEEP, "Exact scan command locks the target")
	await capture("04-terminal")
	await enter("keep --pid 8041")
	expect(game.stage == Game.Stage.SAVED, "Ordered commands preserve the archive")
	if game.picture != null:
		var material := game.picture.material as ShaderMaterial
		expect(material.get_shader_parameter("preserved"), "Preserved camera renders green")
	expect(find_label(Game.LETTER) != null, "Preserved final message is visible")
	await capture("05-saved")
	await click("NEXT LEVEL")
	expect(game.stage == Game.Stage.NEXT, "Next opens a new archive scene")
	expect(find_label("下一关 · 未知回波") != null, "Next scene has the second signal")
	await click("重玩零号档案")
	expect(game.stage == Game.Stage.ARCHIVE and game.seen.is_empty() and not game.prune_selected
		and game.prune_elapsed < 0.0, "Replay resets clues and pruning")
	await click("0x8041_ERR")
	await click("永昌堡")
	await complete_pruning()
	await enter("status")
	expect(game.stage == Game.Stage.SCAN, "Alternative status response is accepted")
	game._process(44.9)
	expect(game.stage == Game.Stage.SCAN, "Purge remains live before its deadline")
	game._process(0.2)
	expect(game.stage == Game.Stage.LOST, "45-second purge can lose the level")
	await capture("06-lost")
	await click("RETRY")
	game._process(172.0)
	await click("永昌堡")
	await click("0x8041_ERR")
	await complete_pruning()
	await enter("status")
	game._process(8.01)
	expect(game.stage == Game.Stage.LOST, "Overall deadline still applies after terminal unlock")
	await click("返回标题")
	expect(game.stage == Game.Stage.INTRO, "Failure can return to title")
	print("Spacetime Sentinel: %d checks, %d failed" % [checked, failures])
	game.queue_free()
	await create_timer(0.12).timeout
	quit(int(failures > 0))

func click(words: String) -> void:
	var target := find_button(game.ui, words)
	if target == null:
		expect(false, "Button exists: " + words)
		return
	await process_frame
	await click_at(target.get_global_transform_with_canvas() * (target.size * 0.5))

func click_picture(uv: Vector2) -> void:
	await process_frame
	var where := game.picture.get_global_transform_with_canvas() * (game.picture.size * uv)
	await click_at(where)

func complete_pruning() -> void:
	await click_picture(Game.CAM_ART.MACHINE_BOUNDS.get_center())
	await click("确认剪除")
	game._process(1.40)

func click_at(where: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = where
	event.global_position = where
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func enter(command: String) -> void:
	await process_frame
	if not is_instance_valid(game.field):
		expect(false, "Terminal input exists")
		return
	for letter in command:
		var key := InputEventKey.new()
		key.unicode = letter.unicode_at(0)
		key.keycode = key.unicode
		key.pressed = true
		root.push_input(key, true)
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func find_button(at: Node, words: String) -> Button:
	if at is Button and at.text == words:
		return at
	for child in at.get_children():
		var result := find_button(child, words)
		if result != null:
			return result
	return null

func find_label(words: String) -> Label:
	for node in game.ui.find_children("*", "Label", true, false):
		if words in node.text:
			return node
	return null

func capture(name: String) -> void:
	if capture_folder.is_empty():
		return
	for index in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(capture_folder.path_join(name + ".png"))
	expect(error == OK, "Visual capture saved: " + name)

func expect(result: bool, detail: String) -> void:
	checked += 1
	if not result:
		failures += 1
		push_error(detail)
