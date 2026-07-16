class_name GameDataRepository
extends RefCounted

const DATA_DIRECTORY := "res://data/gameplay"
const REQUIRED_FILES := {
	"classes": "classes.json",
	"combat": "combat.json",
	"enemies": "enemies.json",
	"equipment": "equipment.json",
}

var _documents: Dictionary = {}


func _init() -> void:
	for document_name in REQUIRED_FILES:
		_documents[document_name] = _load_json(REQUIRED_FILES[document_name])
	_validate()


func classes() -> Dictionary:
	return _documents["classes"]


func combat() -> Dictionary:
	return _documents["combat"]


func enemies() -> Array:
	return _documents["enemies"]["enemies"]


func equipment() -> Dictionary:
	return _documents["equipment"]


func class_definition(class_id: StringName) -> Dictionary:
	var document := classes()
	var definitions: Dictionary = document["classes"]
	var key := String(class_id)
	if not definitions.has(key):
		key = document["default_class_id"]
	var result: Dictionary = definitions[key].duplicate(true)
	result["id"] = key
	result["accent"] = Color(String(result["accent"]))
	return result


func slot_definition(slot_value: int) -> Dictionary:
	for definition in equipment()["slots"]:
		if int(definition["enum"]) == slot_value:
			return definition
	assert(false, "缺少装备部位定义：%d" % slot_value)
	return {}


func rarity_definition(rarity_value: int) -> Dictionary:
	for definition in equipment()["rarities"]:
		if int(definition["enum"]) == rarity_value:
			return definition
	assert(false, "缺少装备品质定义：%d" % rarity_value)
	return {}


func _load_json(file_name: String) -> Dictionary:
	var path := "%s/%s" % [DATA_DIRECTORY, file_name]
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "无法读取玩法数据：%s" % path)
	var parsed = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary, "玩法数据必须是 JSON 对象：%s" % path)
	return parsed as Dictionary


func _validate() -> void:
	assert(not classes()["classes"].is_empty(), "至少需要一个职业定义。")
	assert(not enemies().is_empty(), "至少需要一个敌人定义。")
	assert(not equipment()["slots"].is_empty(), "至少需要一个装备部位。")
	var total_weight := 0.0
	for rarity in equipment()["rarities"]:
		total_weight += float(rarity["weight"])
	assert(absf(total_weight - 1.0) < 0.001, "装备品质权重之和必须为 1。")
