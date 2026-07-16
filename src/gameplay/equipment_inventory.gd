class_name EquipmentInventory
extends RefCounted


const Rules = preload("res://src/gameplay/equipment_rules.gd")

const NORMAL_CRAFT_BASE_COST := 30
const SET_CRAFT_BASE_COST := 80

var rng := RandomNumberGenerator.new()
var inventory: Array[Dictionary] = []
var equipped: Dictionary = {}
var materials := 0
var next_instance_id := 1
var total_drops := 0


func _init() -> void:
	rng.randomize()


func roll_normal_drop(floor_number: int, offline := false) -> Dictionary:
	var chance := Rules.ONLINE_DROP_CHANCE
	if offline:
		chance *= Rules.OFFLINE_EFFICIENCY
	if rng.randf() >= chance:
		return {}
	var item_tier := maxi(1, floor_number)
	var item := Rules.create_normal_item(rng, item_tier)
	return add_item(item)


func grant_boss_drop(floor_number: int, first_clear: bool) -> Dictionary:
	var item_tier := maxi(1, floor_number + 1)
	var item: Dictionary
	if first_clear or rng.randf() < Rules.REPEAT_BOSS_SET_CHANCE:
		var set_ids := Rules.SET_DEFINITIONS.keys()
		var set_id: String = set_ids[rng.randi_range(0, set_ids.size() - 1)]
		item = Rules.create_set_item(rng, item_tier, set_id)
	else:
		item = Rules.create_normal_item(rng, item_tier, "", "epic")
	return add_item(item)


func add_item(source_item: Dictionary) -> Dictionary:
	var item := source_item.duplicate(true)
	item.instance_id = next_instance_id
	next_instance_id += 1
	inventory.append(item)
	total_drops += 1
	return item


func potential_upgrade_targets(item: Dictionary) -> Array[String]:
	var upgrades: Array[String] = []
	for target in Rules.valid_targets(item.slot):
		if not equipped.has(target):
			upgrades.append(target)
			continue
		if Rules.item_score(item) > Rules.item_score(equipped[target]) + 0.001:
			upgrades.append(target)
	return upgrades


func is_potential_upgrade(item: Dictionary) -> bool:
	return not potential_upgrade_targets(item).is_empty()


func equip_inventory_item(index: int, requested_target := "") -> bool:
	if index < 0 or index >= inventory.size():
		return false
	var item: Dictionary = inventory[index]
	var valid_targets := Rules.valid_targets(item.slot)
	var target := requested_target
	if target.is_empty():
		target = _best_target_for(item)
	if target not in valid_targets:
		return false
	inventory.remove_at(index)
	if equipped.has(target):
		inventory.append(equipped[target])
	equipped[target] = item
	return true


func equip_newest_if_upgrade() -> bool:
	if inventory.is_empty():
		return false
	var index := inventory.size() - 1
	if not is_potential_upgrade(inventory[index]):
		return false
	return equip_inventory_item(index)


func dismantle_inventory_item(index: int) -> int:
	if index < 0 or index >= inventory.size():
		return 0
	var item: Dictionary = inventory[index]
	var gained := dismantle_value(item)
	materials += gained
	inventory.remove_at(index)
	return gained


func dismantle_value(item: Dictionary) -> int:
	var base_value: int = Rules.QUALITY_DATA[item.quality].material
	return base_value + ceili(float(item.item_tier) * 0.5)


func dismantle_non_upgrades() -> int:
	var gained := 0
	for index in range(inventory.size() - 1, -1, -1):
		if not is_potential_upgrade(inventory[index]):
			gained += dismantle_inventory_item(index)
	return gained


func normal_craft_cost(item_tier: int) -> int:
	return NORMAL_CRAFT_BASE_COST + maxi(0, item_tier) * 2


func set_craft_cost(item_tier: int) -> int:
	return SET_CRAFT_BASE_COST + maxi(0, item_tier) * 4


func craft_normal_item(slot_id: String, item_tier: int) -> Dictionary:
	if slot_id not in Rules.EQUIPMENT_TARGETS:
		return {}
	var cost := normal_craft_cost(item_tier)
	if materials < cost:
		return {}
	materials -= cost
	return add_item(Rules.create_normal_item(rng, item_tier, slot_id, "rare"))


func craft_set_item(slot_id: String, item_tier: int, set_id: String) -> Dictionary:
	if slot_id not in Rules.ARMOR_SLOTS or not Rules.SET_DEFINITIONS.has(set_id):
		return {}
	var cost := set_craft_cost(item_tier)
	if materials < cost:
		return {}
	materials -= cost
	return add_item(Rules.create_set_item(rng, item_tier, set_id, true, slot_id))


func seed_reference_loadout(item_tier: int, quality := "rare") -> void:
	equipped.clear()
	for target in Rules.EQUIPMENT_TARGETS:
		var item := Rules.create_normal_item(rng, item_tier, target, quality)
		item.instance_id = next_instance_id
		next_instance_id += 1
		equipped[target] = item


func average_item_tier() -> float:
	if equipped.is_empty():
		return 0.0
	var total := 0.0
	for item in equipped.values():
		total += float(item.item_tier)
	return total / Rules.EQUIPMENT_TARGETS.size()


func total_equipment_stats() -> Dictionary:
	var totals := {
		"primary": 0.0,
		"stamina": 0.0,
		"mastery": 0.0,
		"haste": 0.0,
		"critical_strike": 0.0,
		"versatility": 0.0,
	}
	for item in equipped.values():
		totals.primary += float(item.primary)
		totals.stamina += float(item.stamina)
		for affix_id in item.affixes:
			totals[affix_id] += float(item.affixes[affix_id])
	return totals


func active_set_bonuses() -> Array[Dictionary]:
	return Rules.active_set_bonuses(equipped)


func weakest_target() -> String:
	for target in Rules.EQUIPMENT_TARGETS:
		if not equipped.has(target):
			return target
	var weakest := Rules.EQUIPMENT_TARGETS[0]
	var weakest_score := Rules.item_score(equipped[weakest])
	for target in Rules.EQUIPMENT_TARGETS:
		var score := Rules.item_score(equipped[target])
		if score < weakest_score:
			weakest = target
			weakest_score = score
	return weakest


func _best_target_for(item: Dictionary) -> String:
	var valid_targets := Rules.valid_targets(item.slot)
	for target in valid_targets:
		if not equipped.has(target):
			return target
	var weakest := valid_targets[0]
	var weakest_score := Rules.item_score(equipped[weakest])
	for target in valid_targets:
		var score := Rules.item_score(equipped[target])
		if score < weakest_score:
			weakest = target
			weakest_score = score
	return weakest
