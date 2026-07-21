class_name GameDataRepository
extends RefCounted

const DATA_DIRECTORY := "res://data/gameplay"
const REQUIRED_FILES := {
	"classes": "classes.json",
	"combat": "combat.json",
	"enemies": "enemies.json",
	"equipment": "equipment.json",
	"first_rift": "first_rift.json",
	"talents": "talents.json",
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


func talents() -> Dictionary:
	return _documents["talents"]


func first_rift_floor(floor_number: int) -> Dictionary:
	for definition in first_rift()["floors"]:
		if int(definition["floor"]) == floor_number:
			return (definition as Dictionary).duplicate(true)
	return {}


func talent_definition(class_id: String, talent_id: String) -> Dictionary:
	var trees: Dictionary = talents()["trees"]
	if not trees.has(class_id):
		return {}
	for definition in trees[class_id]["nodes"]:
		if String(definition["id"]) == talent_id:
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
	assert(rift["floors"].size() >= 10, "第一裂隙必须包含 1～10 层定义。")
	for floor_number in range(1, 11):
		var floor_definition := first_rift_floor(floor_number)
		assert(not floor_definition.is_empty(), "缺少第 %d 层定义。" % floor_number)
		assert(not String(floor_definition.get("mechanic_label", "")).is_empty(),
			"第 %d 层缺少玩家可见机制名称。" % floor_number)
		assert(not String(floor_definition.get("tutorial", "")).is_empty(),
			"第 %d 层缺少教学目标。" % floor_number)
		var should_be_boss := floor_number % 5 == 0
		assert(bool(floor_definition.get("is_boss", false)) == should_be_boss,
			"第 %d 层的 Boss 标记不正确。" % floor_number)
		if not should_be_boss:
			assert(not (floor_definition.get("enemy_names", []) as Array).is_empty(),
				"第 %d 层缺少普通敌人轮换。" % floor_number)

	var loadout: Dictionary = rift["skill_loadout"]
	assert(int(loadout["equipped_slots"]) == 5, "出战技能槽必须固定为 5。")
	assert(int(loadout["initial_skill_pool_size"]) >= 6, "首版技能池至少需要 6 个技能。")
	assert(bool(loadout["skill_pool_expandable"]), "技能池必须支持后续扩展。")
	assert(bool(loadout["change_only_before_battle"]), "技能只能在战前更换。")
	assert(String(loadout["scheduler"]) == "cyclic", "技能调度必须使用循环队列。")
	assert(bool(loadout["skip_unavailable"]), "循环队列必须跳过不可用技能。")
	assert(not bool(loadout["react_to_enemy_actions"]), "技能队列不能自动读取敌方行动。")

	var potion: Dictionary = rift["potion"]
	assert(not bool(potion["in_combat_allowed"]), "战斗中禁止使用药物。")
	var economy: Dictionary = potion["economy"]
	assert(float(economy["direct_drop_chance"]) >= 0.0, "药水掉率不能为负数。")
	assert(float(economy["material_drop_chance"]) >= 0.0, "药材掉率不能为负数。")
	assert(int(economy["craft"]["material_cost"]) > 0, "制作药水必须消耗材料。")
	assert(int(economy["craft"]["gold_cost"]) >= 0, "制作金币消耗不能为负数。")
	assert(int(economy["shop"]["base_price"]) > 0, "药水商店基础价格必须大于 0。")
	assert(float(economy["shop"]["purchase_growth"]) > 0.0, "连续购买必须提高药水价格。")
	assert(float(economy["shop"]["tier_growth"]) >= 0.0, "商店阶级价格增幅不能为负数。")

	var steady_rage := talent_definition("fury_warrior", "steady_rage")
	assert(not steady_rage.is_empty(), "狂怒战士必须定义稳定怒意天赋。")
	assert(String(steady_rage["target_skill"]) == "rage_barrier", "稳定怒意必须作用于怒意壁垒。")
	assert(not bool(steady_rage["effects"]["haste_affects_cooldown"]), "稳定怒意必须移除壁垒的急速冷却收益。")
	assert(is_equal_approx(
		float(steady_rage["effects"]["haste_to_power_per_percent"]),
		0.01,
	), "稳定怒意的急速转护盾系数必须与公式一致。")

	var shield_reflow := talent_definition("fury_warrior", "shield_reflow")
	assert(is_equal_approx(
		float(shield_reflow["effects"]["barrier_first_hit_rage_refund_ratio"]),
		0.20,
	), "怒盾回流必须在壁垒首次吸收伤害时返还20%怒意。")

	var immovable := talent_definition("fury_warrior", "immovable")
	assert(is_equal_approx(
		float(immovable["effects"]["absorbed_damage_to_spender_ratio"]),
		0.40,
	), "不动如山必须把40%壁垒吸收伤害转为泄怒反击。")
	assert(is_equal_approx(
		float(immovable["effects"]["counter_attack_power_cap"]),
		1.0,
	), "不动如山反击上限必须为100%攻击强度。")
