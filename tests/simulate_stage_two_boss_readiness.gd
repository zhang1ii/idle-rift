extends SceneTree


const MainScene = preload("res://src/main/combat_prototype.tscn")
const EquipmentRules = preload("res://src/gameplay/equipment_rules.gd")

const FLOOR := 10
const RUNS_PER_BUILD := 10
const STEP := 0.10
const TIME_LIMIT := 72.0
const NORMAL_ITEM_TIER := 9
const SET_ITEM_TIER := 6
const BUILDS := [
	{"name": "血5狂2·无天赋", "sets": [["blood_mark", 5], ["frenzy_tide", 2]], "talent": ""},
	{"name": "血5狂2·刻骨裂痕", "sets": [["blood_mark", 5], ["frenzy_tide", 2]], "talent": "carved_wounds"},
	{"name": "血5狂2·沸腾血性", "sets": [["blood_mark", 5], ["frenzy_tide", 2]], "talent": "boiling_spirit"},
	{"name": "狂5血2·刻骨裂痕", "sets": [["frenzy_tide", 5], ["blood_mark", 2]], "talent": "carved_wounds"},
	{"name": "狂5血2·沸腾血性", "sets": [["frenzy_tide", 5], ["blood_mark", 2]], "talent": "boiling_spirit"},
	{"name": "血4狂4·刻骨裂痕", "sets": [["blood_mark", 4], ["frenzy_tide", 4]], "talent": "carved_wounds"},
	{"name": "铁5血2·厚重筋骨", "sets": [["iron_vow", 5], ["blood_mark", 2]], "talent": "thick_sinew"},
]


func _init() -> void:
	call_deferred("_run_simulation")


func _run_simulation() -> void:
	print("=== Stage-two farm-like loadouts vs floor 10 ===")
	print("Normal T%d rare + seven/eight T%d epic set pieces" % [NORMAL_ITEM_TIER, SET_ITEM_TIER])
	for build in BUILDS:
		await _simulate_build(build)
	quit()


func _simulate_build(build: Dictionary) -> void:
	var wins := 0
	var deaths := 0
	var collapses := 0
	var total_win_time := 0.0
	var total_win_health_ratio := 0.0
	var total_effective_g := 0.0
	for seed_value in range(RUNS_PER_BUILD):
		var game = MainScene.instantiate()
		root.add_child(game)
		await process_frame
		_configure_loadout(game, build, seed_value)
		total_effective_g += game.hero_stats.gear_tier
		game.rng.seed = 50000 + seed_value
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
	print("%-20s | win %2d/%d | avg %5.1fs | hp %5.1f%% | death %2d | collapse %2d | G%.2f" % [
		build.name,
		wins,
		RUNS_PER_BUILD,
		average_time,
		average_health,
		deaths,
		collapses,
		total_effective_g / RUNS_PER_BUILD,
	])


func _configure_loadout(game, build: Dictionary, seed_value: int) -> void:
	game.equipment_inventory.rng.seed = 60000 + seed_value
	game.equipment_inventory.seed_reference_loadout(NORMAL_ITEM_TIER, "rare")
	var armor_index := 0
	for set_entry in build.sets:
		var set_id: String = set_entry[0]
		var piece_count: int = set_entry[1]
		for _piece_index in range(piece_count):
			var slot: String = EquipmentRules.ARMOR_SLOTS[armor_index]
			game.equipment_inventory.equipped[slot] = EquipmentRules.create_set_item(
				game.equipment_inventory.rng,
				SET_ITEM_TIER,
				set_id,
				slot,
			)
			armor_index += 1
	game.defeated_boss_floors.append(5)
	if not String(build.talent).is_empty():
		game.set_talent_enabled(String(build.talent), true)
	game._apply_equipment_loadout(false)
