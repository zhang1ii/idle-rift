extends SceneTree


const BattleStage = preload("res://src/main/main.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var stage = BattleStage.instantiate()
	root.add_child(stage)
	await process_frame
	var hero: AnimatedSprite2D = stage.get_node("World/Hero")
	var enemy: AnimatedSprite2D = stage.get_node("World/Enemy")
	var slash: AnimatedSprite2D = stage.get_node("World/SlashFx")
	assert(hero.sprite_frames.get_frame_count("idle") == 4)
	assert(hero.sprite_frames.get_frame_count("attack") == 6)
	assert(hero.sprite_frames.get_frame_count("heavy_attack") == 6)
	assert(not hero.sprite_frames.get_animation_loop("attack"))
	assert(enemy.sprite_frames.get_frame_count("hurt") == 4)
	assert(enemy.sprite_frames.get_frame_count("death") == 6)
	assert(not enemy.sprite_frames.get_animation_loop("death"))
	assert(slash.sprite_frames.get_frame_count("slash") == 4)
	print("Battle presentation tests passed: hero, hound and slash action resources loaded.")
	quit()
