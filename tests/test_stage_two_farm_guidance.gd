extends SceneTree


const EquipmentRules = preload("res://src/gameplay/equipment_rules.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame

	assert(game._stage_two_farm_guidance().is_empty())
	game.defeated_boss_floors.append(5)
	assert("第 5 层" in game._stage_two_farm_guidance())
	assert(not game._offense_mixed_set_ready())

	for index in 4:
		var slot: String = EquipmentRules.ARMOR_SLOTS[index]
		game.equipment_inventory.equipped[slot] = EquipmentRules.create_set_item(
			game.equipment_inventory.rng,
			6,
			"blood_mark",
			slot,
		)
	for index in range(5, 7):
		var slot: String = EquipmentRules.ARMOR_SLOTS[index]
		game.equipment_inventory.equipped[slot] = EquipmentRules.create_set_item(
			game.equipment_inventory.rng,
			6,
			"frenzy_tide",
			slot,
		)
	game._apply_equipment_loadout(false)
	assert(not game._offense_mixed_set_ready())
	assert("第 5 层" in game._stage_two_farm_guidance())

	var finishing_slot: String = EquipmentRules.ARMOR_SLOTS[4]
	game.equipment_inventory.add_item(EquipmentRules.create_set_item(
		game.equipment_inventory.rng,
		6,
		"blood_mark",
		finishing_slot,
	))
	assert(game.equip_inventory_item(
		game.equipment_inventory.inventory.size() - 1,
		finishing_slot,
	))
	assert(game._offense_mixed_set_ready())
	assert("第 9 层" in game._stage_two_farm_guidance())
	assert("第 9 层" in game.battle_event.text)
	assert("构筑建议" in game.run_summary.text)

	game.defeated_boss_floors.append(10)
	game._refresh_all_ui()
	assert(game._stage_two_farm_guidance().is_empty())
	assert("构筑建议" not in game.run_summary.text)

	print("Stage two guidance tests passed: floor 5 farming, offense 5+2 completion and floor 9 transition.")
	quit()
