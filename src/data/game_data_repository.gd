class_name GameDataRepository
extends RefCounted

const DATA_DIRECTORY := "res://data/gameplay"
const REQUIRED_FILES := {
	"classes": "classes.json",
	"combat": "combat.json",
	"enemies": "enemies.json",
	"equipment": "equipment.json",
	"first_rift": "first_rift.json",
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


func first_rift() -> Dictionary:
	return _documents["first_rift"]


func first_rift_floor(floor_number: int) -> Dictionary:
	for definition in first_rift()["floors"]:
		if int(definition["floor"]) == floor_number:
			return (definition as Dictionary).duplicate(true)
	return {}


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
	assert(equipment()["slots"].size() == 13, "正式装备合同必须包含 13 个装备槽。")
	assert(int(equipment()["slot_count"]) == 13, "装备槽声明必须为 13。")
	assert(equipment()["rarities"].size() == 5, "正式装备合同必须包含 5 个品质。")
	var total_weight := 0.0
	for rarity in equipment()["rarities"]:
		total_weight += float(rarity["weight"])
		if String(rarity["id"]) == "common":
			assert(int(rarity["affix_min"]) == 0 and int(rarity["affix_max"]) == 0, "白装不能带词缀。")
		else:
			assert(int(rarity["affix_min"]) == 2 and int(rarity["affix_max"]) == 2, "非白装必须固定 2 条词缀。")
	assert(absf(total_weight - 1.0) < 0.001, "装备品质权重之和必须为 1。")

	var rift := first_rift()
	assert(int(rift["normal_kills_to_clear"]) > 0, "普通层通关击杀数必须大于 0。")
	assert(float(rift["equipment_drop_chance"]) > 0.0, "装备掉率必须大于 0。")
	assert(float(rift["equipment_drop_chance"]) <= 1.0, "装备掉率不能超过 100%。")
	assert(is_equal_approx(
		float(combat()["rewards"]["drop_chance"]),
		float(rift["equipment_drop_chance"]),
	), "战斗掉率必须与第一裂隙合同一致。")
	assert(float(rift["offline_efficiency"]) > 0.0, "离线效率必须大于 0。")
	assert(float(rift["offline_efficiency"]) <= 1.0, "离线效率不能超过在线效率。")
	assert(rift["floors"].size() >= 5, "第一裂隙至少需要 1～5 层定义。")
	for floor_number in range(1, 6):
		assert(not first_rift_floor(floor_number).is_empty(), "缺少第 %d 层定义。" % floor_number)
