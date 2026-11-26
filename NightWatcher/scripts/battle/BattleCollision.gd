extends RefCounted

# Movement stays in the battlefield plane. Queries use the same mesh and
# coordinate transform as the projected 3D scenery.
const MASK := 1 << 19
const FIXTURE_MASK := 1 << 20
const GRID_STEP := 15.0
const BANK_STEP := 4.0
const SKIN := 0.35
const BRIDGE_CLEARANCE := 29.0
const CLOSED_BRIDGE_RADIUS := 27.0
const LOW_STEP := 0.28

var model: Node3D
var area: Rect2
var water: Array[PackedVector2Array] = []
var bridges: Array[Vector2] = []
var route_edges: Array[PackedVector2Array] = []
var closed_bridge := -1
var const_queries: Dictionary = {}
var grids: Dictionary = {}
var traced_routes: Dictionary = {}
var mesh_ids: Dictionary = {}

func setup(world: Node3D, bounds: Rect2, channels: Array[PackedVector2Array],
		crossings: Array[Vector2], routes: Array[PackedVector2Array]) -> void:
	model = world
	area = bounds
	water = channels
	bridges = crossings
	set_bridge(-1, routes)
	register_meshes([model.get_node("Terrain, ruins and landmarks")])

func register_meshes(instances: Array) -> void:
	for instance: MeshInstance3D in instances:
		if instance.mesh == null or instance.mesh.get_surface_count() == 0 or mesh_ids.has(instance.get_instance_id()):
			continue
		var body := StaticBody3D.new()
		body.name = "Walking collision"
		body.collision_layer = MASK
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var tris: ConcavePolygonShape3D = instance.mesh.create_trimesh_shape()
		if tris == null:
			continue
		tris.backface_collision = true
		shape.shape = tris
		body.add_child(shape)
		instance.add_child(body)
		mesh_ids[instance.get_instance_id()] = true
	grids.clear()
	traced_routes.clear()

func set_bridge(state: int, routes: Array[PackedVector2Array]) -> void:
	closed_bridge = state
	route_edges.clear()
	if water.is_empty():
		return
	for route in routes:
		for index in range(route.size() - 1):
			route_edges.append(PackedVector2Array([route[index], route[index + 1]]))

func can_stand(at: Vector2, radius: float, airborne := false) -> bool:
	if not terrain_allows(at, radius, airborne):
		return false
	var query := shape_query(radius, airborne)
	query.transform = Transform3D(Basis.IDENTITY, center(at, airborne, radius))
	query.motion = Vector3.ZERO
	return model.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func shape_query(radius: float, airborne: bool) -> PhysicsShapeQueryParameters3D:
	var key := Vector2(radius, float(airborne))
	if not const_queries.has(key):
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius / model.PIXELS
		capsule.height = maxf(capsule.radius * 2.0, body_height(radius, airborne))
		var result := PhysicsShapeQueryParameters3D.new()
		result.shape = capsule
		result.collision_mask = MASK | (FIXTURE_MASK if radius == 12.0 and not airborne else 0)
		result.margin = 0.006
		const_queries[key] = result
	return const_queries[key]

func body_height(radius: float, airborne: bool) -> float:
	if airborne:
		return 0.35
	if radius >= 15.0:
		return 2.35 - LOW_STEP
	return (1.63 if radius >= 12.0 else 1.50) - LOW_STEP

func center(at: Vector2, airborne: bool, radius := 12.0) -> Vector3:
	# Ground bodies clear only the height of a low step. The top of this upright
	# capsule follows the hood or skull, so raised archways must clear the head.
	var height := 0.79 if airborne else LOW_STEP + body_height(radius, false) * 0.5
	return model.screen_floor(at, height)

func terrain_allows(at: Vector2, radius: float, airborne: bool) -> bool:
	if not area.grow(-radius).has_point(at):
		return false
	if airborne:
		return true
	if closed_bridge >= 0 and occupies_bridge(closed_bridge, at, radius):
		return false
	for channel in water:
		var over_channel := Geometry2D.is_point_in_polygon(at, channel)
		if not over_channel:
			for i in range(channel.size()):
				if at.distance_squared_to(Geometry2D.get_closest_point_to_segment(at, channel[i],
						channel[(i + 1) % channel.size()])) < radius * radius:
					over_channel = true
					break
		if over_channel and not uses_crossing(at, radius):
			return false
	return true

