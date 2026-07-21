extends SceneTree


const EquipmentRules = preload("res://src/gameplay/equipment_rules.gd")
const GameDataRepository = preload("res://src/data/game_data_repository.gd")
const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var repository = GameDataRepository.new()
	for floor_number in range(1, 11):
		var definition := repository.first_rift_floor(floor_number)
		assert(not definition.is_empty())
		assert(not String(definition.mechanic_label).is_empty())
		assert(not String(definition.tutorial).is_empty())
		assert(bool(definition.get("is_boss", false)) == (floor_number % 5 == 0))
	assert("武器" in EquipmentRules.floor_drop_preview(6))
	assert("精通" in EquipmentRules.floor_drop_preview(7))
	assert("全能" in EquipmentRules.floor_drop_preview(8))
	assert("急速" in EquipmentRules.floor_drop_preview(9))

	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame

	game.current_floor = 1
	game._start_battle()
	assert(_enemy_name_matches_floor(game, repository, 1))
	assert("基础攻击" in game.mode_status.text)
	game._return_to_preparation("test")

	game.current_floor = 2
	game._start_battle()
	assert(_enemy_name_matches_floor(game, repository, 2))
	game._enemy_take_action()
	assert(game.normal_enemy_wound_stacks == 1)
	var health_after_hit: float = game.hero_health
	game._process_normal_enemy_effects(1.01)
	assert(game.hero_health < health_after_hit)
	assert("腐血" in game.battle_event.text)
	for ignored in 4:
		game._enemy_take_action()
	assert(game.normal_enemy_wound_stacks == 3)
	game._return_to_preparation("test")

	game.current_floor = 3
	game._start_battle()
	assert(_enemy_name_matches_floor(game, repository, 3))
	assert(is_equal_approx(game._apply_damage_to_enemy(100.0), 75.0))
	assert(is_equal_approx(game._apply_damage_to_enemy(100.0, true), 100.0))
	game._return_to_preparation("test")

	game.current_floor = 4
	game._start_battle()
	assert(_enemy_name_matches_floor(game, repository, 4))
	game.normal_enemy_attack_count = 2
	game._refresh_combat_ui()
	assert("裂地重击" in game.enemy_action.text)
	var health_before_heavy: float = game.hero_health
	game._enemy_take_action()
	var normal_taken: float = float(game.enemy_damage) * game.hero_stats.damage_taken_multiplier()
	assert(health_before_heavy - game.hero_health > normal_taken * 2.0)
	assert("裂地重击" in game.battle_event.text)
	game._return_to_preparation("test")

	game.current_floor = 5
	game._start_battle()
	assert("裂隙守关者·碎岩" in game.enemy_name.text)
	game._return_to_preparation("test")

	game.current_floor = 10
	game._start_battle()
	assert("逆序守关者·刻轮" in game.enemy_name.text)
	assert("逆序刻印" in game.mode_status.text)

	print("Rift floor content tests passed: 10 identities, drop tendencies and floor 2-4 mechanics.")
	quit()


func _enemy_name_matches_floor(game, repository, floor_number: int) -> bool:
	var names: Array = repository.first_rift_floor(floor_number).enemy_names
	for candidate in names:
		if String(candidate) in game.enemy_name.text:
			return true
	return false
