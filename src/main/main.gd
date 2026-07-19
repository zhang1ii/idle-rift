extends "res://src/main/fury_combat_controller.gd"


const EquipmentInventoryModel = preload("res://src/gameplay/equipment_inventory.gd")
const EquipmentEvaluator = preload("res://src/gameplay/equipment_evaluator.gd")
const PlayerWalletModel = preload("res://src/gameplay/player_wallet.gd")
const GameDataRepository = preload("res://src/data/game_data_repository.gd")
const TalentTreeModelScript = preload("res://src/gameplay/talent_tree_model.gd")
const TalentTreePanelScript = preload("res://src/ui/talent_tree_panel.gd")
const FunctionalBattleViewScene = preload("res://src/ui/functional_battle_view.tscn")
const EquipmentInventoryPanelScript = preload("res://src/ui/equipment_inventory_panel.gd")

var player_wallet = PlayerWalletModel.new()
var equipment_inventory = EquipmentInventoryModel.new(player_wallet)
var talent_tree = TalentTreeModelScript.new()
var last_dropped_item: Dictionary = {}
var active_talent_ids: Array[String] = []
var barrier_refund_pending := 0.0
var immovable_counter_stored := 0.0
var talent_toggle_button: Button
var talent_panel: TalentTreePanel
var equipment_toggle_button: Button
var equipment_panel: EquipmentInventoryPanel
var battle_view: FunctionalBattleView


func _ready() -> void:
	talent_tree.configure(GameDataRepository.new().talents()["trees"]["fury_warrior"])
	# The vertical slice starts with its calibrated G4 reference set. Unlike the
	# old hard-coded character sheet, every displayed/combat stat is now rebuilt
	# from these thirteen concrete items and will change when one is replaced.
	equipment_inventory.rng.seed = 20260718
	equipment_inventory.seed_reference_loadout(4, "rare")
	_apply_equipment_loadout(false)
	super._ready()
	equipment_inventory.rng.randomize()
	print("Idle Rift equipment drops, backpack and talent hooks loaded.")


func _build_interface() -> void:
	super._build_interface()
	talent_toggle_button = _button("天赋树 [Tab]", 96, 23)
	talent_toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	talent_toggle_button.position = Vector2(-106, 37)
	talent_toggle_button.pressed.connect(_toggle_talent_panel)
	add_child(talent_toggle_button)
	talent_panel = TalentTreePanelScript.new()
	add_child(talent_panel)
	talent_panel.setup(talent_tree)
	talent_panel.talent_requested.connect(_on_talent_requested)
	talent_panel.reset_requested.connect(_on_talent_reset_requested)
	talent_panel.close_requested.connect(_hide_talent_panel)
	talent_panel.visible = false
	equipment_toggle_button = _button("背包 [B]", 96, 23)
	equipment_toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	equipment_toggle_button.position = Vector2(-208, 37)
	equipment_toggle_button.pressed.connect(_toggle_equipment_panel)
	add_child(equipment_toggle_button)
	equipment_panel = EquipmentInventoryPanelScript.new()
	add_child(equipment_panel)
	equipment_panel.setup(equipment_inventory)
	equipment_panel.equip_requested.connect(_on_equipment_equip_requested)
	equipment_panel.sell_requested.connect(_on_equipment_sell_requested)
	equipment_panel.sell_non_upgrades_requested.connect(_on_sell_non_upgrades_requested)
	equipment_panel.close_requested.connect(_hide_equipment_panel)
	equipment_panel.visible = false


