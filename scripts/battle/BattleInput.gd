class_name BattleInput
extends RefCounted

var battle: Node2D
var attack_held := false


func setup(level: Node2D) -> void:
	battle = level
	attack_held = false


func read_move_direction() -> Vector2:
	var horizontal := float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var vertical := float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	return Vector2(horizontal, vertical).normalized()


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and attack_held:
		attack_held = false
		if not battle.ended and not battle.paused and battle.open_slot < 0:
			battle.combat.release_attack()
		else:
			battle.combat.cancel_charge()
		battle.get_viewport().set_input_as_handled()
		return
	if battle.ended or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		battle.toggle_pause()
		battle.get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB and not battle.paused:
		battle.show_routes = not battle.show_routes
		battle.get_viewport().set_input_as_handled()


func handle_unhandled_input(event: InputEvent) -> void:
	if battle.ended:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if battle.paused:
			return
		match event.keycode:
			KEY_E:
				interact()
			KEY_Q:
				borrow_fire()
			KEY_R:
				battle.use_bridge()
			KEY_F:
				battle.lantern_on = not battle.lantern_on and battle.oil > 0.0
			KEY_ENTER:
				battle.start_night()
			KEY_SHIFT:
				battle.combat.dash()
			KEY_SPACE, KEY_J:
				battle.combat.slash()
			KEY_1, KEY_2, KEY_3, KEY_4:
				battle.build_selected(event.keycode - KEY_1)
			KEY_U:
				battle.upgrade_selected()
	elif not battle.paused and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and battle.open_slot < 0:
		attack_held = true
		battle.combat.start_charge()


func cancel_pointer_attack() -> void:
	if attack_held:
		attack_held = false
		battle.combat.cancel_charge()


func closest(points: Array[Vector2], reach: float) -> int:
	var index := -1
	var best := reach ** 2
	var origin: Vector2 = battle.player
	for candidate in range(points.size()):
		var distance := origin.distance_squared_to(points[candidate])
		if distance < best:
			index = candidate
			best = distance
	return index


func available_supply() -> int:
	var nearest := -1
	var best := 37.0 ** 2
	var origin: Vector2 = battle.player
	for index in range(battle.supplies.size()):
		var pile: Dictionary = battle.supplies[index]
		var distance := origin.distance_squared_to(pile["position"])
		if pile["available"] and distance < best:
			best = distance
			nearest = index
	return nearest


func needs_preparation() -> bool:
	return battle.oil < 100.0 or battle.combat.player_hp < battle.combat.player_hp_max


func action_hint() -> String:
	if available_supply() >= 0:
		return "E  拾取余烬与骨材"
	if battle.player.distance_to(battle.fire_point) <= battle.CAMP_REACH and (battle.fire_hp < 100.0 or needs_preparation()):
		return "E 添火（%d 余烬）  ·  Q 营火整备（%d 余烬）" % [battle.FUEL_COST, battle.OIL_COST]
	var index := closest(battle.slot_points, battle.SLOT_REACH)
	if index >= 0:
		return battle.combat.slot_hint(index, true) if battle.night else "E · " + battle.support_name[index]
	if battle.biome == 2 and closest(battle.levers, 68.0) >= 0:
		return "R  切换吊桥路线"
	return ""


func interact() -> void:
	if battle.open_slot >= 0:
		battle.close_build()
		return
	var supply := available_supply()
	if supply >= 0:
		var item: Dictionary = battle.supplies[supply]
		item["available"] = false
		battle.run.embers += item["embers"]
		battle.run.bone += item["bone"]
		battle.play_cue("wood")
		battle.announce("收取  %d 余烬  /  %d 骨材" % [item["embers"], item["bone"]])
		return
	if battle.player.distance_to(battle.fire_point) <= battle.CAMP_REACH and battle.fire_hp < 100.0:
		if battle.run.embers >= battle.FUEL_COST:
			battle.run.embers -= battle.FUEL_COST
			battle.heal_fire(22.0)
			battle.combat.ember_spent("fuel")
			battle.play_cue("fuel")
		else:
			battle.announce("余烬不足，无法添火")
		return
	var index := closest(battle.slot_points, battle.SLOT_REACH)
	if index >= 0:
		if battle.night:
			battle.combat.service_slot(index)
		else:
			battle.open_build(index)


func borrow_fire() -> void:
	if battle.player.distance_to(battle.fire_point) <= battle.CAMP_REACH and needs_preparation() and battle.run.embers >= battle.OIL_COST:
		battle.run.embers -= battle.OIL_COST
		battle.oil = minf(100.0, battle.oil + 52.0)
		battle.combat.player_hp = minf(battle.combat.player_hp_max, battle.combat.player_hp + 35.0)
		battle.lantern_on = true
		battle.play_cue("fuel")
		battle.announce("营火整备 · 补灯油，恢复生命")
