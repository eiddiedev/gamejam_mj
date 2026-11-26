class_name TowerData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var base_price: Vector2i = Vector2i.ZERO
@export var health_by_level: PackedFloat32Array = PackedFloat32Array()
@export var level_descriptions: PackedStringArray = PackedStringArray()


static func create(tower_id: String, name_text: String, price: Vector2i, health: Array[float], descriptions: Array[String]) -> TowerData:
	var data := TowerData.new()
	data.id = tower_id
	data.display_name = name_text
	data.base_price = price
	data.health_by_level = PackedFloat32Array(health)
	data.level_descriptions = PackedStringArray(descriptions)
	return data


func cost_at(level: int = 1) -> Vector2i:
	var multiplier := 1.0 + float(level - 1) * 0.52
	return Vector2i(ceili(base_price.x * multiplier), ceili(base_price.y * multiplier))


func health_at(level: int) -> float:
	if health_by_level.is_empty():
		return 0.0
	return health_by_level[clampi(level - 1, 0, health_by_level.size() - 1)]


func description_at(level: int) -> String:
	if level_descriptions.is_empty():
		return ""
	return level_descriptions[clampi(level - 1, 0, level_descriptions.size() - 1)]


func descriptions_array() -> Array[String]:
	var result: Array[String] = []
	for line in level_descriptions:
		result.append(line)
	return result
