extends SceneTree

const Model = preload("res://scripts/model/BattleModel.gd")
const Terrain = preload("res://scripts/battle/BattleMaps.gd")
const Collision = preload("res://scripts/battle/BattleCollision.gd")
const Lights = preload("res://scripts/battle/LightManager.gd")
const VALLEY_THORAX := "res://assets/props/fallen_king/valley_tripo_ribs.glb"
const VALLEY_ARMS := "res://assets/props/fallen_king/valley_tripo_arm.glb"
const VALLEY_FOSSILS := [
	"res://assets/props/fallen_king/valley_tripo_cranium.glb",
	VALLEY_THORAX,
	VALLEY_ARMS,
]

var checks := 0
var failures := 0

func _initialize() -> void:
	run_checks.call_deferred()

func run_checks() -> void:
	var battle_script: Script = load("res://scripts/battle/BattleLevel.gd")
	var rules := battle_script.get_script_constant_map()
	for biome in range(4):
		await check_region(biome, rules.PLAYER_RADIUS, rules.SLOT_REACH)
	await check_valley_eye_ballista()
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
	if biome == 0:
		check_valley_fossils(model, resolver)
		check_valley_saddle(resolver, watcher_radius)
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

func check_valley_fossils(model: Model, resolver: Collision) -> void:
	var nodes := model.find_children("*", "Node3D", true, false)
	for path: String in VALLEY_FOSSILS:
		var instances := nodes.filter(func(node: Node): return node.scene_file_path == path)
		verify(instances.size() == 1, "%s is instantiated once in the live Valley" % path.get_file())
		if instances.size() != 1:
			continue
		var imported: Node3D = instances[0]
		var visible_parts: Array[Node] = imported.find_children("*", "MeshInstance3D", true, false)
		if imported is MeshInstance3D:
			visible_parts.append(imported)
		var tagged := 0
		var exact := true
		var hit := false
		for part: MeshInstance3D in visible_parts:
			if not part.is_visible_in_tree() or part.mesh == null:
				continue
			if not part.get_meta(&"walk_obstacle", false):
				exact = false
				continue
			tagged += 1
			var body := part.get_node_or_null("Walking collision") as StaticBody3D
			var shape_node := body.get_child(0) as CollisionShape3D if body != null and body.get_child_count() > 0 else null
			var shape := shape_node.shape as ConcavePolygonShape3D if shape_node != null else null
			var placed := (shape != null and not shape_node.disabled and (body.collision_layer & Collision.MASK) != 0
				and shape_node.global_transform.is_equal_approx(part.global_transform))
			exact = exact and placed and shape.get_faces() == part.mesh.get_faces()
			if placed:
				hit = hit or fossil_surface_hit(model, body, shape.get_faces())
		verify(tagged > 0 and exact, "%s collision uses its imported triangles and final transform" % path.get_file())
		verify(hit, "%s imported surfaces take hits in the active physics world" % path.get_file())
		if path == VALLEY_THORAX:
			var connected := largest_connected_share(visible_parts)
			verify(connected >= 0.95, "Thorax keeps at least 95%% of its triangles connected after welding UV seams (%.1f%%)" % (connected * 100.0))
		elif path == VALLEY_ARMS:
			check_forearm_connectivity(visible_parts)

func check_forearm_connectivity(parts: Array[Node]) -> void:
	var northern := false
	var eastern := false
	for part: MeshInstance3D in parts:
		if not part.is_visible_in_tree() or part.mesh == null:
			continue
		var label := String(part.name).to_lower()
		northern = northern or label.begins_with("northern forearm") or label.begins_with("northern_forearm")
		eastern = eastern or label.begins_with("eastern forearm") or label.begins_with("eastern_forearm")
		# The two arms and buried hand are separate anatomical pieces on purpose.
		var connected := largest_connected_share([part])
		verify(connected >= 0.95, "%s keeps at least 95%% of its triangles connected after welding UV seams (%.1f%%)" % [part.name, connected * 100.0])
	verify(northern and eastern, "Both authored Tripo forearms are installed and visible")

