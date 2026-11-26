extends Node3D

const Fort = preload("res://world/fort.gd")
const Terrain = preload("res://terrain.gd")
const Enemy = preload("res://enemy.gd")
const Builder = preload("res://world/mesh_builder.gd")
const ASH := Color(0.17, 0.212, 0.231, 0.68)
const RUST := Color(0.440, 0.215, 0.173, 0.69)
const LEATHER := Color(0.249, 0.213, 0.173, 0.67)
const BRASS := Color(0.569, 0.411, 0.218, 0.58)
const LAMP := Color(1.0, 0.723, 0.290, 0.31)

var ink: ShaderMaterial
var watcher: Node3D
var cloak: MeshInstance3D
var feet: Array[MeshInstance3D] = []
var wood: Array[MeshInstance3D] = []
var enemies: Dictionary = {}
var shadow_model: ArrayMesh
var moth_body: ArrayMesh
var moth_wings: Array[ArrayMesh] = []

func _ready() -> void:
	make_watcher()
	make_wood()
	make_enemy_models()

func mesh_node(shape: ArrayMesh, parent: Node3D, material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	parent.add_child(node)
	return node

func make_watcher() -> void:
	watcher = Node3D.new()
	watcher.name = "Watcher's rig"
	add_child(watcher)
	var body := Builder.new()
	body.tube(PackedVector3Array([Vector3(0,0.31,0.015), Vector3(0,0.57,-0.019), Vector3(0,0.92,-0.01),
		Vector3(0,1.12,0.02)]), PackedFloat32Array([0.28,0.225,0.30,0.18]), ASH, 9)
	body.tube(PackedVector3Array([Vector3(0,0.55,0), Vector3(0,0.625,0)]),
		PackedFloat32Array([0.25,0.25]), LEATHER, 9)
	body.block(Vector3(0.021,0.556,0.241), 0.106, 0.079, 0.034, 0.0, BRASS, 0.012)
	body.block(Vector3(0.203,0.52,0.09), 0.16, 0.20, 0.133, -0.17, LEATHER, 0.031)
	body.tube(PackedVector3Array([Vector3(0,1.045,0.025),Vector3(0,1.18,0.027),
		Vector3(-0.028,1.36,0.007),Vector3(-0.066,1.52,-0.063)]),
		PackedFloat32Array([0.206,0.238,0.18,0.019]), ASH.lightened(0.1), 9, 0.17)
	body.block(Vector3(0.006,1.084,0.185), 0.212, 0.172, 0.092, 0.02,
		Color(0.375, 0.291, 0.226, 0.64), 0.039, 0.025)
	body.block(Vector3(0,1.194,0.236), 0.21, 0.032, 0.026, 0.00, Color("#1d292e"), 0.008)
	body.tube(PackedVector3Array([Vector3(0.228,0.901,0.037), Vector3(0.35,0.708,0.086),
		Vector3(0.41,0.753,0.31)]), PackedFloat32Array([0.112,0.087,0.073]), ASH, 7)
	body.tube(PackedVector3Array([Vector3(-0.217,0.885,0.009), Vector3(-0.326,0.651,0.109),
		Vector3(-0.32,0.48,0.12)]), PackedFloat32Array([0.110,0.090,0.061]), ASH, 7)
	body.block(Vector3(0.412,0.682,0.33), 0.131, 0.071, 0.128, -0.03, LEATHER, 0.019)
	body.block(Vector3(0.412,0.496,0.33), 0.184, 0.154, 0.167, 0.06, LAMP, 0.027)
	body.block(Vector3(0.412,0.466,0.33), 0.195, 0.047, 0.184, 0.06, BRASS, 0.026)
	for side in [-1.0, 1.0]:
		for face in [-1.0, 1.0]:
			body.block(Vector3(0.412 + side * 0.087,0.496,0.33 + face * 0.075),
				0.027, 0.16, 0.026, 0.0, LEATHER, 0.007)
	mesh_node(body.build(), watcher, ink)
	var cape := Builder.new()
	cape.tube(PackedVector3Array([Vector3(0,0.36,-0.15), Vector3(0,0.64,-0.118),
		Vector3(0,0.93,-0.074), Vector3(0,1.072,-0.009)]),
		PackedFloat32Array([0.33,0.296,0.32,0.195]), RUST, 12, 0.22)
	# A split cloak is open across the front, leaving the lamp, buckle and arms readable.
	var cape_shell := Builder.new()
	for index in range(0, cape.vertices.size(), 3):
		var z := (cape.vertices[index].z + cape.vertices[index + 1].z + cape.vertices[index + 2].z) / 3.0
		var y := (cape.vertices[index].y + cape.vertices[index + 1].y + cape.vertices[index + 2].y) / 3.0
		if z < 0.090 or y > 0.87:
			cape_shell.triangle(cape.vertices[index], cape.vertices[index + 1], cape.vertices[index + 2],
				cape.colors[index], cape.normals[index])
	cloak = mesh_node(cape_shell.build(), watcher, ink)
	for side in [-1.0, 1.0]:
		var boot := Builder.new()
		boot.block(Vector3(0,0.043,0.065), 0.172, 0.13, 0.27, side * 0.095, LEATHER, 0.03)
		boot.block(Vector3(0,0.149,0), 0.16, 0.33, 0.142, 0, ASH, 0.024)
		var node := mesh_node(boot.build(), watcher, ink)
		node.position.x = side * 0.12
		feet.append(node)

func make_wood() -> void:
	var pile := Builder.new()
	for index in range(4):
		pile.block(Vector3(0.033 * index - 0.07, 0.026 + (index % 2) * 0.055, 0.078 * index - 0.14),
			0.38, 0.088, 0.103, 0.38 + index * 0.045,
			Color(0.36 + index * 0.025, 0.249 + index * 0.018, 0.161, 0.72), 0.027)
	var mesh := pile.build()
	for point in Terrain.STASHES:
		var node := mesh_node(mesh, self, ink)
		node.position = Fort.space(point)
		wood.append(node)

func make_enemy_models() -> void:
	var shadow := Builder.new()
	var soot := Color(0.113, 0.142, 0.155, 0.73)
	for index in range(5):
		var bias := float(index - 2) * 0.086
		shadow.tube(PackedVector3Array([Vector3(bias,0.09,0.46), Vector3(bias,0.22,0.19),
			Vector3(bias * 1.7,0.32,-0.14),Vector3(bias * 2.38,0.46, -0.48 + bias),
			Vector3(bias * 2.50 + 0.07,0.49,-0.92 + bias)]),
			PackedFloat32Array([0.075,0.148,0.134,0.098,0.012]), soot.lightened(index * 0.026), 6, 0.18)
	for side in [-1.0,1.0]:
		shadow.block(Vector3(side * 0.097,0.161,0.48), 0.084, 0.046, 0.045, 0.0, LAMP, 0.013, side * 0.35)
	shadow_model = shadow.build()
	var insect := Builder.new()
	insect.tube(PackedVector3Array([Vector3(0,0,-0.23),Vector3(0,0,0.02),
		Vector3(0,0,0.22),Vector3(0,0.012,0.245)]), PackedFloat32Array([0.032,0.085,0.056,0.02]),
		Color(0.29,0.18,0.24,0.65), 7)
	moth_body = insect.build()
	for side in [-1.0, 1.0]:
		var wing := Builder.new()
		var shoulder := Vector3(side * 0.10,0,0.1)
		var high := Vector3(side * 0.53,0.035,0.236)
		var bend := Vector3(side * 0.43,0.03,-0.19)
		var tail := Vector3(side * 0.23,0,-0.31)
		wing.triangle(Vector3.ZERO, high, shoulder, Color(0.431,0.287,0.343,0.73), Vector3.UP)
		wing.triangle(Vector3.ZERO, bend, high, Color(0.32,0.217,0.295,0.73), Vector3.UP)
		wing.triangle(Vector3.ZERO, tail, bend, Color(0.49,0.313,0.362,0.73), Vector3.UP)
		wing.triangle(Vector3(0,0.004,0), Vector3(side * 0.43,0.043,0.178),
			Vector3(side * 0.33,0.035,0.028), Color(0.78,0.486,0.30,0.71), Vector3.UP)
		wing.triangle(Vector3(0,0.004,-0.016), Vector3(side * 0.30,0.042,-0.171),
			Vector3(side * 0.31,0.032,-0.236), Color(0.70,0.380,0.269,0.71), Vector3.UP)
		moth_wings.append(wing.build())

func sync(game) -> void:
	var active: bool = game.phase in [1,2,3]
	watcher.visible = active
	for index in range(wood.size()):
		wood[index].visible = active and game.wood_available[index]
	if active:
		watcher.position = Fort.space(game.player)
		var look: Vector2 = game.aim
		watcher.rotation.y = atan2(look.x, look.y)
		var gait: float = sin(game.clock * 17.0) if game.moving else 0.0
		cloak.rotation.x = -0.066 * gait
		for index in range(feet.size()):
			feet[index].position.z = gait * (0.115 if index == 0 else -0.115)
			feet[index].position.y = maxf(0.0, gait * (0.042 if index == 0 else -0.042))
	for enemy in enemies.keys():
		if enemy not in game.enemies:
			enemies[enemy].queue_free()
			enemies.erase(enemy)
	for enemy in game.enemies:
		var moth: bool = enemy.kind == Enemy.Kind.MOTH
		if not enemies.has(enemy):
			var node := Node3D.new()
			add_child(node)
			enemies[enemy] = node
			mesh_node(moth_body if moth else shadow_model, node, ink)
			if moth:
				for wing in moth_wings:
					mesh_node(wing, node, ink)
		var actor: Node3D = enemies[enemy]
		actor.visible = moth or enemy.lit or game.is_trapped(enemy.position)
		actor.position = Fort.space(enemy.position,
			(0.37 if moth else 0.09) + sin(game.clock * 8.1 + enemy.offset) * 0.075)
		actor.rotation.y = atan2(enemy.facing.x, enemy.facing.y)
		if moth:
			var wingbeat: float = sin(game.clock * 24.0 + enemy.offset) * 0.74
			actor.get_child(1).rotation.z = wingbeat
			actor.get_child(2).rotation.z = -wingbeat
