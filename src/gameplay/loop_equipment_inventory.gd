class_name LoopEquipmentInventory
extends "res://src/gameplay/equipment_inventory.gd"


const Effects = preload("res://src/gameplay/legendary_loop_effects.gd")


func add_item(source_item: Dictionary) -> Dictionary:
	var normalized := source_item.duplicate(true)
	Effects.assign_loop_effect(normalized, rng)
	return super.add_item(normalized)


func has_special_effect(effect_id: String) -> bool:
	for item in equipped.values():
		if String(item.get("special_effect", "")) == effect_id:
			return true
	return false


func active_loop_effect_ids() -> Array[String]:
	var result: Array[String] = []
	for item in equipped.values():
		var effect_id := String(item.get("special_effect", ""))
		if Effects.is_loop_effect(effect_id) and effect_id not in result:
			result.append(effect_id)
	return result
