extends Control


const Rules = preload("res://src/gameplay/combat_rules.gd")
const CharacterStats = preload("res://src/gameplay/character_stats.gd")
const GameDataRepository = preload("res://src/data/game_data_repository.gd")

enum BattleState { PREPARING, FIGHTING }

const NORMAL_RESPAWN_DELAY := 0.65
const VULNERABILITY_MULTIPLIER := 1.25
const BLEED_TICK_INTERVAL := 1.0
const BLEED_TICK_COUNT := 3

var floor_status: Label
var mode_status: Label
var unlock_status: Label
var battle_status: Label
var battle_event: Label
var hero_health_bar: ProgressBar
var hero_health_text: Label
var hero_resource_bar: ProgressBar
var hero_resource_text: Label
var hero_action: Label
var enemy_name: Label
var enemy_health_bar: ProgressBar
var enemy_health_text: Label
var enemy_action: Label
var run_summary: Label
var selected_floor: Label
var previous_floor_button: Button
var next_floor_button: Button
var start_button: Button

var hero_stats = CharacterStats.new()
var game_data = GameDataRepository.new()
var skill_catalog: Dictionary = Rules.skill_catalog()
var skill_order: Array[String] = [
	"resource_builder",
	"vulnerability",
	"bleeding_strike",
	"resource_spender",
	"defensive_guard",
]
var skill_cooldowns: Dictionary = {}
var skill_cursor := 0
var skill_labels: Array[Label] = []
var skill_up_buttons: Array[Button] = []
var skill_down_buttons: Array[Button] = []

var battle_state := BattleState.PREPARING
var current_floor := 1
var highest_unlocked_floor := Rules.BOSS_INTERVAL
var defeated_boss_floors: Array[int] = []
var hero_health := 0.0
var hero_resource := 0.0
var guard_charges := 0
var enemy_health := 0.0
var enemy_max_health := 0.0
var enemy_damage := 0.0
var enemy_attack_interval := 1.75
var vulnerability_actions := 0
var bleed_ticks_remaining := 0
var bleed_tick_timer := BLEED_TICK_INTERVAL
var hero_action_timer := 0.0
var enemy_action_timer := 0.0
var respawn_timer := -1.0
var ordinary_kills := 0
var loot_count := 0
var enemy_sequence := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_build_interface()
	for index in skill_order.size():
		skill_up_buttons[index].pressed.connect(_move_skill.bind(index, -1))
		skill_down_buttons[index].pressed.connect(_move_skill.bind(index, 1))
	previous_floor_button.pressed.connect(_change_floor.bind(-1))
	next_floor_button.pressed.connect(_change_floor.bind(1))
	start_button.pressed.connect(_on_start_button_pressed)
	_reset_skill_cooldowns()
	hero_health = hero_stats.max_health()
	_refresh_all_ui()
	print("Idle Rift class combat prototype loaded.")


func _process(delta: float) -> void:
	if battle_state != BattleState.FIGHTING:
		return
	_tick_skill_cooldowns(delta)
	if respawn_timer >= 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_spawn_enemy()
		return

	_process_bleed(delta)
	if enemy_health <= 0.0 or battle_state != BattleState.FIGHTING:
		return
	hero_action_timer -= delta
	enemy_action_timer -= delta
	if hero_action_timer <= 0.0:
		_hero_take_action()
		hero_action_timer = hero_stats.adjusted_time(Rules.BASE_ACTION_INTERVAL)
	if battle_state == BattleState.FIGHTING and enemy_health > 0.0 \
	and enemy_action_timer <= 0.0:
		_enemy_take_action()
		enemy_action_timer = enemy_attack_interval
	_refresh_combat_ui()


func _on_start_button_pressed() -> void:
	if battle_state == BattleState.FIGHTING:
		_return_to_preparation("已退出本次战斗，可以重新调整技能顺序。")
	else:
		_start_battle()


func _start_battle() -> void:
	battle_state = BattleState.FIGHTING
	hero_health = hero_stats.max_health()
	hero_resource = 0.0
	guard_charges = 0
	ordinary_kills = 0
	loot_count = 0
	enemy_sequence = 0
	skill_cursor = 0
	_reset_skill_cooldowns()
	hero_action_timer = hero_stats.adjusted_time(Rules.BASE_FIRST_ACTION_DELAY)
	respawn_timer = -1.0
	_spawn_enemy()
	battle_event.text = "战斗开始：自动扫描队列并释放第一个可用技能。"
	_refresh_all_ui()