func occupies_bridge(index: int, at: Vector2, radius: float, extra_clearance := 0.0) -> bool:
	return at.distance_squared_to(bridges[index]) < (CLOSED_BRIDGE_RADIUS + radius + extra_clearance) ** 2

func uses_crossing(at: Vector2, radius: float) -> bool:
	var threshold := maxf(6.0, BRIDGE_CLEARANCE - radius)
	for edge in route_edges:
		var closest := Geometry2D.get_closest_point_to_segment(at, edge[0], edge[1])
		if at.distance_squared_to(closest) <= threshold * threshold:
			return true
	return false

func sweep(start: Vector2, motion: Vector2, radius: float, airborne := false) -> Vector2:
	if motion.length_squared() < 0.00001:
		return start
	var length := motion.length()
	var usable := area.grow(-radius)
	var allowed := 1.0
	for axis in range(2):
		if motion[axis] > 0.0 and start[axis] + motion[axis] >= usable.end[axis]:
			allowed = minf(allowed, (usable.end[axis] - start[axis] - 0.01) / motion[axis])
		elif motion[axis] < 0.0 and start[axis] + motion[axis] <= usable.position[axis]:
			allowed = minf(allowed, (usable.position[axis] - start[axis] + 0.01) / motion[axis])
	allowed = maxf(0.0, allowed)
	if not airborne and (not water.is_empty() or closed_bridge >= 0):
		var count := maxi(1, ceili(length * allowed / BANK_STEP))
		for i in range(1, count + 1):
			var fraction := allowed * float(i) / count
			if not terrain_allows(start + motion * fraction, radius, false):
				allowed = allowed * (i - 1) / count
				break
		# Also solve the raised-bridge disk continuously between samples.
		if closed_bridge >= 0:
			allowed = minf(allowed, disk_limit(start, motion, bridges[closed_bridge], CLOSED_BRIDGE_RADIUS + radius))
	var query := shape_query(radius, airborne)
	var from := center(start, airborne, radius)
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = center(start + motion * allowed, airborne, radius) - from
	var fractions := model.get_world_3d().direct_space_state.cast_motion(query)
	if not fractions.is_empty() and fractions[0] < 1.0:
		allowed = maxf(0.0, allowed * fractions[0] - SKIN / length)
	return start + motion * allowed

func disk_limit(start: Vector2, motion: Vector2, origin: Vector2, radius: float) -> float:
	var offset := start - origin
	var a := motion.length_squared()
	var b := offset.dot(motion)
	var c := offset.length_squared() - radius * radius
	var delta := b * b - a * c
	if c < 0.0 or b >= 0.0 or delta < 0.0:
		return 1.0
	return clampf((-b - sqrt(delta)) / a - SKIN / sqrt(a), 0.0, 1.0)

func route(lane: int, authored: PackedVector2Array, radius: float) -> PackedVector2Array:
	var cache_key := Vector3(lane, radius, closed_bridge)
	if traced_routes.has(cache_key):
		return traced_routes[cache_key]
	if authored.size() < 2:
		return authored
	var goal := find_nearest_stand(authored[-1], radius)
	var path := follow_waypoints(authored, 0, radius)
	if can_stand(path[0], radius) and path[-1].distance_squared_to(goal) < 1.0:
		traced_routes[cache_key] = path
		return path
	# A border entry sealed by the modeled relief advances to the first live
	# approach on the same lane. Never send a wave into an isolated pocket.
	for i in range(1, authored.size() - 1):
		var candidate := find_nearest_stand(authored[i], radius)
		if candidate.distance_squared_to(goal) < 68.0 ** 2 or not can_stand(candidate, radius):
			continue
		var detour := search(candidate, goal, radius)
		if detour.is_empty() or detour[-1].distance_squared_to(goal) > 1.0:
			continue
		path = follow_waypoints(authored, i, radius)
		if path[-1].distance_squared_to(goal) > 1.0:
			path = PackedVector2Array([candidate])
			path.append_array(detour)
		traced_routes[cache_key] = path
		return path
	path = accessible_approach(authored[0], goal, radius)
	traced_routes[cache_key] = path
	return path

