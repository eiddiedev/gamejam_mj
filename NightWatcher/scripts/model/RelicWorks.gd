extends Node3D

const Ink = preload("res://world/mesh_builder.gd")
const Fields = preload("res://scripts/battle/BattleMaps.gd")
const Walk = preload("res://scripts/battle/BattleCollision.gd")
const WROUGHT := Color("#4a4130")
const IRON := Color("#889188")
const BONE := Color("#c0b398")
const BRASS := Color("#94775a")
const CHAR := Color("#49352e")
const OIL := Color("#885b39")

var ground
var level
var cradles: Array[Node3D] = []
var fittings: Array[MeshInstance3D] = []
var contents: Array[MeshInstance3D] = []
var fixture_bodies: Array[StaticBody3D] = []
var fixture_shapes: Array[CollisionShape3D] = []
var fixture_pending: Array[bool] = []
var flames: Array[MeshInstance3D] = []
var torch_bounce: Array[OmniLight3D] = []
var appearances: Array[String] = []

func setup(world: Node3D, field: Node2D) -> void:
	ground = world
	level = field
	for index in range(level.slot_points.size()):
		var site: Array = Fields.SUPPORTS[level.biome][index]
		var pair: Array = site[0]
		var rack := Node3D.new()
		rack.name = site[3]
		rack.position = ground.at(pair[0], pair[1], site[1])
		if String(site[2]) == "oil":
			rack.rotation.y = -0.45 if index % 2 else 0.42
		add_child(rack)
		cradles.append(rack)
		var profile: String = site[2]
		var details := Ink.new()
		build_socket(details, profile)
		fittings.append(paint_mesh(details, rack))
		var built := paint_mesh(Ink.new(), rack)
		contents.append(built)
		var bulk := StaticBody3D.new()
		bulk.name = "Installed iron and timber collision"
		bulk.collision_layer = 0
		bulk.collision_mask = 0
		built.add_child(bulk)
		var hull := CollisionShape3D.new()
		bulk.add_child(hull)
		fixture_bodies.append(bulk)
		fixture_shapes.append(hull)
		fixture_pending.append(false)
		var flame := MeshInstance3D.new()
		flame.mesh = ember_shape()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("#ffbb63")
		material.emission_enabled = true
		material.emission = Color("#f08c43")
		material.emission_energy_multiplier = 0.22
		flame.material_override = material
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rack.add_child(flame)
		flame.hide()
		flames.append(flame)
		var glow := OmniLight3D.new()
		glow.position.y = 0.59
		glow.light_color = Color("#ffab64")
		glow.omni_range = 2.91
		glow.omni_attenuation = 1.61
		glow.visible = false
		rack.add_child(glow)
		torch_bounce.append(glow)
		appearances.append("")
		level.combat.towers[index].hide()

func sync(clock: float) -> void:
	for index in range(cradles.size()):
		var piece = level.combat.towers[index]
		var signature := "%s:%s" % [piece.kind, piece.level]
		if appearances[index] != signature:
			appearances[index] = signature
			redraw(index, piece.kind, piece.level)
		var flame := flames[index]
		flame.visible = (piece.kind == "brazier" and piece.lit) or (piece.kind == "oil" and piece.burn > 0.0)
		var glow := torch_bounce[index]
		glow.visible = flame.visible
		if flame.visible:
			var flash := 1.0 + 0.14 * sin(clock * 11.0 + index) + 0.08 * sin(clock * 18.4 + index)
			flame.position = Vector3(0, 0.35 if piece.kind == "brazier" else 0.041, 0)
			flame.scale = Vector3(1.0, flash, 1.0) * (0.63 + piece.level * 0.12)
			flame.rotation.y = sin(clock * 5.3 + index) * 0.43
			glow.light_energy = flash * (0.65 + 0.14 * piece.level)
		var mount := contents[index]
		if fixture_pending[index] and not occupies_fixture(index):
			fixture_pending[index] = false
			fixture_bodies[index].collision_layer = Walk.FIXTURE_MASK
		if piece.kind == "ballista" and piece.level > 0:
			mount.rotation.y = lerp_angle(mount.rotation.y, atan2(piece.look.x, piece.look.y), 0.22)
			mount.position.y = -minf(0.10, piece.flash * 0.50)
		else:
			mount.rotation.y = 0.0
			mount.position.y = 0.0

