extends RefCounted


const Progression = preload("res://src/gameplay/progression_model.gd")

const BOSS_INTERVAL := 5
const BASE_ACTION_INTERVAL := 1.50
const BASE_FIRST_ACTION_DELAY := 0.80
const ATTACK_SKILL_COOLDOWN := 4.00
const MAX_RESOURCE := 100.0


static func is_boss_floor(floor_number: int) -> bool:
	return floor_number > 0 and floor_number % BOSS_INTERVAL == 0


static func enemy_stats(floor_number: int) -> Dictionary:
	if is_boss_floor(floor_number):
		return Progression.boss_enemy_stats(floor_number)
	return Progression.normal_enemy_stats(floor_number)


static func unlocked_floor_after_boss(
	current_highest_floor: int,
	boss_floor: int,
) -> int:
	if not is_boss_floor(boss_floor):
		return current_highest_floor
	return maxi(current_highest_floor, boss_floor + BOSS_INTERVAL)


static func skill_interval(agility: float) -> float:
	return BASE_ACTION_INTERVAL * 100.0 / (100.0 + maxf(0.0, agility))


static func first_action_delay(agility: float) -> float:
	return BASE_FIRST_ACTION_DELAY * 100.0 / (100.0 + maxf(0.0, agility))


# Kept for the generic combat UI base. The Fury controller replaces this catalog.
static func skill_catalog() -> Dictionary:
	return {
		"resource_builder": {
			"name": "Battle Strike",
			"kind": "attack",
			"cooldown": ATTACK_SKILL_COOLDOWN,
			"damage_multiplier": 0.65,
			"resource_gain": 25.0,
			"resource_cost": 0.0,
			"description": "Generate 25 resource",
		},
		"vulnerability": {
			"name": "Expose Weakness",
			"kind": "attack",
			"cooldown": ATTACK_SKILL_COOLDOWN,
			"damage_multiplier": 0.55,
			"resource_gain": 15.0,
			"resource_cost": 0.0,
			"description": "Generate 15 resource and apply vulnerability",
		},
		"bleeding_strike": {
			"name": "Bleeding Strike",
			"kind": "attack",
			"cooldown": ATTACK_SKILL_COOLDOWN,
			"damage_multiplier": 0.50,
			"resource_gain": 15.0,
			"resource_cost": 0.0,
			"description": "Generate 15 resource and apply bleed",
		},
		"resource_spender": {
			"name": "Finishing Blow",
			"kind": "attack",
			"cooldown": ATTACK_SKILL_COOLDOWN,
			"damage_multiplier": 1.40,
			"resource_gain": 0.0,
			"resource_cost": 50.0,
			"description": "Spend 50 resource and critically strike",
		},
		"defensive_guard": {
			"name": "Iron Guard",
			"kind": "defense",
			"cooldown": 10.0,
			"damage_multiplier": 0.0,
			"resource_gain": 0.0,
			"resource_cost": 20.0,
			"description": "Spend 20 resource and reduce the next hit",
		},
	}
