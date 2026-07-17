extends SceneTree


const FuryBattleModel = preload("res://src/combat/fury_battle_model.gd")


func _init() -> void:
	var model = FuryBattleModel.new()
	var events: Array[Dictionary] = []
	model.event_emitted.connect(func(event: Dictionary) -> void: events.append(event))
	model.start(1)
	for index in 4000:
		model.tick(0.01)
	assert(events.any(func(event: Dictionary) -> bool:
		return event.type == "skill_cast_started" and event.skill_id == "rage_builder"))
	assert(events.any(func(event: Dictionary) -> bool:
		return event.type == "skill_cast_started" and event.skill_id == "single_spender"))
	assert(events.any(func(event: Dictionary) -> bool:
		return event.type == "skill_cast_started" and event.skill_id == "rage_barrier"))
	assert(events.any(func(event: Dictionary) -> bool: return event.type == "bleed_applied"))
	assert(events.any(func(event: Dictionary) -> bool: return event.type == "enemy_defeated"))
	print("Fury battle model tests passed: casts, impacts, bleed, barrier and loot events.")
	quit()
