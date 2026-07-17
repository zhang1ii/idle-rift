extends SceneTree


const MainScene = preload("res://src/main/combat_prototype.tscn")
const Progression = preload("res://src/gameplay/progression_model.gd")


func _init() -> void:
	call_deferred("_run_simulation")


func _run_simulation() -> void:
	for gear_tier in range(0, 5):
		await _simulate_tier(float(gear_tier))
	quit()


func _simulate_tier(gear_tier: float) -> void:
	var wins := 0
	var total_win_time := 0.0
	var total_end_time := 0.0
	for seed_value in range(20):
		var game = MainScene.instantiate()
		root.add_child(game)
		await process_frame
		game.hero_stats.apply_reference_gear_tier(gear_tier)
		game.rng.seed = seed_value
		game.current_floor = 5
		game._start_battle()
		var elapsed := 0.0
		while game.battle_state == game.BattleState.FIGHTING and elapsed < 90.0:
			game._process(0.05)
			elapsed += 0.05
		var won: bool = game.highest_unlocked_floor >= 10
		if won:
			wins += 1
			total_win_time += elapsed
		total_end_time += elapsed
		game.queue_free()
		await process_frame
	var average_win := total_win_time / wins if wins > 0 else 0.0
	var average_end := total_end_time / 20.0
	print("Tier %.0f | gap %.0f | %s | wins %d/20 | avg win %.1fs | avg end %.1fs" % [
		gear_tier,
		Progression.gear_gap(5, gear_tier),
		Progression.boss_readiness(5, gear_tier),
		wins,
		average_win,
		average_end,
	])
