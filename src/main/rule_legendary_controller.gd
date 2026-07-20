extends "res://src/main/loop_experiment_controller.gd"


const FUSION_RATIO := LegendaryEffects.FUSION_ECHO_RATIO

var pending_fusion_echo_ids: Array[String] = []
var counter_plating_charges := 0
var prevented_disruptions := 0
var fusion_casts := 0
var last_scarcity_unavailable := 0


func _ready() -> void:
	super._ready()
	_grant_prototype_rule_items()
	_refresh_all_ui()
	print("Idle Rift rule-changing legendary experiment loaded.")


func _start_battle() -> void:
	pending_fusion_echo_ids.clear()
	counter_plating_charges = 0
	prevented_disruptions = 0
	fusion_casts = 0
	last_scarcity_unavailable = 0
	super._start_battle()


func _is_skill_available(skill_id: String, skill: Dictionary) -> bool:
	if _is_sourceless_mode() and _is_energy_spender(skill):
		return float(skill_cooldowns.get(skill_id, 0.0)) <= 0.0
	return super._is_skill_available(skill_id, skill)


func _hero_take_action() -> void:
	var skipped := PackedStringArray()
	var fusion_echoes: Array[String] = []
	for offset in skill_order.size():
		var index := (skill_cursor + offset) % skill_order.size()
		var skill_id := skill_order[index]
		var skill: Dictionary = skill_catalog[skill_id]
		if _consume_boss_disruption(index):
			_record_skill_skip(skill_id)
			if equipment_inventory.has_special_effect(LegendaryEffects.RIFT_FUSER):
				fusion_echoes.append(skill_id)
				skipped.append("%s（裂化熔接）" % skill["name"])
			else:
				skipped.append("%s（技能格裂化）" % skill["name"])
			continue
		if not _is_skill_available(skill_id, skill):
			skipped.append(skill["name"])
			_record_skill_skip(skill_id)
			continue
		pending_fusion_echo_ids.assign(fusion_echoes)
		var outcome := loop_tracker.record_cast(index, skipped.size())
		skill_cursor = (index + 1) % skill_order.size()
		_cast_fury_skill(skill_id, skill, skipped.size())
		fusion_casts += fusion_echoes.size()
		pending_fusion_echo_ids.clear()
		_resolve_loop_outcome(outcome)
		return
	pending_fusion_echo_ids.clear()
	if loop_tracker.progress > 0:
		_resolve_loop_outcome(loop_tracker.record_wait())
	battle_event.text = "本轮五个技能均不可用，等待下一次出手机会。"


func _cast_fury_skill(skill_id: String, skill: Dictionary, skipped_count: int) -> void:
	var unavailable_other := _unavailable_other_skill_count(skill_id)
	var fusion_echoes: Array[String] = pending_fusion_echo_ids.duplicate()
	var health_before := enemy_health
	super._cast_fury_skill(skill_id, skill, skipped_count)
	var dealt := maxf(0.0, health_before - enemy_health)
	if _is_sourceless_mode() and _is_energy_spender(skill):
		battle_event.text += " · 无源炉心视作满额释放"
	if skill_id in ATTACK_SKILLS and dealt > 0.0:
		_apply_rule_attack_bonuses(dealt, unavailable_other)
	for echo_skill_id in fusion_echoes:
		if enemy_health <= 0.0:
			break
		_resolve_fusion_echo(echo_skill_id)


func _apply_rule_attack_bonuses(dealt: float, unavailable_other: int) -> void:
	var bonus_ratio := 0.0
	var notes := PackedStringArray()
	if equipment_inventory.has_special_effect(LegendaryEffects.LONE_CORE):
		last_scarcity_unavailable = unavailable_other
		var scarcity_ratio := LegendaryEffects.scarcity_bonus_ratio(unavailable_other)
		if scarcity_ratio > 0.0:
			bonus_ratio += scarcity_ratio
			notes.append("孤鸣核心%d格" % unavailable_other)
	if equipment_inventory.has_special_effect(LegendaryEffects.COUNTER_PLATING) \
	and counter_plating_charges > 0:
		counter_plating_charges -= 1
		bonus_ratio += LegendaryEffects.COUNTER_ATTACK_RATIO
		notes.append("反震装甲")
	if bonus_ratio <= 0.0 or enemy_health <= 0.0:
		return
	var bonus_damage := _apply_damage_to_enemy(dealt * bonus_ratio)
	battle_event.text += " · %s附加 %.0f 伤害" % ["+".join(notes), bonus_damage]
	_resolve_enemy_defeat()


