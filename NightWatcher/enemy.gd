extends RefCounted

enum Kind { SHADOW, MOTH }
enum State { APPROACH, FEED, RECOIL, DEAD }

var kind: Kind
var state := State.APPROACH
var position: Vector2
var path: PackedVector2Array
var waypoint := 1
var gate_index: int
var wait := 0.0
var vitality := 1.0
var lit := false
var facing := Vector2.DOWN
var age := 0.0
var offset: float

func _init(species: Kind, route: PackedVector2Array, gate: int, phase_offset: float) -> void:
	kind = species
	path = route
	position = path[0]
	gate_index = gate
	offset = phase_offset

func tick(delta: float, game) -> void:
	age += delta
	lit = game.is_illuminated(position)
	var trap: bool = game.is_trapped(position)
	if lit or trap:
		vitality -= delta * (game.lantern_damage() if lit else 2.9)
	else:
		vitality = minf(1.0, vitality + delta * 0.09)
	if vitality <= 0.0:
		state = State.DEAD
		game.enemy_burned(self)
		return
	if state == State.FEED:
		wait -= delta
		if wait <= 0.0:
			game.fire_struck(15.0)
			state = State.RECOIL
			wait = 3.5
		return
	if state == State.RECOIL:
		wait -= delta
		position = position.move_toward(path[path.size() - 2], 44 * delta)
		if wait <= 0.0:
			state = State.APPROACH
		return
	var target := path[waypoint]
	if kind == Kind.SHADOW and waypoint == path.size() - 2 and position.distance_to(target) < 13.0:
		if game.damage_wall(gate_index, delta):
			return
	var speed := 43.5 if kind == Kind.MOTH else 30.0
	if lit:
		speed *= 0.54
	facing = position.direction_to(target)
	position = position.move_toward(target, speed * delta)
	if position.distance_squared_to(target) >= 0.25:
		return
	if waypoint < path.size() - 1:
		waypoint += 1
	elif kind == Kind.MOTH:
		state = State.DEAD
		game.fire_struck(12.0)
	else:
		state = State.FEED
		wait = 0.72
