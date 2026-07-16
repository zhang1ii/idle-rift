extends "res://src/main/fury_combat_controller.gd"


const EquipmentInventoryModel = preload("res://src/gameplay/equipment_inventory.gd")

var equipment_inventory = EquipmentInventoryModel.new()
var last_dropped_item: Dictionary = {}


func _ready() -> void:
	super._ready()
	equipment_inventory.rng.randomize()
	print("Idle Rift equipment drops and backpack model loaded.")


func _resolve_enemy_defeat() -> void:
	if enemy_health > 0.0:
		return
	if Rules.is_boss_floor(current_floor):
		var first_clear := current_floor not in defeated_boss_floors
		last_dropped_item = equipment_inventory.grant_boss_drop(current_floor, first_clear)
		_on_boss_defeated()
		battle_event.text += " 获得：%s。" % EquipmentInventoryModel.Rules.item_display_name(last_dropped_item)
		loot_count += 1
		return
	ordinary_kills += 1
	last_dropped_item = equipment_inventory.roll_normal_drop(current_floor)
	respawn_timer = NORMAL_RESPAWN_DELAY
	enemy_name.text = "正在寻找下一名敌人……"
	if last_dropped_item.is_empty():
		battle_event.text = "击杀完成，本次没有装备掉落。"
		return
	loot_count += 1
	var upgrade_mark := " · 可能提升" if equipment_inventory.is_potential_upgrade(last_dropped_item) else ""
	battle_event.text = "装备掉落：%s%s" % [
		EquipmentInventoryModel.Rules.item_display_name(last_dropped_item),
		upgrade_mark,
	]
