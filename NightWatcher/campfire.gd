extends Node2D

signal extinguished

const MAX_HP := 100.0
const DECAY_RATE := 1.5
const FLAME_SHADER = preload("res://flame.gdshader")

var hp := MAX_HP
var light_energy := 1.3
var time := 0.0
var flame_anchor := Vector3.ZERO
var flame: MeshInstance3D
var flame_material: ShaderMaterial

func _ready() -> void:
	flame = MeshInstance3D.new()
	flame.name = "Ink flame"
	var sheet := QuadMesh.new()
	sheet.size = Vector2(1.0, 0.86)
	flame.mesh = sheet
	flame.position = flame_anchor
	flame_material = ShaderMaterial.new()
	flame_material.shader = FLAME_SHADER
	# The flame blends over the contour pass and still depth-tests against the fort.
	flame_material.render_priority = 100
	flame.material_override = flame_material
	add_child(flame)
	update_light()

func animate(delta: float) -> void:
	time += delta
	flame_material.set_shader_parameter("t", time)
	queue_redraw()

func _draw() -> void:
	if hp <= 0.0:
		return
	for index in range(8):
		var progress := fmod(time * (0.61 + float(index % 4) * 0.10) + index * 0.293, 1.0)
		var drift := cos(index * 4.7 + progress * 2.5) * (7.0 + 19.0 * progress)
		var at := Vector2(drift, -5.0 - progress * (25.0 + 45.0 * ratio()))
		var tint := Color(1.0, 0.58 + progress * 0.32, 0.24, (1.0 - progress) * 0.69)
		draw_circle(at, 0.74 + (index % 3) * 0.24, tint, true, -1, true)

func decay(delta: float) -> void:
	set_hp(hp - DECAY_RATE * delta)

func reset() -> void:
	hp = MAX_HP
	update_light()

func add_fuel() -> void:
	set_hp(hp + 25.0)

func damage(amount: float) -> void:
	set_hp(hp - amount)

func set_hp(value: float) -> void:
	var was_lit := hp > 0.0
	hp = clampf(value, 0.0, MAX_HP)
	update_light()
	if hp <= 0.0 and was_lit:
		extinguished.emit()

func ratio() -> float:
	return hp / MAX_HP

func update_light() -> void:
	light_energy = lerpf(0.10, 1.3, ratio())
	flame.visible = hp > 0.0
	flame_material.set_shader_parameter("fuel", ratio())
