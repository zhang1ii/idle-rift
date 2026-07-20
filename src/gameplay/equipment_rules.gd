class_name EquipmentRules
extends RefCounted


const Progression = preload("res://src/gameplay/progression_model.gd")

const ARMOR_SLOTS: Array[String] = [
	"head", "shoulders", "chest", "wrists",
	"hands", "waist", "legs", "feet",
]
const EQUIPMENT_TARGETS: Array[String] = [
	"weapon",
	"head", "shoulders", "chest", "wrists",
	"hands", "waist", "legs", "feet",
	"ring_1", "ring_2",
	"trinket_1", "trinket_2",
]
const DROP_SLOT_POOL: Array[String] = [
	"weapon",
	"head", "shoulders", "chest", "wrists",
	"hands", "waist", "legs", "feet",
	"ring", "ring",
	"trinket", "trinket",
]
const AFFIX_IDS: Array[String] = [
	"mastery", "haste", "critical_strike", "versatility",
]
const SET_THRESHOLDS: Array[int] = [2, 4, 5]

const ONLINE_DROP_CHANCE := 0.03
const OFFLINE_EFFICIENCY := 0.60
const REPEAT_BOSS_SET_CHANCE := 0.35
const SET_POWER := 1.00
const DROP_TENDENCY_CHANCE := 0.65

const SLOT_WEIGHTS := {
	"weapon": 1.50,
	"head": 1.00,
	"shoulders": 0.80,
	"chest": 1.20,
	"wrists": 0.60,
	"hands": 0.80,
	"waist": 0.80,
	"legs": 1.20,
	"feet": 0.80,
	"ring": 0.60,
	"trinket": 0.80,
}
const PRIMARY_SLOT_WEIGHTS := {
	"weapon": 1.50,
	"head": 1.00,
	"shoulders": 0.80,
	"chest": 1.20,
	"wrists": 0.60,
	"hands": 0.80,
	"waist": 0.80,
	"legs": 1.20,
	"feet": 0.80,
	"ring": 0.00,
	"trinket": 0.00,
}
const TOTAL_SLOT_WEIGHT := 11.50
const TOTAL_PRIMARY_SLOT_WEIGHT := 8.70

const QUALITY_ORDER: Array[String] = [
	"common", "uncommon", "rare", "epic", "legendary",
]
const QUALITY_DATA := {
	"common": {
		"name": "普通", "base_multiplier": 0.70,
		"affix_min": 0.0, "affix_max": 0.0, "sell_base": 1,
	},
	"uncommon": {
		"name": "优秀", "base_multiplier": 0.85,
		"affix_min": 0.70, "affix_max": 0.85, "sell_base": 3,
	},
	"rare": {
		"name": "稀有", "base_multiplier": 1.00,
		"affix_min": 0.85, "affix_max": 1.00, "sell_base": 7,
	},
	"epic": {
		"name": "史诗", "base_multiplier": 1.12,
		"affix_min": 1.00, "affix_max": 1.15, "sell_base": 15,
	},
	"legendary": {
		"name": "传说", "base_multiplier": 1.25,
		"affix_min": 1.15, "affix_max": 1.35, "sell_base": 30,
	},
}

const SET_DEFINITIONS := {
	"blood_mark": {
		"name": "血痕战甲",
		"affixes": ["mastery", "critical_strike"],
		"bonuses": {
			2: "流血伤害提高 10%",
			4: "流血可按角色 50% 的暴击率造成 150% 伤害",
			5: "泄怒命中流血目标时额外触发一次 125% 流血伤害",
		},
	},
	"frenzy_tide": {
		"name": "狂潮战甲",
		"affixes": ["haste", "mastery"],
		"bonuses": {
			2: "怒意获取提高 10%",
			4: "爆发强化期间技能冷却恢复速度提高 15%",
			5: "最后一层爆发强化返还 20 怒意并缩短爆发冷却 4 秒",
		},
	},
	"iron_vow": {
		"name": "铁誓战甲",
		"affixes": ["versatility", "haste"],
		"bonuses": {
			2: "怒意壁垒护盾量提高 12%",
			4: "护盾存在期间受到的伤害降低 10%",
			5: "护盾破裂后获得一次 25% 减伤并回复 15 怒意（12 秒冷却）",
		},
	},
}
const FLOOR_DROP_PROFILES := {
	1: {"name": "锋刃与重甲", "slots": ["weapon", "head", "chest"], "affixes": ["critical_strike", "versatility"]},
	2: {"name": "血痕遗物", "slots": ["shoulders", "wrists", "hands"], "affixes": ["mastery", "critical_strike"]},
	3: {"name": "守誓护具", "slots": ["waist", "legs", "feet"], "affixes": ["versatility", "haste"]},
	4: {"name": "迅捷饰件", "slots": ["ring", "trinket"], "affixes": ["haste", "critical_strike"]},
}