func _return_to_preparation(message: String) -> void:
	battle_state = BattleState.PREPARING
	respawn_timer = -1.0
	battle_event.text = message
	_refresh_all_ui()


func _spawn_enemy() -> void:
	enemy_sequence += 1
	var stats := Rules.enemy_stats(current_floor)
	enemy_max_health = stats["max_health"]
	enemy_health = enemy_max_health
	enemy_damage = stats["damage"]
	enemy_attack_interval = stats["attack_interval"]
	enemy_action_timer = enemy_attack_interval
	vulnerability_actions = 0
	bleed_ticks_remaining = 0
	bleed_tick_timer = BLEED_TICK_INTERVAL
	respawn_timer = -1.0
	var definition := _current_floor_definition()
	if Rules.is_boss_floor(current_floor):
		var boss_name := String(definition.get("name", "裂隙守卫"))
		enemy_name.text = "%s · 第 %d 层" % [boss_name, current_floor]
	else:
		var enemy_kinds: Array = definition.get(
			"enemy_names",
			["洞窟爬兽", "遗迹守卫", "裂隙游魂"],
		)
		enemy_name.text = "%s · Lv.%d" % [
			enemy_kinds[(enemy_sequence - 1) % enemy_kinds.size()], current_floor]
	_refresh_combat_ui()


func _current_floor_definition() -> Dictionary:
	return game_data.first_rift_floor(current_floor)


func _current_floor_mechanic() -> String:
	return String(_current_floor_definition().get("mechanic", "basic_attack"))


func _hero_take_action() -> void:
	var skipped := PackedStringArray()
	for offset in skill_order.size():
		var index := (skill_cursor + offset) % skill_order.size()
		var skill_id := skill_order[index]
		var skill: Dictionary = skill_catalog[skill_id]
		if skill_cooldowns[skill_id] > 0.0:
			skipped.append(skill["name"])
			continue
		if hero_resource < skill["resource_cost"]:
			skipped.append(skill["name"])
			continue
		skill_cursor = (index + 1) % skill_order.size()
		_cast_skill(skill_id, skill, skipped.size())
		return
	battle_event.text = "本轮没有可用技能，等待下一次出手机会。"


func _cast_skill(skill_id: String, skill: Dictionary, skipped_count: int) -> void:
	hero_resource -= skill["resource_cost"]
	hero_resource = minf(
		Rules.MAX_RESOURCE,
		hero_resource + skill["resource_gain"],
	)
	skill_cooldowns[skill_id] = skill["cooldown"]
	var notes := PackedStringArray()
	if skipped_count > 0:
		notes.append("跳过 %d 个不可用技能" % skipped_count)

	if skill["kind"] == "defense":
		guard_charges = 1
		notes.append("下一次受伤降低 55%")
		battle_event.text = "释放 %s · %s" % [skill["name"], "，".join(notes)]
		return

	var damage: float = (
		hero_stats.attack_power()
		* skill["damage_multiplier"]
		* hero_stats.outgoing_multiplier()
	)
	if vulnerability_actions > 0 and skill_id != "vulnerability":
		damage *= VULNERABILITY_MULTIPLIER
		vulnerability_actions -= 1
		notes.append("易伤增伤")

	var is_critical := skill_id == "resource_spender" \
		or rng.randf() < hero_stats.critical_chance()
	if skill_id == "resource_spender":
		damage *= hero_stats.mastery_spender_multiplier()
		notes.append("精通强化")
	if is_critical:
		damage *= 2.0
		notes.append("暴击")

	enemy_health = maxf(0.0, enemy_health - damage)
	match skill_id:
		"vulnerability":
			vulnerability_actions = 3
			notes.append("施加 3 次易伤")
		"bleeding_strike":
			bleed_ticks_remaining = BLEED_TICK_COUNT
			bleed_tick_timer = BLEED_TICK_INTERVAL
			notes.append("施加流血 DOT")
	battle_event.text = "释放 %s，造成 %.0f 伤害" % [skill["name"], damage]
	if not notes.is_empty():
		battle_event.text += " · " + "，".join(notes)
	_resolve_enemy_defeat()


func _process_bleed(delta: float) -> void:
	if bleed_ticks_remaining <= 0 or enemy_health <= 0.0:
		return
	bleed_tick_timer -= delta
	if bleed_tick_timer > 0.0:
		return
	bleed_tick_timer += BLEED_TICK_INTERVAL
	bleed_ticks_remaining -= 1
	var damage := hero_stats.attack_power() * 0.18 * hero_stats.outgoing_multiplier()
	enemy_health = maxf(0.0, enemy_health - damage)
	battle_event.text = "流血造成 %.0f 伤害（剩余 %d 跳）" % [
		damage, bleed_ticks_remaining]
	_resolve_enemy_defeat()