func _cast_next_boss_ability() -> void:
	var ability_id: String = BossRules.ABILITY_CYCLE[boss_ability_cursor]
	var disrupted_slot := -1
	if ability_id == "slow":
		disrupted_slot = BOSS_DISRUPTION_SLOT_ORDER[
			floor_slow_stacks % BOSS_DISRUPTION_SLOT_ORDER.size()
		]
	var defense_covered: bool = (
		ability_id == "slow"
		and hero_shield > 0.0
		and equipment_inventory.has_special_effect(LegendaryEffects.COUNTER_PLATING)
	)
	super._cast_next_boss_ability()
	if not defense_covered or battle_state != BattleState.FIGHTING:
		return
	_remove_one_disruption(disrupted_slot)
	counter_plating_charges = 1
	prevented_disruptions += 1
	battle_event.text = (
		"Boss 击碎一块地板：出手频率降低。反震装甲保护第%d技能格，"
		+ "并强化下一次攻击。"
	) % (disrupted_slot + 1)
	_refresh_skill_order_ui()


func _refresh_skill_order_ui() -> void:
	super._refresh_skill_order_ui()
	if equipment_inventory.has_special_effect(LegendaryEffects.RIFT_FUSER):
		for label in skill_labels:
			label.text = label.text.replace("[裂化：下次跳过]", "[裂化：待熔接]")


func _refresh_combat_ui() -> void:
	super._refresh_combat_ui()
	if hero_action != null and battle_state == BattleState.FIGHTING:
		if _is_sourceless_mode():
			hero_action.text += " · 无源满额"
		if counter_plating_charges > 0:
			hero_action.text += " · 反震已充能"
	if enemy_action != null and prevented_disruptions > 0:
		enemy_action.text += " · 已防裂%d次" % prevented_disruptions


func _is_sourceless_mode() -> bool:
	if not equipment_inventory.has_special_effect(LegendaryEffects.SOURCELESS_FURNACE):
		return false
	for configured_skill_id in skill_order:
		var configured_skill: Dictionary = skill_catalog[configured_skill_id]
		if float(configured_skill.get("base_rage_gain", 0.0)) > 0.0:
			return false
	return true


func _is_energy_spender(skill: Dictionary) -> bool:
	return float(skill.get("base_rage_cost", 0.0)) > 0.0


func _unavailable_other_skill_count(current_skill_id: String) -> int:
	var current_index := skill_order.find(current_skill_id)
	var unavailable := 0
	for index in skill_order.size():
		if index == current_index:
			continue
		var other_id := skill_order[index]
		if other_id in pending_fusion_echo_ids \
		or int(boss_disrupted_slots.get(index, 0)) > 0 \
		or not _is_skill_available(other_id, skill_catalog[other_id]):
			unavailable += 1
	return unavailable


func _resolve_fusion_echo(skill_id: String) -> void:
	var skill: Dictionary = skill_catalog[skill_id]
	skill_cooldowns[skill_id] = maxf(
		float(skill_cooldowns.get(skill_id, 0.0)),
		float(skill["cooldown"]),
	)
	var detail := ""
	match skill_id:
		"fury_burst":
			var charges := maxi(1, roundi(_burst_charge_count() * FUSION_RATIO))
			burst_skills_remaining = maxi(burst_skills_remaining, charges)
			detail = "获得%d层爆发强化" % charges
		"dot_heal":
			detail = _resolve_fused_heal()
		"rage_barrier":
			detail = _resolve_fused_barrier()
		_:
			detail = _resolve_fused_attack(skill_id, skill)
	battle_event.text += " · 熔接【%s】70%%：%s" % [skill["name"], detail]


