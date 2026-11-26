class_name OathData
extends Resource

@export var id: String = ""
@export var base_word: String = ""
@export var letter_index: int = 0
@export var rarity: String = "common"
@export var title: String = ""
@export var effect: String = ""


static func create(oath_id: String, source_word: String, index: int, tier: String, title_text: String, effect_text: String) -> OathData:
	var data := OathData.new()
	data.id = oath_id
	data.base_word = source_word
	data.letter_index = index
	data.rarity = tier
	data.title = title_text
	data.effect = effect_text
	return data


func to_dict() -> Dictionary:
	return {
		"base": base_word,
		"letter": letter_index,
		"rarity": rarity,
		"title": title,
		"effect": effect,
	}
