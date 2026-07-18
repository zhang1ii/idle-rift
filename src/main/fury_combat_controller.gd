extends "res://src/main/combat_ui_base.gd"


const FuryRules = preload("res://src/gameplay/fury_rules.gd")
const BossRules = preload("res://src/gameplay/boss_rules.gd")

var reserve_skill_id := "aoe_spender"
var reserve_skill_label: Label
var skill_swap_buttons: Array[Button] = []

var hero_shield := 0.0
var dot_damage_bank := 0.0
var bleed_tick_damage := 0.0
var burst_skills_remaining := 0
var intimidation_actions := 0
var boss_guard_charges := 0
var platforms_remaining := BossRules.PLATFORM_COUNT
var floor_slow_stacks := 0
var boss_ability_cursor := 0
var boss_ability_timer := BossRules.ABILITY_INTERVAL


func _ready() -> void:
	skill_catalog = FuryRules.skill_catalog()
	skill_order = [
		"rage_builder",
		"fury_burst",
		"dot_heal",
		"single_spender",
		"rage_barrier",
	]
	super._ready()
	for index in skill_swap_buttons.size():
		skill_swap_buttons[index].pressed.connect(_swap_with_reserve.bind(index))
	print("Idle Rift Fury Warrior and boss timeline loaded.")


func _process(delta: float) -> void:
	if battle_state != BattleState.FIGHTING:
		return
	_tick_skill_cooldowns(delta)
	if respawn_timer >= 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_spawn_enemy()
		return

	_process_fury_bleed(delta)
	if enemy_health <= 0.0 or battle_state != BattleState.FIGHTING:
		return

	hero_action_timer -= delta
	if hero_action_timer <= 0.0:
		_hero_take_action()
		hero_action_timer = _current_action_interval()

	if Rules.is_boss_floor(current_floor):
		boss_ability_timer -= delta
		if boss_ability_timer <= 0.0:
			_cast_next_boss_ability()
			boss_ability_timer = BossRules.ABILITY_INTERVAL
	else:
		enemy_action_timer -= delta
		if enemy_action_timer <= 0.0:
			_enemy_take_action()
			enemy_action_timer = enemy_attack_interval
	_refresh_combat_ui()


func _start_battle() -> void:
	hero_shield = 0.0
	dot_damage_bank = 0.0
	burst_skills_remaining = 0
	intimidation_actions = 0
	boss_guard_charges = 0
	platforms_remaining = BossRules.PLATFORM_COUNT
	floor_slow_stacks = 0
	boss_ability_cursor = 0
	boss_ability_timer = BossRules.ABILITY_INTERVAL
	super._start_battle()


func _spawn_enemy() -> void:
	super._spawn_enemy()
	intimidation_actions = 0
	boss_guard_charges = 0
	if Rules.is_boss_floor(current_floor):
		boss_ability_cursor = 0
		boss_ability_timer = BossRules.ABILITY_INTERVAL


func _hero_take_action() -> void:
	var skipped := PackedStringArray()
	for offset in skill_order.size():
		var index := (skill_cursor + offset) % skill_order.size()
		var skill_id := skill_order[index]
		var skill: Dictionary = skill_catalog[skill_id]
		if not _is_skill_available(skill_id, skill):
			skipped.append(skill["name"])
			continue
		skill_cursor = (index + 1) % skill_order.size()
		_cast_fury_skill(skill_id, skill, skipped.size())
		return
	battle_event.text = "本轮五个技能均不可用，等待下一次出手机会。"


func _is_skill_available(skill_id: String, skill: Dictionary) -> bool:
	if skill_cooldowns.get(skill_id, 0.0) > 0.0:
		return false
	if skill_id == "dot_heal":
		return dot_damage_bank > 0.0 and hero_health < hero_stats.max_health()
	if skill_id == "rage_barrier":
		if hero_resource <= 0.0:
			return false
		if Rules.is_boss_floor(current_floor):
			var next_ability := BossRules.ABILITY_CYCLE[boss_ability_cursor]
			return next_ability == "heavy_attack" \
				and boss_ability_timer <= _current_action_interval() * 1.75
		return hero_health <= hero_stats.max_health() * 0.50
	return hero_resource >= _effective_rage_cost(skill)


func _effective_rage_cost(skill: Dictionary) -> float:
	var cost: float = skill["base_rage_cost"]
	if burst_skills_remaining > 0 and cost > 0.0:
		cost *= 1.0 - FuryRules.burst_cost_reduction(hero_stats.mastery)
	return cost


