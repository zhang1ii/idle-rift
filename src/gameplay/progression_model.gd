class_name ProgressionModel
extends RefCounted


const GEAR_SLOT_COUNT := 13
const BOSS_INTERVAL := 5

const OFFENSE_GROWTH_PER_TIER := 1.12
const DEFENSE_GROWTH_PER_TIER := 1.10

const BASE_NORMAL_HEALTH := 70.0
const BASE_NORMAL_DAMAGE := 6.0
const BASE_NORMAL_KILL_TIME := 4.0

const FIRST_BOSS_FLOOR := 5
const FIRST_BOSS_HEALTH := 1240.0
const FIRST_BOSS_HEAVY_DAMAGE := 110.0
const BOSS_TARGET_KILL_TIME := 48.0
const BOSS_HARD_ENRAGE_TIME := 68.0

const BASE_STRENGTH := 60.0
const BASE_AGILITY := 20.0
const BASE_INTELLECT := 15.0
const BASE_STAMINA := 60.0
const BASE_MASTERY := 5.0
const BASE_HASTE := 5.0
const BASE_CRITICAL_STRIKE := 5.0
const BASE_VERSATILITY := 6.0

# Totals supplied by a complete thirteen-slot loadout at average tier G.
const PRIMARY_PER_LOADOUT_TIER := 5.0
const STAMINA_PER_LOADOUT_TIER := 2.5
const SECONDARY_PER_LOADOUT_TIER := 10.0

const FURY_MASTERY_WEIGHT := 0.325
const FURY_HASTE_WEIGHT := 0.375
const FURY_CRITICAL_WEIGHT := 0.25
const FURY_VERSATILITY_WEIGHT := 0.05


static func offense_multiplier(gear_tier: float) -> float:
	return pow(OFFENSE_GROWTH_PER_TIER, maxf(0.0, gear_tier))


static func defense_multiplier(gear_tier: float) -> float:
	return pow(DEFENSE_GROWTH_PER_TIER, maxf(0.0, gear_tier))


static func expected_gear_tier(floor_number: int) -> int:
	return maxi(0, floor_number - 1)


static func dropped_item_tier(floor_number: int, boss_drop := false) -> int:
	return maxi(0, floor_number + 1 if boss_drop else floor_number)


static func full_loadout_budget(gear_tier: float) -> Dictionary:
	var tier := maxf(0.0, gear_tier)
	return {
		"primary": PRIMARY_PER_LOADOUT_TIER * tier,
		"stamina": STAMINA_PER_LOADOUT_TIER * tier,
		"secondary": SECONDARY_PER_LOADOUT_TIER * tier,
	}


static func average_item_budget(item_tier: int) -> Dictionary:
	var totals := full_loadout_budget(float(item_tier))
	return {
		"primary": totals.primary / GEAR_SLOT_COUNT,
		"stamina": totals.stamina / GEAR_SLOT_COUNT,
		"secondary": totals.secondary / GEAR_SLOT_COUNT,
	}


static func reference_stats(gear_tier: float) -> Dictionary:
	var tier := maxf(0.0, gear_tier)
	var secondary_gain := SECONDARY_PER_LOADOUT_TIER * tier
	return {
		"strength": BASE_STRENGTH + PRIMARY_PER_LOADOUT_TIER * tier,
		"agility": BASE_AGILITY,
		"intellect": BASE_INTELLECT,
		"stamina": BASE_STAMINA + STAMINA_PER_LOADOUT_TIER * tier,
		"mastery": BASE_MASTERY + secondary_gain * FURY_MASTERY_WEIGHT,
		"haste": BASE_HASTE + secondary_gain * FURY_HASTE_WEIGHT,
		"critical_strike": BASE_CRITICAL_STRIKE + secondary_gain * FURY_CRITICAL_WEIGHT,
		"versatility": BASE_VERSATILITY + secondary_gain * FURY_VERSATILITY_WEIGHT,
	}


static func normal_enemy_stats(floor_number: int) -> Dictionary:
	var tier := maxf(0.0, float(floor_number - 1))
	return {
		"max_health": BASE_NORMAL_HEALTH * pow(OFFENSE_GROWTH_PER_TIER, tier),
		"damage": BASE_NORMAL_DAMAGE * pow(DEFENSE_GROWTH_PER_TIER, tier),
		"attack_interval": 1.75,
	}


static func boss_health(floor_number: int) -> float:
	var tier_delta := float(floor_number - FIRST_BOSS_FLOOR)
	return FIRST_BOSS_HEALTH * pow(OFFENSE_GROWTH_PER_TIER, tier_delta)


static func boss_heavy_damage(floor_number: int) -> float:
	var tier_delta := float(floor_number - FIRST_BOSS_FLOOR)
	return FIRST_BOSS_HEAVY_DAMAGE * pow(DEFENSE_GROWTH_PER_TIER, tier_delta)


static func boss_enemy_stats(floor_number: int) -> Dictionary:
	return {
		"max_health": boss_health(floor_number),
		"damage": boss_heavy_damage(floor_number),
		"attack_interval": 4.0,
	}


static func estimated_normal_kill_time(floor_number: int, gear_tier: float) -> float:
	var gap := float(expected_gear_tier(floor_number)) - gear_tier
	return BASE_NORMAL_KILL_TIME * pow(OFFENSE_GROWTH_PER_TIER, gap)


static func estimated_boss_kill_time(floor_number: int, gear_tier: float) -> float:
	var gap := float(expected_gear_tier(floor_number)) - gear_tier
	return BOSS_TARGET_KILL_TIME * pow(OFFENSE_GROWTH_PER_TIER, gap)


static func gear_gap(floor_number: int, gear_tier: float) -> float:
	return float(expected_gear_tier(floor_number)) - gear_tier


static func boss_readiness(floor_number: int, gear_tier: float) -> String:
	var gap := gear_gap(floor_number, gear_tier)
	if gap <= 1.0:
		return "ready"
	if gap <= 2.0:
		return "risky"
	return "wall"