func _enemy_take_action() -> void:
	var damage := enemy_damage * hero_stats.damage_taken_multiplier()
	var blocked := false
	if guard_charges > 0:
		damage *= 0.45
		guard_charges -= 1
		blocked = true
	hero_health = maxf(0.0, hero_health - damage)
	battle_event.text = "%s 攻击，英雄受到 %.0f 伤害" % [enemy_name.text, damage]
	if blocked:
		battle_event.text += " · 铁壁减伤生效"
	if hero_health <= 0.0:
		_return_to_preparation("挑战失败。调整资源循环与防御技能时机后重试。")


func _resolve_enemy_defeat() -> void:
	if enemy_health > 0.0:
		return
	if Rules.is_boss_floor(current_floor):
		_on_boss_defeated()
	else:
		ordinary_kills += 1
		loot_count += 1
		respawn_timer = NORMAL_RESPAWN_DELAY
		enemy_name.text = "正在寻找下一名敌人……"
		battle_event.text = "击杀完成，获得 1 件待鉴定战利品。"


func _on_boss_defeated() -> void:
	var defeated_floor := current_floor
	var first_clear := defeated_floor not in defeated_boss_floors
	if first_clear:
		defeated_boss_floors.append(defeated_floor)
		highest_unlocked_floor = Rules.unlocked_floor_after_boss(
			highest_unlocked_floor, defeated_floor)
	battle_state = BattleState.PREPARING
	if first_clear:
		current_floor = defeated_floor + 1
		battle_event.text = "Boss 已击败！已解锁第 %d–%d 层。" % [
			defeated_floor + 1, highest_unlocked_floor]
	else:
		battle_event.text = "再次击败第 %d 层守关 Boss。" % defeated_floor
	_refresh_all_ui()


func _move_skill(index: int, direction: int) -> void:
	if battle_state == BattleState.FIGHTING:
		return
	var target_index := index + direction
	if target_index < 0 or target_index >= skill_order.size():
		return
	var moved_skill := skill_order[index]
	skill_order[index] = skill_order[target_index]
	skill_order[target_index] = moved_skill
	battle_event.text = "技能顺序已调整，下一场战斗生效。"
	_refresh_skill_order_ui()


func _change_floor(direction: int) -> void:
	if battle_state == BattleState.FIGHTING:
		return
	current_floor = clampi(current_floor + direction, 1, highest_unlocked_floor)
	battle_event.text = "已选择第 %d 层。" % current_floor
	_refresh_all_ui()


func _reset_skill_cooldowns() -> void:
	skill_cooldowns.clear()
	for skill_id in skill_order:
		skill_cooldowns[skill_id] = 0.0


func _tick_skill_cooldowns(delta: float) -> void:
	var recovered_time := delta * hero_stats.haste_multiplier()
	for skill_id in skill_cooldowns:
		skill_cooldowns[skill_id] = maxf(
			0.0, skill_cooldowns[skill_id] - recovered_time)


func _refresh_all_ui() -> void:
	var boss_floor := Rules.is_boss_floor(current_floor)
	floor_status.text = "力量系原型 · 第 %d 层" % current_floor
	var definition := _current_floor_definition()
	var mode_name := "守关 BOSS" if boss_floor else "普通挂机层"
	var mechanic_label := String(definition.get("mechanic_label", ""))
	mode_status.text = mode_name if mechanic_label.is_empty() \
		else "%s · %s" % [mode_name, mechanic_label]
	mode_status.modulate = Color("ffb45c") if boss_floor else Color("8fd7ff")
	unlock_status.text = "已解锁 1–%d 层" % highest_unlocked_floor
	selected_floor.text = "第 %d 层" % current_floor
	previous_floor_button.disabled = battle_state == BattleState.FIGHTING or current_floor <= 1
	next_floor_button.disabled = battle_state == BattleState.FIGHTING \
		or current_floor >= highest_unlocked_floor
	start_button.text = "返回准备" if battle_state == BattleState.FIGHTING \
		else "开始自动战斗"
	battle_status.text = "自动战斗 · 未就绪或资源不足的技能会被跳过" \
		if battle_state == BattleState.FIGHTING \
		else "战前准备 · 配置资源循环与防御时机"
	_refresh_skill_order_ui()
	_refresh_combat_ui()