func _cast_fury_skill(skill_id: String, skill: Dictionary, skipped_count: int) -> void:
	var notes := PackedStringArray()
	if skipped_count > 0:
		notes.append("跳过 %d 个不可用技能" % skipped_count)
	var burst_active := burst_skills_remaining > 0 and skill_id != "fury_burst"
	var cost := _effective_rage_cost(skill)
	var resource_before := hero_resource
	hero_resource = maxf(0.0, hero_resource - cost)
	var rage_spent := resource_before - hero_resource
	skill_cooldowns[skill_id] = skill["cooldown"]

	if skill_id == "fury_burst":
		burst_skills_remaining = _burst_charge_count()
		notes.append("后续 %d 个技能获得爆发强化" % burst_skills_remaining)
		battle_event.text = "释放 %s · %s" % [skill["name"], "，".join(notes)]
		return

	if skill_id == "dot_heal":
		var healing := minf(
			dot_damage_bank * _dot_heal_conversion_ratio(),
			hero_stats.max_health() * _dot_heal_cap_ratio(),
		)
		hero_health = minf(hero_stats.max_health(), hero_health + healing)
		dot_damage_bank = 0.0
		notes.append("恢复 %.0f 生命" % healing)
		_consume_burst_charge(burst_active)
		battle_event.text = "释放 %s · %s" % [skill["name"], "，".join(notes)]
		return

	if skill_id == "rage_barrier":
		hero_shield += FuryRules.barrier_amount(hero_resource)
		notes.append("%.0f 怒意转化为 %.0f 护盾" % [hero_resource, hero_shield])
		hero_resource = 0.0
		_consume_burst_charge(burst_active)
		battle_event.text = "释放 %s · %s" % [skill["name"], "，".join(notes)]
		return

	var builder_bonus := _builder_base_rage_bonus(skill_id)
	var base_rage_gain := float(skill["base_rage_gain"]) + builder_bonus
	var rage_gain := FuryRules.rage_gain(base_rage_gain, hero_stats.mastery)
	if builder_bonus > 0.0:
		notes.append("沸腾血性额外攒怒")
	if burst_active and rage_gain > 0.0:
		rage_gain *= 1.0 + FuryRules.burst_gain_bonus(hero_stats.mastery)
		notes.append("爆发强化攒怒")
	hero_resource = minf(FuryRules.MAX_RAGE, hero_resource + rage_gain)
	if rage_gain > 0.0:
		notes.append("获得 %.0f 怒意" % rage_gain)

	var damage: float = (
		hero_stats.attack_power()
		* skill["damage_multiplier"]
		* hero_stats.outgoing_multiplier()
	)
	if skill_id in ["single_spender", "aoe_spender"]:
		damage *= FuryRules.mastery_damage_multiplier(hero_stats.mastery)
		notes.append("精通强化泄怒")
		var spender_multiplier := _spender_damage_multiplier(skill_id)
		if spender_multiplier > 1.0:
			damage *= spender_multiplier
			notes.append("精准倾泻提高伤害")
	if intimidation_actions > 0:
		damage *= 1.0 - BossRules.INTIMIDATION_DAMAGE_PENALTY
		intimidation_actions -= 1
		notes.append("受到恫吓压制")
	if rng.randf() < hero_stats.critical_chance():
		damage *= 2.0
		notes.append("暴击")
	if skill_id in ["single_spender", "aoe_spender"]:
		var counter_damage := _spender_counter_damage(skill_id)
		if counter_damage > 0.0:
			damage += counter_damage
			notes.append("不动如山反击 %.0f" % counter_damage)
			_consume_spender_counter_damage(skill_id)
	var actual_damage := _apply_damage_to_enemy(damage)
	if boss_guard_charges == 0 and actual_damage < damage:
		notes.append("外骨骼减伤")

	if skill_id == "rage_builder":
		_apply_bleed(0.18)
		notes.append("施加流血")
	elif skill_id == "aoe_spender":
		_apply_bleed(0.22)
		notes.append("施加 AOE 流血")
	var refund := _burst_spender_refund(skill_id, burst_active, rage_spent)
	if refund > 0.0:
		hero_resource = minf(FuryRules.MAX_RAGE, hero_resource + refund)
		notes.append("无尽狂潮返还 %.0f 怒意" % refund)
	_consume_burst_charge(burst_active)
	battle_event.text = "释放 %s，造成 %.0f 伤害" % [skill["name"], actual_damage]
	if not notes.is_empty():
		battle_event.text += " · " + "，".join(notes)
	_resolve_enemy_defeat()


