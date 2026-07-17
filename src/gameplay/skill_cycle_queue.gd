class_name SkillCycleQueue
extends RefCounted


const SLOT_COUNT := 5

var catalog_ids: Array[String] = []
var equipped_ids: Array[String] = []
var cursor := 0
var battle_locked := false


func configure(available_skill_ids: Array, initial_loadout: Array) -> bool:
	catalog_ids.clear()
	for skill_id in available_skill_ids:
		var normalized := String(skill_id)
		if normalized.is_empty() or normalized in catalog_ids:
			return false
		catalog_ids.append(normalized)
	return set_loadout(initial_loadout)


func set_loadout(skill_ids: Array) -> bool:
	if battle_locked or skill_ids.size() != SLOT_COUNT:
		return false
	var normalized: Array[String] = []
	for skill_id in skill_ids:
		var id := String(skill_id)
		if id not in catalog_ids or id in normalized:
			return false
		normalized.append(id)
	equipped_ids = normalized
	cursor = 0
	return true


func swap_in(slot_index: int, skill_id: String) -> bool:
	if battle_locked or slot_index < 0 or slot_index >= equipped_ids.size():
		return false
	if skill_id not in catalog_ids:
		return false
	if skill_id in equipped_ids and equipped_ids[slot_index] != skill_id:
		return false
	equipped_ids[slot_index] = skill_id
	cursor = 0
	return true


func swap_slots(first_index: int, second_index: int) -> bool:
	if battle_locked:
		return false
	if first_index < 0 or first_index >= equipped_ids.size():
		return false
	if second_index < 0 or second_index >= equipped_ids.size():
		return false
	var previous := equipped_ids[first_index]
	equipped_ids[first_index] = equipped_ids[second_index]
	equipped_ids[second_index] = previous
	cursor = 0
	return true


func begin_battle() -> bool:
	if equipped_ids.size() != SLOT_COUNT:
		return false
	battle_locked = true
	cursor = 0
	return true


func end_battle() -> void:
	battle_locked = false
	cursor = 0


func next_available(availability: Dictionary) -> Dictionary:
	if not battle_locked or equipped_ids.size() != SLOT_COUNT:
		return {}
	var skipped: Array[String] = []
	for offset in equipped_ids.size():
		var index := (cursor + offset) % equipped_ids.size()
		var skill_id := equipped_ids[index]
		if not bool(availability.get(skill_id, false)):
			skipped.append(skill_id)
			continue
		cursor = (index + 1) % equipped_ids.size()
		return {
			"skill_id": skill_id,
			"slot_index": index,
			"skipped": skipped,
			"next_cursor": cursor,
		}
	return {
		"skill_id": "",
		"slot_index": -1,
		"skipped": skipped,
		"next_cursor": cursor,
	}


func snapshot() -> Dictionary:
	return {
		"catalog_ids": catalog_ids.duplicate(),
		"equipped_ids": equipped_ids.duplicate(),
		"cursor": cursor,
		"battle_locked": battle_locked,
	}
