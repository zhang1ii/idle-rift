extends SceneTree


const Tracker = preload("res://src/gameplay/skill_loop_tracker.gd")
const Effects = preload("res://src/gameplay/legendary_loop_effects.gd")
const FuryRules = preload("res://src/gameplay/fury_rules.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_tracker_rules()
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame

	assert(game.initial_prototype_item_count == 3)
	assert(game.equipment_inventory.inventory.size() == 3)
	for effect_id in Effects.all_ids():
		assert(_equip_effect(game, effect_id))
		assert(game.equipment_inventory.has_special_effect(effect_id))
	assert(game.equipment_inventory.active_loop_effect_ids().size() == 3)

	game.current_floor = 5
	game._start_battle()
	game.hero_stats.critical_strike = 0.0
	game.enemy_health = 10000.0
	game.enemy_max_health = 10000.0
	game.boss_guard_charges = 0
	game.intimidation_actions = 0
	game.hero_resource = 0.0
	game.bleed_tick_damage = 20.0
	game.bleed_ticks_remaining = 4
	var health_before_loop: float = game.enemy_health
	game._resolve_loop_outcome({"completed": true, "broken": false})
	assert(is_equal_approx(game.hero_resource, 15.0))
	assert(is_equal_approx(health_before_loop - game.enemy_health, 24.0))
	assert(game.loop_echo_charges == 1)

	game._resolve_loop_outcome({"completed": false, "broken": true})
	assert(game.fracture_gear_stacks == 1)
	game.enemy_health = 10000.0
	game.enemy_max_health = 10000.0
	game.hero_resource = 0.0
	var health_before_attack: float = game.enemy_health
	var base_builder_damage: float = (
		game.hero_stats.attack_power()
		* float(FuryRules.skill_catalog()["rage_builder"]["damage_multiplier"])
		* game.hero_stats.outgoing_multiplier()
	)
	game._cast_fury_skill(
		"rage_builder",
		FuryRules.skill_catalog()["rage_builder"],
		0,
	)
	assert(is_equal_approx(
		health_before_attack - game.enemy_health,
		base_builder_damage * 1.70,
	))
	assert(game.loop_echo_charges == 0)
	assert(game.fracture_gear_stacks == 0)

	game._return_to_preparation("切换测试")
	game.current_floor = 5
	game._start_battle()
	game.boss_ability_cursor = 0
	game._cast_next_boss_ability()
	assert(int(game.boss_disrupted_slots.get(1, 0)) == 1)
	assert("裂化" in game.skill_labels[1].text)
	game.skill_cursor = 1
	game.hero_resource = 0.0
	game._hero_take_action()
	assert(not game.boss_disrupted_slots.has(1))
	assert(game.boss_disruptions_triggered == 1)
	assert(game.loop_tracker.broken_loops == 1)

	game.platforms_remaining = 1
	game.boss_ability_cursor = 0
	game._cast_next_boss_ability()
	assert(game.battle_state == game.BattleState.PREPARING)
	assert("失败诊断" in game.last_failure_diagnostic)
	assert("输出不足" in game.last_failure_diagnostic)

	print("Skill loop experiment tests passed: completion, break, legendaries, boss disruption and diagnostics.")
	quit()


func _test_tracker_rules() -> void:
	var tracker = Tracker.new()
	for index in range(4):
		var outcome: Dictionary = tracker.record_cast(index, 0)
		assert(not outcome.completed)
	var completion: Dictionary = tracker.record_cast(4, 0)
	assert(completion.completed)
	assert(tracker.completed_loops == 1)
	assert(tracker.progress == 0)
	tracker.record_cast(0, 0)
	var broken: Dictionary = tracker.record_cast(2, 1)
	assert(broken.broken)
	assert(tracker.broken_loops == 1)


func _equip_effect(game, effect_id: String) -> bool:
	for index in game.equipment_inventory.inventory.size():
		var item: Dictionary = game.equipment_inventory.inventory[index]
		if String(item.get("special_effect", "")) != effect_id:
			continue
		var target := "trinket_1" if Effects.effect_slot(effect_id) == "trinket" \
			else ("ring_1" if effect_id == Effects.FRACTURE_GEAR else "ring_2")
		return game.equip_inventory_item(index, target)
	return false
