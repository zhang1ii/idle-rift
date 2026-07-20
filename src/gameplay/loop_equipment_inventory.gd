class_name LoopEquipmentInventory
extends "res://src/gameplay/equipment_inventory.gd"


const Effects = preload("res://src/gameplay/legendary_loop_effects.gd")
const WEAK_EFFECT_POWER := 0.70
const WEAK_EFFECT_TOKEN_COST := 12

var discovered_effect_ids: Array[String] = []
var special_effects_unlocked := false



func add_item(source_item: Dictionary) -> Dictionary:
	var normalized := source_item.duplicate(true)
	if special_effects_unlocked:
		Effects.assign_loop_effect(normalized, rng)
	else:
		normalized["special_effect"] = ""
		normalized["effect_power"] = 0.0
	var effect_id := String(normalized.get("special_effect", ""))
	if Effects.is_loop_effect(effect_id) and effect_id not in discovered_effect_ids:
		discovered_effect_ids.append(effect_id)
	return super.add_item(normalized)


func has_special_effect(effect_id: String) -> bool:
	for item in equipped.values():
		if String(item.get("special_effect", "")) == effect_id:
			return true
	return false

func special_effect_power(effect_id: String) -> float:
	var power := 0.0
	for item in equipped.values():
		if String(item.get("special_effect", "")) == effect_id:
			power = maxf(power, float(item.get("effect_power", 1.0)))
	return power

func exchange_weakened_effect(effect_id: String, item_tier: int) -> Dictionary:
	if not Effects.is_loop_effect(effect_id) or effect_id not in discovered_effect_ids:
		return {}
	if not wallet.spend_tokens(WEAK_EFFECT_TOKEN_COST):
		return {}
	var item := Rules.create_normal_item(
		rng,
		maxi(1, item_tier),
		Effects.effect_slot(effect_id),
		"epic",
	)
	item["special_effect"] = effect_id
	item["effect_power"] = WEAK_EFFECT_POWER
	return add_item(item)


func active_loop_effect_ids() -> Array[String]:
	var result: Array[String] = []
	for item in equipped.values():
		var effect_id := String(item.get("special_effect", ""))
		if Effects.is_loop_effect(effect_id) and effect_id not in result:
			result.append(effect_id)
	return result