func _build_arena(parent: Control) -> void:
	battle_view = FunctionalBattleViewScene.instantiate()
	parent.add_child(battle_view)
	battle_status = battle_view.get_node("%BattleStatus")
	battle_event = battle_view.get_node("%BattleEvent")
	hero_health_bar = battle_view.get_node("%HeroHealth")
	hero_health_text = battle_view.get_node("%HeroHealthText")
	hero_resource_bar = battle_view.get_node("%HeroRage")
	hero_resource_text = battle_view.get_node("%HeroRageText")
	hero_action = battle_view.get_node("%HeroAction")
	enemy_name = battle_view.get_node("%EnemyName")
	enemy_health_bar = battle_view.get_node("%EnemyHealth")
	enemy_health_text = battle_view.get_node("%EnemyHealthText")
	enemy_action = battle_view.get_node("%EnemyAction")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_TAB:
		_toggle_talent_panel()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_B:
		_toggle_equipment_panel()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and talent_panel != null and talent_panel.visible:
		_hide_talent_panel()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and equipment_panel != null and equipment_panel.visible:
		_hide_equipment_panel()
		get_viewport().set_input_as_handled()


func allocate_talent(talent_id: String) -> bool:
	if battle_state == BattleState.FIGHTING or not talent_tree.allocate(talent_id):
		return false
	_sync_active_talents_from_tree()
	return true


func refund_talent(talent_id: String) -> bool:
	if battle_state == BattleState.FIGHTING or not talent_tree.refund(talent_id):
		return false
	_sync_active_talents_from_tree()
	return true


func reset_talents() -> bool:
	if battle_state == BattleState.FIGHTING or not talent_tree.reset():
		return false
	_sync_active_talents_from_tree()
	return true


func equip_inventory_item(index: int, requested_target := "") -> bool:
	if battle_state == BattleState.FIGHTING:
		return false
	if not equipment_inventory.equip_inventory_item(index, requested_target):
		return false
	_apply_equipment_loadout(true)
	if equipment_panel != null:
		equipment_panel.refresh()
	_refresh_all_ui()
	return true


func sell_inventory_item(index: int) -> int:
	if battle_state == BattleState.FIGHTING:
		return 0
	var gained := equipment_inventory.sell_inventory_item(index)
	if equipment_panel != null:
		equipment_panel.refresh()
	_refresh_all_ui()
	return gained


func sell_non_upgrades() -> int:
	if battle_state == BattleState.FIGHTING:
		return 0
	var gained := equipment_inventory.sell_non_upgrades()
	if equipment_panel != null:
		equipment_panel.refresh()
	_refresh_all_ui()
	return gained


func _on_equipment_equip_requested(index: int) -> void:
	equip_inventory_item(index)


func _on_equipment_sell_requested(index: int) -> void:
	sell_inventory_item(index)


func _on_sell_non_upgrades_requested() -> void:
	sell_non_upgrades()


func _apply_equipment_loadout(preserve_health_ratio: bool) -> void:
	var old_max_health := hero_stats.max_health()
	var health_ratio := clampf(hero_health / old_max_health, 0.0, 1.0) \
		if preserve_health_ratio and old_max_health > 0.0 else 1.0
	var effective_tier := EquipmentEvaluator.average_power_tier(equipment_inventory.equipped)
	hero_stats.apply_equipment_stats(
		equipment_inventory.total_equipment_stats(),
		effective_tier,
	)
	_apply_talent_stat_modifiers()
	if preserve_health_ratio:
		hero_health = hero_stats.max_health() * health_ratio


func _on_talent_requested(talent_id: String) -> void:
	if talent_tree.has_talent(talent_id):
		refund_talent(talent_id)
	else:
		allocate_talent(talent_id)


func _on_talent_reset_requested() -> void:
	reset_talents()


func _sync_active_talents_from_tree() -> void:
	active_talent_ids.assign(talent_tree.active_talent_ids)
	_apply_talent_stat_modifiers()
	if talent_panel != null:
		talent_panel.refresh()
	_refresh_all_ui()


func _toggle_talent_panel() -> void:
	if talent_panel == null:
		return
	talent_panel.visible = not talent_panel.visible
	if talent_panel.visible:
		_hide_equipment_panel()
		talent_panel.refresh()


func _hide_talent_panel() -> void:
	if talent_panel != null:
		talent_panel.visible = false


