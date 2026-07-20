extends SceneTree


const EquipmentRules = preload("res://src/gameplay/equipment_rules.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")
const Progression = preload("res://src/gameplay/progression_model.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.equipment_inventory.equipped.size() == 13)
	var initial_inventory_count: int = game.equipment_inventory.inventory.size()
	assert(initial_inventory_count == game.initial_prototype_item_count)
	var totals: Dictionary = game.equipment_inventory.total_equipment_stats()
	assert(is_equal_approx(
		game.hero_stats.strength,
		Progression.BASE_STRENGTH + float(totals.primary),
	))
	assert(is_equal_approx(
		game.hero_stats.stamina,
		Progression.BASE_STAMINA + float(totals.stamina),
	))
	assert(is_equal_approx(
		game.hero_stats.mastery,
		Progression.BASE_MASTERY + float(totals.mastery),
	))

	game.hero_health = game.hero_stats.max_health() * 0.55
	var old_max_health: float = game.hero_stats.max_health()
	var old_attack_power: float = game.hero_stats.attack_power()
	var upgrade := EquipmentRules.create_normal_item(
		game.equipment_inventory.rng,
		8,
		"weapon",
		"legendary",
	)
	game.equipment_inventory.add_item(upgrade)
	assert(game.equip_inventory_item(game.equipment_inventory.inventory.size() - 1, "weapon"))
	assert(game.hero_stats.attack_power() > old_attack_power)
	assert(game.hero_stats.max_health() > old_max_health)
	assert(is_equal_approx(
		game.hero_health / game.hero_stats.max_health(),
		0.55,
	))
	assert(game.equipment_inventory.inventory.size() == initial_inventory_count + 1)

	game._start_battle()
	game.equipment_inventory.add_item(EquipmentRules.create_normal_item(
		game.equipment_inventory.rng,
		9,
		"head",
		"legendary",
	))
	assert(not game.equip_inventory_item(game.equipment_inventory.inventory.size() - 1))
	assert(game.equipment_inventory.equipped.weapon.item_tier == 8)

	print("Equipment combat stats tests passed: real items, loop showcases, stat rebuild, health ratio and battle lock.")
	quit()
