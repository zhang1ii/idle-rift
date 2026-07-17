extends SceneTree


const MainScene = preload("res://src/main/main.tscn")


func _init() -> void:
	call_deferred("_run_simulation")


func _run_simulation() -> void:
	var wins := 0
	var total_win_time := 0.0
	for seed_value in 10:
		var game = MainScene.instantiate()
		root.add_child(game)
		await process_frame
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
		print("Seed %d: %s at %.1fs" % [
			seed_value,
			"WIN" if won else "FAIL",
			elapsed,
		])
		game.queue_free()
		await process_frame
	var average := total_win_time / wins if wins > 0 else 0.0
	print("Fury balance: %d/10 wins, average win time %.1fs" % [wins, average])
	quit()
