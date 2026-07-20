extends SceneTree


const MainScene = preload("res://src/main/combat_prototype.tscn")
const Effects = preload("res://src/gameplay/legendary_loop_effects.gd")
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
	var lone_index := _find_effect_index(game, Effects.LONE_CORE)
	game.equipment_panel._select_inventory_item(lone_index)
	await _settle_frames()
	_save_viewport("rule_legendary_backpack.png")

	var fuser_index := _find_effect_index(game, Effects.RIFT_FUSER)
	game.equip_inventory_item(fuser_index, "ring_1")
	game._toggle_equipment_panel()
	game.current_floor = 5
	game._start_battle()
	game._cast_next_boss_ability()
	await _settle_frames()
	_save_viewport("boss_fusion_disruption.png")

	print("UI previews captured at %s" % OUTPUT_DIR)
	quit()


func _find_effect_index(game, effect_id: String) -> int:
	for index in game.equipment_inventory.inventory.size():
		if String(game.equipment_inventory.inventory[index].get("special_effect", "")) == effect_id:
			return index
	return -1


func _settle_frames() -> void:
	for _frame in 4:
		await process_frame


func _save_viewport(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() != 1280 or image.get_height() != 720:
		image.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	assert(error == OK, "Failed to save UI preview: %s" % file_name)
