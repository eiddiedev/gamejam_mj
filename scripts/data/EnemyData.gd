class_name EnemyData
extends Resource

@export var kind: int = 0
@export var display_name: String = ""
@export var base_health: float = 30.0
@export var base_speed: float = 50.0
@export var base_power: float = 5.0
@export var base_armor: float = 0.0
@export var reward: Vector2i = Vector2i.ZERO
@export var xp: int = 4
@export var intro_hint: String = ""


static func create(enemy_kind: int, name_text: String, hp: float, spd: float, pwr: float, arm: float, loot: Vector2i, exp_value: int, hint: String) -> EnemyData:
	var data := EnemyData.new()
	data.kind = enemy_kind
	data.display_name = name_text
	data.base_health = hp
	data.base_speed = spd
	data.base_power = pwr
	data.base_armor = arm
	data.reward = loot
	data.xp = exp_value
	data.intro_hint = hint
	return data
