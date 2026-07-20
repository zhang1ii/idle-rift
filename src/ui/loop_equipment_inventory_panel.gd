class_name LoopEquipmentInventoryPanel
extends "res://src/ui/equipment_inventory_panel.gd"


const Effects = preload("res://src/gameplay/legendary_loop_effects.gd")


func _item_detail(item: Dictionary) -> String:
	var detail := super._item_detail(item)
	var effect_id := String(item.get("special_effect", ""))
	if not Effects.is_loop_effect(effect_id):
		return detail
	return "%s\n传奇特效【%s】：%s" % [
		detail,
		Effects.effect_name(effect_id),
		Effects.effect_description(effect_id),
	]
