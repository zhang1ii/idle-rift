extends SceneTree


const Repository = preload("res://src/data/game_data_repository.gd")
const TalentTreeModel = preload("res://src/gameplay/talent_tree_model.gd")
const FuryTalentRules = preload("res://src/gameplay/fury_talent_rules.gd")


func _init() -> void:
	var tree: Dictionary = Repository.new().talents()["trees"]["fury_warrior"]
	assert(tree["nodes"].size() == 12)
	assert(tree["branches"].size() == 3)

	var model = TalentTreeModel.new()
	model.configure(tree)
	assert(model.maximum_points == 7)
	assert(model.point_budget == 0)
	assert(not model.can_allocate("carved_wounds"))
	assert(model.record_guard_boss_victory(4) == 0)
	assert(model.record_guard_boss_victory(5) == 1)
	assert(model.record_guard_boss_victory(5) == 0)
	assert(model.point_budget == 1)
	assert(model.allocate("carved_wounds"))
	assert(not model.can_allocate("blood_memory"))
	assert(model.record_guard_boss_victory(10) == 1)
	assert(model.allocate("boiling_spirit"))
	assert(model.points_remaining() == 0)

	model.begin_battle()
	assert(not model.refund("boiling_spirit"))
	assert(not model.reset())
	model.end_battle()
	assert(model.reset())
	assert(model.point_budget == 2)

	var full_model = TalentTreeModel.new()
	full_model.configure(tree, 7)
	assert(full_model.allocate("carved_wounds"))
	assert(full_model.allocate("boiling_spirit"))
	assert(full_model.allocate("blood_memory"))
	assert(full_model.allocate("thick_sinew"))
	assert(full_model.allocate("thirsting_wounds"))
	assert(full_model.allocate("steady_rage"))
	assert(full_model.allocate("crimson_execution"))
	assert(full_model.points_remaining() == 0)
	assert(not full_model.can_allocate("immovable"))

	var active: Array[String] = full_model.active_talent_ids
	assert(is_equal_approx(FuryTalentRules.bleed_damage_multiplier(tree, active), 1.15))
	assert(is_equal_approx(FuryTalentRules.builder_rage_bonus(tree, active), 5.0))
	assert(is_equal_approx(FuryTalentRules.dot_heal_conversion_ratio(tree, active), 0.90))
	assert(is_equal_approx(FuryTalentRules.bleed_leech_ratio(tree, active), 0.08))
	assert(is_equal_approx(FuryTalentRules.remaining_bleed_burst_ratio(tree, active), 0.40))
	assert(FuryTalentRules.steady_rage_enabled(active))
	assert(is_equal_approx(FuryTalentRules.haste_to_barrier_rate(tree, active), 0.01))
	assert(is_equal_approx(FuryTalentRules.max_health_multiplier(tree, active), 1.08))

	var guard_active: Array[String] = [
		"thick_sinew", "steady_rage", "shield_reflow", "immovable",
	]
	assert(is_equal_approx(
		FuryTalentRules.barrier_first_hit_refund_ratio(tree, guard_active),
		0.20,
	))
	assert(is_equal_approx(
		FuryTalentRules.absorbed_damage_to_spender_ratio(tree, guard_active),
		0.40,
	))
	assert(is_equal_approx(
		FuryTalentRules.counter_attack_power_cap(tree, guard_active),
		1.0,
	))

	for boss_floor in range(15, 50, 5):
		model.record_guard_boss_victory(boss_floor)
	assert(model.point_budget == 7)
	assert(model.record_guard_boss_victory(50) == 0)
	print("Talent tree tests passed: guard-boss points, cap, prerequisites, lock and formulas.")
	quit()
