extends SceneTree


const Progression = preload("res://src/gameplay/progression_model.gd")
const Rules = preload("res://src/gameplay/combat_rules.gd")
const CharacterStats = preload("res://src/gameplay/character_stats.gd")


func _init() -> void:
	var item := Progression.average_item_budget(4)
	assert(is_equal_approx(item.primary * 13.0, 20.0))
	assert(is_equal_approx(item.stamina * 13.0, 10.0))
	assert(is_equal_approx(item.secondary * 13.0, 40.0))

	var hero = CharacterStats.new()
	hero.apply_reference_gear_tier(4.0)
	assert(is_equal_approx(hero.strength, 80.0))
	assert(is_equal_approx(hero.stamina, 70.0))
	assert(is_equal_approx(hero.mastery, 18.0))
	assert(is_equal_approx(hero.haste, 20.0))
	assert(is_equal_approx(hero.critical_strike, 15.0))
	assert(is_equal_approx(hero.versatility, 8.0))

	for floor_number in range(2, 5):
		assert(Rules.enemy_stats(floor_number).max_health > Rules.enemy_stats(floor_number - 1).max_health)
	for floor_number in range(7, 10):
		assert(Rules.enemy_stats(floor_number).max_health > Rules.enemy_stats(floor_number - 1).max_health)
	assert(Rules.enemy_stats(10).max_health > Rules.enemy_stats(5).max_health)

	assert(is_equal_approx(Progression.estimated_boss_kill_time(5, 4.0), 48.0))
	assert(Progression.estimated_boss_kill_time(5, 3.0) < 55.0)
	assert(Progression.estimated_boss_kill_time(5, 2.0) < Progression.BOSS_HARD_ENRAGE_TIME)
	assert(Progression.estimated_boss_kill_time(5, 1.0) >= 67.0)
	assert(Progression.estimated_boss_kill_time(5, 0.0) > Progression.BOSS_HARD_ENRAGE_TIME)
	assert(Progression.boss_readiness(5, 3.0) == "ready")
	assert(Progression.boss_readiness(5, 2.0) == "risky")
	assert(Progression.boss_readiness(5, 1.0) == "wall")

	assert(Progression.dropped_item_tier(4) == 4)
	assert(Progression.dropped_item_tier(5, true) == 6)
	print("Progression model tests passed: 13-slot budgets, scaling, and boss wall thresholds.")
	quit()
