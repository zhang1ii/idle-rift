extends SceneTree


const FuryRules = preload("res://src/gameplay/fury_rules.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")

const BUILDS := [
	{"label": "none", "talents": []},
	{"label": "steady", "talents": [FuryRules.STEADY_RAGE_TALENT_ID]},
	{"label": "full_guard", "talents": FuryRules.GUARD_TALENT_IDS},
	{"label": "full_fury", "talents": FuryRules.FURY_TALENT_IDS},
]


func _init() -> void:
	call_deferred("_run_simulation")


func _run_simulation() -> void:
	for gear_tier in [2.0, 3.0, 4.0]:
		for build in BUILDS:
			await _simulate(gear_tier, build)
	quit()


func _simulate(gear_tier: float, build: Dictionary) -> void:
	var wins := 0
	var total_win_time := 0.0
	for seed_value in range(20):
		var game = MainScene.instantiate()
		root.add_child(game)
		await process_frame
		game.hero_stats.apply_reference_gear_tier(gear_tier)
		for talent_id in build["talents"]:
			assert(game.set_talent_enabled(String(talent_id), true))
		game.rng.seed = seed_value
		game.current_floor = 5
		game._start_battle()
		var elapsed := 0.0
		while game.battle_state == game.BattleState.FIGHTING and elapsed < 90.0:
			game._process(0.05)
			elapsed += 0.05
		if game.highest_unlocked_floor >= 10:
			wins += 1
			total_win_time += elapsed
		game.queue_free()
		await process_frame
	var average := total_win_time / wins if wins > 0 else 0.0
	print("Talent balance | G%.0f | %s | wins %d/20 | avg %.1fs" % [
		gear_tier,
		String(build["label"]),
		wins,
		average,
	])