func _refresh_skill_order_ui() -> void:
	for index in skill_order.size():
		var skill_id := skill_order[index]
		var skill: Dictionary = skill_catalog[skill_id]
		var cooldown: float = skill_cooldowns.get(skill_id, 0.0)
		skill_labels[index].text = "%d. %s [%.1fs] · %s" % [
			index + 1, skill["name"], cooldown, skill["description"]]
		skill_up_buttons[index].disabled = battle_state == BattleState.FIGHTING or index == 0
		skill_down_buttons[index].disabled = battle_state == BattleState.FIGHTING \
			or index == skill_order.size() - 1


func _refresh_combat_ui() -> void:
	hero_health_bar.max_value = hero_stats.max_health()
	hero_health_bar.value = hero_health
	hero_health_text.text = "生命 %.0f / %.0f" % [hero_health, hero_stats.max_health()]
	hero_resource_bar.max_value = Rules.MAX_RESOURCE
	hero_resource_bar.value = hero_resource
	hero_resource_text.text = "战意 %.0f / %.0f" % [hero_resource, Rules.MAX_RESOURCE]
	if battle_state == BattleState.FIGHTING:
		enemy_health_bar.max_value = maxf(1.0, enemy_max_health)
		enemy_health_bar.value = enemy_health
		enemy_health_text.text = "生命 %.0f / %.0f" % [enemy_health, enemy_max_health]
	else:
		enemy_health_bar.max_value = 1.0
		enemy_health_bar.value = 0.0
		enemy_health_text.text = "等待开战"
	if battle_state == BattleState.FIGHTING:
		hero_action.text = "出手间隔 %.2fs · 铁壁 %d" % [
			hero_stats.adjusted_time(Rules.BASE_ACTION_INTERVAL), guard_charges]
		enemy_action.text = "易伤 %d · 流血 %d 跳" % [
			vulnerability_actions, bleed_ticks_remaining]
	else:
		hero_action.text = "攻击强度 %.0f · 首次 %.2fs · 间隔 %.2fs" % [
			hero_stats.attack_power(),
			hero_stats.adjusted_time(Rules.BASE_FIRST_ACTION_DELAY),
			hero_stats.adjusted_time(Rules.BASE_ACTION_INTERVAL),
		]
		enemy_action.text = "战斗状态会在这里显示"
	run_summary.text = (
		"力量 %.0f  敏捷 %.0f  智力 %.0f  耐力 %.0f\n"
		+ "精通 %.0f%%  急速 %.0f%%  暴击 %.0f%%  全能 %.0f%%\n"
		+ "击杀 %d · 待鉴定 %d"
	) % [
		hero_stats.strength, hero_stats.agility, hero_stats.intellect, hero_stats.stamina,
		hero_stats.mastery, hero_stats.haste, hero_stats.critical_strike,
		hero_stats.versatility, ordinary_kills, loot_count,
	]
	_refresh_skill_order_ui()


func _build_interface() -> void:
	var old_content := get_node_or_null("Content")
	if old_content:
		old_content.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 10
	margin.offset_top = 8
	margin.offset_right = -10
	margin.offset_bottom = -8
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)
	_build_header(layout)
	_build_arena(layout)
	_build_bottom(layout)


func _build_header(parent: Control) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 24
	header.add_theme_constant_override("separation", 14)
	parent.add_child(header)
	var title := _label("IDLE RIFT · PLAYTEST", 15, Color("e8b852"))
	title.custom_minimum_size.x = 158
	header.add_child(title)
	floor_status = _label("", 12)
	header.add_child(floor_status)
	mode_status = _label("", 12)
	header.add_child(mode_status)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	unlock_status = _label("", 12, Color("a8b3c2"))
	header.add_child(unlock_status)


func _build_arena(parent: Control) -> void:
	var arena := ColorRect.new()
	arena.custom_minimum_size.y = 150
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.color = Color("12151b")
	parent.add_child(arena)
	var ground := ColorRect.new()
	ground.color = Color("201b17")
	ground.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ground.offset_top = -25
	arena.add_child(ground)
	battle_status = _label("", 11, Color("b8c4d1"))
	battle_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	battle_status.offset_top = 4
	battle_status.offset_bottom = 22
	battle_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena.add_child(battle_status)
	_build_combatant_card(arena, true)
	_build_combatant_card(arena, false)
	var versus := _label("VS", 18, Color("edb856"))
	versus.set_anchors_preset(Control.PRESET_CENTER)
	versus.position = Vector2(-24, -25)
	versus.size = Vector2(48, 24)
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena.add_child(versus)
	battle_event = _label("配置五技能循环，然后开始自动战斗。", 10, Color("e0d1ad"))
	battle_event.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	battle_event.offset_left = 75
	battle_event.offset_top = -25
	battle_event.offset_right = -75
	battle_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_event.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arena.add_child(battle_event)


