extends SceneTree


const MainScene = preload("res://src/main/main.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var stage = MainScene.instantiate()
	root.add_child(stage)
	await process_frame
	var hero: AnimatedSprite2D = stage.get_node("World/Hero")
	var enemy: AnimatedSprite2D = stage.get_node("World/Enemy")
	assert(not hero.flip_h)
	assert(not enemy.flip_h)
	assert(hero.sprite_frames.get_frame_count("attack") == 6)
	assert(enemy.sprite_frames.get_frame_count("idle") == 4)
	assert(enemy.sprite_frames.get_frame_count("hurt") == 4)
	var contact_x: float = stage._contact_hero_x()
	var blade_world_x := contact_x + (85.0 - 48.0) * hero.scale.x
	var shoulder_world_x: float = stage._enemy_origin.x + (28.0 - 56.0) * enemy.scale.x
	assert(absf(blade_world_x - shoulder_world_x) <= 3.1)
	print("Battle presentation tests passed: facing, frames and weapon contact.")
	quit()
