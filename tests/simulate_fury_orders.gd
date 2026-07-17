extends SceneTree


const MainScene = preload("res://src/main/combat_prototype.tscn")

const LOADOUT_ORDERS := [
	["rage_barrier", "rage_builder", "fury_burst", "dot_heal", "single_spender"],
	["rage_builder", "rage_barrier", "fury_burst", "dot_heal", "single_spender"],
	["rage_builder", "fury_burst", "rage_barrier", "dot_heal", "single_spender"],
	["rage_builder", "fury_burst", "dot_heal", "rage_barrier", "single_spender"],
	["rage_builder", "fury_burst", "dot_heal", "single_spender", "rage_barrier"],
]


func _init() -> void:
	call_deferred("_run_simulation")


func _run_simulation() -> void:
	for order_index in LOADOUT_ORDERS.size():
		await _simulate_order(order_index, LOADOUT_ORDERS[order_index])
	quit()


func _simulate_order(order_index: int, order: Array) -> void:
	var wins := 0
	var total_win_time := 0.0
	for seed_value in range(20):
		var game = MainScene.instantiate()
		root.add_child(game)
		await process_frame
		game.hero_stats.apply_reference_gear_tier(3.0)
		game.skill_order.assign(order)
		game._reset_skill_cooldowns()
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
	print("G3 barrier slot %d | wins %d/20 | avg %.1fs" % [
		order_index + 1, wins, average,
	])
