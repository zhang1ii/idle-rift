extends RefCounted


const MAX_RAGE := 100.0
const ATTACK_COOLDOWN := 4.0
const BLEED_TICKS := 4
const BLEED_INTERVAL := 1.0
const BOILING_SPIRIT_TALENT_ID := "boiling_spirit"
const CHAINED_BURST_TALENT_ID := "chained_burst"
const PRECISE_RELEASE_TALENT_ID := "precise_release"
const ENDLESS_FRENZY_TALENT_ID := "endless_frenzy"
const FURY_TALENT_IDS: Array[String] = [
	BOILING_SPIRIT_TALENT_ID,
	CHAINED_BURST_TALENT_ID,
	PRECISE_RELEASE_TALENT_ID,
	ENDLESS_FRENZY_TALENT_ID,
]
const CARVED_WOUNDS_TALENT_ID := "carved_wounds"
const BLOOD_MEMORY_TALENT_ID := "blood_memory"
const THIRSTING_WOUNDS_TALENT_ID := "thirsting_wounds"
const BLOOD_TALENT_IDS: Array[String] = [
	CARVED_WOUNDS_TALENT_ID,
	BLOOD_MEMORY_TALENT_ID,
	THIRSTING_WOUNDS_TALENT_ID,
]
const THICK_SINEW_TALENT_ID := "thick_sinew"
const STEADY_RAGE_TALENT_ID := "steady_rage"
const SHIELD_REFLOW_TALENT_ID := "shield_reflow"
const IMMOVABLE_TALENT_ID := "immovable"
const GUARD_TALENT_IDS: Array[String] = [
	THICK_SINEW_TALENT_ID,
	STEADY_RAGE_TALENT_ID,
	SHIELD_REFLOW_TALENT_ID,
	IMMOVABLE_TALENT_ID,
]
const THICK_SINEW_HEALTH_MULTIPLIER := 1.08
const BOILING_SPIRIT_BASE_RAGE_BONUS := 5.0
const BASE_BURST_CHARGES := 3
const CHAINED_BURST_CHARGE_BONUS := 1
const PRECISE_RELEASE_DAMAGE_MULTIPLIER := 1.15
const ENDLESS_FRENZY_REFUND_RATIO := 0.20
const CARVED_WOUNDS_BLEED_MULTIPLIER := 1.15
const BASE_DOT_HEAL_CONVERSION_RATIO := 0.75
const BASE_DOT_HEAL_CAP_RATIO := 0.35
const BLOOD_MEMORY_CONVERSION_RATIO := 0.90
const BLOOD_MEMORY_HEAL_CAP_RATIO := 0.40
const THIRSTING_WOUNDS_LEECH_RATIO := 0.08
const STEADY_RAGE_HASTE_TO_BARRIER := 0.01
const SHIELD_REFLOW_REFUND_RATIO := 0.20
const IMMOVABLE_ABSORB_TO_DAMAGE := 0.40
const IMMOVABLE_ATTACK_POWER_CAP := 1.0


static func skill_catalog() -> Dictionary:
	return {
		"rage_builder": {
			"name": "撕裂打击",
			"kind": "attack",
			"cooldown": ATTACK_COOLDOWN,
			"damage_multiplier": 0.60,
			"base_rage_gain": 25.0,
			"base_rage_cost": 0.0,
			"description": "攒怒并施加精通流血",
		},
		"fury_burst": {
			"name": "狂怒爆发",
			"kind": "buff",
			"cooldown": 16.0,
			"damage_multiplier": 0.0,
			"base_rage_gain": 0.0,
			"base_rage_cost": 0.0,
			"description": "强化后续 3 个技能的攒怒与消耗",
		},
		"dot_heal": {
			"name": "鲜血回响",
			"kind": "heal",
			"cooldown": 8.0,
			"damage_multiplier": 0.0,
			"base_rage_gain": 0.0,
			"base_rage_cost": 0.0,
			"description": "消耗已记录的 DOT 伤害进行治疗",
		},
		"single_spender": {
			"name": "毁灭猛击",
			"kind": "attack",
			"cooldown": ATTACK_COOLDOWN,
			"damage_multiplier": 2.20,
			"base_rage_gain": 0.0,
			"base_rage_cost": 50.0,
			"description": "高额单体泄怒技能",
		},
		"aoe_spender": {
			"name": "血怒旋风",
			"kind": "attack",
			"cooldown": ATTACK_COOLDOWN,
			"damage_multiplier": 1.10,
			"base_rage_gain": 0.0,
			"base_rage_cost": 40.0,
			"description": "AOE 泄怒并施加精通流血",
		},
		"rage_barrier": {
			"name": "怒意壁垒",
			"kind": "defense",
			"cooldown": 12.0,
			"damage_multiplier": 0.0,
			"base_rage_gain": 0.0,
			"base_rage_cost": 0.0,
			"description": "将当前全部怒意转化为护盾",
		},
	}