func _spender_counter_damage(_skill_id: String) -> float:
	return 0.0


func _consume_spender_counter_damage(_skill_id: String) -> void:
	pass


func _builder_base_rage_bonus(_skill_id: String) -> float:
	return 0.0


func _burst_charge_count() -> int:
	return FuryRules.BASE_BURST_CHARGES


func _spender_damage_multiplier(_skill_id: String) -> float:
	return 1.0


func _burst_spender_refund(
	_skill_id: String,
	_was_burst_active: bool,
	_rage_spent: float,
) -> float:
	return 0.0


func _bleed_damage_multiplier() -> float:
	return 1.0


func _dot_heal_conversion_ratio() -> float:
	return FuryRules.BASE_DOT_HEAL_CONVERSION_RATIO


func _dot_heal_cap_ratio() -> float:
	return FuryRules.BASE_DOT_HEAL_CAP_RATIO


func _consume_burst_charge(was_active: bool) -> void:
	if was_active:
		burst_skills_remaining = maxi(0, burst_skills_remaining - 1)


func _apply_bleed(tick_multiplier: float) -> void:
	bleed_ticks_remaining = FuryRules.BLEED_TICKS
	bleed_tick_timer = FuryRules.BLEED_INTERVAL
	bleed_tick_damage = (
		hero_stats.attack_power()
		* tick_multiplier
		* hero_stats.outgoing_multiplier()
		* FuryRules.mastery_damage_multiplier(hero_stats.mastery)
		* _bleed_damage_multiplier()
	)


func _process_fury_bleed(delta: float) -> void:
	if bleed_ticks_remaining <= 0 or enemy_health <= 0.0:
		return
	bleed_tick_timer -= delta
	if bleed_tick_timer > 0.0:
		return
	bleed_tick_timer += FuryRules.BLEED_INTERVAL
	bleed_ticks_remaining -= 1
	var damage := bleed_tick_damage
	if intimidation_actions > 0:
		damage *= 1.0 - BossRules.INTIMIDATION_DAMAGE_PENALTY
	var actual_damage := _apply_damage_to_enemy(damage)
	dot_damage_bank += actual_damage
	battle_event.text = "流血造成 %.0f 伤害（剩余 %d 跳）" % [
		actual_damage, bleed_ticks_remaining]
	_resolve_enemy_defeat()


func _apply_damage_to_enemy(damage: float) -> float:
	var actual_damage := damage
	if Rules.is_boss_floor(current_floor) and boss_guard_charges > 0:
		actual_damage *= 1.0 - BossRules.CARAPACE_REDUCTION
		boss_guard_charges -= 1
	enemy_health = maxf(0.0, enemy_health - actual_damage)
	return actual_damage


func _enemy_take_action() -> void:
	_take_hero_damage(enemy_damage, enemy_name.text)


func _take_hero_damage(raw_damage: float, source_name: String) -> void:
	var damage := raw_damage * hero_stats.damage_taken_multiplier()
	var absorbed := minf(hero_shield, damage)
	hero_shield -= absorbed
	damage -= absorbed
	hero_health = maxf(0.0, hero_health - damage)
	battle_event.text = "%s 造成 %.0f 伤害" % [source_name, damage]
	if absorbed > 0.0:
		battle_event.text += " · 护盾吸收 %.0f" % absorbed
	if hero_health <= 0.0:
		_return_to_preparation("挑战失败。调整怒意循环与壁垒时机后重试。")


func _cast_next_boss_ability() -> void:
	var ability_id := BossRules.ABILITY_CYCLE[boss_ability_cursor]
	boss_ability_cursor = (boss_ability_cursor + 1) % BossRules.ABILITY_CYCLE.size()
	match ability_id:
		"slow":
			platforms_remaining -= 1
			floor_slow_stacks += 1
			battle_event.text = "Boss 击碎一块地板：出手频率降低。"
			if platforms_remaining <= 0:
				_collapse_all_platforms()
		"intimidation":
			intimidation_actions = BossRules.INTIMIDATION_ACTIONS
			battle_event.text = "Boss 发出恫吓：接下来 3 个攻击技能伤害降低。"
		"heavy_attack":
			_take_hero_damage(BossRules.HEAVY_ATTACK_DAMAGE, "Boss 的势大力沉")
		"defense":
			boss_guard_charges = 1
			battle_event.text = "Boss 硬化外骨骼：下一次受到的伤害降低 70%。"