func _build_combatant_card(arena: Control, is_hero: bool) -> void:
	var card := ColorRect.new()
	card.color = Color("17303f") if is_hero else Color("401b19")
	card.offset_top = 28
	card.offset_bottom = 126
	if is_hero:
		card.offset_left = 24
		card.offset_right = 230
	else:
		card.anchor_left = 1.0
		card.anchor_right = 1.0
		card.offset_left = -230
		card.offset_right = -24
	arena.add_child(card)
	var info := VBoxContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info.offset_left = 9
	info.offset_top = 5
	info.offset_right = -9
	info.offset_bottom = -5
	info.add_theme_constant_override("separation", 1)
	card.add_child(info)
	var name_label := _label("力量系原型（我方）" if is_hero else "敌方（右侧）", 14,
		Color("85d6ff") if is_hero else Color("ff9480"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_hero \
		else HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(name_label)
	var health_bar := ProgressBar.new()
	health_bar.custom_minimum_size.y = 13
	health_bar.show_percentage = false
	info.add_child(health_bar)
	var health_text := _label("", 9)
	health_text.horizontal_alignment = name_label.horizontal_alignment
	info.add_child(health_text)
	if is_hero:
		hero_resource_bar = ProgressBar.new()
		hero_resource_bar.custom_minimum_size.y = 10
		hero_resource_bar.show_percentage = false
		info.add_child(hero_resource_bar)
		hero_resource_text = _label("", 9, Color("f0c45d"))
		info.add_child(hero_resource_text)
	var action_label := _label("", 9, Color("b3bfce"))
	action_label.horizontal_alignment = name_label.horizontal_alignment
	info.add_child(action_label)
	if is_hero:
		hero_health_bar = health_bar
		hero_health_text = health_text
		hero_action = action_label
	else:
		enemy_name = name_label
		enemy_health_bar = health_bar
		enemy_health_text = health_text
		enemy_action = action_label


func _build_bottom(parent: Control) -> void:
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size.y = 148
	bottom.add_theme_constant_override("separation", 6)
	parent.add_child(bottom)
	_build_skill_panel(bottom)
	_build_control_panel(bottom)


func _build_skill_panel(parent: Control) -> void:
	var panel := _panel(Color("111318"), 1.85)
	parent.add_child(panel)
	var layout := _inset_vbox(panel)
	layout.add_child(_label("战前五技能循环（自动跳过不可用技能）", 11, Color("e8b852")))
	for index in skill_order.size():
		var row := HBoxContainer.new()
		layout.add_child(row)
		var skill_label := _label("", 9)
		skill_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(skill_label)
		skill_labels.append(skill_label)
		var up := _button("↑", 24, 18)
		var down := _button("↓", 24, 18)
		row.add_child(up)
		row.add_child(down)
		skill_up_buttons.append(up)
		skill_down_buttons.append(down)


func _build_control_panel(parent: Control) -> void:
	var panel := _panel(Color("111318"), 1.0)
	parent.add_child(panel)
	var layout := _inset_vbox(panel)
	run_summary = _label("", 8, Color("b3bfce"))
	run_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(run_summary)
	var navigation := HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(navigation)
	previous_floor_button = _button("‹", 30, 22)
	next_floor_button = _button("›", 30, 22)
	selected_floor = _label("", 11)
	selected_floor.custom_minimum_size.x = 62
	selected_floor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation.add_child(previous_floor_button)
	navigation.add_child(selected_floor)
	navigation.add_child(next_floor_button)
	start_button = _button("开始自动战斗", 0, 24)
	start_button.add_theme_color_override("font_color", Color("ffd680"))
	layout.add_child(start_button)


func _panel(color: Color, stretch_ratio: float) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = color
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch_ratio
	return panel


func _inset_vbox(parent: Control) -> VBoxContainer:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 8
	layout.offset_top = 5
	layout.offset_right = -8
	layout.offset_bottom = -5
	layout.add_theme_constant_override("separation", 2)
	parent.add_child(layout)
	return layout


func _label(text_value: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text_value: String, width: float, height: float) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(width, height)
	button.add_theme_font_size_override("font_size", 9)
	return button
