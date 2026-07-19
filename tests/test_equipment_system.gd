extends SceneTree


const Progression = preload("res://src/gameplay/progression_model.gd")
const Rules = preload("res://src/gameplay/equipment_rules.gd")
const Inventory = preload("res://src/gameplay/equipment_inventory.gd")


func _init() -> void:
	var total_primary := 0.0
	var total_stamina := 0.0
	var total_secondary := 0.0
	for target in Rules.EQUIPMENT_TARGETS:
		var budget := Rules.item_budget(4, target)
		total_primary += budget.primary
		total_stamina += budget.stamina
		total_secondary += budget.secondary
	var expected := Progression.full_loadout_budget(4.0)
	assert(is_equal_approx(total_primary, expected.primary))
	assert(is_equal_approx(total_stamina, expected.stamina))
	assert(is_equal_approx(total_secondary, expected.secondary))

	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var white := Rules.create_normal_item(rng, 4, "head", "common")
	var rare := Rules.create_normal_item(rng, 4, "head", "rare")
	assert(white.affixes.is_empty())
	assert(rare.affixes.size() == 2)
	assert(rare.primary > white.primary)

	var inventory = Inventory.new()
	inventory.rng.seed = 23
	inventory.seed_reference_loadout(1, "rare")
	assert(inventory.equipped.size() == 13)
	assert(is_equal_approx(inventory.average_item_tier(), 1.0))
	var upgrade := inventory.add_item(Rules.create_normal_item(inventory.rng, 4, "weapon", "rare"))
	assert(inventory.is_potential_upgrade(upgrade))
	assert(inventory.equip_newest_if_upgrade())
	assert(inventory.equipped.weapon.item_tier == 4)
	var junk := inventory.add_item(Rules.create_normal_item(inventory.rng, 1, "weapon", "common"))
	assert(not inventory.is_potential_upgrade(junk))
	var gold_before: int = inventory.gold
	var sale_value := inventory.sell_inventory_item(inventory.inventory.size() - 1)
	assert(sale_value > 0)
	assert(inventory.gold == gold_before + sale_value)

	var loadout := {}
	for index in range(5):
		var slot: String = Rules.ARMOR_SLOTS[index]
		loadout[slot] = Rules.create_set_item(rng, 6, "bloodrage", slot)
	for index in range(5, 7):
		var slot: String = Rules.ARMOR_SLOTS[index]
		loadout[slot] = Rules.create_set_item(rng, 6, "iron_vow", slot)
	var bonuses := Rules.active_set_bonuses(loadout)
	assert(bonuses.size() == 4)
	assert(_has_bonus(bonuses, "bloodrage", 2))
	assert(_has_bonus(bonuses, "bloodrage", 4))
	assert(_has_bonus(bonuses, "bloodrage", 5))
	assert(_has_bonus(bonuses, "iron_vow", 2))
	var five_piece := _find_bonus(bonuses, "bloodrage", 5)
	assert(is_equal_approx(five_piece.power, Rules.SET_POWER))
	print("Equipment tests passed: 13 slots, qualities, backpack sales, drop-only items, and 2/4/5 sets.")
	quit()


func _has_bonus(bonuses: Array[Dictionary], set_id: String, threshold: int) -> bool:
	return not _find_bonus(bonuses, set_id, threshold).is_empty()


func _find_bonus(bonuses: Array[Dictionary], set_id: String, threshold: int) -> Dictionary:
	for bonus in bonuses:
		if bonus.set_id == set_id and bonus.threshold == threshold:
			return bonus
	return {}
