extends SceneTree


const MainScene = preload("res://src/main/combat_prototype.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.battle_view != null)
	assert(game.hero_health_bar == game.battle_view.get_node("%HeroHealth"))
	assert(game.enemy_health_bar == game.battle_view.get_node("%EnemyHealth"))
	assert(game.battle_view.hero.sprite_frames.get_frame_count("attack") == 6)
	assert(game.battle_view.enemy.sprite_frames.get_frame_count("idle") == 4)
	assert(game.battle_view.enemy.sprite_frames.get_frame_count("hurt") == 4)

	game.current_floor = 1
	game._start_battle()
	game.enemy_health = 10000.0
	game.skill_cursor = game.skill_order.find("rage_builder")
	game._hero_take_action()
	assert(game.battle_view.hero.animation == "attack")
	assert(game.hero_resource > float(game.skill_catalog["rage_builder"]["base_rage_gain"]))
	game._refresh_combat_ui()
	assert(is_equal_approx(game.hero_health_bar.value, game.hero_health))
	assert(is_equal_approx(game.hero_resource_bar.value, game.hero_resource))

	var health_before: float = game.hero_health
	game._take_hero_damage(20.0, "test")
	assert(game.hero_health < health_before)
	assert(game.battle_view.hero.modulate != Color.WHITE)

	print("Functional battle view tests passed: authoritative HUD, sprites and combat feedback.")
	quit()
