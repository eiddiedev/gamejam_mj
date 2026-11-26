extends Node2D

const TEXTURE_SIDE := 96
const GOLD := Color("#ffb35c")
const Walk = preload("res://scripts/battle/BattleCollision.gd")

var sources: Array[Dictionary] = []
var links: Array[Dictionary] = []
var terrain: Node3D
var shadow_ray := PhysicsRayQueryParameters3D.new()
var lights: Array[PointLight2D] = []
var round_texture: ImageTexture
var cone_texture: ImageTexture

func _ready() -> void:
	round_texture = light_texture(false)
	cone_texture = light_texture(true)

func install_walls(walls: Array[PackedVector2Array], model: Node3D) -> void:
	terrain = model
	shadow_ray.collision_mask = Walk.MASK
	for shape in walls:
		var occluder := LightOccluder2D.new()
		var outline := OccluderPolygon2D.new()
		outline.polygon = shape
		outline.closed = true
		occluder.occluder = outline
		add_child(occluder)

func set_sources(active: Array[Dictionary], chains: Array[Dictionary]) -> void:
	sources = active
	links = chains

func refresh_visuals(clock: float) -> void:
	if round_texture == null:
		return
	while lights.size() < sources.size():
		var light := PointLight2D.new()
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		light.shadow_filter_smooth = 2.0
		add_child(light)
		lights.append(light)
	for index in range(lights.size()):
		var light := lights[index]
		light.enabled = index < sources.size()
		if not light.enabled:
			continue
		var source := sources[index]
		var cone: bool = source.has("aim")
		light.position = source["position"]
		light.texture = cone_texture if cone else round_texture
		light.texture_scale = float(source["radius"]) * 2.0 / TEXTURE_SIDE
		light.rotation = (source["aim"] as Vector2).angle() if cone else 0.0
		light.color = source.get("color", GOLD)
		light.energy = float(source.get("energy", 0.75)) * (0.95 + sin(clock * 8.0 + index * 2.1) * 0.05)
		light.shadow_enabled = not source.get("ignore_occlusion", false)
	queue_redraw()

func is_position_lit(point: Vector2, ignore_occlusion := false) -> bool:
	return strength_at(point, ignore_occlusion) > 0.0

func strength_at(point: Vector2, ignore_occlusion := false) -> float:
	var strongest := 0.0
	for source in sources:
		var origin: Vector2 = source["position"]
		var distance_sq := point.distance_squared_to(origin)
		var radius: float = source["radius"]
		if distance_sq > radius * radius:
			continue
		if source.has("aim") and distance_sq > 225.0:
			var facing: Vector2 = source["aim"]
			if facing.dot(origin.direction_to(point)) < 0.72:
				continue
		if not ignore_occlusion and not source.get("ignore_occlusion", false) and is_blocked(origin, point, source.get("height", 0.93)):
			continue
		strongest = maxf(strongest, 1.0 - 0.75 * sqrt(distance_sq) / radius)
	for chain in links:
		var width: float = chain.get("width", 16.0)
		if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point, chain["from"], chain["to"])) <= width * width:
			strongest = maxf(strongest, 0.65)
	return strongest

func is_blocked(a: Vector2, b: Vector2, height := 0.93) -> bool:
	if a.distance_squared_to(b) < 9.0:
		return false
	shadow_ray.from = terrain.screen_floor(a, height)
	shadow_ray.to = terrain.screen_floor(b, 1.0)
	return not terrain.get_world_3d().direct_space_state.intersect_ray(shadow_ray).is_empty()

func _draw() -> void:
	for chain in links:
		draw_line(chain["from"], chain["to"], Color("#ffc16e28"), chain.get("width", 16.0) * 1.4, true)
		draw_line(chain["from"], chain["to"], Color("#ffdc91b9"), 2.0, true)

func light_texture(cone: bool) -> ImageTexture:
	var image := Image.create_empty(TEXTURE_SIDE, TEXTURE_SIDE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIDE):
		for x in range(TEXTURE_SIDE):
			var at := (Vector2(x, y) + Vector2(0.5, 0.5)) / TEXTURE_SIDE * 2.0 - Vector2.ONE
			var radius := at.length()
			var alpha := pow(maxf(0.0, 1.0 - radius), 1.45)
			if cone and radius > 0.075:
				alpha *= smoothstep(0.69, 0.90, at.x / radius)
			image.set_pixel(x, y, Color(1.0, 0.91, 0.78, alpha))
	return ImageTexture.create_from_image(image)
