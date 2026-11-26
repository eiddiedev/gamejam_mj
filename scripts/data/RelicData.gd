class_name RelicData
extends Resource

@export var id: String = ""
@export var description: String = ""


static func create(relic_id: String, desc: String) -> RelicData:
	var data := RelicData.new()
	data.id = relic_id
	data.description = desc
	return data
