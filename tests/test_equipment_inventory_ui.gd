extends SceneTree


const EquipmentRules = preload("res://src/gameplay/equipment_rules.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.equipment_panel != null)
	assert(game.equipment_panel._equipped_buttons.size() == 13)
	assert(game.equipment_panel._inventory_buttons.is_empty())

	game.equipment_inventory.add_item(EquipmentRules.create_normal_item(
		game.equipment_inventory.rng, 8, "weapon", "legendary"))
	game.equipment_inventory.add_item(EquipmentRules.create_normal_item(
		game.equipment_inventory.rng, 1, "weapon", "common"))
	game._toggle_equipment_panel()
	assert(game.equipment_panel.visible)
	assert(not game.talent_panel.visible)
	assert(game.equipment_panel._inventory_buttons.size() == 2)

	game.equipment_panel._select_inventory_item(0)
	game.equipment_panel._request_equip()
	assert(game.equipment_inventory.equipped.weapon.item_tier == 8)
	assert(game.equipment_inventory.inventory.size() == 2)
	var gold_before: int = game.equipment_inventory.gold
	game.equipment_panel._select_inventory_item(0)
	game.equipment_panel._request_sell()
	assert(game.equipment_inventory.inventory.size() == 1)
	assert(game.equipment_inventory.gold > gold_before)

	game._start_battle()
	game._toggle_equipment_panel()
	assert(game.equipment_panel.visible)
	assert(game.equipment_panel.locked)
	assert(game.equipment_panel._equip_button.disabled)
	assert(game.equipment_panel._sell_button.disabled)
	assert(game.sell_inventory_item(0) == 0)
	assert(game.equipment_inventory.inventory.size() == 1)

	print("Equipment UI tests passed: 13 slots, equip, sales, exclusive panels and battle lock.")
	quit()
