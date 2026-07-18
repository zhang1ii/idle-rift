extends SceneTree


const FuryRules = preload("res://src/gameplay/fury_rules.gd")
const Repository = preload("res://src/data/game_data_repository.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var talent := Repository.new().talent_definition("fury_warrior", "steady_rage")
	assert(talent.id == FuryRules.STEADY_RAGE_TALENT_ID)
	assert(is_equal_approx(
		FuryRules.steady_rage_power_multiplier(20.0),
		1.20,
	))
	assert(is_equal_approx(
		FuryRules.barrier_amount(80.0, 20.0, true),
		115.20,
	))
	assert(is_equal_approx(
		FuryRules.cooldown_recovery_multiplier("rage_barrier", 20.0, true),
		1.0,
	))
	assert(is_equal_approx(
		FuryRules.cooldown_recovery_multiplier("rage_builder", 20.0, true),
		1.2,
	))

	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.set_talent_enabled(FuryRules.STEADY_RAGE_TALENT_ID, true))
	game.current_floor = 5
	game._start_battle()
	assert(not game.set_talent_enabled(FuryRules.STEADY_RAGE_TALENT_ID, false))

	game.skill_cooldowns["rage_barrier"] = 12.0
	game.skill_cooldowns["rage_builder"] = 4.0
	game._tick_skill_cooldowns(1.0)
	assert(is_equal_approx(game.skill_cooldowns["rage_barrier"], 11.0))
	assert(is_equal_approx(game.skill_cooldowns["rage_builder"], 2.8))

	game.hero_resource = 80.0
	game.skill_cooldowns["rage_barrier"] = 0.0
	game.skill_cursor = game.skill_order.find("rage_barrier")
	game._hero_take_action()
	assert(is_equal_approx(game.hero_shield, 115.20))
	assert(game.hero_resource == 0.0)
	print("Steady Rage tests passed: prebattle talent, fixed cooldown and haste-to-shield conversion.")
	quit()