func redraw(index: int, profile: String, rank: int) -> void:
	var details := Ink.new()
	match profile:
		"brazier":
			brazier(details, rank)
		"ballista":
			bow(details, rank, index == 1 and level.biome in [0, 3])
		"barricade":
			shutter(details, rank)
		"oil":
			oil_bed(details, rank)
	contents[index].mesh = details.build()
	var hull: ConcavePolygonShape3D = null
	if rank > 0 and profile in ["brazier", "ballista", "barricade"]:
		hull = contents[index].mesh.create_trimesh_shape()
		if hull != null:
			hull.backface_collision = true
	fixture_shapes[index].shape = hull
	fixture_pending[index] = hull != null and occupies_fixture(index)
	fixture_bodies[index].collision_layer = Walk.FIXTURE_MASK if hull != null and not fixture_pending[index] else 0

func occupies_fixture(index: int) -> bool:
	var fixture := contents[index]
	var player_local: Vector3 = fixture.to_local(ground.screen_floor(level.player))
	var bounds := fixture.get_aabb()
	var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
	return footprint.grow(level.PLAYER_RADIUS / ground.PIXELS + 0.03).has_point(Vector2(player_local.x, player_local.z))

func paint_mesh(builder: RefCounted, parent: Node3D) -> MeshInstance3D:
	var out := MeshInstance3D.new()
	out.mesh = builder.build()
	out.material_override = ground.material
	parent.add_child(out)
	return out

func build_socket(mesh: RefCounted, profile: String) -> void:
	match profile:
		"brazier":
			for point in [Vector3(-0.29,0,0.1), Vector3(0.30,-0.02,0.04), Vector3(0.01,0.0,-0.24)]:
				mesh.block(point,0.23,0.17,0.20,point.x,IRON,0.044,0,false)
			mesh.tube(PackedVector3Array([Vector3(0,-0.025,0),Vector3(0,0.075,0)]), PackedFloat32Array([0.29,0.22]),WROUGHT,9)
		"ballista":
			for side in [-1.0,1.0]:
				mesh.block(Vector3(side*0.20,-0.06,0.024),0.125,0.20,0.29,side*0.09,BRASS,0.026,0,false)
				mesh.block(Vector3(side*0.20,0.06,0.10),0.049,0.12,0.12,side*0.10,IRON,0.013,0,false)
		"barricade":
			for side in [-1.0, 1.0]:
				mesh.block(Vector3(side*0.53,-0.05,-0.03),0.29,0.28,0.23,side*0.16,IRON,0.054,0,false)
				mesh.block(Vector3(side*0.26,-0.015,0.033),0.16,0.11,0.30,side*0.09,WROUGHT,0.026,0,false)
		"oil":
			mesh.block(Vector3(0,-0.038,0),0.88,0.064,0.56,0,CHAR,0.13,0,false)
			for side in [-1.0,1.0]:
				mesh.block(Vector3(side*0.44,-0.024,0),0.12,0.09,0.58,0,WROUGHT,0.028,0,false)
				mesh.block(Vector3(0,-0.028,side*0.30),0.88,0.10,0.12,0,IRON,0.031,0,false)

func brazier(mesh: RefCounted, rank: int) -> void:
	for index in range(3):
		var theta := index*TAU/3.0 + 0.4
		var rim := Vector3(cos(theta),0,sin(theta))
		mesh.tube(PackedVector3Array([rim*0.285, rim*0.21+Vector3.UP*0.19, rim*0.32+Vector3.UP*0.34]),
			PackedFloat32Array([0.054,0.039,0.05]),BRASS,6,0.13)
	var pan := 0.34 + 0.035 * rank
	mesh.tube(PackedVector3Array([Vector3.UP*0.25,Vector3.UP*0.37]),PackedFloat32Array([pan*0.66,pan]),WROUGHT,11,0.0)
	rim_band(mesh, pan, 0.365, 0.025, BRASS)
	if rank >= 2:
		rim_band(mesh, pan * 0.72, 0.29, 0.024, IRON)
	if rank >= 3:
		for side in [-1.0,1.0]:
			mesh.block(Vector3(side*pan,0.33,0.01),0.113,0.12,0.18,0,BRASS.lightened(0.16),0.021,0,false)

