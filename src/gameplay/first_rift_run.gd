class_name FirstRiftRun
extends RefCounted


signal event_emitted(event: Dictionary)

const Repository = preload("res://src/data/game_data_repository.gd")

var game_data: GameDataRepository
var highest_unlocked_floor := 1
var current_floor := 1
var floor_kill_progress: Dictionary = {}
var cleared_normal_floors: Array[int] = []
var defeated_boss_floors: Array[int] = []
var potion_count := 0
var auto_farm_running := false
var battle_in_progress := false
var last_stop_reason := ""


func _init(repository: GameDataRepository = null) -> void:
	game_data = repository if repository != null else Repository.new()
	potion_count = int(game_data.first_rift()["potion"]["starting_count"])


func can_enter_floor(floor_number: int) -> bool:
	return floor_number > 0 and floor_number <= highest_unlocked_floor


func enter_floor(floor_number: int) -> Dictionary:
	if not can_enter_floor(floor_number):
		return {}
	current_floor = floor_number
	auto_farm_running = true
	battle_in_progress = false
	last_stop_reason = ""
	var boss_entry := is_boss_floor(floor_number)
	var result := {
		"floor": floor_number,
		"is_boss": boss_entry,
		"restore_full_health": boss_entry,
		"reset_class_resource": boss_entry,
		"reset_skill_cooldowns": boss_entry,
		"clear_temporary_effects": boss_entry,
		"consumes_potion": false,
	}
	if boss_entry:
		var configured: Dictionary = game_data.first_rift()["boss_entry"]
		result.restore_full_health = bool(configured["restore_full_health"])
		result.reset_class_resource = bool(configured["reset_class_resource"])
		result.reset_skill_cooldowns = bool(configured["reset_skill_cooldowns"])
		result.clear_temporary_effects = bool(configured["clear_temporary_effects"])
	_emit("floor_entered", result)
	return result


func prepare_before_battle(current_health: float, maximum_health: float) -> Dictionary:
	if not auto_farm_running or battle_in_progress or is_boss_floor(current_floor):
		return {}
	if maximum_health <= 0.0:
		return {}
	var potion: Dictionary = game_data.first_rift()["potion"]
	assert(not bool(potion["in_combat_allowed"]))
	var health := clampf(current_health, 0.0, maximum_health)
	var target_health := maximum_health * float(potion["minimum_start_health_ratio"])
	var healing_per_potion := maximum_health * float(potion["heal_max_health_ratio"])
	var used := 0
	while health < target_health and potion_count > 0:
		health = minf(maximum_health, health + healing_per_potion)
		potion_count -= 1
		used += 1
	var result := {
		"health": health,
		"healing": health - current_health,
		"potions_used": used,
		"potions_remaining": potion_count,
		"ready": health >= target_health,
	}
	_emit("prebattle_potion_resolved", result)
	return result


func begin_encounter() -> bool:
	if not auto_farm_running or battle_in_progress:
		return false
	battle_in_progress = true
	_emit("encounter_started", {"floor": current_floor})
	return true


func record_enemy_defeated() -> Dictionary:
	if not auto_farm_running or is_boss_floor(current_floor):
		return {}
	battle_in_progress = false
	if current_floor in cleared_normal_floors:
		var repeat_result := {"floor": current_floor, "repeat_farm": true}
		_emit("repeat_farm_kill", repeat_result)
		return repeat_result
	var kills := int(floor_kill_progress.get(current_floor, 0)) + 1
	floor_kill_progress[current_floor] = kills
	var needed := int(game_data.first_rift()["normal_kills_to_clear"])
	var result := {
		"floor": current_floor,
		"kills": kills,
		"needed": needed,
		"cleared": false,
	}
	if kills >= needed:
		cleared_normal_floors.append(current_floor)
		highest_unlocked_floor = maxi(highest_unlocked_floor, current_floor + 1)
		result.cleared = true
		result.unlocked_floor = highest_unlocked_floor
		_emit("normal_floor_cleared", result)
	else:
		_emit("normal_floor_progress", result)
	return result


func record_boss_victory() -> Dictionary:
	if not auto_farm_running or not is_boss_floor(current_floor):
		return {}
	if current_floor not in defeated_boss_floors:
		defeated_boss_floors.append(current_floor)
	highest_unlocked_floor = maxi(highest_unlocked_floor, current_floor + 1)
	auto_farm_running = false
	battle_in_progress = false
	var result := {
		"boss_floor": current_floor,
		"unlocked_floor": highest_unlocked_floor,
	}
	_emit("boss_defeated", result)
	return result


func record_player_death(reason := "hero_defeated") -> Dictionary:
	auto_farm_running = false
	battle_in_progress = false
	last_stop_reason = reason
	var result := {
		"floor": current_floor,
		"reason": reason,
		"progress_preserved": true,
	}
	_emit("auto_farm_stopped", result)
	return result


func healing_from_damage(damage_dealt: float, leech_ratio: float) -> float:
	return maxf(0.0, damage_dealt) * maxf(0.0, leech_ratio)


func healing_from_kill(maximum_health: float, kill_heal_ratio: float) -> float:
	return maxf(0.0, maximum_health) * maxf(0.0, kill_heal_ratio)


func floor_definition(floor_number: int) -> Dictionary:
	return game_data.first_rift_floor(floor_number)


func snapshot() -> Dictionary:
	return {
		"highest_unlocked_floor": highest_unlocked_floor,
		"current_floor": current_floor,
		"floor_kill_progress": floor_kill_progress.duplicate(true),
		"cleared_normal_floors": cleared_normal_floors.duplicate(),
		"defeated_boss_floors": defeated_boss_floors.duplicate(),
		"potion_count": potion_count,
		"auto_farm_running": auto_farm_running,
		"battle_in_progress": battle_in_progress,
		"last_stop_reason": last_stop_reason,
	}


static func is_boss_floor(floor_number: int) -> bool:
	return floor_number > 0 and floor_number % 5 == 0


func _emit(type: String, payload: Dictionary) -> void:
	var event := payload.duplicate(true)
	event["type"] = type
	event_emitted.emit(event)
