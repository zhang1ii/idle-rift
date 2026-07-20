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
	var initial_count: int = game.equipment_inventory.inventory.size()
	assert(initial_count == game.initial_prototype_item_count)
	assert(game.equipment_panel._inventory_buttons.size() == initial_count)

	game.equipment_inventory.add_item(EquipmentRules.create_normal_item(
		game.equipment_inventory.rng, 8, "weapon", "legendary"))
	game.equipment_inventory.add_item(EquipmentRules.create_normal_item(
		game.equipment_inventory.rng, 1, "weapon", "common"))
	game._toggle_equipment_panel()
	assert(game.equipment_panel.visible)
	assert(not game.talent_panel.visible)
	assert(game.equipment_panel._inventory_buttons.size() == initial_count + 2)

	game.equipment_panel._select_inventory_item(initial_count)
	game.equipment_panel._request_equip()
	assert(game.equipment_inventory.equipped.weapon.item_tier == 8)
	assert(game.equipment_inventory.inventory.size() == initial_count + 2)
	var gold_before: int = game.equipment_inventory.gold
	game.equipment_panel._select_inventory_item(0)
	game.equipment_panel._request_sell()
	assert(game.equipment_inventory.inventory.size() == initial_count + 1)
	assert(game.equipment_inventory.gold > gold_before)

	game._start_battle()
	game._toggle_equipment_panel()
	assert(game.equipment_panel.visible)
	assert(game.equipment_panel.locked)
	assert(game.equipment_panel._equip_button.disabled)
	assert(game.equipment_panel._sell_button.disabled)
	assert(game.sell_inventory_item(0) == 0)
	assert(game.equipment_inventory.inventory.size() == initial_count + 1)

	print("Equipment UI tests passed: showcase legendaries, 13 slots, equip, sales and battle lock.")
	quit()
