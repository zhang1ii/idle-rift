extends SceneTree


const FuryRules = preload("res://src/gameplay/fury_rules.gd")
const Repository = preload("res://src/data/game_data_repository.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var talent := Repository.new().talent_definition(
		"fury_warrior",
		FuryRules.CARVED_WOUNDS_TALENT_ID,
	)
	assert(is_equal_approx(
		float(talent["effects"]["bleed_damage_multiplier"]),
		1.15,
	))
	assert(is_equal_approx(FuryRules.bleed_talent_damage_multiplier(false), 1.0))
	assert(is_equal_approx(FuryRules.bleed_talent_damage_multiplier(true), 1.15))
	assert(is_equal_approx(FuryRules.dot_heal_conversion_ratio(false), 0.75))
	assert(is_equal_approx(FuryRules.dot_heal_conversion_ratio(true), 0.90))
	assert(is_equal_approx(FuryRules.dot_heal_cap_ratio(false), 0.35))
	assert(is_equal_approx(FuryRules.dot_heal_cap_ratio(true), 0.40))

	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.set_talent_enabled(FuryRules.CARVED_WOUNDS_TALENT_ID, true))
	assert(game.set_talent_enabled(FuryRules.BLOOD_MEMORY_TALENT_ID, true))
	game.current_floor = 1
	game._start_battle()
	assert(not game.set_talent_enabled(FuryRules.CARVED_WOUNDS_TALENT_ID, false))

	game._apply_bleed(0.18)
	var expected_tick: float = (
		game.hero_stats.attack_power()
		* 0.18
		* game.hero_stats.outgoing_multiplier()
		* FuryRules.mastery_damage_multiplier(game.hero_stats.mastery)
		* FuryRules.CARVED_WOUNDS_BLEED_MULTIPLIER
	)
	assert(is_equal_approx(game.bleed_tick_damage, expected_tick))

	game.hero_health = 0.0
	game.dot_damage_bank = 1000.0
	game._cast_fury_skill(
		"dot_heal",
		FuryRules.skill_catalog()["dot_heal"],
		0,
	)
	assert(is_equal_approx(game.hero_health, game.hero_stats.max_health() * 0.40))
	assert(is_equal_approx(game.dot_damage_bank, 0.0))
	print("Blood talent tests passed: bleed damage and Blood Memory healing.")
	quit()
