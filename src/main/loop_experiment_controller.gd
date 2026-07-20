extends "res://src/main/main.gd"


const SkillLoopTrackerScript = preload("res://src/gameplay/skill_loop_tracker.gd")
const LoopEquipmentInventoryScript = preload("res://src/gameplay/loop_equipment_inventory.gd")
const LoopEquipmentPanelScript = preload("res://src/ui/loop_equipment_inventory_panel.gd")
const LegendaryEffects = preload("res://src/gameplay/legendary_loop_effects.gd")
const EquipmentRulesScript = preload("res://src/gameplay/equipment_rules.gd")

const COMPLETE_LOOP_RAGE_REWARD := 15.0
const METRONOME_ECHO_RATIO := 0.50
const FRACTURE_GEAR_DAMAGE_PER_STACK := 0.20
const FRACTURE_GEAR_MAX_STACKS := 3
const BLOOD_CLOSED_LOOP_RATIO := 0.30
const BOSS_DISRUPTION_SLOT_ORDER: Array[int] = [1, 3, 0, 4, 2]
const ATTACK_SKILLS: Array[String] = ["rage_builder", "single_spender", "aoe_spender"]

var loop_tracker = SkillLoopTrackerScript.new()
var boss_disrupted_slots: Dictionary = {}
var skill_skip_counts: Dictionary = {}
var loop_echo_charges := 0
var fracture_gear_stacks := 0
var boss_disruptions_triggered := 0
var battle_elapsed := 0.0
var last_barrier_cast_at := -1.0
var last_heavy_attack_at := -1.0
var last_heavy_absorbed := 0.0
var last_failure_diagnostic := ""
var initial_prototype_item_count := 0
var skill_scan_direction := 1
var reverse_casts_remaining := 0


func _ready() -> void:
	equipment_inventory = LoopEquipmentInventoryScript.new(player_wallet)
	super._ready()
	_replace_equipment_panel()
	_grant_prototype_loop_items()
	_refresh_all_ui()
	print("Idle Rift five-slot loop experiment loaded.")


func _process(delta: float) -> void:
	if battle_state == BattleState.FIGHTING:
		battle_elapsed += delta
	super._process(delta)


func _start_battle() -> void:
	loop_tracker.reset()
	boss_disrupted_slots.clear()
	skill_skip_counts.clear()
	loop_echo_charges = 0
	fracture_gear_stacks = 0
	boss_disruptions_triggered = 0
	battle_elapsed = 0.0
	last_barrier_cast_at = -1.0
	last_heavy_attack_at = -1.0
	last_heavy_absorbed = 0.0
	last_failure_diagnostic = ""
	skill_scan_direction = 1
	reverse_casts_remaining = 0
	loop_tracker.set_direction(1)
	super._start_battle()


func _hero_take_action() -> void:
	var skipped := PackedStringArray()
	for offset in skill_order.size():
		var index := _scan_index(offset)
		var skill_id := skill_order[index]
		var skill: Dictionary = skill_catalog[skill_id]
		if _consume_boss_disruption(index):
			skipped.append("%s（技能格裂化）" % skill["name"])
			_record_skill_skip(skill_id)
			continue
		if not _is_skill_available(skill_id, skill):
			skipped.append(skill["name"])
			_record_skill_skip(skill_id)
			continue
		var outcome := loop_tracker.record_cast(index, skipped.size())
		skill_cursor = posmod(index + skill_scan_direction, skill_order.size())
		_cast_fury_skill(skill_id, skill, skipped.size())
		_resolve_loop_outcome(outcome)
		_after_successful_cycle_cast()
		return
	if loop_tracker.progress > 0:
		_resolve_loop_outcome(loop_tracker.record_wait())
	battle_event.text = "本轮五个技能均不可用，等待下一次出手机会。"


