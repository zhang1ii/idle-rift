extends SceneTree


const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_simulation")


func _run_simulation() -> void:
	await _simulate_loadout("默认单体 + 护盾", "")
	await _simulate_loadout("AOE 替换护盾", "rage_barrier")
	await _simulate_loadout("AOE 替换回血", "dot_heal")
	quit()


func _simulate_loadout(label: String, replaced_skill: String) -> void:
	var wins := 0
	var total_win_time := 0.0
	for seed_value in 10:
		var game = MainScene.instantiate()
		root.add_child(game)
		await process_frame
		if not replaced_skill.is_empty():
			game._swap_with_reserve(game.skill_order.find(replaced_skill))
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
	print("%s: %d/10 wins, average %.1fs" % [label, wins, average])