func _resolve_fused_heal() -> String:
	var bank_before := dot_damage_bank
	var healing := minf(
		bank_before * _dot_heal_conversion_ratio(),
		hero_stats.max_health() * _dot_heal_cap_ratio(),
	) * FUSION_RATIO
	hero_health = minf(hero_stats.max_health(), hero_health + healing)
	dot_damage_bank = bank_before * (1.0 - FUSION_RATIO)
	return "恢复%.0f生命" % healing


func _resolve_fused_barrier() -> String:
	var rage_spent := hero_resource
	var barrier := FuryRules.barrier_amount(
		rage_spent,
		hero_stats.haste,
		is_talent_enabled(FuryRules.STEADY_RAGE_TALENT_ID),
	) * FUSION_RATIO
	hero_shield = minf(
		FuryRules.barrier_cap(hero_stats.max_health()),
		hero_shield + barrier,
	)
	hero_resource = 0.0
	if is_talent_enabled(FuryRules.SHIELD_REFLOW_TALENT_ID):
		barrier_refund_pending += FuryRules.shield_reflow_refund(rage_spent) * FUSION_RATIO
	return "转化%.0f护盾" % barrier


func _resolve_fused_attack(skill_id: String, skill: Dictionary) -> String:
	var damage := (
		hero_stats.attack_power()
		* float(skill["damage_multiplier"])
		* hero_stats.outgoing_multiplier()
		* FUSION_RATIO
	)
	if skill_id in ["single_spender", "aoe_spender"]:
		damage *= FuryRules.mastery_damage_multiplier(hero_stats.mastery)
		damage *= _spender_damage_multiplier(skill_id)
	var actual_damage := _apply_damage_to_enemy(damage)
	var notes := PackedStringArray(["造成%.0f伤害" % actual_damage])
	if skill_id == "rage_builder":
		var rage_gain := FuryRules.rage_gain(
			float(skill["base_rage_gain"]) + _builder_base_rage_bonus(skill_id),
			hero_stats.mastery,
		) * FUSION_RATIO
		hero_resource = minf(FuryRules.MAX_RAGE, hero_resource + rage_gain)
		_apply_fusion_bleed(0.18)
		notes.append("获得%.0f怒意并施加流血" % rage_gain)
	elif skill_id == "aoe_spender":
		_apply_fusion_bleed(0.22)
		notes.append("施加流血")
	_resolve_enemy_defeat()
	return "，".join(notes)


func _apply_fusion_bleed(tick_multiplier: float) -> void:
	var candidate_damage := (
		hero_stats.attack_power()
		* tick_multiplier
		* hero_stats.outgoing_multiplier()
		* FuryRules.mastery_damage_multiplier(hero_stats.mastery)
		* _bleed_damage_multiplier()
		* FUSION_RATIO
	)
	bleed_tick_damage = maxf(bleed_tick_damage, candidate_damage)
	bleed_ticks_remaining = maxi(bleed_ticks_remaining, FuryRules.BLEED_TICKS)
	bleed_tick_timer = FuryRules.BLEED_INTERVAL


func _remove_one_disruption(slot_index: int) -> void:
	var charges := int(boss_disrupted_slots.get(slot_index, 0))
	if charges <= 1:
		boss_disrupted_slots.erase(slot_index)
	else:
		boss_disrupted_slots[slot_index] = charges - 1


func _grant_prototype_rule_items() -> void:
	for effect_id in LegendaryEffects.rule_ids():
		var item := EquipmentRulesScript.create_normal_item(
			equipment_inventory.rng,
			4,
			LegendaryEffects.effect_slot(effect_id),
			"legendary",
		)
		item["special_effect"] = effect_id
		equipment_inventory.add_item(item)
	initial_prototype_item_count += LegendaryEffects.rule_ids().size()
	if equipment_panel != null:
		equipment_panel.refresh()
	battle_event.text = "玩法测试：背包中已放入7件循环传奇，可在战前组合装备。"