func follow_waypoints(authored: PackedVector2Array, first_index: int, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var first := find_nearest_stand(authored[first_index], radius)
	result.append(first)
	for i in range(first_index + 1, authored.size()):
		var target := find_nearest_stand(authored[i], radius)
		if result[-1].distance_to(target) < 3.0 or not can_stand(target, radius):
			continue
		if traverse_clear(result[-1], target, radius):
			result.append(target)
		else:
			var alternative := search(result[-1], target, radius)
			for point in alternative:
				result.append(point)
	return result

func accessible_approach(wanted: Vector2, goal: Vector2, radius: float) -> PackedVector2Array:
	# Find a nearby legal entry into the connected lane rather than teleporting foes
	# through an obstacle. Consider several directions so two sealed lanes can diverge.
	var toward := goal.direction_to(wanted)
	for range_value: float in [240.0, 175.0, 120.0, 82.0]:
		for turn: float in [0.0, 0.40, -0.40, 0.90, -0.90, 1.50, -1.50, PI]:
			var start := find_nearest_stand(goal + toward.rotated(turn) * range_value, radius)
			if not can_stand(start, radius):
				continue
			if traverse_clear(start, goal, radius):
				return PackedVector2Array([start, goal])
			var alternative := search(start, goal, radius)
			if not alternative.is_empty() and alternative[-1].distance_squared_to(goal) < 1.0:
				var path := PackedVector2Array([start])
				path.append_array(alternative)
				return path
	return PackedVector2Array()

func find_nearest_stand(at: Vector2, radius: float, airborne := false) -> Vector2:
	if can_stand(at, radius, airborne):
		return at
	for ring in range(1, 8):
		for side in range(12):
			var point := at + Vector2.from_angle(side * TAU / 12.0) * (ring * GRID_STEP * 0.57)
			if can_stand(point, radius, airborne):
				return point
	return at

func traverse_clear(from: Vector2, to: Vector2, radius: float, airborne := false) -> bool:
	return sweep(from, to - from, radius, airborne).distance_squared_to(to) < 0.30 ** 2

func search(from: Vector2, to: Vector2, radius: float, airborne := false) -> PackedVector2Array:
	if traverse_clear(from, to, radius, airborne):
		return PackedVector2Array([to])
	var graph := grid(radius, airborne)
	var start := nearby_cell(graph, from, radius, airborne)
	var finish := nearby_cell(graph, to, radius, airborne)
	if not graph.is_in_boundsv(start) or not graph.is_in_boundsv(finish):
		return PackedVector2Array()
	var points := graph.get_point_path(start, finish)
	if points.is_empty():
		return points
	var result := PackedVector2Array()
	var anchor := from
	for i in range(points.size()):
		var point := points[i]
		if i + 1 < points.size() and traverse_clear(anchor, points[i + 1], radius, airborne):
			continue
		if not traverse_clear(anchor, point, radius, airborne):
			return PackedVector2Array()
		result.append(point)
		anchor = point
	if not traverse_clear(anchor, to, radius, airborne):
		return PackedVector2Array()
	if not result[-1].is_equal_approx(to):
		result.append(to)
	return result

func grid(radius: float, airborne := false) -> AStarGrid2D:
	var key := Vector3(radius, closed_bridge if not airborne else -1, float(airborne))
	if grids.has(key):
		return grids[key]
	var graph := AStarGrid2D.new()
	var cell_size := 11.0 if not water.is_empty() and not airborne else GRID_STEP
	graph.region = Rect2i(Vector2i.ZERO, Vector2i(ceili(area.size.x / cell_size) + 1,
		ceili(area.size.y / cell_size) + 1))
	graph.offset = area.position
	graph.cell_size = Vector2.ONE * cell_size
	graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	graph.update()
	for y in range(graph.region.size.y):
		for x in range(graph.region.size.x):
			var id := Vector2i(x, y)
			graph.set_point_solid(id, not can_stand(graph.get_point_position(id), radius, airborne))
	grids[key] = graph
	return graph

func nearby_cell(graph: AStarGrid2D, point: Vector2, radius: float, airborne := false) -> Vector2i:
	var base := Vector2i(((point - graph.offset) / graph.cell_size).round())
	var best := Vector2i(-1, -1)
	var nearest := INF
	for y in range(-3, 4):
		for x in range(-3, 4):
			var id := base + Vector2i(x, y)
			if not graph.is_in_boundsv(id) or graph.is_point_solid(id):
				continue
			var at := graph.get_point_position(id)
			var distance := at.distance_squared_to(point)
			if distance < nearest and traverse_clear(point, at, radius, airborne):
				best = id
				nearest = distance
	return best