func _collapse_all_platforms() -> void:
	hero_health = 0.0
	battle_state = BattleState.PREPARING
	battle_event.text = "Boss 狂暴并摧毁全部地块，双方坠落；本次突破失败。"
	_refresh_all_ui()


func _current_action_interval() -> float:
	return (
		hero_stats.adjusted_time(Rules.BASE_ACTION_INTERVAL)
		* (1.0 + floor_slow_stacks * BossRules.SLOW_PER_BROKEN_PLATFORM)
	)


func _swap_with_reserve(index: int) -> void:
	if battle_state == BattleState.FIGHTING:
		return
	var removed_skill := skill_order[index]
	skill_order[index] = reserve_skill_id
	reserve_skill_id = removed_skill
	if not skill_cooldowns.has(skill_order[index]):
		skill_cooldowns[skill_order[index]] = 0.0
	battle_event.text = "已更换第 %d 个技能槽。" % (index + 1)
	_refresh_skill_order_ui()


func _refresh_all_ui() -> void:
	super._refresh_all_ui()
	floor_status.text = "狂怒战士 · 第 %d 层" % current_floor
	battle_status.text = "自动战斗 · 六选五怒意循环" \
		if battle_state == BattleState.FIGHTING \
		else "战前准备 · 从六技能中选择五个并排序"


func _refresh_skill_order_ui() -> void:
	for index in skill_order.size():
		var skill_id := skill_order[index]
		var skill: Dictionary = skill_catalog[skill_id]
		var cooldown: float = skill_cooldowns.get(skill_id, 0.0) / hero_stats.haste_multiplier()
		skill_labels[index].text = "%d. %s [%.1fs] · %s" % [
			index + 1, skill["name"], cooldown, skill["description"]]
		skill_up_buttons[index].disabled = battle_state == BattleState.FIGHTING or index == 0
		skill_down_buttons[index].disabled = battle_state == BattleState.FIGHTING \
			or index == skill_order.size() - 1
		skill_swap_buttons[index].disabled = battle_state == BattleState.FIGHTING
	if reserve_skill_label:
		reserve_skill_label.text = "备选：%s · 点击任意槽位的‘换’进行替换" % [
			skill_catalog[reserve_skill_id]["name"]]


func _refresh_combat_ui() -> void:
	super._refresh_combat_ui()
	hero_resource_text.text = "怒意 %.0f / %.0f · 护盾 %.0f" % [
		hero_resource, FuryRules.MAX_RAGE, hero_shield]
	hero_action.text = "间隔 %.2fs · 爆发强化剩余 %d 技能" % [
		_current_action_interval(), burst_skills_remaining]
	if Rules.is_boss_floor(current_floor):
		var next_ability := BossRules.ABILITY_CYCLE[boss_ability_cursor]
		enemy_action.text = "地块 %d/%d · 下个：%s（%.1fs）" % [
			platforms_remaining, BossRules.PLATFORM_COUNT,
			BossRules.ability_name(next_ability), boss_ability_timer]
	else:
		enemy_action.text = "流血 %d 跳 · DOT 记录 %.0f" % [
			bleed_ticks_remaining, dot_damage_bank]
	run_summary.text = (
		"力量 %.0f  耐力 %.0f  精通 %.0f%%\n"
		+ "急速 %.0f%%  暴击 %.0f%%  全能 %.0f%%\n"
		+ "击杀 %d · 待鉴定 %d · 备选 %s"
	) % [
		hero_stats.strength, hero_stats.stamina, hero_stats.mastery,
		hero_stats.haste, hero_stats.critical_strike, hero_stats.versatility,
		ordinary_kills, loot_count, skill_catalog[reserve_skill_id]["name"],
	]


func _build_skill_panel(parent: Control) -> void:
	var panel := _panel(Color("111318"), 1.95)
	parent.add_child(panel)
	var layout := _inset_vbox(panel)
	layout.add_child(_label("狂怒战士：六选五技能循环", 11, Color("e8b852")))
	for index in skill_order.size():
		var row := HBoxContainer.new()
		layout.add_child(row)
		var skill_label := _label("", 9)
		skill_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(skill_label)
		skill_labels.append(skill_label)
		var up := _button("↑", 22, 18)
		var down := _button("↓", 22, 18)
		var swap := _button("换", 28, 18)
		row.add_child(up)
		row.add_child(down)
		row.add_child(swap)
		skill_up_buttons.append(up)
		skill_down_buttons.append(down)
		skill_swap_buttons.append(swap)
	reserve_skill_label = _label("", 9, Color("a8b3c2"))
	layout.add_child(reserve_skill_label)
