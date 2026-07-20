class_name LegendaryLoopEffects
extends RefCounted


const RIFT_METRONOME := "rift_metronome"
const FRACTURE_GEAR := "fracture_gear"
const BLOOD_CLOSED_LOOP := "blood_closed_loop"

const DEFINITIONS := {
	RIFT_METRONOME: {
		"name": "裂隙节拍器",
		"slot": "trinket",
		"description": "完成五格回路后，下一次攻击额外造成50%回响伤害。",
	},
	FRACTURE_GEAR: {
		"name": "断链齿轮",
		"slot": "ring",
		"description": "每次回路断裂积累1层，下一次攻击每层额外造成20%伤害，最多3层。",
	},
	BLOOD_CLOSED_LOOP: {
		"name": "血色闭环",
		"slot": "ring",
		"description": "完成五格回路时，立即结算目标剩余流血伤害的30%。",
	},
}


static func all_ids() -> Array[String]:
	return [RIFT_METRONOME, FRACTURE_GEAR, BLOOD_CLOSED_LOOP]


static func is_loop_effect(effect_id: String) -> bool:
	return DEFINITIONS.has(effect_id)


static func effect_name(effect_id: String) -> String:
	return String(DEFINITIONS.get(effect_id, {}).get("name", "未知特效"))


static func effect_description(effect_id: String) -> String:
	return String(DEFINITIONS.get(effect_id, {}).get("description", ""))


static func effect_slot(effect_id: String) -> String:
	return String(DEFINITIONS.get(effect_id, {}).get("slot", ""))


static func assign_loop_effect(item: Dictionary, rng: RandomNumberGenerator) -> void:
	if String(item.get("quality", "")) != "legendary":
		return
	var slot := String(item.get("slot", ""))
	if slot not in ["ring", "trinket"]:
		return
	var current := String(item.get("special_effect", ""))
	if is_loop_effect(current):
		return
	var pool: Array[String] = [RIFT_METRONOME] if slot == "trinket" else [
		FRACTURE_GEAR,
		BLOOD_CLOSED_LOOP,
	]
	item["special_effect"] = pool[rng.randi_range(0, pool.size() - 1)]