func largest_connected_share(parts: Array[Node]) -> float:
	var vertex_ids: Dictionary = {}
	var parents := PackedInt32Array()
	var triangle_roots := PackedInt32Array()
	for part: MeshInstance3D in parts:
		if not part.is_visible_in_tree() or part.mesh == null:
			continue
		# Indices differ across UV seams, so use a small position tolerance in scene space.
		var corners := PackedInt32Array()
		var faces := part.mesh.get_faces()
		corners.resize(faces.size())
		for index in range(faces.size()):
			var vertex := part.global_transform * faces[index]
			var cell := Vector3i((vertex / 0.0015).round())
			if not vertex_ids.has(cell):
				vertex_ids[cell] = parents.size()
				parents.append(-1)
			corners[index] = vertex_ids[cell]
		for index in range(0, corners.size() - 2, 3):
			var first := corners[index]
			join_vertices(parents, first, corners[index+1])
			join_vertices(parents, first, corners[index+2])
			triangle_roots.append(first)
	if triangle_roots.is_empty():
		return 0.0
	var counts: Dictionary = {}
	var largest := 0
	for id in triangle_roots:
		var component := vertex_root(parents, id)
		var count: int = counts.get(component, 0) + 1
		counts[component] = count
		largest = maxi(largest, count)
	return float(largest) / triangle_roots.size()

func vertex_root(parents: PackedInt32Array, vertex: int) -> int:
	while parents[vertex] >= 0:
		var parent := parents[vertex]
		if parents[parent] >= 0:
			parents[vertex] = parents[parent]
		vertex = parent
	return vertex

func join_vertices(parents: PackedInt32Array, a: int, b: int) -> void:
	var left := vertex_root(parents, a)
	var right := vertex_root(parents, b)
	if left == right:
		return
	if parents[left] > parents[right]:
		var swap := left
		left = right
		right = swap
	parents[left] += parents[right]
	parents[right] = left

func fossil_surface_hit(model: Model, body: StaticBody3D, faces: PackedVector3Array) -> bool:
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = Collision.MASK
	query.hit_back_faces = true
	var space := model.get_world_3d().direct_space_state
	var step := maxi(1, ceili(faces.size() / 54.0)) * 3
	for index in range(0, faces.size() - 2, step):
		var a := body.to_global(faces[index])
		var b := body.to_global(faces[index+1])
		var c := body.to_global(faces[index+2])
		var across := (b-a).cross(c-a)
		if across.length_squared() < 0.00000001:
			continue
		var surface := (a+b+c) / 3.0
		var normal := across.normalized() * 0.019
		query.from = surface + normal
		query.to = surface - normal
		if space.intersect_ray(query).get("collider") == body:
			return true
	return false

func check_valley_saddle(resolver: Collision, watcher_radius: float) -> void:
	var saddle_start := Terrain.point([507,167])
	var saddle_end := Terrain.point([532,148])
	var arm_start := Terrain.point([552,398])
	var arm_end := Terrain.point([578,359])
	for radius: float in [10.0, watcher_radius, 15.0]:
		verify(resolver.can_stand(saddle_start, radius) and resolver.can_stand(saddle_end, radius)
			and resolver.traverse_clear(saddle_start, saddle_end, radius)
			and resolver.traverse_clear(saddle_end, saddle_start, radius),
			"The Valley saddle stays open in both directions for radius %d" % radius)
		var path := resolver.search(arm_start, arm_end, radius)
		var traveled := 0.0
		var last := arm_start
		var clear := resolver.can_stand(arm_start, radius) and resolver.can_stand(arm_end, radius)
		for target in path:
			clear = clear and resolver.traverse_clear(last, target, radius)
			traveled += last.distance_to(target)
			last = target
		verify(clear and last.is_equal_approx(arm_end) and traveled <= arm_start.distance_to(arm_end) * 1.65,
			"A local route around the Valley arm break stays reachable for radius %d" % radius)

