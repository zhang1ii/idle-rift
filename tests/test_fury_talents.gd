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

	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.set_talent_enabled(FuryRules.BOILING_SPIRIT_TALENT_ID, true))
	game.current_floor = 1
	game._start_battle()
	assert(not game.set_talent_enabled(FuryRules.BOILING_SPIRIT_TALENT_ID, false))

	game.hero_resource = 0.0
	game.burst_skills_remaining = 0
	game._cast_fury_skill(
		"rage_builder",
		FuryRules.skill_catalog()["rage_builder"],
		0,
	)
	var expected_rage := FuryRules.rage_gain(30.0, game.hero_stats.mastery)
	assert(is_equal_approx(game.hero_resource, expected_rage))
	print("Fury talent tests passed: Boiling Spirit adds base rage before mastery.")
	quit()
