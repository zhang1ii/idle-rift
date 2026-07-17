extends "res://src/main/fury_combat_controller.gd"


const EquipmentInventoryModel = preload("res://src/gameplay/equipment_inventory.gd")

var equipment_inventory = EquipmentInventoryModel.new()
var last_dropped_item: Dictionary = {}
var active_talent_ids: Array[String] = []


func _ready() -> void:
	super._ready()
	equipment_inventory.rng.randomize()
	print("Idle Rift equipment drops, backpack and talent hooks loaded.")


func set_talent_enabled(talent_id: String, enabled: bool) -> bool:
	if battle_state == BattleState.FIGHTING:
		return false
	if talent_id != FuryRules.STEADY_RAGE_TALENT_ID:
		return false
	if enabled and talent_id not in active_talent_ids:
		active_talent_ids.append(talent_id)
	elif not enabled:
		active_talent_ids.erase(talent_id)
	return true


func is_talent_enabled(talent_id: String) -> bool:
	return talent_id in active_talent_ids


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
	if skill_id != "rage_barrier" \
	or not is_talent_enabled(FuryRules.STEADY_RAGE_TALENT_ID):
		super._cast_fury_skill(skill_id, skill, skipped_count)
		return
	var notes := PackedStringArray()
	if skipped_count > 0:
		notes.append("跳过 %d 个不可用技能" % skipped_count)
	var burst_active := burst_skills_remaining > 0
	var rage_spent := hero_resource
	skill_cooldowns[skill_id] = skill["cooldown"]
	hero_shield += FuryRules.barrier_amount(
		rage_spent,
		hero_stats.haste,
		true,
	)
	hero_resource = 0.0
	notes.append("稳定怒意将急速转化为 %.0f 护盾" % hero_shield)
	_consume_burst_charge(burst_active)
	battle_event.text = "释放 %s · %s" % [skill["name"], "，".join(notes)]


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
