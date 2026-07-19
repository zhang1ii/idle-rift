extends SceneTree


const Inventory = preload("res://src/gameplay/equipment_inventory.gd")
const Evaluator = preload("res://src/gameplay/equipment_evaluator.gd")

const SAMPLE_COUNT := 300
const FARM_SECONDS := 2.0 * 60.0 * 60.0
const SECONDS_PER_KILL := 4.65
const FARM_FLOOR := 4


func _init() -> void:
	_simulate_mode(false)
	_simulate_mode(true)
	quit()


func _simulate_mode(offline: bool) -> void:
	var kills := floori(FARM_SECONDS / SECONDS_PER_KILL)
	var total_world_drops := 0.0
	var total_gold := 0.0
	var total_raw_tier := 0.0
	var total_power_tier := 0.0
	var ready_count := 0
	var strong_count := 0
	for sample in range(SAMPLE_COUNT):
		var inventory = Inventory.new()
		inventory.rng.seed = 1000 + sample
		inventory.seed_reference_loadout(1, "rare")
		var world_drops := 0
		for ignored_kill in range(kills):
			var item := inventory.roll_normal_drop(FARM_FLOOR, offline)
			if item.is_empty():
				continue
			world_drops += 1
			if inventory.is_potential_upgrade(item):
				inventory.equip_newest_if_upgrade()
			inventory.sell_non_upgrades()
		var power_tier := Evaluator.average_power_tier(inventory.equipped)
		total_world_drops += world_drops
		total_gold += inventory.gold
		total_raw_tier += inventory.average_item_tier()
		total_power_tier += power_tier
		if power_tier >= 3.0:
			ready_count += 1
		if power_tier >= 3.5:
			strong_count += 1
	print("%s 2h | world drops %.1f | sale gold %.1f | raw G %.2f | effective G %.2f | G>=3 %.1f%% | G>=3.5 %.1f%%" % [
		"Offline" if offline else "Online",
		total_world_drops / SAMPLE_COUNT,
		total_gold / SAMPLE_COUNT,
		total_raw_tier / SAMPLE_COUNT,
		total_power_tier / SAMPLE_COUNT,
		100.0 * ready_count / SAMPLE_COUNT,
		100.0 * strong_count / SAMPLE_COUNT,
	])
