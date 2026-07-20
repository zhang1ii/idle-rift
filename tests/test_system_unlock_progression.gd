extends SceneTree


const Effects = preload("res://src/gameplay/legendary_loop_effects.gd")
const BossRules = preload("res://src/gameplay/boss_rules.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(is_equal_approx(BossRules.ability_interval(5), 4.0))
	assert(is_equal_approx(BossRules.ability_interval(10), 2.75))

	assert(not game._talent_system_unlocked())
	assert(not game.equipment_inventory.special_effects_unlocked)
	assert(game.equipment_inventory.inventory.is_empty())
	assert("第5层" in game._progression_stage_text())

	game.current_floor = 5
	game._start_battle()
	game._on_boss_defeated()
	assert(game._talent_system_unlocked())
	assert(game.talent_tree.point_budget == 1)
	assert(not game.equipment_inventory.special_effects_unlocked)
	assert("套装构筑" in game._progression_stage_text())

	game.current_floor = 10
	game._start_battle()
	game._on_boss_defeated()
	assert(game.equipment_inventory.special_effects_unlocked)
	assert(10 in game.defeated_boss_floors)
	assert("特效装备" in game._progression_stage_text())
	assert(game.equipment_inventory.inventory.size() == 1)
	var starter: Dictionary = game.equipment_inventory.inventory[0]
	assert(String(starter.special_effect) == Effects.RIFT_METRONOME)
	assert(int(starter.item_tier) == 11)

	print("System unlock tests passed: floor 5 talents/sets, floor 10 special effects.")
	quit()