func bow(mesh: RefCounted, rank: int, eye: bool) -> void:
	var bed := 0.43 if eye else 0.73
	var height := 0.12 if eye else 0.24
	var span := (0.40 if eye else 0.53) + rank*0.046
	mesh.block(Vector3(0,height,0),0.13,0.14,bed,0,CHAR,0.025,0,false)
	for side in [-1.0,1.0]:
		var wing := Vector3(side*span,height+0.14,0.05)
		var points := PackedVector3Array([Vector3(0,height+0.04,0.16),Vector3(side*span*0.53,height+0.13,0.23),wing,wing+Vector3(side*0.06,-0.02,-0.14)])
		mesh.smooth_tube(points,PackedFloat32Array([0.075,0.062,0.044,0.019]),BONE,7,0.08,false)
		mesh.tube(PackedVector3Array([wing+Vector3(side*0.06,-0.02,-0.14),Vector3(0,height+0.092,-0.20)]),
			PackedFloat32Array([0.012,0.012]),WROUGHT,5)
		if rank >= 2:
			mesh.block(Vector3(side*0.095,height-0.015,-0.08),0.07,0.074,0.32,0,IRON,0.016,0,false)
	mesh.block(Vector3(0,height+0.15,0.17),0.066,0.058,0.45,0,BRASS if rank == 3 else IRON,0.018,0,false)

func shutter(mesh: RefCounted, rank: int) -> void:
	for row in range(2):
		mesh.block(Vector3(0,0.14+row*0.18,0.05),1.16,0.125,0.105,0,WROUGHT.lightened(row*0.06),0.027,0.024,false)
	for index in range(5):
		var at := Vector3((index-2)*0.22,0,0.048)
		mesh.tube(PackedVector3Array([at,at+Vector3(-0.04,0.41,0),at+Vector3(0.03,0.66+sin(index*2.11)*0.11,-0.076)]),
			PackedFloat32Array([0.092,0.082,0.012]),CHAR,5,0.09,false)
		if rank >= 2:
			mesh.tube(PackedVector3Array([at+Vector3(0,0.29,0.02),at+Vector3(0,0.62,0.24)]),
				PackedFloat32Array([0.056,0.006]),IRON,5)
	if rank == 3:
		rim_band(mesh,0.47,0.06,0.016,BRASS)

func oil_bed(mesh: RefCounted, rank: int) -> void:
	mesh.block(Vector3(0,0.024,0),0.75,0.035,0.47,0,OIL.lightened(rank*0.06),0.088,0,false)
	for index in range(rank+1):
		mesh.block(Vector3((index-1)*0.18,0.06,0),0.05,0.047,0.36,0,BRASS,0.013,0,false)

func rim_band(mesh: RefCounted, radius: float, height: float, weight: float, tone: Color) -> void:
	var points := PackedVector3Array()
	var widths := PackedFloat32Array()
	for index in range(13):
		var theta := index*TAU/12.0
		points.append(Vector3(cos(theta)*radius,height,sin(theta)*radius))
		widths.append(weight)
	mesh.tube(points,widths,tone,5,0.051,false)

func ember_shape() -> ArrayMesh:
	var mesh := Ink.new()
	for index in range(5):
		var angle := index*TAU/5.0
		var a := Vector3(cos(angle)*0.19,0,sin(angle)*0.19)
		var b := Vector3(cos(angle+TAU/5.0)*0.19,0,sin(angle+TAU/5.0)*0.19)
		var waist := (a+b)*0.35 + Vector3.UP*0.19
		mesh.triangle(a,b,waist,Color("#ffca64"))
		mesh.triangle(a,waist,waist*0.39 + Vector3(0.075,0.38,-0.046),Color("#ffe09d"))
	return mesh.build()
