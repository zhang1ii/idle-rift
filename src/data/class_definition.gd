class_name ClassDefinition
extends RefCounted

const DEFINITIONS := {
	&"iron_vow": {
		"name": "铁誓卫",
		"fantasy": "格挡、反击、积累守势后发动盾击",
		"resource": "守势",
		"accent": Color("5f9eaa"),
	},
	&"ember_blade": {
		"name": "烬刃客",
		"fantasy": "高速连击、暴击、流血与击杀加速",
		"resource": "杀意",
		"accent": Color("bd5a43"),
	},
	&"rift_chanter": {
		"name": "裂隙咏者",
		"fantasy": "元素循环、共鸣积累与范围法术",
		"resource": "共鸣",
		"accent": Color("766ec5"),
	},
	&"ash_shepherd": {
		"name": "灰烬牧灵",
		"fantasy": "收集残魂、召唤随从与死亡触发",
		"resource": "残魂",
		"accent": Color("61a884"),
	},
}


static func get_definition(class_id: StringName) -> Dictionary:
	return DEFINITIONS.get(class_id, DEFINITIONS[&"iron_vow"])


static func all_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for class_id in DEFINITIONS:
		result.append(class_id)
	return result
