class_name CombatState
extends RefCounted

var elapsed_time := 0.0
var selected_class_id: StringName = &"iron_vow"
var kill_count := 0
var gold := 0
var class_resource := 0.0
var blocked_attacks := 0
var counter_attacks := 0
var paused := false
var speed_multiplier := 1.0

var hero_health := 100.0
var hero_attack_cooldown := 0.0
var enemy_attack_cooldown := 1.0
var respawn_delay := 0.0

var enemy_id := ""
var enemy_name := ""
var enemy_level := 1
var enemy_health := 1.0
var enemy_max_health := 1.0

var inventory: Array[EquipmentItem] = []
var equipped: Dictionary = {}


func snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"elapsed_time": elapsed_time,
		"selected_class_id": String(selected_class_id),
		"kill_count": kill_count,
		"gold": gold,
		"class_resource": class_resource,
		"hero_health": hero_health,
		"enemy_id": enemy_id,
		"enemy_level": enemy_level,
		"enemy_health": enemy_health,
	}
