extends SceneTree


const MainScene = preload("res://src/main/combat_prototype.tscn")
const Repository = preload("res://src/data/game_data_repository.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.talent_panel != null)
	assert(game.talent_panel._talent_buttons.size() == 12)
	assert(not game._talent_system_unlocked())
	assert(not game.allocate_talent("carved_wounds"))
	assert(not game.talent_panel.visible)
	game._toggle_talent_panel()
	assert(not game.talent_panel.visible)
	game.defeated_boss_floors.append(5)

	var definition: Dictionary = Repository.new().talents()["trees"]["fury_warrior"]
	game.talent_tree.configure(definition, 7)
	game.talent_panel.refresh()
	assert(game.allocate_talent("carved_wounds"))
	assert(not game.allocate_talent("blood_memory"))
	assert(game.allocate_talent("boiling_spirit"))
	assert(game.allocate_talent("blood_memory"))
	assert(game.active_talent_ids == game.talent_tree.active_talent_ids)

	game._start_battle()
	assert(game.talent_tree.battle_locked)
	assert(not game.talent_panel.visible)
	assert(not game.allocate_talent("thick_sinew"))
	assert(not game.refund_talent("boiling_spirit"))
	game._return_to_preparation("test")
	assert(not game.talent_tree.battle_locked)
	assert(game.allocate_talent("thick_sinew"))
	assert(not game.refund_talent("carved_wounds"))
	assert(game.reset_talents())
	assert(game.active_talent_ids.is_empty())
	assert(game.talent_tree.points_remaining() == 7)

	game.talent_tree.configure(definition)
	game.defeated_boss_floors.clear()
	game.current_floor = 5
	game._start_battle()
	game._on_boss_defeated()
	assert(game.talent_tree.point_budget == 1)
	assert(not game.talent_tree.battle_locked)
	assert(game.allocate_talent("carved_wounds"))
	assert(game.talent_tree.points_remaining() == 0)

	print("Talent UI tests passed: 12 nodes, legal allocation, respec, battle lock and boss point award.")
	quit()
