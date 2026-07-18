extends SceneTree


const FuryRules = preload("res://src/gameplay/fury_rules.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame

	var base_health: float = game.hero_stats.max_health()
	assert(game.set_talent_enabled(FuryRules.THICK_SINEW_TALENT_ID, true))
	assert(is_equal_approx(game.hero_stats.max_health(), base_health * 1.08))
	assert(game.set_talent_enabled(FuryRules.STEADY_RAGE_TALENT_ID, true))
	assert(game.set_talent_enabled(FuryRules.SHIELD_REFLOW_TALENT_ID, true))
	assert(game.set_talent_enabled(FuryRules.IMMOVABLE_TALENT_ID, true))

	game.current_floor = 1
	game._start_battle()
	assert(is_equal_approx(game.hero_health, game.hero_stats.max_health()))
	game.hero_stats.critical_strike = 0.0

	game.hero_resource = 80.0
	game.hero_shield = game.hero_stats.max_health() - 10.0
	game.burst_skills_remaining = 2
	game._cast_fury_skill(
		"rage_barrier",
		FuryRules.skill_catalog()["rage_barrier"],
		0,
	)
	assert(is_equal_approx(game.hero_shield, game.hero_stats.max_health()))
	assert(is_equal_approx(game.barrier_refund_pending, 16.0))
	assert(game.burst_skills_remaining == 2)

	game.hero_resource = 0.0
	game._take_hero_damage(50.0, "测试重击")
	assert(is_equal_approx(game.hero_resource, 16.0))
	assert(is_equal_approx(game.barrier_refund_pending, 0.0))
	var expected_counter := FuryRules.immovable_counter_damage(
		50.0 * game.hero_stats.damage_taken_multiplier(),
		game.hero_stats.attack_power(),
	)
	assert(is_equal_approx(game.immovable_counter_stored, expected_counter))

	game._take_hero_damage(10.0, "测试追击")
	assert(is_equal_approx(game.hero_resource, 16.0))
	expected_counter = minf(
		game.hero_stats.attack_power() * FuryRules.IMMOVABLE_ATTACK_POWER_CAP,
		expected_counter + FuryRules.immovable_counter_damage(
			10.0 * game.hero_stats.damage_taken_multiplier(),
			game.hero_stats.attack_power(),
		),
	)
	assert(is_equal_approx(game.immovable_counter_stored, expected_counter))

	game.hero_resource = 100.0
	game.enemy_health = 1000.0
	game.enemy_max_health = 1000.0
	var health_before: float = game.enemy_health
	var base_spender_damage: float = (
		game.hero_stats.attack_power()
		* float(FuryRules.skill_catalog()["single_spender"]["damage_multiplier"])
		* game.hero_stats.outgoing_multiplier()
		* FuryRules.mastery_damage_multiplier(game.hero_stats.mastery)
	)
	game._cast_fury_skill(
		"single_spender",
		FuryRules.skill_catalog()["single_spender"],
		0,
	)
	assert(is_equal_approx(
		health_before - game.enemy_health,
		base_spender_damage + expected_counter,
	))
	assert(is_equal_approx(game.immovable_counter_stored, 0.0))

	game._return_to_preparation("测试结束")
	assert(game.set_talent_enabled(FuryRules.THICK_SINEW_TALENT_ID, false))
	print("Guard talent tests passed: health, shield cap, rage reflow and counter damage.")
	quit()
