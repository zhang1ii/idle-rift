extends SceneTree


const MainScene = preload("res://src/main/combat_prototype.tscn")
const OUTPUT_DIR := "C:/tmp/idle-rift-preview"


func _init() -> void:
	call_deferred("_capture_previews")


func _capture_previews() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var game = MainScene.instantiate()
	root.add_child(game)
	await _settle_frames()
	_save_viewport("preparation.png")

	game._toggle_equipment_panel()
	game.equipment_panel._select_inventory_item(0)
	await _settle_frames()
	_save_viewport("loop_legendary_backpack.png")

	game._toggle_equipment_panel()
	game.current_floor = 5
	game._start_battle()
	game._cast_next_boss_ability()
	await _settle_frames()
	_save_viewport("boss_slot_disruption.png")

	print("UI previews captured at %s" % OUTPUT_DIR)
	quit()


func _settle_frames() -> void:
	for _frame in 4:
		await process_frame


func _save_viewport(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 1280 or image.get_height() != 720:
		image.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	assert(error == OK, "Failed to save UI preview: %s" % file_name)
