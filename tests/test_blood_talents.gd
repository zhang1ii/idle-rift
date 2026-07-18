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
	assert(is_equal_approx(FuryRules.bleed_leech_ratio(false), 0.0))
	assert(is_equal_approx(FuryRules.bleed_leech_ratio(true), 0.08))

	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.set_talent_enabled(FuryRules.CARVED_WOUNDS_TALENT_ID, true))
	assert(game.set_talent_enabled(FuryRules.BLOOD_MEMORY_TALENT_ID, true))
	assert(game.set_talent_enabled(FuryRules.THIRSTING_WOUNDS_TALENT_ID, true))
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

	game.hero_health = game.hero_stats.max_health() - 50.0
	game.enemy_health = 1000.0
	game.enemy_max_health = 1000.0
	game.intimidation_actions = 0
	game.boss_guard_charges = 0
	game._apply_bleed(0.18)
	game.bleed_tick_timer = 0.0
	var health_before: float = game.hero_health
	var tick_damage: float = game.bleed_tick_damage
	game._process_fury_bleed(0.01)
	assert(is_equal_approx(
		game.hero_health - health_before,
		tick_damage * FuryRules.THIRSTING_WOUNDS_LEECH_RATIO,
	))
	print("Blood talent tests passed: bleed, DOT healing and bleed leech.")
	quit()
