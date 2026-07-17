extends SceneTree


const FuryRules = preload("res://src/gameplay/fury_rules.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_simulation")


func _run_simulation() -> void:
	for gear_tier in [2.0, 3.0, 4.0]:
		await _simulate(gear_tier, false)
		await _simulate(gear_tier, true)
	quit()


func _simulate(gear_tier: float, talent_enabled: bool) -> void:
	var wins := 0
	var total_win_time := 0.0
	for seed_value in range(20):
		var game = MainScene.instantiate()
		root.add_child(game)
		await process_frame
		game.hero_stats.apply_reference_gear_tier(gear_tier)
		assert(game.set_talent_enabled(
			FuryRules.STEADY_RAGE_TALENT_ID,
			talent_enabled,
		))
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
	print("G%.0f | steady rage %s | wins %d/20 | avg %.1fs" % [
		gear_tier,
		"ON" if talent_enabled else "OFF",
		wins,
		average,
	])
