extends Node3D

const Builder = preload("res://world/mesh_builder.gd")
const Enemy = preload("res://scripts/entities/EnemyController.gd")
const Watcher = preload("res://scripts/entities/PlayerController.gd")

const BONE := Color("#d9cdab")
const WEATHERED := Color("#9c8c72")
const COAL := Color("#282f35")
const TEAL := Color("#547d79")
const BRASS := Color("#bd8b50")
const EMBER := Color("#ed915f")
const STEEL := Color("#9ebabc")
const ENEMY_SCALES := [1.0, 0.97, 0.89, 1.60, 1.14, 1.76]
const LANTERN_PATH := "res://assets/props/watch_lantern.glb"
const THIGH_LENGTH := 0.247
const SHIN_LENGTH := 0.256
const ARM_LENGTH := 0.235
const FOREARM_LENGTH := 0.226

class FootPin:
	var anchor := Vector3.ZERO
	var from := Vector3.ZERO
	var goal := Vector3.ZERO
	var position := Vector3.ZERO
	var age := -1.0
	var duration := 0.12
	var lift := 0.10

var floor_model: Node3D
var battle: Node2D
var actors: Dictionary = {}
var fallen: Array[Dictionary] = []
var lantern_asset: PackedScene
var lantern_mount: Node3D
var sword_mount: Node3D

func setup(model: Node3D, level: Node2D) -> void:
	name = "Articulated combat figures"
	floor_model = model
	battle = level
	if ResourceLoader.exists(LANTERN_PATH):
		lantern_asset = load(LANTERN_PATH) as PackedScene
	var combat = battle.combat
	combat.watcher.draw_body = false
	combat.moth_contact.connect(release_moth_on_contact)
	for support in combat.towers:
		support.hide()
	if combat.ally != null:
		combat.ally.draw_body = false
	sync(0.0)

func sync(delta: float) -> void:
	var combat = battle.combat
	for source in actors.keys():
		if not is_instance_valid(source) or source is Enemy and source.removed:
			var rig: Dictionary = actors[source]
			var root: Node3D = rig.root
			if rig.has("rite"):
				(rig.rite as Node3D).hide()
			if root.visible:
				fallen.append({"rig": rig, "time": 0.0, "ground": root.position,
					"size": root.scale, "turn": root.rotation.y})
			else:
				root.queue_free()
			actors.erase(source)
	step_fallen(delta)
	var watcher: Watcher = combat.watcher
	var player_rig := use_actor(watcher, -1)
	lantern_mount = player_rig.lantern
	sword_mount = player_rig.sword
	pose_watcher(watcher, player_rig, battle.player, delta, false)
	var ally: Watcher = combat.ally
	if ally != null:
		pose_watcher(ally, use_actor(ally, -2), ally.position, delta, true)
	for enemy: Enemy in combat.enemies:
		if enemy.removed:
			continue
		enemy.draw_body = false
		var rig := use_actor(enemy, enemy.kind)
		pose_enemy(enemy, rig, delta)

func step_fallen(delta: float) -> void:
	for index in range(fallen.size() - 1, -1, -1):
		var pose := fallen[index]
		pose.time += delta
		var rig: Dictionary = pose.rig
		var root: Node3D = rig.root
		if pose.time > 0.45:
			root.queue_free()
			fallen.remove_at(index)
			continue
		var slip := ease(clampf(pose.time / 0.43, 0.0, 1.0), 0.53)
		var sink := smoothstep(0.48, 1.0, slip)
		var begin: Vector3 = pose.ground
		var size: Vector3 = pose.size
		var direction := Vector3(sin(pose.turn), 0.0, cos(pose.turn))
		root.position = begin - direction * slip * 0.20 - Vector3.UP * sink * 0.20
		root.rotation = Vector3(-0.79 * slip, pose.turn, 0.43 * slip)
		root.scale = size * (1.0 - sink * 0.80)
		flash(rig, (1.0 - slip) * 0.77)

func use_actor(source: Node2D, kind: int) -> Dictionary:
	if actors.has(source):
		return actors[source]
	var rig := make_moth() if kind == Enemy.MOTH else make_biped(kind)
	actors[source] = rig
	return rig

func puppet_root(label: String, factor: float) -> Dictionary:
	var root := Node3D.new()
	root.name = label
	root.scale = Vector3.ONE * factor
	add_child(root)
	var look := StandardMaterial3D.new()
	look.vertex_color_use_as_albedo = true
	look.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	look.roughness = 1.0
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	look.emission_enabled = true
	look.emission = Color("#25323d")
	look.emission_energy_multiplier = 0.15
	return {"root": root, "material": look, "stride": 0.0, "last": Vector3.ZERO,
		"velocity": Vector3.ZERO, "pace_peak": 0.0, "placed": false, "reset_feet": true}

