class_name LegendaryLoopEffects
extends RefCounted


const RIFT_METRONOME := "rift_metronome"
const FRACTURE_GEAR := "fracture_gear"
const BLOOD_CLOSED_LOOP := "blood_closed_loop"
const LONE_CORE := "lone_core"
const SOURCELESS_FURNACE := "sourceless_furnace"
const RIFT_FUSER := "rift_fuser"
const COUNTER_PLATING := "counter_plating"

const SCARCITY_DAMAGE_PER_UNAVAILABLE := 0.12
const SCARCITY_MAX_UNAVAILABLE := 4
const FUSION_ECHO_RATIO := 0.70
const COUNTER_ATTACK_RATIO := 0.50

const DEFINITIONS := {
	RIFT_METRONOME: {
		"name": "裂隙节拍器",
		"slot": "trinket",
		"category": "result",
		"description": "完成五格回路后，下一次攻击额外造成50%回响伤害。",
	},
	FRACTURE_GEAR: {
		"name": "断链齿轮",
		"slot": "ring",
		"category": "result",
		"description": "每次回路断裂积累1层，下一次攻击每层额外造成20%伤害，最多3层。",
	},
	BLOOD_CLOSED_LOOP: {
		"name": "血色闭环",
		"slot": "ring",
		"category": "result",
		"description": "完成五格回路时，立即结算目标剩余流血伤害的30%。",
	},
	LONE_CORE: {
		"name": "孤鸣核心",
		"slot": "ring",
		"category": "rule",
		"description": "释放攻击时，其他技能每有1个当前不可释放，伤害提高12%，最多48%。",
	},
	SOURCELESS_FURNACE: {
		"name": "无源炉心",
		"slot": "trinket",
		"category": "rule",
		"description": "五格没有攒能技能时，所有耗能技能无视资源门槛并视为满额释放。",
	},
	RIFT_FUSER: {
		"name": "裂隙熔接器",
		"slot": "ring",
		"category": "rule",
		"description": "技能格裂化时，将其70%核心效果熔接到下一次实际释放的技能。",
	},
	COUNTER_PLATING: {
		"name": "反震装甲",
		"slot": "trinket",
		"category": "rule",
		"description": "护盾覆盖碎地板时阻止技能格裂化，并使下一次攻击额外造成50%伤害。",
	},
}


static func result_ids() -> Array[String]:
	return [RIFT_METRONOME, FRACTURE_GEAR, BLOOD_CLOSED_LOOP]


static func rule_ids() -> Array[String]:
	return [LONE_CORE, SOURCELESS_FURNACE, RIFT_FUSER, COUNTER_PLATING]


static func all_ids() -> Array[String]:
	var ids := result_ids()
	ids.append_array(rule_ids())
	return ids


static func is_loop_effect(effect_id: String) -> bool:
	return DEFINITIONS.has(effect_id)


static func effect_name(effect_id: String) -> String:
	return String(DEFINITIONS.get(effect_id, {}).get("name", "未知特效"))


static func effect_description(effect_id: String) -> String:
	return String(DEFINITIONS.get(effect_id, {}).get("description", ""))


static func effect_slot(effect_id: String) -> String:
	return String(DEFINITIONS.get(effect_id, {}).get("slot", ""))


static func effect_category(effect_id: String) -> String:
	return String(DEFINITIONS.get(effect_id, {}).get("category", ""))


static func scarcity_bonus_ratio(unavailable_other_skills: int) -> float:
	return (
		clampi(unavailable_other_skills, 0, SCARCITY_MAX_UNAVAILABLE)
		* SCARCITY_DAMAGE_PER_UNAVAILABLE
	)


static func assign_loop_effect(item: Dictionary, rng: RandomNumberGenerator) -> void:
	if String(item.get("quality", "")) != "legendary":
		return
	var slot := String(item.get("slot", ""))
	if slot not in ["ring", "trinket"]:
		return
	var current := String(item.get("special_effect", ""))
	if is_loop_effect(current):
		return
	var pool: Array[String] = [
		RIFT_METRONOME,
		SOURCELESS_FURNACE,
		COUNTER_PLATING,
	] if slot == "trinket" else [
		FRACTURE_GEAR,
		BLOOD_CLOSED_LOOP,
		LONE_CORE,
		RIFT_FUSER,
	]
	item["special_effect"] = pool[rng.randi_range(0, pool.size() - 1)]
	item["effect_power"] = 1.0
