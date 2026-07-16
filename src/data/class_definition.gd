class_name ClassDefinition
extends RefCounted

const Repository = preload("res://src/data/game_data_repository.gd")

static var _repository := Repository.new() as GameDataRepository


static func get_definition(class_id: StringName) -> Dictionary:
	return _repository.class_definition(class_id)


static func all_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for class_id in _repository.classes()["classes"]:
		result.append(StringName(class_id))
	return result