static func canonical_slot(slot_id: String) -> String:
	if slot_id.begins_with("ring"):
		return "ring"
	if slot_id.begins_with("trinket"):
		return "trinket"
	return slot_id


static func valid_targets(item_slot: String) -> Array[String]:
	match canonical_slot(item_slot):
		"ring":
			return ["ring_1", "ring_2"]
		"trinket":
			return ["trinket_1", "trinket_2"]
		_:
			return [canonical_slot(item_slot)]


static func item_budget(item_tier: int, slot_id: String) -> Dictionary:
	var tier := maxf(0.0, float(item_tier))
	var slot := canonical_slot(slot_id)
	var weight: float = SLOT_WEIGHTS.get(slot, 0.0)
	var primary_weight: float = PRIMARY_SLOT_WEIGHTS.get(slot, 0.0)
	return {
		"primary": Progression.PRIMARY_PER_LOADOUT_TIER * tier * primary_weight / TOTAL_PRIMARY_SLOT_WEIGHT,
		"stamina": Progression.STAMINA_PER_LOADOUT_TIER * tier * weight / TOTAL_SLOT_WEIGHT,
		"secondary": Progression.SECONDARY_PER_LOADOUT_TIER * tier * weight / TOTAL_SLOT_WEIGHT,
	}


static func roll_quality(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	if roll < 0.45:
		return "common"
	if roll < 0.75:
		return "uncommon"
	if roll < 0.92:
		return "rare"
	if roll < 0.99:
		return "epic"
	return "legendary"


static func create_normal_item(
	rng: RandomNumberGenerator,
	item_tier: int,
	forced_slot := "",
	forced_quality := "",
	preferred_affixes: Array[String] = [],
) -> Dictionary:
	var slot := canonical_slot(forced_slot)
	if slot.is_empty():
		slot = DROP_SLOT_POOL[rng.randi_range(0, DROP_SLOT_POOL.size() - 1)]
	var quality := forced_quality if not forced_quality.is_empty() else roll_quality(rng)
	var quality_data: Dictionary = QUALITY_DATA[quality]
	var budget := item_budget(item_tier, slot)
	var affixes := {}
	if quality != "common":
		var available := AFFIX_IDS.duplicate()
		var first_affix := ""
		var valid_preferences: Array[String] = []
		for affix_id in preferred_affixes:
			if affix_id in available:
				valid_preferences.append(affix_id)
		if not valid_preferences.is_empty() and rng.randf() < DROP_TENDENCY_CHANCE:
			first_affix = valid_preferences[rng.randi_range(0, valid_preferences.size() - 1)]
		else:
			first_affix = available[rng.randi_range(0, available.size() - 1)]
		available.erase(first_affix)
		var second_affix: String = available[rng.randi_range(0, available.size() - 1)]
		var roll_multiplier := rng.randf_range(
			quality_data.affix_min, quality_data.affix_max)
		var total_secondary: float = budget.secondary * roll_multiplier
		var first_share := rng.randf_range(0.45, 0.55)
		affixes[first_affix] = total_secondary * first_share
		affixes[second_affix] = total_secondary * (1.0 - first_share)
	var special_effect := ""
	if quality == "legendary" and slot in ["ring", "trinket"]:
		special_effect = _roll_special_effect(rng, slot)
	return {
		"instance_id": 0,
		"slot": slot,
		"item_tier": item_tier,
		"quality": quality,
		"primary": budget.primary * quality_data.base_multiplier,
		"stamina": budget.stamina * quality_data.base_multiplier,
		"affixes": affixes,
		"special_effect": special_effect,
		"effect_power": 1.0 if not special_effect.is_empty() else 0.0,
		"set_id": "",
		"set_power": 0.0,
	}

static func create_floor_item(rng: RandomNumberGenerator, item_tier: int, floor_number: int) -> Dictionary:
	var profile := floor_drop_profile(floor_number)
	var forced_slot := ""
	if rng.randf() < DROP_TENDENCY_CHANCE:
		var slots: Array = profile.slots
		forced_slot = String(slots[rng.randi_range(0, slots.size() - 1)])
	var preferences: Array[String] = []
	preferences.assign(profile.affixes)
	return create_normal_item(rng, item_tier, forced_slot, "", preferences)


static func create_set_item(
	rng: RandomNumberGenerator,
	item_tier: int,
	set_id: String,
	forced_slot := "",
) -> Dictionary:
	assert(SET_DEFINITIONS.has(set_id))
	var slot := canonical_slot(forced_slot)
	if slot.is_empty() or slot not in ARMOR_SLOTS:
		slot = ARMOR_SLOTS[rng.randi_range(0, ARMOR_SLOTS.size() - 1)]
	var budget := item_budget(item_tier, slot)
	var definition: Dictionary = SET_DEFINITIONS[set_id]
	var fixed_affixes: Array = definition.affixes
	var affixes := {
		fixed_affixes[0]: budget.secondary * 0.55,
		fixed_affixes[1]: budget.secondary * 0.45,
	}
	return {
		"instance_id": 0,
		"slot": slot,
		"item_tier": item_tier,
		"quality": "epic",
		"primary": budget.primary * QUALITY_DATA.epic.base_multiplier,
		"stamina": budget.stamina * QUALITY_DATA.epic.base_multiplier,
		"affixes": affixes,
		"special_effect": "",
		"effect_power": 0.0,
		"set_id": set_id,
		"set_power": SET_POWER,
	}


static func item_score(item: Dictionary) -> float:
	var secondary_total := 0.0
	for value in item.affixes.values():
		secondary_total += float(value)
	var special_score := 4.0 if not item.special_effect.is_empty() else 0.0
	return item.primary + item.stamina * 0.35 + secondary_total * 0.60 + special_score


static func active_set_bonuses(equipped: Dictionary) -> Array[Dictionary]:
	var groups := {}
	for target in equipped:
		var item: Dictionary = equipped[target]
		var set_id: String = item.get("set_id", "")
		if set_id.is_empty() or target not in ARMOR_SLOTS:
			continue
		if not groups.has(set_id):
			groups[set_id] = {"pieces": 0, "power_total": 0.0}
		groups[set_id].pieces += 1
		groups[set_id].power_total += float(item.get("set_power", 0.0))
	var active: Array[Dictionary] = []
	for set_id in groups:
		var group: Dictionary = groups[set_id]
		var piece_count: int = group.pieces
		var average_power: float = group.power_total / piece_count
		for threshold in SET_THRESHOLDS:
			if piece_count >= threshold:
				active.append({
					"set_id": set_id,
					"set_name": SET_DEFINITIONS[set_id].name,
					"threshold": threshold,
					"power": average_power,
					"description": SET_DEFINITIONS[set_id].bonuses[threshold],
				})
	return active

static func floor_drop_profile(floor_number: int) -> Dictionary:
	if floor_number > 0 and floor_number % 5 == 0:
		return {"name": "守关者珍藏", "slots": ARMOR_SLOTS, "affixes": AFFIX_IDS}
	var position := posmod(floor_number - 1, 5) + 1
	return FLOOR_DROP_PROFILES.get(position, FLOOR_DROP_PROFILES[1])

static func floor_drop_preview(floor_number: int) -> String:
	if floor_number > 0 and floor_number % 5 == 0:
		return "守关者珍藏 · 可能掉落三套职业套装或史诗散件"
	var profile := floor_drop_profile(floor_number)
	var slot_names := PackedStringArray()
	for slot_id in profile.slots:
		slot_names.append(_slot_display_name(String(slot_id)))
	var affix_names := PackedStringArray()
	for affix_id in profile.affixes:
		affix_names.append(_affix_display_name(String(affix_id)))
	return "%s · 倾向 %s · %s" % [profile.name, "/".join(slot_names), "/".join(affix_names)]


static func item_display_name(item: Dictionary) -> String:
	var prefix: String = QUALITY_DATA[item.quality].name
	if not item.set_id.is_empty():
		prefix = SET_DEFINITIONS[item.set_id].name
	return "%s · T%d %s" % [prefix, item.item_tier, item.slot]


static func _roll_special_effect(rng: RandomNumberGenerator, slot: String) -> String:
	var ring_effects := ["暴击后短暂提高急速", "流血跳伤有概率返还怒意"]
	var trinket_effects := ["周期性提高力量", "低生命时获得临时护盾"]
	var effects: Array = ring_effects if slot == "ring" else trinket_effects
	return effects[rng.randi_range(0, effects.size() - 1)]

static func _slot_display_name(slot_id: String) -> String:
	match slot_id:
		"weapon": return "武器"
		"head": return "头盔"
		"shoulders": return "肩甲"
		"chest": return "胸甲"
		"wrists": return "护腕"
		"hands": return "手套"
		"waist": return "腰带"
		"legs": return "腿甲"
		"feet": return "鞋子"
		"ring": return "戒指"
		"trinket": return "饰品"
		_: return slot_id

static func _affix_display_name(affix_id: String) -> String:
	match affix_id:
		"mastery": return "精通"
		"haste": return "急速"
		"critical_strike": return "暴击"
		"versatility": return "全能"
		_: return affix_id
