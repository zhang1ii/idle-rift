extends SceneTree


const MainScene = preload("res://src/main/combat_prototype.tscn")
const EquipmentRules = preload("res://src/gameplay/equipment_rules.gd")

const FLOOR := 10
const RUNS_PER_BUILD := 5
const STEP := 0.10
const TIME_LIMIT := 72.0
const GEAR_TIERS := [6, 7]
const BUILDS := [
	{"id": "baseline", "name": "史诗散件", "sets": []},
	{"id": "blood5", "name": "血痕5", "sets": [["blood_mark", 5]]},
	{"id": "frenzy5", "name": "狂潮5", "sets": [["frenzy_tide", 5]]},
	{"id": "iron5", "name": "铁誓5", "sets": [["iron_vow", 5]]},
	{"id": "blood5_frenzy2", "name": "血痕5+狂潮2", "sets": [["blood_mark", 5], ["frenzy_tide", 2]]},
	{"id": "frenzy5_blood2", "name": "狂潮5+血痕2", "sets": [["frenzy_tide", 5], ["blood_mark", 2]]},
	{"id": "iron5_blood2", "name": "铁誓5+血痕2", "sets": [["iron_vow", 5], ["blood_mark", 2]]},
	{"id": "blood4_frenzy4", "name": "血痕4+狂潮4", "sets": [["blood_mark", 4], ["frenzy_tide", 4]]},
]


func _init() -> void:
	call_deferred("_run_simulation")


func _run_simulation() -> void:
	print("=== Floor 10 set balance (%d seeds per build) ===" % RUNS_PER_BUILD)
	for gear_tier in GEAR_TIERS:
		print("\n--- Gear tier %d ---" % gear_tier)
		for build in BUILDS:
			await _simulate_build(gear_tier, build)
	quit()


func _simulate_build(gear_tier: int, build: Dictionary) -> void:
	var wins := 0
	var deaths := 0
	var collapses := 0
	var total_win_time := 0.0
	var total_win_health_ratio := 0.0
	var total_effective_tier := 0.0
	for seed_value in range(RUNS_PER_BUILD):
		var game = MainScene.instantiate()
		root.add_child(game)
		await process_frame
		_configure_loadout(game, gear_tier, build.sets, seed_value)
		total_effective_tier += game.hero_stats.gear_tier
		game.rng.seed = 10000 + gear_tier * 100 + seed_value
		game.current_floor = FLOOR
		game._start_battle()
		var elapsed := 0.0
		while game.battle_state == game.BattleState.FIGHTING and elapsed < TIME_LIMIT:
			game._process(STEP)
			elapsed += STEP
		var won: bool = FLOOR in game.defeated_boss_floors
		if won:
			wins += 1
			total_win_time += elapsed
			total_win_health_ratio += game.hero_health / game.hero_stats.max_health()
		elif game.platforms_remaining <= 0:
			collapses += 1
		else:
			deaths += 1
		game.queue_free()
		await process_frame
	var average_time := total_win_time / wins if wins > 0 else 0.0
	var average_health := total_win_health_ratio * 100.0 / wins if wins > 0 else 0.0
	print("%-18s | win %2d/%d | avg %5.1fs | hp %5.1f%% | death %2d | collapse %2d | G%.2f" % [
		build.name,
		wins,
		RUNS_PER_BUILD,
		average_time,
		average_health,
		deaths,
		collapses,
		total_effective_tier / RUNS_PER_BUILD,
	])


func _configure_loadout(game, gear_tier: int, sets: Array, seed_value: int) -> void:
	game.equipment_inventory.rng.seed = 20000 + gear_tier * 100 + seed_value
	game.equipment_inventory.seed_reference_loadout(gear_tier, "epic")
	var armor_index := 0
	for set_entry in sets:
		var set_id: String = set_entry[0]
		var piece_count: int = set_entry[1]
		for _piece_index in range(piece_count):
			var slot: String = EquipmentRules.ARMOR_SLOTS[armor_index]
			game.equipment_inventory.equipped[slot] = EquipmentRules.create_set_item(
				game.equipment_inventory.rng,
				gear_tier,
				set_id,
				slot,
			)
			armor_index += 1
	game._apply_equipment_loadout(false)
