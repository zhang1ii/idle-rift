extends RefCounted


const Progression = preload("res://src/gameplay/progression_model.gd")


var primary_stat := "strength"
var gear_tier := 4.0
var strength := 80.0
var agility := 20.0
var intellect := 15.0
var stamina := 70.0

var mastery := 18.0
var haste := 20.0
var critical_strike := 15.0
var versatility := 8.0
var max_health_multiplier := 1.0


func apply_reference_gear_tier(value: float) -> void:
	gear_tier = maxf(0.0, value)
	var stats := Progression.reference_stats(gear_tier)
	strength = stats.strength
	agility = stats.agility
	intellect = stats.intellect
	stamina = stats.stamina
	mastery = stats.mastery
	haste = stats.haste
	critical_strike = stats.critical_strike
	versatility = stats.versatility


func primary_value() -> float:
	match primary_stat:
		"agility":
			return agility
		"intellect":
			return intellect
		_:
			return strength


func attack_power() -> float:
	return 10.0 + primary_value() * 0.35


func max_health() -> float:
	return (80.0 + stamina * 2.0) * maxf(0.0, max_health_multiplier)


func haste_multiplier() -> float:
	return 1.0 + maxf(0.0, haste) / 100.0


func adjusted_time(base_seconds: float) -> float:
	return base_seconds / haste_multiplier()


func critical_chance() -> float:
	return clampf(critical_strike / 100.0, 0.0, 1.0)


func outgoing_multiplier() -> float:
	return 1.0 + maxf(0.0, versatility) / 100.0


func damage_taken_multiplier() -> float:
	return maxf(0.0, 1.0 - maxf(0.0, versatility) / 200.0)


func mastery_spender_multiplier() -> float:
	return 1.0 + maxf(0.0, mastery) / 100.0