func check_valley_eye_ballista() -> void:
	var scene: PackedScene = load("res://scenes/levels/Level01_FallenKing.tscn")
	var battle := scene.instantiate()
	root.add_child(battle)
	battle.set_physics_process(false)
	battle.ambience.stop()
	battle.ambience.stream = null
	await physics_frame
	await physics_frame
	var eye: Node = battle.combat.towers[1]
	var anchor: Vector2 = eye.position
	var reachable := connected_ground(battle.collision, battle.player, battle.PLAYER_RADIUS)
	var distance := INF
	for stand in reachable:
		var gap := stand.distance_squared_to(anchor)
		if gap < distance:
			distance = gap
			battle.player = stand
	verify(distance < battle.SLOT_REACH ** 2, "The elevated eye ballista can be reached from the normal Valley spawn")
	battle.interact()
	verify(battle.open_slot == 1, "Normal interaction opens the eye ballista socket")
	battle.build_selected(1)
	verify(eye.kind == "ballista" and eye.level == 1, "The eye socket accepts its ballista through normal build controls")
	battle.scenery.reliquary.sync(battle.clock)
	var fixture: MeshInstance3D = battle.scenery.reliquary.contents[1]
	var muzzle := fixture.to_global(Vector3(0.0, 0.23, 0.0))
	var sphere := SphereShape3D.new()
	sphere.radius = 0.035
	var placement := PhysicsShapeQueryParameters3D.new()
	placement.shape = sphere
	placement.collision_mask = Collision.MASK
	placement.transform = Transform3D(Basis.IDENTITY, muzzle)
	verify(battle.scenery.model.get_world_3d().direct_space_state.intersect_shape(placement, 1).is_empty(),
		"The installed eye ballista muzzle sits in open terrain space")
	battle.start_night()
	verify(eye_aims_at_lane(battle, eye, reachable), "The elevated eye ballista damages a lit lane enemy and emits its shot from the muzzle")
	battle.cue.stop()
	battle.cue.stream = null
	battle.queue_free()
	await process_frame

func eye_aims_at_lane(battle: Node, eye: Node, reachable: PackedVector2Array) -> bool:
	for lane in range(battle.paths.size()):
		var route: PackedVector2Array = battle.route_for_actor(lane, 10.0)
		for step in range(1, route.size()):
			var count := maxi(1, ceili(route[step-1].distance_to(route[step]) / 18.0))
			for sample in range(count):
				var target := route[step-1].lerp(route[step], float(sample) / count)
				if target.distance_to(eye.position) > battle.combat.inspect_radius(1):
					continue
				if not light_lane_from_ground(battle, target, reachable):
					continue
				var crawler = battle.combat.spawn(battle.Combat.Enemy.CRAWLER, lane)
				crawler.position = target
				var initial: float = crawler.health
				var fired: bool = battle.combat.tower_sys.fire_ballista(eye, battle.combat.enemies)
				var effects: Array[Dictionary] = battle.combat.effects_layer.effects
				var traced: bool = effects.any(func(effect: Dictionary) -> bool:
					return effect.has("b") and effect.a.is_equal_approx(battle.support_muzzle(1)))
				return fired and traced and crawler.health < initial
	return false

func light_lane_from_ground(battle: Node, target: Vector2, reachable: PackedVector2Array) -> bool:
	for stand in reachable:
		var offset := target - stand
		if offset.length_squared() < 28.0 ** 2 or offset.length_squared() > 138.0 ** 2:
			continue
		battle.player = stand
		battle.aim = offset.normalized()
		battle.refresh_lights()
		if battle.light_manager.is_position_lit(target):
			return true
	return false

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
