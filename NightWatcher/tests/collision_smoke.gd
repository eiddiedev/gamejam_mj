extends SceneTree

const Model = preload("res://scripts/model/BattleModel.gd")
const Terrain = preload("res://scripts/battle/BattleMaps.gd")
const Collision = preload("res://scripts/battle/BattleCollision.gd")
const Lights = preload("res://scripts/battle/LightManager.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	run_checks.call_deferred()

func run_checks() -> void:
	var battle_script: Script = load("res://scripts/battle/BattleLevel.gd")
	var rules := battle_script.get_script_constant_map()
	for biome in range(4):
		await check_region(biome, rules.PLAYER_RADIUS, rules.SLOT_REACH)
	await check_transformed_terrain()
	await check_occupied_bridges()
	print("Night Watcher mesh collision: %d checks, %d failed" % [checks, failures])
	quit(int(failures > 0))

func check_region(biome: int, watcher_radius: float, interaction_range: float) -> void:
	var region: Dictionary = Terrain.MAPS[biome]
	var view := make_view()
	var model := Model.new()
	view.add_child(model)
	model.build_region(biome)
	var resolver := Collision.new()
	var bridges: Array[Vector2] = []
	bridges.assign(Array(Terrain.line(region.get("bridges", []))))
	var paths := Terrain.polygons(region["routes"])
	var detours := Terrain.polygons(region.get("detours", []))
	resolver.setup(model, Terrain.ART.grow(-8.0), Terrain.polygons(region.get("water", [])), bridges, paths)
	var extra: Array[MeshInstance3D] = []
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_meta(&"walk_obstacle", false):
			extra.append(mesh)
	resolver.register_meshes(extra)
	await physics_frame
	await physics_frame
	var hearth := Terrain.point(region["fire"])
	var watcher := Terrain.point(region["start"])
	verify(resolver.can_stand(watcher, watcher_radius), "%d watcher spawn is clear" % biome)
	verify(resolver.can_stand(hearth, watcher_radius), "%d hearth approach is clear" % biome)
	if biome == 3:
		check_obsidian_gates(resolver, watcher_radius)
	var reachable := connected_ground(resolver, watcher, watcher_radius)
	for site: Array in Terrain.SUPPORTS[biome]:
		var anchor := Terrain.point(site[0])
		var accessible := false
		for stand in reachable:
			if stand.distance_squared_to(anchor) < interaction_range * interaction_range:
				accessible = true
				break
		verify(accessible, "%d %s can be approached from the watcher spawn" % [biome, site[3]])
	for state: int in ([-1, 0, 1] if biome == 2 else [-1]):
		var effective: Array[PackedVector2Array] = []
		for index in range(paths.size()):
			effective.append(detours[index] if state >= 0 and int(index > 0) == state else paths[index])
		resolver.set_bridge(state, effective)
		if state >= 0:
			verify(not resolver.terrain_allows(bridges[state], 12.0, false), "Raised bridge rejects a grounded actor")
		for lane in range(effective.size()):
			for radius: float in [10.0, 15.0]:
				var route := resolver.route(lane, effective[lane], radius)
				var connected := route.size() >= 2 and route[-1].distance_to(hearth) < 1.0
				var clear := connected and resolver.can_stand(route[0], radius)
				for index in range(1, route.size()):
					clear = clear and resolver.traverse_clear(route[index - 1], route[index], radius)
				verify(clear, "%d bridge %d lane %d radius %d sweeps to the hearth" % [biome, state, lane, radius])
	view.queue_free()
	await process_frame

func check_obsidian_gates(resolver: Collision, watcher_radius: float) -> void:
	for gate in [[460.0, 270.0, 0.34], [615.0, 146.0, -0.53]]:
		var center := Terrain.point([gate[0], gate[1]])
		var axis := Vector2(-sin(gate[2]), sin(Model.PITCH) * cos(gate[2]))
		var span := axis * Model.PIXELS * 0.75
		var inside := center + span
		var outside := center - span
		verify(resolver.can_stand(center, watcher_radius)
			and resolver.traverse_clear(inside, outside, watcher_radius)
			and resolver.traverse_clear(outside, inside, watcher_radius),
			"The watcher can pass through the open Obsidian gate at %s" % center)
		verify(not resolver.traverse_clear(inside, outside, 15.0),
			"The same Obsidian lintel blocks a tall ground enemy")

func connected_ground(resolver: Collision, watcher: Vector2, radius: float) -> PackedVector2Array:
	var grid := resolver.grid(radius)
	var first := resolver.nearby_cell(grid, watcher, radius)
	if not grid.is_in_boundsv(first):
		return PackedVector2Array()
	var pending: Array[Vector2i] = [first]
	var seen := {first: true}
	var points := PackedVector2Array()
	var index := 0
	while index < pending.size():
		var current := pending[index]
		var stand := grid.get_point_position(current)
		points.append(stand)
		index += 1
		for step: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next := current + step
			if not grid.is_in_boundsv(next) or seen.has(next) or grid.is_point_solid(next):
				continue
			if resolver.traverse_clear(stand, grid.get_point_position(next), radius):
				seen[next] = true
				pending.append(next)
	return points

func check_transformed_terrain() -> void:
	var view := make_view()
	var model := Model.new()
	view.add_child(model)
	var ground := MeshInstance3D.new()
	ground.name = "Terrain, ruins and landmarks"
	model.add_child(ground)
	var resolver := Collision.new()
	resolver.setup(model, Terrain.ART.grow(-8.0), [], [], [])
	var origin := Vector2(640, 400)
	var gate := Node3D.new()
	gate.position = model.screen_floor(origin)
	gate.rotation.y = 0.21
	model.add_child(gate)
	var lintel := add_box(gate, Vector3(0.0, 2.0, 0.0), Vector3(2.8, 0.3, 0.4))
	var left := add_box(gate, Vector3(-1.16, 0.86, 0.0), Vector3(0.44, 1.72, 0.4))
	var right := add_box(gate, Vector3(1.16, 0.86, 0.0), Vector3(0.44, 1.72, 0.4))
	resolver.register_meshes([lintel, left, right])
	await physics_frame
	await physics_frame
	var approach := origin + Vector2(-21, -90)
	var exit := origin + Vector2(21, 90)
	verify(resolver.traverse_clear(approach, exit, 12.0), "Watcher passes through the actual elevated arch opening")
	verify(not resolver.traverse_clear(approach, exit, 15.0), "A tall giant collides with the low lintel")
	var post_a := approach + Vector2(62, 0)
	var post_b := exit + Vector2(62, 0)
	var stopped := resolver.sweep(post_a, post_b - post_a, 12.0)
	verify(stopped.distance_to(post_b) > 40.0 and resolver.can_stand(stopped, 12.0),
		"A long dash sweeps against a rotated post without tunneling into it")
	var lighting := Lights.new()
	view.add_child(lighting)
	lighting.install_walls([], model)
	lighting.set_sources([{"position": post_a, "radius": 230.0}], [])
	verify(not lighting.is_position_lit(post_b) and lighting.is_position_lit(post_b, true),
		"The visible stone post blocks a low light ray while explicit high-ground sight can bypass it")
	lighting.set_sources([{"position": approach, "radius": 230.0}], [])
	verify(lighting.is_position_lit(exit), "The same light reaches through the real opening below the stone lintel")
	view.queue_free()
	await process_frame

func check_occupied_bridges() -> void:
	var level: PackedScene = load("res://scenes/levels/BaseBattleLevel.tscn")
	for index in range(2):
		var battle := level.instantiate()
		battle.biome = 2
		root.add_child(battle)
		battle.ambience.stop()
		battle.ambience.stream = null
		await physics_frame
		await physics_frame
		var reachable := connected_ground(battle.collision, battle.player, battle.PLAYER_RADIUS)
		var crossing: Vector2 = battle.bridges[index]
		battle.player = crossing
		battle.use_bridge()
		verify(battle.bridge_closed == -1, "Bridge %d cannot rise under the watcher" % index)
		for stand in reachable:
			if not battle.collision.occupies_bridge(index, stand, battle.PLAYER_RADIUS, 2.0):
				battle.player = stand
				if battle.closest(battle.levers, 68.0) == index:
					break
		var at_lever: bool = (
			battle.closest(battle.levers, 68.0) == index
			and not battle.collision.occupies_bridge(index, battle.player, battle.PLAYER_RADIUS, 2.0)
		)
		verify(at_lever, "Bridge %d lever can be operated from dry ground connected to the spawn" % index)
		var crawler = battle.combat.spawn(battle.Combat.Enemy.CRAWLER, index)
		crawler.position = crossing
		battle.use_bridge()
		verify(battle.bridge_closed == -1 and battle.bridge_cooldown <= 0.0
			and battle.collision.can_stand(crossing, crawler.radius),
			"Bridge %d stays traversable and ready to retry while a grounded enemy is on deck" % index)
		crawler.position = crawler.path[0]
		var moth = battle.combat.spawn(battle.Combat.Enemy.MOTH, index)
		moth.position = crossing
		battle.use_bridge()
		verify(battle.bridge_closed == index and not battle.collision.can_stand(crossing, crawler.radius),
			"Bridge %d rises once the deck clears even with an enemy overhead" % index)
		battle.queue_free()
		await process_frame

func add_box(parent: Node3D, at: Vector3, dimensions: Vector3) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	piece.mesh = box
	piece.position = at
	parent.add_child(piece)
	return piece

func make_view() -> SubViewport:
	var result := SubViewport.new()
	result.size = Vector2i(1280, 800)
	result.own_world_3d = true
	root.add_child(result)
	return result

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
