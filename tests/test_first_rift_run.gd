extends SceneTree


const FirstRiftRun = preload("res://src/gameplay/first_rift_run.gd")


func _init() -> void:
	var run = FirstRiftRun.new()
	assert(run.highest_unlocked_floor == 1)
	assert(run.potion_count == 3)
	assert(run.talent_tree.point_budget == 0)
	assert(run.can_enter_floor(1))
	assert(not run.can_enter_floor(2))
	assert(run.floor_definition(5).is_boss)

	var entry := run.enter_floor(1)
	assert(not entry.is_boss)
	for ignored_kill in range(19):
		var progress := run.record_enemy_defeated()
		assert(not progress.cleared)
	assert(run.highest_unlocked_floor == 1)
	var clear_result := run.record_enemy_defeated()
	assert(clear_result.cleared)
	assert(run.highest_unlocked_floor == 2)
	assert(1 in run.cleared_normal_floors)
	var repeat_result := run.record_enemy_defeated()
	assert(repeat_result.repeat_farm)

	for floor_number in range(2, 5):
		run.enter_floor(floor_number)
		for ignored_kill in range(20):
			run.record_enemy_defeated()
	assert(run.highest_unlocked_floor == 5)

	run.enter_floor(4)
	var preparation := run.prepare_before_battle(30.0, 100.0)
	assert(is_equal_approx(preparation.health, 100.0))
	assert(preparation.potions_used == 2)
	assert(run.potion_count == 1)
	assert(run.begin_encounter())
	assert(run.prepare_before_battle(30.0, 100.0).is_empty())
	var stop_result := run.record_player_death("hero_defeated")
	assert(stop_result.progress_preserved)
	assert(not run.auto_farm_running)
	assert(run.last_stop_reason == "hero_defeated")

	var boss_entry := run.enter_floor(5)
	assert(boss_entry.is_boss)
	assert(boss_entry.restore_full_health)
	assert(boss_entry.reset_class_resource)
	assert(boss_entry.reset_skill_cooldowns)
	assert(not boss_entry.consumes_potion)
	assert(run.prepare_before_battle(10.0, 100.0).is_empty())
	assert(run.potion_count == 1)
	assert(run.begin_encounter())
	var victory := run.record_boss_victory()
	assert(victory.first_clear)
	assert(victory.talent_points_awarded == 1)
	assert(victory.total_talent_points == 1)
	assert(victory.unlocked_floor == 6)
	assert(run.highest_unlocked_floor == 6)
	assert(not run.auto_farm_running)

	run.enter_floor(5)
	assert(run.begin_encounter())
	var repeat_victory := run.record_boss_victory()
	assert(not repeat_victory.first_clear)
	assert(repeat_victory.talent_points_awarded == 0)
	assert(repeat_victory.total_talent_points == 1)


	for floor_number in range(6, 10):
		assert(run.enter_floor(floor_number).floor == floor_number)
		for ignored_kill in range(20):
			run.record_enemy_defeated()
	assert(run.highest_unlocked_floor == 10)
	assert(run.floor_definition(10).is_boss)
	var second_boss_entry := run.enter_floor(10)
	assert(second_boss_entry.is_boss)
	assert(second_boss_entry.restore_full_health)
	assert(run.begin_encounter())
	var second_boss_victory := run.record_boss_victory()
	assert(second_boss_victory.first_clear)
	assert(second_boss_victory.talent_points_awarded == 1)
	assert(second_boss_victory.total_talent_points == 2)
	assert(second_boss_victory.unlocked_floor == 11)
	assert(run.highest_unlocked_floor == 11)

	assert(is_equal_approx(run.healing_from_damage(100.0, 0.05), 5.0))
	assert(is_equal_approx(run.healing_from_kill(200.0, 0.08), 16.0))
	print("First Rift tests passed: floors 1-10, potions, boss talent points and death stop.")
	quit()
