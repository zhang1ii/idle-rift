extends RefCounted


const MAX_RAGE := 100.0
const ATTACK_COOLDOWN := 4.0
const BLEED_TICKS := 4
const BLEED_INTERVAL := 1.0
const STEADY_RAGE_TALENT_ID := "steady_rage"
const STEADY_RAGE_HASTE_TO_BARRIER := 0.008


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


static func burst_gain_bonus(mastery_percent: float) -> float:
	return 0.40 + maxf(0.0, mastery_percent) / 200.0


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


static func cooldown_recovery_multiplier(
	skill_id: String,
	haste_percent: float,
	steady_rage_enabled: bool,
) -> float:
	if steady_rage_enabled and skill_id == "rage_barrier":
		return 1.0
	return 1.0 + maxf(0.0, haste_percent) / 100.0
