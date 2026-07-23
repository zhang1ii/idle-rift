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
	assert(absf(game.hero_resource_bar.value - game.hero_resource) <= game.hero_resource_bar.step)

	var health_before: float = game.hero_health
	game._take_hero_damage(20.0, "test")
	assert(game.hero_health < health_before)
	assert(game.battle_view.hero.modulate != Color.WHITE)

	game._return_to_preparation("presentation stress test")
	var view = game.battle_view
	var hero_origin: Vector2 = view._hero_origin
	var enemy_origin: Vector2 = view._enemy_origin
	view.play_skill("rage_builder")
	view.play_skill("single_spender")
	assert(view.hero.position.distance_to(hero_origin) <= view.HERO_STRONG_STEP_DISTANCE + 4.0)
	await create_timer(0.50).timeout
	assert(view.hero.position.is_equal_approx(hero_origin))
	assert(view.hero.animation == "idle")

	for index in 8:
		view._spawn_damage_number(10.0 + index, enemy_origin, false)
	assert(view._floating_damage_labels.size() == view.MAX_FLOATING_DAMAGE_LABELS)

	view.play_enemy_damage(20.0, true, false, true)
	view.spawn_enemy()
	assert(view.enemy.rotation == 0.0)
	assert(view.enemy.position.distance_to(enemy_origin) <= view.ENEMY_SPAWN_OFFSET + 0.1)
	await create_timer(0.30).timeout
	assert(view.enemy.position.is_equal_approx(enemy_origin))
	assert(view.enemy.modulate.is_equal_approx(Color.WHITE))

	view.fx.play_contact_sparks(enemy_origin, true)
	view.fx.show_shield()
	view.reset_presentation()
	assert(view.hero.position.is_equal_approx(hero_origin))
	assert(view.enemy.position.is_equal_approx(enemy_origin))
	assert(view._floating_damage_labels.is_empty())
	assert(is_zero_approx(view.fx.impact_alpha))
	assert(is_zero_approx(view.fx.shield_alpha))

	print("Functional battle view tests passed: HUD, sprites, bounded motion and reset stability.")
	quit()