func _cast_fury_skill(skill_id: String, skill: Dictionary, skipped_count: int) -> void:
	var health_before := enemy_health
	super._cast_fury_skill(skill_id, skill, skipped_count)
	if skill_id == "rage_barrier":
		last_barrier_cast_at = battle_elapsed
	if skill_id not in ATTACK_SKILLS:
		return
	var dealt := maxf(0.0, health_before - enemy_health)
	if dealt <= 0.0:
		return
	var bonus_ratio := 0.0
	var notes := PackedStringArray()
	if equipment_inventory.has_special_effect(LegendaryEffects.RIFT_METRONOME) \
	and loop_echo_charges > 0:
		loop_echo_charges -= 1
		bonus_ratio += METRONOME_ECHO_RATIO * equipment_inventory.special_effect_power(LegendaryEffects.RIFT_METRONOME)
		notes.append("裂隙节拍器回响")
	if equipment_inventory.has_special_effect(LegendaryEffects.FRACTURE_GEAR) \
	and fracture_gear_stacks > 0:
		bonus_ratio += FRACTURE_GEAR_DAMAGE_PER_STACK * fracture_gear_stacks * equipment_inventory.special_effect_power(LegendaryEffects.FRACTURE_GEAR)
		notes.append("断链齿轮%d层" % fracture_gear_stacks)
		fracture_gear_stacks = 0
	if bonus_ratio <= 0.0:
		return
	var bonus_damage := 0.0
	if enemy_health > 0.0:
		bonus_damage = _apply_damage_to_enemy(dealt * bonus_ratio)
	battle_event.text += " · %s附加 %.0f 伤害" % ["+".join(notes), bonus_damage]
	_resolve_enemy_defeat()


func _cast_next_boss_ability() -> void:
	var ability_id := BossRules.ability_cycle(current_floor)[boss_ability_cursor]
	var disrupted_slot := -1
	if ability_id == "slow":
		disrupted_slot = BOSS_DISRUPTION_SLOT_ORDER[
			floor_slow_stacks % BOSS_DISRUPTION_SLOT_ORDER.size()
		]
	super._cast_next_boss_ability()
	if ability_id != "slow" or battle_state != BattleState.FIGHTING:
		return
	boss_disrupted_slots[disrupted_slot] = int(
		boss_disrupted_slots.get(disrupted_slot, 0)) + 1
	battle_event.text += " 第%d技能格裂化，下次扫描必定跳过。" % (disrupted_slot + 1)
	_refresh_skill_order_ui()


func _apply_reverse_loop() -> void:
	skill_scan_direction = -1
	reverse_casts_remaining = skill_order.size()
	skill_cursor = skill_order.size() - 1
	loop_tracker.set_direction(-1)
	battle_event.text = "Boss 施加逆序刻印：队列翻转为 5→4→3→2→1。"
	_refresh_skill_order_ui()

func _scan_index(offset: int) -> int:
	return posmod(skill_cursor + offset * skill_scan_direction, skill_order.size())

func _after_successful_cycle_cast() -> void:
	if reverse_casts_remaining <= 0:
		return
	reverse_casts_remaining -= 1
	if reverse_casts_remaining > 0:
		return
	skill_scan_direction = 1
	skill_cursor = 0
	loop_tracker.set_direction(1)
	battle_event.text += " · 逆序结束，恢复 1→5"
	_refresh_skill_order_ui()


func exchange_weakened_effect(effect_id: String) -> Dictionary:
	if battle_state == BattleState.FIGHTING:
		return {}
	var item: Dictionary = equipment_inventory.exchange_weakened_effect(
		effect_id,
		maxi(1, current_floor + 1),
	)
	if not item.is_empty():
		battle_event.text = "使用徽记兑换【%s】弱化版。" % LegendaryEffects.effect_name(effect_id)
	if equipment_panel != null:
		equipment_panel.refresh()
	_refresh_all_ui()
	return item

func _on_exchange_requested(effect_id: String) -> void:
	exchange_weakened_effect(effect_id)


func _take_hero_damage(raw_damage: float, source_name: String) -> void:
	var shield_before := hero_shield
	var is_heavy := source_name.contains("势大力沉")
	if is_heavy:
		last_heavy_attack_at = battle_elapsed
	super._take_hero_damage(raw_damage, source_name)
	if is_heavy:
		last_heavy_absorbed = maxf(0.0, shield_before - hero_shield)
	if hero_health <= 0.0:
		last_failure_diagnostic = _build_failure_diagnostic("death")
		battle_event.text = last_failure_diagnostic


