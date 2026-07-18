extends "res://src/main/fury_combat_controller.gd"


const EquipmentInventoryModel = preload("res://src/gameplay/equipment_inventory.gd")

var equipment_inventory = EquipmentInventoryModel.new()
var last_dropped_item: Dictionary = {}
var active_talent_ids: Array[String] = []
var barrier_refund_pending := 0.0
var immovable_counter_stored := 0.0


func _ready() -> void:
	super._ready()
	equipment_inventory.rng.randomize()
	print("Idle Rift equipment drops, backpack and talent hooks loaded.")


func set_talent_enabled(talent_id: String, enabled: bool) -> bool:
	if battle_state == BattleState.FIGHTING:
		return false
	if talent_id not in FuryRules.GUARD_TALENT_IDS \
	and talent_id not in FuryRules.FURY_TALENT_IDS \
	and talent_id not in FuryRules.BLOOD_TALENT_IDS:
		return false
	if enabled and talent_id not in active_talent_ids:
		active_talent_ids.append(talent_id)
	elif not enabled:
		active_talent_ids.erase(talent_id)
	_apply_talent_stat_modifiers()
	return true


func is_talent_enabled(talent_id: String) -> bool:
	return talent_id in active_talent_ids


func _apply_talent_stat_modifiers() -> void:
	hero_stats.max_health_multiplier = FuryRules.THICK_SINEW_HEALTH_MULTIPLIER \
		if is_talent_enabled(FuryRules.THICK_SINEW_TALENT_ID) else 1.0
	hero_health = minf(hero_health, hero_stats.max_health())


func _start_battle() -> void:
	_apply_talent_stat_modifiers()
	barrier_refund_pending = 0.0
	immovable_counter_stored = 0.0
	super._start_battle()


func _is_skill_available(skill_id: String, skill: Dictionary) -> bool:
	# The final gameplay rule is a pure player-authored cycle. Defense skills may
	# check their own cooldown and resource, but never inspect the enemy timeline.
	if skill_id == "rage_barrier":
		return skill_cooldowns.get(skill_id, 0.0) <= 0.0 and hero_resource > 0.0
	return super._is_skill_available(skill_id, skill)


func _tick_skill_cooldowns(delta: float) -> void:
	var steady_rage := is_talent_enabled(FuryRules.STEADY_RAGE_TALENT_ID)
	for skill_id in skill_cooldowns:
		var recovery_multiplier := FuryRules.cooldown_recovery_multiplier(
			skill_id,
			hero_stats.haste,
			steady_rage,
		)
		skill_cooldowns[skill_id] = maxf(
			0.0,
			skill_cooldowns[skill_id] - delta * recovery_multiplier,
		)


func _cast_fury_skill(skill_id: String, skill: Dictionary, skipped_count: int) -> void:
	if skill_id != "rage_barrier":
		super._cast_fury_skill(skill_id, skill, skipped_count)
		return
	var notes := PackedStringArray()
	if skipped_count > 0:
		notes.append("跳过 %d 个不可用技能" % skipped_count)
	var rage_spent := hero_resource
	skill_cooldowns[skill_id] = skill["cooldown"]
	var barrier_gained := FuryRules.barrier_amount(
		rage_spent,
		hero_stats.haste,
		is_talent_enabled(FuryRules.STEADY_RAGE_TALENT_ID),
	)
	hero_shield = minf(
		FuryRules.barrier_cap(hero_stats.max_health()),
		hero_shield + barrier_gained,
	)
	hero_resource = 0.0
	if is_talent_enabled(FuryRules.SHIELD_REFLOW_TALENT_ID):
		barrier_refund_pending += FuryRules.shield_reflow_refund(rage_spent)
	else:
		barrier_refund_pending = 0.0
	if is_talent_enabled(FuryRules.STEADY_RAGE_TALENT_ID):
		notes.append("稳定怒意将急速转化为 %.0f 护盾" % barrier_gained)
	else:
		notes.append("%.0f 怒意转化为 %.0f 护盾" % [rage_spent, barrier_gained])
	if hero_shield >= FuryRules.barrier_cap(hero_stats.max_health()):
		notes.append("护盾达到生命值上限")
	# Rage Barrier receives no burst gain or cost benefit, so it must not waste a
	# Fury Burst charge merely because it appears inside the strict skill cycle.
	battle_event.text = "释放 %s · %s" % [skill["name"], "，".join(notes)]