static func rage_gain(base_gain: float, mastery_percent: float) -> float:
	return base_gain * (1.0 + maxf(0.0, mastery_percent) / 100.0)


static func builder_base_rage_gain(base_gain: float, boiling_spirit_enabled: bool) -> float:
	return maxf(0.0, base_gain) + (
		BOILING_SPIRIT_BASE_RAGE_BONUS if boiling_spirit_enabled else 0.0
	)


static func burst_gain_bonus(mastery_percent: float) -> float:
	return 0.40 + maxf(0.0, mastery_percent) / 200.0


static func burst_charge_count(chained_burst_enabled: bool) -> int:
	return BASE_BURST_CHARGES + (
		CHAINED_BURST_CHARGE_BONUS if chained_burst_enabled else 0
	)


static func spender_talent_damage_multiplier(precise_release_enabled: bool) -> float:
	return PRECISE_RELEASE_DAMAGE_MULTIPLIER if precise_release_enabled else 1.0


static func endless_frenzy_refund(rage_spent: float, endless_frenzy_enabled: bool) -> float:
	if not endless_frenzy_enabled:
		return 0.0
	return maxf(0.0, rage_spent) * ENDLESS_FRENZY_REFUND_RATIO


static func bleed_talent_damage_multiplier(carved_wounds_enabled: bool) -> float:
	return CARVED_WOUNDS_BLEED_MULTIPLIER if carved_wounds_enabled else 1.0


static func dot_heal_conversion_ratio(blood_memory_enabled: bool) -> float:
	return BLOOD_MEMORY_CONVERSION_RATIO \
		if blood_memory_enabled else BASE_DOT_HEAL_CONVERSION_RATIO


static func dot_heal_cap_ratio(blood_memory_enabled: bool) -> float:
	return BLOOD_MEMORY_HEAL_CAP_RATIO if blood_memory_enabled else BASE_DOT_HEAL_CAP_RATIO


static func bleed_leech_ratio(thirsting_wounds_enabled: bool) -> float:
	return THIRSTING_WOUNDS_LEECH_RATIO if thirsting_wounds_enabled else 0.0


static func burst_cost_reduction(mastery_percent: float) -> float:
	return clampf(0.20 + maxf(0.0, mastery_percent) / 200.0, 0.0, 0.70)


static func mastery_damage_multiplier(mastery_percent: float) -> float:
	return 1.0 + maxf(0.0, mastery_percent) / 100.0


static func barrier_amount(
	rage_spent: float,
	haste_percent := 0.0,
	steady_rage_enabled := false,
) -> float:
	var amount := maxf(0.0, rage_spent) * 1.20
	if steady_rage_enabled:
		amount *= steady_rage_power_multiplier(haste_percent)
	return amount


static func steady_rage_power_multiplier(haste_percent: float) -> float:
	return 1.0 + maxf(0.0, haste_percent) * STEADY_RAGE_HASTE_TO_BARRIER


static func barrier_cap(max_health: float) -> float:
	return maxf(0.0, max_health)


static func shield_reflow_refund(rage_spent: float) -> float:
	return maxf(0.0, rage_spent) * SHIELD_REFLOW_REFUND_RATIO


static func immovable_counter_damage(
	absorbed_damage: float,
	attack_power: float,
) -> float:
	return minf(
		maxf(0.0, absorbed_damage) * IMMOVABLE_ABSORB_TO_DAMAGE,
		maxf(0.0, attack_power) * IMMOVABLE_ATTACK_POWER_CAP,
	)


static func cooldown_recovery_multiplier(
	skill_id: String,
	haste_percent: float,
	steady_rage_enabled: bool,
) -> float:
	if steady_rage_enabled and skill_id == "rage_barrier":
		return 1.0
	return 1.0 + maxf(0.0, haste_percent) / 100.0