func _collapse_all_platforms() -> void:
	super._collapse_all_platforms()
	last_failure_diagnostic = _build_failure_diagnostic("collapse")
	battle_event.text = last_failure_diagnostic


func equip_inventory_item(index: int, requested_target := "") -> bool:
	var effect_id := ""
	if index >= 0 and index < equipment_inventory.inventory.size():
		effect_id = String(equipment_inventory.inventory[index].get("special_effect", ""))
	if not super.equip_inventory_item(index, requested_target):
		return false
	if LegendaryEffects.is_loop_effect(effect_id):
		battle_event.text = "已装备【%s】：%s" % [
			LegendaryEffects.effect_name(effect_id),
			LegendaryEffects.effect_description(effect_id),
		]
	return true


func _resolve_enemy_defeat() -> void:
	var drops_before: int = equipment_inventory.total_drops
	super._resolve_enemy_defeat()
	if equipment_inventory.total_drops <= drops_before or last_dropped_item.is_empty():
		return
	var effect_id := String(last_dropped_item.get("special_effect", ""))
	if LegendaryEffects.is_loop_effect(effect_id):
		battle_event.text += " · 传奇特效【%s】：%s" % [
			LegendaryEffects.effect_name(effect_id),
			LegendaryEffects.effect_description(effect_id),
		]


func _refresh_skill_order_ui() -> void:
	super._refresh_skill_order_ui()
	for index in skill_order.size():
		if int(boss_disrupted_slots.get(index, 0)) > 0:
			skill_labels[index].text += "  [裂化：下次跳过]"


		if reverse_casts_remaining > 0:
			skill_labels[index].text += "  [逆序]"
func _refresh_combat_ui() -> void:
	super._refresh_combat_ui()
	if hero_action != null and battle_state == BattleState.FIGHTING:
		hero_action.text += " · 回路 %d/5 · 完成%d 断链%d" % [
			loop_tracker.progress,
			loop_tracker.completed_loops,
			loop_tracker.broken_loops,
		]
	if enemy_action != null and Rules.is_boss_floor(current_floor) \
	and not boss_disrupted_slots.is_empty():
		enemy_action.text += " · 裂化格 %s" % _disrupted_slot_text()
	var active_names := _active_effect_names()
	if run_summary != null and not active_names.is_empty():
		run_summary.text += "\n循环特效：%s" % "、".join(active_names)
	if enemy_action != null and reverse_casts_remaining > 0:
		enemy_action.text += " · 逆序剩余%d次" % reverse_casts_remaining


func _resolve_loop_outcome(outcome: Dictionary) -> void:
	if bool(outcome.get("broken", false)):
		battle_event.text += " · 回路断裂"
		if equipment_inventory.has_special_effect(LegendaryEffects.FRACTURE_GEAR):
			fracture_gear_stacks = mini(
				FRACTURE_GEAR_MAX_STACKS,
				fracture_gear_stacks + 1,
			)
			battle_event.text += "，断链齿轮积累%d层" % fracture_gear_stacks
	if not bool(outcome.get("completed", false)):
		return
	var rage_before := hero_resource
	hero_resource = minf(FuryRules.MAX_RAGE, hero_resource + COMPLETE_LOOP_RAGE_REWARD)
	battle_event.text += " · 完整回路！获得%.0f怒意" % (hero_resource - rage_before)
	if equipment_inventory.has_special_effect(LegendaryEffects.RIFT_METRONOME):
		loop_echo_charges += 1
		battle_event.text += "，裂隙节拍器已充能"
	if equipment_inventory.has_special_effect(LegendaryEffects.BLOOD_CLOSED_LOOP) \
	and enemy_health > 0.0 and bleed_ticks_remaining > 0:
		var bleed_echo: float = bleed_tick_damage * bleed_ticks_remaining * BLOOD_CLOSED_LOOP_RATIO \
			* equipment_inventory.special_effect_power(LegendaryEffects.BLOOD_CLOSED_LOOP)
		var actual := _apply_damage_to_enemy(bleed_echo)
		battle_event.text += "，血色闭环结算%.0f流血" % actual
		_resolve_enemy_defeat()


