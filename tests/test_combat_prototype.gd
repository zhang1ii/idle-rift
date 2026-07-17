extends SceneTree


const FuryRules = preload("res://src/gameplay/fury_rules.gd")
const BossRules = preload("res://src/gameplay/boss_rules.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.skill_order.size() == 5)
	assert(game.skill_catalog.size() == 6)
	assert(game.reserve_skill_id == "aoe_spender")

	var old_first: String = game.skill_order[0]
	game._swap_with_reserve(0)
	assert(game.skill_order[0] == "aoe_spender")
	assert(game.reserve_skill_id == old_first)
	game._swap_with_reserve(0)

	game.current_floor = 1
	game._start_battle()
	game.enemy_health = 10000.0
	game.skill_cursor = game.skill_order.find("rage_builder")
	game._hero_take_action()
	assert(game.hero_resource > 25.0)
	assert(game.bleed_ticks_remaining == FuryRules.BLEED_TICKS)

	game.skill_cooldowns["fury_burst"] = 0.0
	game.skill_cursor = game.skill_order.find("fury_burst")
	game._hero_take_action()
	assert(game.burst_skills_remaining == 3)
	var rage_before: float = game.hero_resource
	game.skill_cooldowns["rage_builder"] = 0.0
	game.skill_cursor = game.skill_order.find("rage_builder")
	game._hero_take_action()
	assert(game.hero_resource - rage_before > 25.0)
	assert(game.burst_skills_remaining == 2)

	game.hero_resource = 100.0
	game.skill_cooldowns["single_spender"] = 0.0
	game.skill_cursor = game.skill_order.find("single_spender")
	game._hero_take_action()
	assert(game.hero_resource > 60.0)
	assert(game.burst_skills_remaining == 1)

	game.hero_health = game.hero_stats.max_health() - 100.0
	game.dot_damage_bank = 60.0
	game.skill_cooldowns["dot_heal"] = 0.0
	game.skill_cursor = game.skill_order.find("dot_heal")
	var health_before_heal: float = game.hero_health
	game._hero_take_action()
	assert(game.hero_health > health_before_heal)
	assert(game.dot_damage_bank == 0.0)

	game._return_to_preparation("test")
	game.current_floor = 5
	game._start_battle()
	game.hero_resource = 80.0
	game.boss_ability_cursor = 2
	game.boss_ability_timer = 1.0
	game.skill_cooldowns["rage_barrier"] = 0.0
	game.skill_cursor = game.skill_order.find("rage_barrier")
	game._hero_take_action()
	assert(is_equal_approx(game.hero_shield, FuryRules.barrier_amount(80.0)))
	assert(game.hero_resource == 0.0)
	var health_before_hit: float = game.hero_health
	game._take_hero_damage(BossRules.HEAVY_ATTACK_DAMAGE, "test")
	assert(health_before_hit - game.hero_health < 20.0)

	game.boss_ability_cursor = 0
	var platforms_before: int = game.platforms_remaining
	game._cast_next_boss_ability()
	assert(game.platforms_remaining == platforms_before - 1)
	assert(game.floor_slow_stacks == 1)
	game._cast_next_boss_ability()
	assert(game.intimidation_actions == BossRules.INTIMIDATION_ACTIONS)

	game.boss_ability_cursor = 3
	game._cast_next_boss_ability()
	assert(game.boss_guard_charges == 1)
	game._apply_damage_to_enemy(100.0)
	assert(game.boss_guard_charges == 0)

	game.platforms_remaining = 1
	game.boss_ability_cursor = 0
	game._cast_next_boss_ability()
	assert(game.battle_state == game.BattleState.PREPARING)
	assert(game.hero_health == 0.0)

	game.current_floor = 5
	game._start_battle()
	game.enemy_health = 1.0
	game._hero_take_action()
	assert(game.highest_unlocked_floor == 10)
	assert(game.current_floor == 6)

	print("Combat tests passed: six-pick-five Fury kit and boss timeline.")
	quit()