func _take_hero_damage(raw_damage: float, source_name: String) -> void:
	var damage := raw_damage * hero_stats.damage_taken_multiplier()
	var absorbed := minf(hero_shield, damage)
	hero_shield -= absorbed
	damage -= absorbed
	var notes := PackedStringArray()
	if absorbed > 0.0:
		notes.append("护盾吸收 %.0f" % absorbed)
		if barrier_refund_pending > 0.0:
			var refund := barrier_refund_pending
			barrier_refund_pending = 0.0
			hero_resource = minf(FuryRules.MAX_RAGE, hero_resource + refund)
			notes.append("怒盾回流 %.0f 怒意" % refund)
		if is_talent_enabled(FuryRules.IMMOVABLE_TALENT_ID):
			var gained_counter := FuryRules.immovable_counter_damage(
				absorbed,
				hero_stats.attack_power(),
			)
			immovable_counter_stored = minf(
				hero_stats.attack_power() * FuryRules.IMMOVABLE_ATTACK_POWER_CAP,
				immovable_counter_stored + gained_counter,
			)
			notes.append("储存 %.0f 反击伤害" % gained_counter)
	hero_health = maxf(0.0, hero_health - damage)
	battle_event.text = "%s 造成 %.0f 伤害" % [source_name, damage]
	if not notes.is_empty():
		battle_event.text += " · " + "，".join(notes)
	if hero_health <= 0.0:
		_return_to_preparation("挑战失败。调整怒意循环与壁垒时机后重试。")


func _spender_counter_damage(_skill_id: String) -> float:
	if not is_talent_enabled(FuryRules.IMMOVABLE_TALENT_ID):
		return 0.0
	return immovable_counter_stored


func _consume_spender_counter_damage(_skill_id: String) -> void:
	immovable_counter_stored = 0.0


func _builder_base_rage_bonus(skill_id: String) -> float:
	if skill_id == "rage_builder" \
	and is_talent_enabled(FuryRules.BOILING_SPIRIT_TALENT_ID):
		return FuryRules.BOILING_SPIRIT_BASE_RAGE_BONUS
	return 0.0


func _burst_charge_count() -> int:
	return FuryRules.burst_charge_count(
		is_talent_enabled(FuryRules.CHAINED_BURST_TALENT_ID),
	)


func _spender_damage_multiplier(skill_id: String) -> float:
	if skill_id in ["single_spender", "aoe_spender"]:
		return FuryRules.spender_talent_damage_multiplier(
			is_talent_enabled(FuryRules.PRECISE_RELEASE_TALENT_ID),
		)
	return 1.0


func _burst_spender_refund(
	skill_id: String,
	was_burst_active: bool,
	rage_spent: float,
) -> float:
	if skill_id not in ["single_spender", "aoe_spender"] or not was_burst_active:
		return 0.0
	return FuryRules.endless_frenzy_refund(
		rage_spent,
		is_talent_enabled(FuryRules.ENDLESS_FRENZY_TALENT_ID),
	)


func _bleed_damage_multiplier() -> float:
	return FuryRules.bleed_talent_damage_multiplier(
		is_talent_enabled(FuryRules.CARVED_WOUNDS_TALENT_ID),
	)


func _dot_heal_conversion_ratio() -> float:
	return FuryRules.dot_heal_conversion_ratio(
		is_talent_enabled(FuryRules.BLOOD_MEMORY_TALENT_ID),
	)


func _dot_heal_cap_ratio() -> float:
	return FuryRules.dot_heal_cap_ratio(
		is_talent_enabled(FuryRules.BLOOD_MEMORY_TALENT_ID),
	)


func _bleed_leech_ratio() -> float:
	return FuryRules.bleed_leech_ratio(
		is_talent_enabled(FuryRules.THIRSTING_WOUNDS_TALENT_ID),
	)


func _resolve_enemy_defeat() -> void:
	if enemy_health > 0.0:
		return
	if Rules.is_boss_floor(current_floor):
		var first_clear := current_floor not in defeated_boss_floors
		last_dropped_item = equipment_inventory.grant_boss_drop(current_floor, first_clear)
		_on_boss_defeated()
		battle_event.text += " 获得：%s。" % EquipmentInventoryModel.Rules.item_display_name(last_dropped_item)
		loot_count += 1
		return
	ordinary_kills += 1
	last_dropped_item = equipment_inventory.roll_normal_drop(current_floor)
	respawn_timer = NORMAL_RESPAWN_DELAY
	enemy_name.text = "正在寻找下一名敌人……"
	if last_dropped_item.is_empty():
		battle_event.text = "击杀完成，本次没有装备掉落。"
		return
	loot_count += 1
	var upgrade_mark := " · 可能提升" if equipment_inventory.is_potential_upgrade(last_dropped_item) else ""
	battle_event.text = "装备掉落：%s%s" % [
		EquipmentInventoryModel.Rules.item_display_name(last_dropped_item),
		upgrade_mark,
	]
