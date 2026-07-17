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
	assert(model.point_budget == 7)
	assert(not model.can_allocate("blood_memory"))
	assert(model.allocate("carved_wounds"))
	assert(not model.can_allocate("blood_memory"))
	assert(model.allocate("boiling_spirit"))
	assert(model.allocate("blood_memory"))
	assert(not model.refund("carved_wounds"))
	assert(model.points_spent() == 3)

	model.begin_battle()
	assert(not model.allocate("thick_sinew"))
	assert(not model.reset())
	model.end_battle()
	assert(model.reset())

	assert(model.allocate("carved_wounds"))
	assert(model.allocate("boiling_spirit"))
	assert(model.allocate("blood_memory"))
	assert(model.allocate("thick_sinew"))
	assert(model.allocate("thirsting_wounds"))
	assert(model.allocate("steady_rage"))
	assert(model.allocate("crimson_execution"))
	assert(model.points_remaining() == 0)
	assert(not model.can_allocate("immovable"))

	var active: Array[String] = model.active_talent_ids
	assert(is_equal_approx(FuryTalentRules.bleed_damage_multiplier(tree, active), 1.15))
	assert(is_equal_approx(FuryTalentRules.builder_rage_bonus(tree, active), 5.0))
	assert(is_equal_approx(FuryTalentRules.dot_heal_conversion_ratio(tree, active), 0.90))
	assert(is_equal_approx(FuryTalentRules.dot_heal_cap_ratio(tree, active), 0.40))
	assert(is_equal_approx(FuryTalentRules.bleed_leech_ratio(tree, active), 0.08))
	assert(is_equal_approx(FuryTalentRules.remaining_bleed_burst_ratio(tree, active), 0.40))
	assert(FuryTalentRules.steady_rage_enabled(active))
	assert(is_equal_approx(FuryTalentRules.haste_to_barrier_rate(tree, active), 0.008))
	assert(is_equal_approx(FuryTalentRules.max_health_multiplier(tree, active), 1.08))
	assert(is_equal_approx(FuryTalentRules.spender_damage_multiplier(tree, active), 1.0))

	print("Talent tree tests passed: 3 branches, 4 tiers, prerequisites, capstone lock and formulas.")
	quit()