func joint(parent: Node3D, label: String, origin: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = origin
	parent.add_child(node)
	return node

func part(parent: Node3D, label: String, mesh: Builder, paint: StandardMaterial3D) -> MeshInstance3D:
	var component := MeshInstance3D.new()
	component.name = label
	component.mesh = mesh.build()
	component.material_override = paint
	parent.add_child(component)
	return component

func rings(mesh: Builder, profile: Array, tint: Color, sides := 8) -> void:
	# Each ring specifies height, x radius, z radius, and optional center offsets.
	var strips: Array[PackedVector3Array] = []
	for row: Array in profile:
		var ring := PackedVector3Array()
		var shift_x: float = row[3] if row.size() > 3 else 0.0
		var shift_z: float = row[4] if row.size() > 4 else 0.0
		for i in range(sides):
			var angle := TAU * (float(i) + 0.5) / sides
			ring.append(Vector3(shift_x + cos(angle) * row[1], row[0], shift_z + sin(angle) * row[2]))
		strips.append(ring)
	var banded := [0.04, -0.02, 0.02, -0.09, -0.06, -0.13, -0.07, 0.0]
	for row in range(1, strips.size()):
		var lower := strips[row - 1]
		var upper := strips[row]
		for i in range(sides):
			var after := (i + 1) % sides
			var shade: float = banded[i % banded.size()]
			var color := tint.lightened(shade) if shade > 0.0 else tint.darkened(-shade)
			mesh.quad(lower[i], upper[i], upper[after], lower[after], color)
	var bottom := strips[0]
	var top := strips[-1]
	for i in range(1, sides - 1):
		mesh.triangle(bottom[0], bottom[i], bottom[i + 1], tint.darkened(0.18), Vector3.DOWN)
		mesh.triangle(top[0], top[i + 1], top[i], tint.lightened(0.12), Vector3.UP)

func bone_segment(mesh: Builder, a: Vector3, b: Vector3, wide: float, thin: float, tint: Color) -> void:
	mesh.tube(PackedVector3Array([a, a.lerp(b, 0.26), a.lerp(b, 0.76), b]),
		PackedFloat32Array([wide, thin, thin * 1.03, wide * 0.90]), tint, 6, 0.03)

func make_biped(kind: int) -> Dictionary:
	var actor_name: String = "守夜人" if kind == -1 else "助战巡夜人" if kind == -2 else Enemy.NAMES[kind]
	var scale_factor := (1.13 if kind == -1 else 1.0) if kind < 0 else float(ENEMY_SCALES[kind])
	var rig := puppet_root(actor_name, scale_factor)
	var root: Node3D = rig.root
	var paint: StandardMaterial3D = rig.material
	var chest := joint(root, "Hips and torso", Vector3(0.0, 0.58, 0.0))
	var head := joint(chest, "Head swivel", Vector3(0.0, 0.53, 0.0))
	var capes := joint(chest, "Cloth hinge", Vector3(0.0, 0.31, -0.12))
	var skeleton := kind in [Enemy.CRAWLER, Enemy.COLOSSUS]
	var hue := coat_color(kind)
	part(chest, "Torso shell", make_ribcage(kind, hue) if skeleton else armor(hue, kind), paint)
	part(head, "Head and facial structure", skull(kind) if skeleton else hood(kind, hue), paint)
	if not skeleton or kind == Enemy.COLOSSUS:
		part(capes, "Layered cloth", cloak(hue, kind), paint)
	var arms: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	var knees: Array[Node3D] = []
	var thighs: Array[Node3D] = []
	var boots: Array[Node3D] = []
	var palms: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var sign_value: float = side
		var shoulder := joint(chest, "Shoulder", Vector3(sign_value * 0.231, 0.415, -0.01))
		var elbow := joint(shoulder, "Elbow", Vector3(0.0, -ARM_LENGTH, 0.0))
		var palm := joint(elbow, "Wrist", Vector3(0.0, -FOREARM_LENGTH, 0.0))
		var thigh := joint(root, "Hip joint", Vector3(sign_value * 0.118, 0.55, 0.0))
		var knee := joint(thigh, "Knee", Vector3(0.0, -THIGH_LENGTH, 0.0))
		var boot := joint(knee, "Ankle", Vector3(0.0, -SHIN_LENGTH, 0.0))
		part(shoulder, "Upper arm", arm_piece(hue, skeleton, true, kind), paint)
		part(elbow, "Forearm", arm_piece(hue, skeleton, false, kind), paint)
		part(palm, "Glove or claw", glove(hue, skeleton, kind), paint)
		part(thigh, "Upper leg", leg_piece(hue, skeleton, true, kind), paint)
		part(knee, "Shin", leg_piece(hue, skeleton, false, kind), paint)
		var foot := Builder.new()
		foot.block(Vector3(0.009,-0.050,0.046),0.134,0.097,0.219,0.0,WEATHERED if skeleton else COAL,0.024,0.0,false)
		part(boot, "Grounded shoe", foot, paint)
		arms.append(shoulder)
		elbows.append(elbow)
		palms.append(palm)
		thighs.append(thigh)
		knees.append(knee)
		boots.append(boot)
	rig.merge({"chest": chest, "head": head, "capes": capes, "arms": arms, "elbows": elbows,
		"thighs": thighs, "knees": knees, "boots": boots, "palms": palms,
		"feet": [FootPin.new(), FootPin.new()]})
	if kind < 0:
		rig["sword"] = add_weapon(palms[1], paint, "sword")
		rig["lantern"] = add_lantern(palms[0], paint)
	elif kind == Enemy.HEXER:
		rig["sword"] = add_weapon(palms[0], paint, "staff")
	elif kind == Enemy.HERALD:
		rig["sword"] = add_weapon(palms[1], paint, "herald")
		rig["rite"] = make_herald_rite(palms[0])
	elif kind == Enemy.COLOSSUS:
		rig["sword"] = add_weapon(palms[1], paint, "maul")
	return rig

func make_herald_rite(palm: Node3D) -> Node3D:
	var mesh := Builder.new()
	var core := Color("#f4badf")
	var corona := Color("#ac5097")
	for edge in range(8):
		var a := TAU * edge / 8.0
		var b := a + TAU / 8.0
		var left := Vector3(cos(a), 0.0, sin(a))
		var right := Vector3(cos(b), 0.0, sin(b))
		mesh.triangle(Vector3.UP * 0.12, left * 0.055, right * 0.055, core)
		mesh.triangle(Vector3.DOWN * 0.094, right * 0.055, left * 0.055, corona)
		mesh.quad(left * 0.152, left * 0.162, right * 0.162, right * 0.152, corona)
	var pigment := StandardMaterial3D.new()
	pigment.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pigment.vertex_color_use_as_albedo = true
	pigment.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rite := part(palm, "Gathered darkness", mesh, pigment)
	rite.position = Vector3(0.0, -0.18, 0.07)
	rite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rite.hide()
	return rite

func coat_color(kind: int) -> Color:
	match kind:
		-2: return Color("#61748e")
		Enemy.SHADE: return Color("#654e79")
		Enemy.HEXER: return Color("#925a7c")
		Enemy.HERALD: return Color("#a45662")
		_: return TEAL

func armor(tint: Color, kind: int) -> Builder:
	var mesh := Builder.new()
	rings(mesh, [[-0.05,0.185,0.123], [0.04,0.216,0.151], [0.17,0.152,0.127],
		[0.35,0.216,0.155], [0.43,0.245,0.139], [0.51,0.118,0.103]],
		tint.darkened(0.16), 8)
	rings(mesh, [[0.03,0.211,0.153], [0.075,0.208,0.163], [0.11,0.199,0.152]],
		Color("#77513a") if kind != Enemy.SHADE else Color("#43344e"), 8)
	for side in [-1.0, 1.0]:
		var x: float = side * 0.12
		mesh.quad(Vector3(x * 0.28, 0.39, 0.154), Vector3(x * 1.62, 0.42, 0.125),
			Vector3(x, 0.26, 0.163), Vector3(x * 0.23, 0.245, 0.159), tint.lightened(0.24))
		if kind in [-1, -2, Enemy.HERALD]:
			mesh.block(Vector3(x * 0.52, 0.064, 0.153), 0.036, 0.036, 0.03, 0.0,
				BRASS, 0.008, 0.0, false)
	for i in range(3):
		var shift := i * 0.061
		mesh.quad(Vector3(-0.12, 0.265 - shift, 0.157), Vector3(0.115, 0.273 - shift, 0.156),
			Vector3(0.12, 0.284 - shift, 0.157), Vector3(-0.12, 0.275 - shift, 0.158), tint.darkened(0.37))
	var collar := BRASS if kind < 0 or kind == Enemy.HERALD else tint.darkened(0.33)
	rings(mesh, [[0.472,0.121,0.116],[0.500,0.129,0.110],[0.541,0.109,0.104]], collar, 7)
	return mesh

func make_ribcage(kind: int, tint: Color) -> Builder:
	var mesh := Builder.new()
	bone_segment(mesh, Vector3(0.0,0.01,-0.040), Vector3(0.0,0.47,-0.050), 0.075, 0.034, WEATHERED)
	rings(mesh, [[-0.05,0.158,0.124],[0.0,0.145,0.139],[0.04,0.094,0.105]], WEATHERED, 6)
	for row in range(4):
		var up := 0.153 + row * 0.077
		for sign_value in [-1.0, 1.0]:
			var side: float = sign_value
			var ribs := PackedVector3Array([Vector3(side*0.022,up,-0.068), Vector3(side*(0.117+row*0.017),up,-0.017),
				Vector3(side*(0.139+row*0.012),up-0.027,0.073), Vector3(side*0.076,up-0.053,0.136),
				Vector3(side*0.028,up-0.046,0.134)])
			mesh.tube(ribs, PackedFloat32Array([0.022,0.021,0.022,0.016,0.010]), BONE, 5, 0.02)
	bone_segment(mesh, Vector3(-0.20,0.41,0.026), Vector3(0.20,0.43,0.023), 0.055, 0.038, BONE)
	if kind == Enemy.COLOSSUS:
		rings(mesh, [[0.31,0.125,0.075,0.16,0.04],[0.44,0.138,0.112,0.16,0.04],[0.51,0.06,0.08,0.16,0.04]], WEATHERED, 7)
		mesh.block(Vector3(-0.09,0.05,0.095), 0.29, 0.065, 0.12, 0.10, tint.darkened(0.33), 0.03, 0.0, false)
	return mesh

func skull(kind: int) -> Builder:
	var mesh := Builder.new()
	rings(mesh, [[0.025,0.067,0.07,0.0,0.028],[0.075,0.117,0.105,0.0,0.022],
		[0.19,0.141,0.122],[0.269,0.122,0.099],[0.301,0.054,0.056]], BONE, 9)
	for side in [-1.0, 1.0]:
		var x: float = side * 0.073
		mesh.quad(Vector3(x-0.044,0.141,0.122), Vector3(x+0.042,0.147,0.122),
			Vector3(x+0.034,0.197,0.127), Vector3(x-0.038,0.191,0.127), COAL)
		mesh.block(Vector3(x,0.154,0.126), 0.035, 0.017, 0.012, 0.0, EMBER, 0.003, 0.0, false)
		if kind == Enemy.COLOSSUS:
			mesh.tube(PackedVector3Array([Vector3(side*0.102,0.193,-0.006), Vector3(side*0.168,0.252,-0.014),
				Vector3(side*0.205,0.363,0.005)]), PackedFloat32Array([0.056,0.041,0.012]), WEATHERED, 5)
	mesh.triangle(Vector3(-0.022,0.151,0.132),Vector3(0.021,0.151,0.132),
		Vector3(0.0,0.108,0.136), COAL)
	for i in range(5):
		var x := (i-2)*0.023
		mesh.block(Vector3(x,0.053,0.106),0.013,0.028,0.02,0.0,COAL,0.003,0.0,false)
	return mesh

func hood(kind: int, tint: Color) -> Builder:
	var mesh := Builder.new()
	var fighter := kind in [-1,-2,Enemy.HERALD]
	var fabric := tint.darkened(0.17) if fighter else tint.darkened(0.31)
	rings(mesh, [[0.028,0.101,0.095],[0.102,0.143,0.138],[0.225,0.146,0.121],
		[0.286,0.100,0.093],[0.316,0.063,0.061,0.0,-0.014]], fabric, 8)
	mesh.quad(Vector3(-0.092,0.097,0.120),Vector3(0.092,0.097,0.12),Vector3(0.102,0.219,0.121),
		Vector3(-0.102,0.221,0.121),COAL.darkened(0.33))
	var rim := STEEL if fighter else tint.lightened(0.35)
	mesh.tube(PackedVector3Array([Vector3(-0.126,0.101,0.126),Vector3(-0.134,0.212,0.126),
		Vector3(0.0,0.256,0.143),Vector3(0.125,0.217,0.123),Vector3(0.121,0.101,0.126)]),
		PackedFloat32Array([0.015,0.017,0.020,0.016,0.015]), rim, 5, 0.02)
	for i in [-1,1]:
		mesh.block(Vector3(i*0.043,0.153,0.132),0.041,0.014,0.014,0.0,
			Color("#ffd091") if fighter else Color("#e2a3b8"),0.003,0.0,false)
	if kind == Enemy.HERALD:
		for i in [-1, 0, 1]:
			var x: float = i * 0.107
			mesh.tube(PackedVector3Array([Vector3(x,0.215,-0.019), Vector3(x*1.28,0.288,-0.021),
				Vector3(x*1.33,0.416 if i == 0 else 0.388,0.014)]),
				PackedFloat32Array([0.045,0.028,0.003]), BRASS, 5, 0.10)
	return mesh

func cloak(tint: Color, kind: int) -> Builder:
	var mesh := Builder.new()
	var longer := kind in [Enemy.SHADE, Enemy.HEXER, Enemy.HERALD]
	var hem := -0.66 if longer else -0.49
	for i in range(6):
		var start := i / 6.0
		var finish := (i + 1) / 6.0
		var top := lerpf(-0.210,0.210,start)
		var next := lerpf(-0.210,0.210,finish)
		var sash := tint.darkened(0.33 if i % 2 == 0 else 0.21)
		var bottom := hem + sin(i*2.40)*0.067
		var outer := (i-2.50)*0.096
		mesh.quad(Vector3(top,0.01,-0.026),Vector3(next,0.02,-0.045),Vector3(outer+0.072,bottom+0.028,-0.23),
			Vector3(outer-0.043,bottom,-0.22),sash)
		mesh.quad(Vector3(outer-0.043,bottom,-0.221),Vector3(outer+0.072,bottom+0.028,-0.231),
			Vector3(outer+0.067,bottom+0.054,-0.224),Vector3(outer-0.044,bottom+0.029,-0.216),
			sash.lightened(0.24))
	return mesh

func arm_piece(tint: Color, skeleton: bool, upper: bool, kind: int) -> Builder:
	var mesh := Builder.new()
	var length := 0.235 if upper else 0.226
	if skeleton:
		bone_segment(mesh,Vector3.ZERO,Vector3(0.014,-length,0.022),0.063 if upper else 0.051,
			0.035 if upper else 0.026,BONE)
		if not upper:
			bone_segment(mesh,Vector3(0.027,-0.02,0.019),Vector3(0.009,-length,0.040),0.026,0.020,WEATHERED)
	else:
		var outer := tint.lightened(0.12 if upper else 0.05)
		rings(mesh,[[-length,0.044,0.061,0.0,0.018],[-length*0.52,0.073,0.065],
			[-0.031,0.095 if upper else 0.064,0.087 if upper else 0.07],[0.050,0.071,0.061]],outer,7)
		if kind < 0 or kind == Enemy.HERALD:
			rings(mesh,[[-length*0.60,0.078,0.075],[-length*0.48,0.080,0.076],[-length*0.42,0.075,0.072]],BRASS.darkened(0.07),7)
	return mesh

func glove(tint: Color, skeleton: bool, kind: int) -> Builder:
	var mesh := Builder.new()
	var outer := BONE if skeleton else tint.darkened(0.35)
	rings(mesh,[[-0.071,0.030,0.043],[-0.039,0.054,0.040],[0.018,0.042,0.048]],outer,6)
	if kind in [Enemy.CRAWLER,Enemy.SHADE]:
		for i in range(3):
			var x := (i-1)*0.027
			bone_segment(mesh,Vector3(x,-0.047,0.020),Vector3(x*1.13,-0.115,0.048),0.014,0.009,outer)
	return mesh

func leg_piece(tint: Color, skeleton: bool, upper: bool, kind: int) -> Builder:
	var mesh := Builder.new()
	var length := 0.245 if upper else 0.256
	if skeleton:
		bone_segment(mesh,Vector3.ZERO,Vector3(0.0,-length,0.006),0.069 if upper else 0.048,
			0.039 if upper else 0.032,BONE)
	else:
		rings(mesh,[[-length,0.057,0.058],[-length*0.47,0.067,0.080],[0.025,0.088,0.087]],tint.darkened(0.38),7)
	if upper and kind == Enemy.HERALD:
		mesh.block(Vector3(0.0,-0.152,0.076),0.087,0.113,0.057,0.0,BRASS,0.025,0.0,false)
	return mesh

func add_weapon(hand: Node3D, paint: StandardMaterial3D, kind: String) -> Node3D:
	var grip := joint(hand, "Weapon pivot", Vector3(0.0,-0.04,0.028))
	var mesh := Builder.new()
	if kind == "staff" or kind == "maul":
		var length := 0.99 if kind == "staff" else 0.57
		bone_segment(mesh,Vector3(0.0,-length*0.61,0.0), Vector3(0.0,length*0.47,0.0),0.035,0.023,WEATHERED)
		if kind == "staff":
			rings(mesh,[[length*0.39,0.035,0.037],[length*0.46,0.091,0.081],
				[length*0.55,0.067,0.076],[length*0.60,0.008,0.008]],Color("#cf82a8"),5)
			for side in [-1.0,1.0]:
				mesh.tube(PackedVector3Array([Vector3(side*0.02,length*0.35,0.0),Vector3(side*0.113,length*0.46,0.0),
					Vector3(side*0.072,length*0.56,0.005)]),PackedFloat32Array([0.025,0.030,0.009]),BRASS,5)
		else:
			mesh.block(Vector3(0.0,length*0.34,0.026),0.286,0.161,0.178,0.05,BONE,0.055,0.0,false)
	else:
		var reach := 0.71 if kind == "sword" else 0.90
		var wide := 0.067 if kind == "sword" else 0.097
		rings(mesh,[[-0.133,0.037,0.039],[-0.071,0.033,0.033],[0.058,0.030,0.032]],COAL,6)
		mesh.block(Vector3(0.0,0.073,0.0),0.237,0.055,0.076,0.0,BRASS,0.018,0.0,false)
		rings(mesh,[[0.116,wide,0.021],[0.220,wide*0.79,0.022],[reach-0.15,wide*0.75,0.021],
			[reach,0.003,0.004]],STEEL,4)
		mesh.triangle(Vector3(-0.023,0.152,0.020),Vector3(0.008,0.174,0.022),
			Vector3(-0.010,reach-0.06,0.003),Color("#d6e1cc"))
	part(grip, "Weapon geometry", mesh, paint)
	return grip

func add_lantern(hand: Node3D, paint: StandardMaterial3D) -> Node3D:
	var hook := joint(hand, "Lantern hook", Vector3(0.0,-0.052,0.032))
	if lantern_asset != null:
		var prop := lantern_asset.instantiate() as Node3D
		prop.name = "Textured bronze lantern"
		prop.scale = Vector3.ONE * 0.28
		prop.position = Vector3(0.0,-0.27,0.0)
		hook.add_child(prop)
		floor_model.paint_textured_prop(prop)
	else:
		var mesh := Builder.new()
		rings(mesh,[[-0.25,0.092,0.089],[-0.213,0.075,0.081],[-0.069,0.071,0.070],
			[-0.035,0.091,0.078],[-0.006,0.036,0.046]],BRASS,6)
		rings(mesh,[[-0.228,0.070,0.068],[-0.109,0.059,0.060],[-0.055,0.070,0.069]],EMBER,6)
		part(hook,"Lantern geometry",mesh,paint)
	return hook

func make_moth() -> Dictionary:
	var rig := puppet_root("噬火蛾",0.93)
	var body: Node3D = rig.root
	var paint: StandardMaterial3D = rig.material
	var chest := Builder.new()
	chest.tube(PackedVector3Array([Vector3(0.0,0.0,-0.36),Vector3(0.0,0.055,-0.17),Vector3(0.0,0.067,0.13),
		Vector3(0.0,0.0,0.27)]),PackedFloat32Array([0.034,0.098,0.115,0.061]),Color("#7c533f"),8,0.03)
	for sign_value in [-1.0,1.0]:
		var s: float = sign_value
		bone_segment(chest,Vector3(s*0.04,0.02,0.205),Vector3(s*0.19,0.12,0.392),0.016,0.011,EMBER)
		chest.block(Vector3(s*0.051,0.029,0.179),0.055,0.047,0.086,0.0,EMBER,0.010,0.0,false)
	part(body,"Segmented thorax",chest,paint)
	var wings: Array[Node3D] = []
	for sign_value in [-1.0,1.0]:
		var s: float = sign_value
		var wing := joint(body,"Wing root",Vector3(s*0.07,0.03,0.005))
		var shape := Builder.new()
		var hinge := Vector3.ZERO
		var tip := Vector3(s*0.66,0.020,0.263)
		var forward := Vector3(s*0.43,0.06,0.30)
		var fringe := Vector3(s*0.58,-0.053,-0.18)
		var tail := Vector3(s*0.17,-0.037,-0.289)
		var fan := Vector3(s*0.31,0.032,0.043)
		shape.triangle(hinge,forward,fan,Color("#b46756"))
		shape.triangle(forward,tip,fan,Color("#dc886a"))
		shape.triangle(tip,fringe,fan,Color("#ab574d"))
		shape.triangle(fringe,tail,fan,Color("#773f45"))
		shape.triangle(tail,hinge,fan,Color("#98564c"))
		for point in [tip,fringe,tail]:
			var vector: Vector3 = point
			bone_segment(shape,hinge+Vector3(0,0.013,0),vector+Vector3(0,0.010,0),0.022,0.010,Color("#dca474"))
		part(wing,"Veined moth wing",shape,paint)
		wings.append(wing)
	rig["wings"] = wings
	return rig

func place(rig: Dictionary, point: Vector2, facing: Vector2, height: float, delta: float) -> float:
	var root: Node3D = rig.root
	var last: Vector3 = rig.last
	var anchor: Vector3 = floor_model.screen_floor(point, height)
	root.position = anchor
	var heading := atan2(facing.x, facing.y / 0.758) if not facing.is_zero_approx() else root.rotation.y
	if not rig.placed or anchor.distance_squared_to(last) > 1.2 ** 2:
		root.rotation.y = heading
		rig.last = anchor
		rig.placed = true
		rig.velocity = Vector3.ZERO
		rig.pace_peak = 0.0
		rig.reset_feet = true
		return 0.0
	root.rotation.y = lerp_angle(root.rotation.y, heading, 1.0 - exp(-delta * 23.0))
	var displacement := anchor - last
	displacement.y = 0.0
	rig.last = anchor
	var velocity: Vector3 = rig.velocity
	if delta > 0.0:
		var measured := displacement / maxf(delta,0.008)
		rig.velocity = velocity.lerp(measured, 1.0 - exp(-delta * 18.0))
		rig.pace_peak = maxf(minf(measured.length(),4.8),rig.pace_peak * exp(-delta * 18.0))
	rig.stride = fposmod(rig.stride + displacement.length() * 8.7, TAU)
	return (rig.velocity as Vector3).length()


func pose_watcher(watcher: Watcher, rig: Dictionary, point: Vector2, delta: float, ally: bool) -> void:
	watcher.draw_body = false
	var combat = battle.combat
	var attacking := watcher.swing > 0.0
	var frozen: bool = not ally and combat.hit_pause > 0.0
	var facing: Vector2 = combat.strike_facing if attacking and not ally else watcher.aim
	var speed := place(rig, point, facing, 0.018, delta)
	var stride: float = rig.stride
	var gait := smoothstep(0.13, 3.35, speed)
	var chamber := smoothstep(0.09, 0.42, watcher.charge)
	var chambered := chamber
	var recovery := 0.0
	var impact := 0.0
	var sweep := 0.0
	var side := -1.0 if not ally and combat.combo == 2 else 1.0
	var heavy: bool = not ally and (combat.strike_heavy if attacking else watcher.charge > 0.09)
	if attacking:
		if ally:
			sweep = smoothstep(0.0, 0.92, 1.0 - watcher.swing / 0.23)
			impact = sin(sweep * PI)
		else:
			var clock: float = combat.strike_clock
			var timing: Vector3 = combat.strike_timing
			chambered = 1.0 if heavy else smoothstep(0.0,timing.x,clock)
			sweep = clampf((clock - timing.x) / timing.y,0.0,1.0)
			recovery = smoothstep(timing.x+timing.y, combat.strike_total, clock)
			impact = smoothstep(0.0,0.54,sweep)
	var thrust := impact * (1.0 - recovery)
	# Draw against the rear leg, then turn through the cut. The held charge and
	# first release frame use the same chamber before the blade advances.
	var load := chambered if ally else chambered * (1.0 - impact) * (1.0 - recovery)
	var weight := 0.0 if ally else 1.0 if heavy else 0.37
	var pelvis := Vector3(side * (0.032 * load - 0.037 * thrust) * weight, 0.0,
		(-0.058 * load + 0.082 * thrust) * weight)
	var settle := float(watcher.dash > 0.0) * clampf(watcher.dash / 0.20, 0.0, 1.0)
	var tired := smoothstep(1.67,1.85,watcher.injury)
	var hips := 0.501 - gait * 0.048 - settle*0.064 - thrust*0.018 - weight * (0.053 * load + 0.075 * thrust)
	var torso: Node3D = rig.chest
	torso.position.x = pelvis.x
	torso.position.y = hips + 0.08 + gait * absf(sin(stride)) * 0.021 - tired*0.026
	torso.position.z = pelvis.z + 0.07*thrust - 0.038*load + settle*0.092
	torso.rotation = Vector3(0.10*gait - load*(0.18 + 0.14*weight) + thrust*(0.38 + 0.24*weight) + settle*0.23 - tired*0.23,
		side * (thrust*(0.43 + 0.18*weight) - load*(0.37 + 0.24*weight)) + sin(stride)*gait*0.09,
		sin(stride)*gait*0.085 + tired*0.17 + side * (load*0.09 + thrust*0.13)*weight)
	var head: Node3D = rig.head
	head.rotation.x = -torso.rotation.x*0.47 + (sin(watcher.clock*2.7)*0.025)*(1.0-gait)
	head.rotation.y = -torso.rotation.y*0.54
	var cloth: Node3D = rig.capes
	var slack := gait * (0.20 + 0.09*sin(stride-0.5)) + settle*0.48
	cloth.rotation.x = 0.06 + slack - load*0.10*weight + thrust*(0.16 + 0.21*weight)
	cloth.rotation.z = sin(stride+0.9)*0.14*gait + side*thrust*(0.27 + 0.16*weight)
	plant_legs(rig, hips, speed, delta if not frozen else 0.0, pelvis)
	var arms: Array = rig.arms
	var elbows: Array = rig.elbows
	arms[0].rotation = Vector3(-0.50 + sin(stride)*0.14*gait - load*0.18 + settle*0.24 + thrust*weight*0.25,
		-0.06 - load*weight*0.16, -0.29-thrust*(0.13 + 0.16*weight))
	elbows[0].rotation.x = -0.51 - 0.13*load
	var lamp: Node3D = rig.lantern
	lamp.rotation = Vector3(0.80 - sin(stride-0.38)*0.18*gait+settle*0.11,0.0,sin(stride+0.4)*gait*0.15)
	pose_sword_arm(rig, chambered, sweep, recovery, side, heavy, gait, stride)
	flash(rig,tired)


func pose_sword_arm(rig: Dictionary, draw: float, sweep: float, recovery: float, side: float,
		heavy: bool, gait: float, stride: float) -> void:
	var root: Node3D = rig.root
	var cut_angle := lerpf(0.54, side * -1.34, draw)
	if sweep > 0.0:
		if sweep < 0.54:
			cut_angle = side * lerpf(-1.34,0.0,ease(sweep / 0.54,1.62))
		else:
			cut_angle = side * lerpf(0.0,1.51,ease((sweep-0.54)/0.46,0.59))
	cut_angle = lerpf(cut_angle,0.54,recovery)
	var radial := Vector3(sin(cut_angle),0.0,cos(cut_angle))
	var pull := draw*(1.0-sweep)*(1.0-recovery)
	var sweep_fold := sin(sweep*PI)*(1.0-recovery)
	var cut_weight := smoothstep(0.17, 0.66, sweep) * (1.0-recovery) if heavy else 0.0
	var hand := Vector3(0.24, 0.71 + pull*(0.50 if heavy else 0.24) + sweep_fold*0.07 - cut_weight*0.105,
		0.03 + cut_weight*0.069)
	hand += radial*(0.19+0.10*sweep_fold)
	hand.z += sin(stride-0.2)*gait*0.04*(1.0-draw)
	var arms: Array = rig.arms
	var elbows: Array = rig.elbows
	var shoulder: Node3D = arms[1]
	var elbow: Node3D = elbows[1]
	var chest: Node3D = rig.chest
	var destination := chest.to_local(root.to_global(hand))
	solve_hinge(shoulder,elbow,destination,Vector3(0.67,-0.58,-0.31),ARM_LENGTH,FOREARM_LENGTH)
	var slope := lerpf(0.44,1.51 if heavy else 0.42,pull)-sweep_fold*(0.89 if heavy else 0.28)
	var upward := (radial + Vector3.UP*slope).normalized()
	var cross := Vector3.UP.cross(upward).normalized()
	var sword: Node3D = rig.sword
	sword.global_basis = root.global_basis * Basis(cross,upward,cross.cross(upward))


func pose_enemy(enemy: Enemy, rig: Dictionary, delta: float) -> void:
	var root: Node3D = rig.root
	root.visible = enemy.kind != Enemy.SHADE or enemy.lit
	if not root.visible:
		return
	if enemy.kind == Enemy.MOTH:
		pose_moth(enemy, rig, delta)
		return
	var speed := place(rig,enemy.position,enemy.facing,0.014,delta)
	var recoil := maxf(enemy.stagger/0.29,enemy.hit/0.13)
	if enemy.kind == Enemy.CRAWLER:
		if enemy.tell > 0.0 or enemy.attack_pose > 0.0:
			pose_crawler_attack(enemy, rig, recoil)
			flash(rig,maxf(enemy.hit/0.13, recoil*0.58))
			return
		if rig.erase("rake_feet"):
			(rig.chest as Node3D).position.x = 0.0
			(rig.head as Node3D).rotation.y = 0.0
			for palm: Node3D in rig.palms:
				palm.rotation = Vector3.ZERO
	var gait := smoothstep(0.10,1.39,speed) if enemy.acting else 0.0
	var weight := 0.72 if enemy.kind in [Enemy.COLOSSUS,Enemy.HERALD] else 1.0
	var stride: float = rig.stride
	var tell := 1.0 - enemy.tell/maxf(enemy.tell_span,0.10) if enemy.tell > 0.0 else 0.0
	var anticipation := smoothstep(0.0,0.83,tell) * (1.0 - smoothstep(0.81,1.0,tell))
	var spell := minf(1.0,enemy.charge)*0.74
	var final_run := smoothstep(0.79,0.999,tell)
	var follow := pow(clampf(enemy.attack_pose/maxf(enemy.attack_recovery,0.1),0.0,1.0),1.45)
	var thrust := maxf(final_run, follow)
	var withdrawal := anticipation + spell
	var hips := 0.502 - gait*0.04 - withdrawal*0.023 - thrust*0.044 - recoil*0.034
	var chest: Node3D = rig.chest
	chest.position.y = hips + 0.063 + 0.029*absf(sin(stride))*gait
	chest.position.z = thrust*0.12 - withdrawal*0.085 - recoil*0.09
	chest.rotation = Vector3(0.075 + 0.22*gait - 0.47*withdrawal + 0.58*thrust - 0.42*recoil,
		sin(stride)*0.21*gait+withdrawal*0.23-thrust*0.34,sin(stride)*0.10*gait+recoil*0.18)
	var head: Node3D = rig.head
	head.rotation.x = -0.085-0.37*chest.rotation.x- recoil*0.24
	head.rotation.z = -sin(stride+0.72)*0.11*gait
	var cloth: Node3D = rig.capes
	cloth.rotation.x = gait*(0.18+0.12*sin(stride)) - withdrawal*0.09 + thrust*0.34
	cloth.rotation.z = sin(stride+0.6)*gait*0.14
	plant_legs(rig, hips, speed, delta if enemy.hit_hold <= 0.0 else 0.0)
	var arms: Array = rig.arms
	var elbows: Array = rig.elbows
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var hand := side * sin(stride) * 0.48 * gait * weight
		var windup := -1.72 if i == 1 and enemy.kind in [Enemy.COLOSSUS,Enemy.HERALD] else 0.78
		arms[i].rotation = Vector3(-0.28 + hand + windup*withdrawal - 1.42*thrust + recoil*0.33,
			side*(0.16+0.37*withdrawal-0.24*thrust), side*(0.25+withdrawal*0.31+recoil*0.12))
		elbows[i].rotation.x = -0.46 - 0.70*withdrawal + 0.39*thrust - recoil*0.14
	if rig.has("sword"):
		var weapon: Node3D = rig.sword
		weapon.rotation.x = (0.74 if enemy.kind == Enemy.HEXER else 1.19) - 0.50*withdrawal + 0.48*thrust
	if enemy.kind == Enemy.HERALD:
		pose_herald_rite(enemy, rig)
	flash(rig,maxf(enemy.hit/0.13, recoil*0.58))


func pose_moth(enemy: Enemy, rig: Dictionary, delta: float) -> void:
	var wanted: float = enemy.get_meta(&"moth_dive", 0.0)
	var previous: float = rig.get("moth_dive", 0.0)
	var dive := maxf(wanted, move_toward(previous, wanted, delta*5.9))
	rig["moth_dive"] = dive
	var fold := smoothstep(0.15, 0.90, dive)
	var altitude := lerpf(0.76 + sin(enemy.age*10.5)*0.17, 0.40, dive)
	place(rig, enemy.position, enemy.facing, altitude, delta)
	var wings: Array = rig.wings
	var flap := sin(enemy.age*31.0) * (1.0 - 0.82*fold)
	for index in range(wings.size()):
		var side := -1.0 if index == 0 else 1.0
		wings[index].rotation = Vector3(0.06*fold, side*0.97*fold, side*(0.16 - flap*0.72 + fold*0.36))
	(rig.root as Node3D).rotation.x = 0.16 + flap*0.06 + 0.69*dive - enemy.hit*2.20
	flash(rig, enemy.hit/0.13)


func release_moth_on_contact(_where: Vector2, _direction: Vector2, _destination: int, moth: Node2D) -> void:
	if not actors.has(moth):
		return
	var root: Node3D = actors[moth].root
	root.hide()
	root.queue_free()
	actors.erase(moth)


func pose_herald_rite(enemy: Enemy, rig: Dictionary) -> void:
	var combat = battle.combat
	var gathering := smoothstep(0.0, combat.HERALD_WARNING, combat.HERALD_WARNING - enemy.special)
	var elapsed: float = combat.HERALD_INTERVAL - enemy.special
	var discharge := 1.0 - smoothstep(0.025, 0.56, elapsed)
	var rite: Node3D = rig.rite
	rite.visible = maxf(gathering, discharge) > 0.025
	if not rite.visible:
		return
	var chest: Node3D = rig.chest
	var shoulder: Node3D = rig.arms[0]
	var elbow: Node3D = rig.elbows[0]
	var palm: Node3D = rig.palms[0]
	var weight := maxf(gathering, discharge)
	var engaged := 0.65 if enemy.tell > 0.0 or enemy.attack_pose > 0.0 else 1.0
	var hand := chest.to_local(palm.global_position)
	var reach := Vector3(-0.38, 0.54 - discharge*0.12, 0.29 + discharge*0.13)
	solve_hinge(shoulder, elbow, hand.lerp(reach, weight * engaged), Vector3(-0.8,-0.4,-0.21), ARM_LENGTH, FOREARM_LENGTH)
	chest.rotation.y += (gathering * 0.23 - discharge * 0.18) * engaged
	chest.rotation.x += (-gathering * 0.11 + discharge * 0.08) * engaged
	rite.scale = Vector3.ONE * (gathering * (0.83 + sin(enemy.age * 29.0) * 0.12) + discharge * 0.49)
	rite.rotation = Vector3(enemy.age * 4.6, enemy.age * 2.4, 0.31)


func pose_crawler_attack(enemy: Enemy, rig: Dictionary, recoil: float) -> void:
	var released := enemy.attack_pose > 0.0
	var progress := 1.0 if released else 1.0 - enemy.tell / enemy.tell_span
	var recovery := 1.0 - enemy.attack_pose / enemy.attack_recovery if released else 0.0
	var strike := smoothstep(0.76, 1.0, progress)
	var load := smoothstep(0.03, 0.57, progress) * (1.0 - strike)
	var follow := strike * (1.0 - smoothstep(0.18, 0.93, recovery))
	var hips := 0.502 - load * 0.085 - follow * 0.127 - recoil * 0.034
	# Sit onto the rear hip, then let the chest pass over the foot that catches the rush.
	var center := Vector3(0.047 * load - 0.064 * follow, 0.0, -0.08 * load + 0.124 * follow)
	var chest: Node3D = rig.chest
	chest.position = Vector3(center.x, hips + 0.063, center.z - recoil * 0.06)
	chest.rotation = Vector3(0.075 - 0.40 * load + 0.75 * follow - recoil * 0.36,
		0.51 * load - 0.53 * follow, 0.14 * load + 0.21 * follow + recoil * 0.18)
	var head: Node3D = rig.head
	head.rotation = Vector3(-0.11 + 0.21 * load - 0.42 * follow, -chest.rotation.y * 0.53,
		-chest.rotation.z * 0.42)
	pose_crawler_feet(rig, progress, released, recovery)
	solve_legs(rig, hips, center)

	var arms: Array = rig.arms
	var elbows: Array = rig.elbows
	var palms: Array = rig.palms
	var claw := relaxed_crawler_hand(arms[1], 1.0).lerp(Vector3(0.46, 0.70, -0.18), load)
	claw = claw.lerp(Vector3(0.018, 0.47, 0.40), follow)
	var counter := relaxed_crawler_hand(arms[0], -1.0).lerp(Vector3(-0.42, 0.18, 0.28), load)
	counter = counter.lerp(Vector3(-0.48, 0.15, -0.23), follow)
	solve_hinge(arms[1], elbows[1], claw, Vector3(0.77, -0.43, -0.36), ARM_LENGTH, FOREARM_LENGTH)
	solve_hinge(arms[0], elbows[0], counter, Vector3(-0.62, -0.51, -0.51), ARM_LENGTH, FOREARM_LENGTH)
	palms[1].rotation = Vector3(-0.26 * load + 0.52 * follow, -0.31 * follow, 0.20 * load - 0.25 * follow)
	palms[0].rotation = Vector3(-0.10 * load - 0.22 * follow, 0.0, -0.13 * load)


func relaxed_crawler_hand(shoulder: Node3D, side: float) -> Vector3:
	var reach := Vector3.DOWN * ARM_LENGTH + (Vector3.DOWN * FOREARM_LENGTH).rotated(Vector3.RIGHT, -0.46)
	return shoulder.position + Basis.from_euler(Vector3(-0.28, side * 0.16, side * 0.25)) * reach


func pose_crawler_feet(rig: Dictionary, progress: float, released: bool, recovery: float) -> void:
	var root: Node3D = rig.root
	var feet: Array = rig.feet
	var lead: FootPin = feet[0]
	var rear: FootPin = feet[1]
	var rest_lead := root.to_global(Vector3(-0.129, 0.05, -0.035))
	if not rig.has("rake_feet") or rig.reset_feet:
		var front := rest_lead if rig.reset_feet else lead.position
		var back := root.to_global(Vector3(0.129, 0.05, 0.051)) if rig.reset_feet else rear.position
		rig.rake_feet = {"front": front, "back": back, "land": Vector3.INF}
		rig.reset_feet = false
	var pins: Dictionary = rig.rake_feet
	var settling := smoothstep(0.0, 0.23, progress)
	var planted_rear: Vector3 = pins.back
	planted_rear.y = rest_lead.y
	rear.anchor = planted_rear
	rear.position = (pins.back as Vector3).lerp(planted_rear, settling)
	rear.age = 0.0 if rear.position.y > planted_rear.y + 0.0001 else -1.0
	var target := root.to_global(Vector3(-0.18, 0.05, 0.24))
	if released:
		if pins.land == Vector3.INF:
			pins.land = target
		var reset := smoothstep(0.63, 0.98, recovery)
		var land: Vector3 = pins.land
		lead.anchor = land.lerp(rest_lead, reset)
		lead.position = lead.anchor + Vector3.UP * sin(reset * PI) * 0.062
		lead.age = 0.0 if reset > 0.0 and reset < 1.0 else -1.0
		return
	var swing := smoothstep(0.70, 1.0, progress)
	var planted: Vector3 = pins.front
	planted.y = lerpf(planted.y, rest_lead.y, settling)
	lead.anchor = planted
	lead.position = planted.lerp(target, swing) + Vector3.UP * sin(PI * swing) * 0.109
	lead.age = 0.0 if lead.position.y > rest_lead.y + 0.0001 else -1.0


func plant_legs(rig: Dictionary, hip_height: float, speed: float, delta: float, pelvis := Vector3.ZERO) -> void:
	var root: Node3D = rig.root
	var feet: Array = rig.feet
	var velocity: Vector3 = rig.velocity
	var forward := velocity.normalized()
	var had_step := false
	var pick := -1
	var furthest := 0.0
	var wanted := PackedVector3Array()
	for side in range(2):
		var x := (-1.0 if side == 0 else 1.0) * 0.129
		var neutral := root.to_global(Vector3(x,0.050,-0.035 if side == 0 else 0.051))
		wanted.append(neutral)
		var pin: FootPin = feet[side]
		if rig.reset_feet:
			pin.age = -1.0
			pin.anchor = neutral
			pin.position = neutral
		if pin.age >= 0.0:
			pin.age += delta
			var phase := clampf(pin.age / pin.duration,0.0,1.0)
			pin.position = pin.from.lerp(pin.goal,smoothstep(0.0,1.0,phase)) + Vector3.UP * sin(PI*phase)*pin.lift
			if phase >= 1.0:
				pin.age = -1.0
				pin.anchor = pin.goal
				pin.position = pin.anchor
			else:
				had_step = true
		else:
			var displacement := neutral - pin.anchor
			var stretch := displacement.length() * (1.10 if displacement.dot(forward) > 0.0 else 0.92)
			if stretch > furthest:
				furthest = stretch
				pick = side
	rig.reset_feet = false
	if not had_step and pick >= 0 and delta > 0.0:
		var scale_factor := root.scale.x
		var measured := maxf(speed, rig.pace_peak * 0.86)
		var pace := clampf((measured - 0.34) / 2.85,0.0,1.0)
		var threshold := lerpf(0.145,0.051,pace) * scale_factor
		if furthest > threshold:
			var pin: FootPin = feet[pick]
			pin.duration = lerpf(0.155,0.080,pace)
			pin.from = pin.anchor
			pin.goal = wanted[pick] + forward * (measured * pin.duration * 0.93 + pace * 0.13 * scale_factor)
			pin.age = 0.0
			pin.lift = scale_factor * lerpf(0.055,0.155,smoothstep(0.20,3.6,speed))
	solve_legs(rig, hip_height, pelvis)


func solve_legs(rig: Dictionary, hip_height: float, shift := Vector3.ZERO) -> void:
	# A weight-bearing leg limits pelvis height rather than dragging its boot.
	var root: Node3D = rig.root
	var feet: Array = rig.feet
	var thighs: Array = rig.thighs
	var knees: Array = rig.knees
	var boots: Array = rig.boots
	var body_height := hip_height
	for side in range(2):
		var thigh: Node3D = thighs[side]
		thigh.position.x = (-0.118 if side == 0 else 0.118) + shift.x
		thigh.position.z = shift.z
		var pin: FootPin = feet[side]
		if pin.age >= 0.0:
			continue
		var support := root.to_local(pin.anchor)
		var width := Vector2(support.x-thigh.position.x,support.z-thigh.position.z).length_squared()
		var vertical := sqrt(maxf(0.0, (THIGH_LENGTH+SHIN_LENGTH-0.004)**2-width))
		body_height = minf(body_height,support.y+vertical)
	body_height = maxf(hip_height-0.092,body_height)
	var torso: Node3D = rig.chest
	torso.position.y += body_height - hip_height
	for side in range(2):
		var thigh: Node3D = thighs[side]
		var knee: Node3D = knees[side]
		var boot: Node3D = boots[side]
		var pin: FootPin = feet[side]
		thigh.position.y = body_height
		solve_hinge(thigh,knee,root.to_local(pin.position),Vector3.BACK,THIGH_LENGTH,SHIN_LENGTH)
		boot.basis = (thigh.basis*knee.basis).inverse() * Basis(Vector3.UP,0.14 if side > 0 else -0.14)


func solve_hinge(first: Node3D, second: Node3D, destination: Vector3, bend_forward: Vector3,
		a: float, b: float) -> void:
	var toward := destination - first.position
	var actual := toward.length()
	var forward := toward.normalized() if actual > 0.001 else Vector3.DOWN
	var reference := bend_forward - forward * bend_forward.dot(forward)
	if reference.length_squared() < 0.001:
		reference = Vector3.RIGHT - forward * forward.x
	reference = reference.normalized()
	var reach := clampf(actual, 0.045, a+b-0.001)
	var along := (a*a - b*b + reach*reach) / (2.0*reach)
	var bend := sqrt(maxf(0.0,a*a-along*along))
	var upper := forward*along + reference*bend
	var lower := forward*reach - upper
	first.basis = segment_basis(upper)
	second.basis = first.basis.inverse() * segment_basis(lower)


func segment_basis(downward: Vector3) -> Basis:
	var pole := -downward.normalized()
	var left := pole.cross(Vector3.BACK)
	if left.length_squared() < 0.001:
		left = pole.cross(Vector3.UP)
	left = left.normalized()
	return Basis(left,pole,left.cross(pole).normalized())


func flash(rig: Dictionary, fraction: float) -> void:
	var paint: StandardMaterial3D = rig.material
	paint.emission = Color("#273643").lerp(Color("#ec9c63"),clampf(fraction*0.83,0.0,1.0))
	paint.emission_energy_multiplier = 0.11 + 0.28*clampf(fraction,0.0,1.0)
