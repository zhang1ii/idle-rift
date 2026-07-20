extends SceneTree


const Effects = preload("res://src/gameplay/legendary_loop_effects.gd")
const FuryRules = preload("res://src/gameplay/fury_rules.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	assert(is_equal_approx(Effects.scarcity_bonus_ratio(0), 0.0))
	assert(is_equal_approx(Effects.scarcity_bonus_ratio(4), 0.48))
	assert(is_equal_approx(Effects.scarcity_bonus_ratio(99), 0.48))

	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.initial_prototype_item_count == 7)

	assert(_equip_effect(game, Effects.LONE_CORE, "ring_1"))
	assert(_equip_effect(game, Effects.RIFT_FUSER, "ring_2"))
	assert(_equip_effect(game, Effects.SOURCELESS_FURNACE, "trinket_1"))
	assert(_equip_effect(game, Effects.COUNTER_PLATING, "trinket_2"))
	assert(game.equipment_inventory.active_loop_effect_ids().size() == 4)

	game._swap_with_reserve(0)
	assert("rage_builder" not in game.skill_order)
	assert(game._is_sourceless_mode())
	game.current_floor = 5
	game._start_battle()
	game.hero_stats.critical_strike = 0.0
	game.enemy_health = 10000.0
	game.enemy_max_health = 10000.0
	game.boss_guard_charges = 0
	game.intimidation_actions = 0
	game.hero_resource = 0.0
	var spender: Dictionary = game.skill_catalog["single_spender"]
	assert(game._is_skill_available("single_spender", spender))

	for configured_id in game.skill_order:
		game.skill_cooldowns[configured_id] = 20.0
	game.skill_cooldowns["single_spender"] = 0.0
	var scarcity_health_before: float = game.enemy_health
	var base_spender_damage := _base_spender_damage(game, "single_spender")
	game._cast_fury_skill("single_spender", spender, 0)
	assert(game.last_scarcity_unavailable == 4)
	assert(is_equal_approx(
		scarcity_health_before - game.enemy_health,
		base_spender_damage * 1.48,
	))
	assert("无源炉心" in game.battle_event.text)

	game._return_to_preparation("反震测试")
	game.current_floor = 5
	game._start_battle()
	game.hero_stats.critical_strike = 0.0
	game.enemy_health = 10000.0
	game.enemy_max_health = 10000.0
	game.hero_shield = 50.0
	game.boss_ability_cursor = 0
	game._cast_next_boss_ability()
	assert(game.prevented_disruptions == 1)
	assert(game.counter_plating_charges == 1)
	assert(game.boss_disrupted_slots.is_empty())
	assert("反震装甲" in game.battle_event.text)

	for configured_id in game.skill_order:
		game.skill_cooldowns[configured_id] = 0.0
	game.hero_health = game.hero_stats.max_health() - 1.0
	game.dot_damage_bank = 10.0
	game.hero_resource = 100.0
	var counter_health_before: float = game.enemy_health
	base_spender_damage = _base_spender_damage(game, "single_spender")
	game._cast_fury_skill("single_spender", spender, 0)
	assert(game.counter_plating_charges == 0)
	assert(game.last_scarcity_unavailable == 0)
	assert(is_equal_approx(
		counter_health_before - game.enemy_health,
		base_spender_damage * 1.50,
	))

	game._return_to_preparation("熔接测试")
	game.current_floor = 5
	game._start_battle()
	game.hero_shield = 0.0
	game.boss_ability_cursor = 0
	game._cast_next_boss_ability()
	assert(int(game.boss_disrupted_slots.get(1, 0)) == 1)
	assert("待熔接" in game.skill_labels[1].text)
	game.skill_cursor = 1
	game.hero_health = game.hero_stats.max_health() - 50.0
	game.dot_damage_bank = 100.0
	game._hero_take_action()
	assert(game.fusion_casts == 1)
	assert(not game.boss_disrupted_slots.has(1))
	assert(game.burst_skills_remaining == 2)
	assert(game.skill_cooldowns["fury_burst"] > 0.0)
	assert(game.loop_tracker.broken_loops == 1)
	assert("熔接" in game.battle_event.text)

	print("Rule legendary tests passed: scarcity, sourceless spenders, fusion and guarded counterplay.")
	quit()


func _equip_effect(game, effect_id: String, target: String) -> bool:
	for index in game.equipment_inventory.inventory.size():
		var item: Dictionary = game.equipment_inventory.inventory[index]
		if String(item.get("special_effect", "")) == effect_id:
			return game.equip_inventory_item(index, target)
	return false


func _base_spender_damage(game, skill_id: String) -> float:
	var skill: Dictionary = game.skill_catalog[skill_id]
	return (
		game.hero_stats.attack_power()
		* float(skill["damage_multiplier"])
		* game.hero_stats.outgoing_multiplier()
		* FuryRules.mastery_damage_multiplier(game.hero_stats.mastery)
		* game._spender_damage_multiplier(skill_id)
	)
