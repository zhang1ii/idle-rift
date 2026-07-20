class_name SkillLoopTracker
extends RefCounted


const SLOT_COUNT := 5

var progress := 0
var completed_loops := 0
var broken_loops := 0
var last_break_reason := ""


func reset() -> void:
	progress = 0
	completed_loops = 0
	broken_loops = 0
	last_break_reason = ""


func record_cast(slot_index: int, skipped_count: int) -> Dictionary:
	var outcome := {
		"completed": false,
		"broken": false,
		"reason": "",
		"progress": progress,
	}
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return _break_loop("invalid_slot")
	if skipped_count > 0:
		return _break_loop("skipped_skill")
	if slot_index != progress:
		return _break_loop("out_of_order")

	progress += 1
	if progress >= SLOT_COUNT:
		completed_loops += 1
		progress = 0
		outcome.completed = true
	outcome.progress = progress
	return outcome


func record_wait() -> Dictionary:
	return _break_loop("no_available_skill")


func snapshot() -> Dictionary:
	return {
		"progress": progress,
		"completed_loops": completed_loops,
		"broken_loops": broken_loops,
		"last_break_reason": last_break_reason,
	}


func _break_loop(reason: String) -> Dictionary:
	broken_loops += 1
	progress = 0
	last_break_reason = reason
	return {
		"completed": false,
		"broken": true,
		"reason": reason,
		"progress": progress,
	}
