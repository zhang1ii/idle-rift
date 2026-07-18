extends SceneTree


const FuryRules = preload("res://src/gameplay/fury_rules.gd")
const Repository = preload("res://src/data/game_data_repository.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var talent := Repository.new().talent_definition(
		"fury_warrior",
		FuryRules.BOILING_SPIRIT_TALENT_ID,
	)
	assert(is_equal_approx(
		float(talent["effects"]["builder_flat_rage_bonus"]),
		5.0,
	))
	assert(is_equal_approx(
		FuryRules.builder_base_rage_gain(25.0, false),
		25.0,
	))
	assert(is_equal_approx(
		FuryRules.builder_base_rage_gain(25.0, true),
		30.0,
	))
	assert(FuryRules.burst_charge_count(false) == 3)
	assert(FuryRules.burst_charge_count(true) == 4)
	assert(is_equal_approx(FuryRules.spender_talent_damage_multiplier(false), 1.0))
	assert(is_equal_approx(FuryRules.spender_talent_damage_multiplier(true), 1.15))

	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.set_talent_enabled(FuryRules.BOILING_SPIRIT_TALENT_ID, true))
	assert(game.set_talent_enabled(FuryRules.CHAINED_BURST_TALENT_ID, true))
	assert(game.set_talent_enabled(FuryRules.PRECISE_RELEASE_TALENT_ID, true))
	game.current_floor = 1
	game._start_battle()
	assert(not game.set_talent_enabled(FuryRules.BOILING_SPIRIT_TALENT_ID, false))

	game._cast_fury_skill(
		"fury_burst",
		FuryRules.skill_catalog()["fury_burst"],
		0,
	)
	assert(game.burst_skills_remaining == 4)

	game.hero_resource = 0.0
	game.burst_skills_remaining = 0
	game._cast_fury_skill(
		"rage_builder",
		FuryRules.skill_catalog()["rage_builder"],
		0,
	)
	var expected_rage := FuryRules.rage_gain(30.0, game.hero_stats.mastery)
	assert(is_equal_approx(game.hero_resource, expected_rage))

	game.hero_stats.critical_strike = 0.0
	game.burst_skills_remaining = 0
	game.hero_resource = 100.0
	game.enemy_health = 1000.0
	game.enemy_max_health = 1000.0
	var health_before: float = game.enemy_health
	var expected_spender_damage: float = (
		game.hero_stats.attack_power()
		* float(FuryRules.skill_catalog()["single_spender"]["damage_multiplier"])
		* game.hero_stats.outgoing_multiplier()
		* FuryRules.mastery_damage_multiplier(game.hero_stats.mastery)
		* FuryRules.PRECISE_RELEASE_DAMAGE_MULTIPLIER
	)
	game._cast_fury_skill(
		"single_spender",
		FuryRules.skill_catalog()["single_spender"],
		0,
	)
	assert(is_equal_approx(health_before - game.enemy_health, expected_spender_damage))
	print("Fury talent tests passed: rage, burst charges and spender damage.")
	quit()