func _toggle_equipment_panel() -> void:
	if equipment_panel == null:
		return
	equipment_panel.visible = not equipment_panel.visible
	if equipment_panel.visible:
		_hide_talent_panel()
		equipment_panel.set_locked(battle_state == BattleState.FIGHTING)


func _hide_equipment_panel() -> void:
	if equipment_panel != null:
		equipment_panel.visible = false


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
	talent_tree.begin_battle()
	_hide_talent_panel()
	_hide_equipment_panel()
	super._start_battle()
	if talent_panel != null:
		talent_panel.refresh()
	if equipment_panel != null:
		equipment_panel.set_locked(true)


func _return_to_preparation(message: String) -> void:
	talent_tree.end_battle()
	super._return_to_preparation(message)
	if talent_panel != null:
		talent_panel.refresh()
	if equipment_panel != null:
		equipment_panel.set_locked(false)


func _collapse_all_platforms() -> void:
	super._collapse_all_platforms()
	talent_tree.end_battle()
	if talent_panel != null:
		talent_panel.refresh()
	if equipment_panel != null:
		equipment_panel.set_locked(false)


func _on_boss_defeated() -> void:
	var defeated_floor := current_floor
	var first_clear := defeated_floor not in defeated_boss_floors
	var awarded := talent_tree.record_guard_boss_victory(defeated_floor) if first_clear else 0
	super._on_boss_defeated()
	talent_tree.end_battle()
	if awarded > 0:
		battle_event.text += " · 获得 %d 点天赋（共 %d 点）" % [awarded, talent_tree.point_budget]
	if talent_panel != null:
		talent_panel.refresh()
	if equipment_panel != null:
		equipment_panel.set_locked(false)


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
		var health_before := enemy_health
		super._cast_fury_skill(skill_id, skill, skipped_count)
		if battle_view != null:
			battle_view.play_skill(skill_id)
			if enemy_health < health_before:
				battle_view.play_enemy_damage(
					health_before - enemy_health,
					skill_id in ["single_spender", "aoe_spender"],
					false,
					enemy_health <= 0.0,
				)
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
	if battle_view != null:
		battle_view.play_skill(skill_id)


func _take_hero_damage(raw_damage: float, source_name: String) -> void:
	var health_before := hero_health
	var shield_before := hero_shield
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
	if battle_view != null:
		battle_view.play_hero_damage(health_before - hero_health, shield_before - hero_shield)


func _spawn_enemy() -> void:
	super._spawn_enemy()
	if battle_view != null:
		battle_view.spawn_enemy()


func _process_fury_bleed(delta: float) -> void:
	var health_before := enemy_health
	super._process_fury_bleed(delta)
	if battle_view != null and enemy_health < health_before:
		battle_view.play_enemy_damage(
			health_before - enemy_health,
			false,
			true,
			enemy_health <= 0.0,
		)


func _refresh_combat_ui() -> void:
	super._refresh_combat_ui()
	if battle_view != null:
		battle_view.sync_shield(hero_shield)
	if run_summary != null:
		run_summary.text += "\n装备 G%.2f · 背包 %d · 金币 %d" % [
			hero_stats.gear_tier,
			equipment_inventory.inventory.size(),
			player_wallet.gold,
		]


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


func _remaining_bleed_burst_damage(skill_id: String) -> float:
	if skill_id not in ["single_spender", "aoe_spender"]:
		return 0.0
	return FuryRules.remaining_bleed_burst_damage(
		bleed_tick_damage,
		bleed_ticks_remaining,
		is_talent_enabled(FuryRules.CRIMSON_EXECUTION_TALENT_ID),
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
		_refresh_equipment_panel_if_visible()
		return
	ordinary_kills += 1
	last_dropped_item = equipment_inventory.roll_normal_drop(current_floor)
	_refresh_equipment_panel_if_visible()
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


func _refresh_equipment_panel_if_visible() -> void:
	if equipment_panel != null and equipment_panel.visible:
		equipment_panel.refresh()