func _consume_boss_disruption(slot_index: int) -> bool:
	var charges := int(boss_disrupted_slots.get(slot_index, 0))
	if charges <= 0:
		return false
	if charges == 1:
		boss_disrupted_slots.erase(slot_index)
	else:
		boss_disrupted_slots[slot_index] = charges - 1
	boss_disruptions_triggered += 1
	return true


func _record_skill_skip(skill_id: String) -> void:
	skill_skip_counts[skill_id] = int(skill_skip_counts.get(skill_id, 0)) + 1


func _build_failure_diagnostic(reason: String) -> String:
	var loop_report := "完整回路%d次、断链%d次" % [
		loop_tracker.completed_loops,
		loop_tracker.broken_loops,
	]
	var skip_report := _most_skipped_skill_report()
	if reason == "collapse":
		return "失败诊断：输出不足。第5次碎地板触发坠落；%s，Boss裂化实际打断%d次%s。" % [
			loop_report,
			boss_disruptions_triggered,
			skip_report,
		]
	var defense_report := "持续承伤超过恢复能力"
	if last_heavy_attack_at >= 0.0 and battle_elapsed - last_heavy_attack_at <= 0.2:
		if last_barrier_cast_at < 0.0:
			defense_report = "重击前没有释放怒意壁垒"
		else:
			defense_report = "壁垒在重击前%.1f秒释放，本次只吸收%.0f伤害" % [
				maxf(0.0, last_heavy_attack_at - last_barrier_cast_at),
				last_heavy_absorbed,
			]
	return "失败诊断：生存不足——%s；%s%s。" % [
		defense_report,
		loop_report,
		skip_report,
	]


func _most_skipped_skill_report() -> String:
	var top_id := ""
	var top_count := 0
	for skill_id in skill_skip_counts:
		var count := int(skill_skip_counts[skill_id])
		if count > top_count:
			top_id = String(skill_id)
			top_count = count
	if top_id.is_empty():
		return ""
	return "；%s被跳过%d次" % [skill_catalog[top_id]["name"], top_count]


func _disrupted_slot_text() -> String:
	var labels := PackedStringArray()
	for index in skill_order.size():
		if int(boss_disrupted_slots.get(index, 0)) > 0:
			labels.append(str(index + 1))
	return ",".join(labels)


func _active_effect_names() -> PackedStringArray:
	var names := PackedStringArray()
	for effect_id in equipment_inventory.active_loop_effect_ids():
		names.append(LegendaryEffects.effect_name(effect_id))
	return names


func _replace_equipment_panel() -> void:
	if equipment_panel != null:
		equipment_panel.queue_free()
	equipment_panel = LoopEquipmentPanelScript.new()
	equipment_panel.recycle_requested.connect(_on_equipment_recycle_requested)
	equipment_panel.exchange_requested.connect(_on_exchange_requested)
	add_child(equipment_panel)
	equipment_panel.setup(equipment_inventory)
	equipment_panel.equip_requested.connect(_on_equipment_equip_requested)
	equipment_panel.sell_requested.connect(_on_equipment_sell_requested)
	equipment_panel.sell_non_upgrades_requested.connect(_on_sell_non_upgrades_requested)
	equipment_panel.close_requested.connect(_hide_equipment_panel)
	equipment_panel.visible = false


func _grant_prototype_loop_items() -> void:
	var showcase_ids := [
		LegendaryEffects.FRACTURE_GEAR,
		LegendaryEffects.BLOOD_CLOSED_LOOP,
		LegendaryEffects.RIFT_METRONOME,
	]
	for effect_id in showcase_ids:
		var item := EquipmentRulesScript.create_normal_item(
			equipment_inventory.rng,
			4,
			LegendaryEffects.effect_slot(effect_id),
			"legendary",
		)
		item["special_effect"] = effect_id
		equipment_inventory.add_item(item)
	initial_prototype_item_count = showcase_ids.size()
	if equipment_panel != null:
		equipment_panel.refresh()
	battle_event.text = "玩法测试：背包中已放入3件循环传奇，可在战前选择装备。"
