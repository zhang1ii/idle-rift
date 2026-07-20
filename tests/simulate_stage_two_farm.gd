extends SceneTree


const Inventory = preload("res://src/gameplay/equipment_inventory.gd")
const Rules = preload("res://src/gameplay/equipment_rules.gd")
const Evaluator = preload("res://src/gameplay/equipment_evaluator.gd")
const Progression = preload("res://src/gameplay/progression_model.gd")

const SAMPLE_COUNT := 300
const TOTAL_MINUTES := 120
const BOSS_FLOOR := 5
const NORMAL_FLOOR := 9
const BOSS_RUN_SECONDS := 55.0
const NORMAL_RESPAWN_SECONDS := 1.15
const READY_EFFECTIVE_G := 7.50
const ONLINE_BOSS_MINUTES := [0, 30, 60, 90, 120]
const SET_IDS := ["blood_mark", "frenzy_tide", "iron_vow"]
const OFFENSE_PATTERNS := [
	{"name": "血痕5+狂潮2", "requirements": {"blood_mark": 5, "frenzy_tide": 2}},
	{"name": "狂潮5+血痕2", "requirements": {"frenzy_tide": 5, "blood_mark": 2}},
	{"name": "血痕4+狂潮4", "requirements": {"blood_mark": 4, "frenzy_tide": 4}},
]


func _init() -> void:
	_run_simulation()
	quit()


func _run_simulation() -> void:
	print("=== Stage 6-10 two-hour farm (%d samples) ===" % SAMPLE_COUNT)
	print("Readiness proxy: offensive mixed set + effective G >= %.2f" % READY_EFFECTIVE_G)
	for boss_minutes in ONLINE_BOSS_MINUTES:
		_simulate_allocation(boss_minutes, false)
	_simulate_allocation(-1, false)
	_simulate_allocation(0, true)


func _simulate_allocation(boss_minutes: int, offline: bool) -> void:
	var total_normal_drops := 0.0
	var total_set_drops := 0.0
	var total_score_g := 0.0
	var total_mixed_g := 0.0
	var total_boss_minutes_used := 0.0
	var mixed_build_count := 0
	var five_piece_count := 0
	var five_two_count := 0
	var four_four_count := 0
	var offense_mixed_count := 0
	var ready_count := 0
	var pattern_counts := {}
	for sample in range(SAMPLE_COUNT):
		var result := _simulate_player(sample, boss_minutes, offline)
		total_normal_drops += result.normal_drops
		total_set_drops += result.set_drops
		total_score_g += result.score_g
		total_boss_minutes_used += result.boss_minutes_used
		five_piece_count += int(result.has_five)
		five_two_count += int(result.has_five_two)
		four_four_count += int(result.has_four_four)
		if result.offense_build.valid:
			offense_mixed_count += 1
			total_mixed_g += result.offense_build.effective_g
			mixed_build_count += 1
			var pattern_name: String = result.offense_build.name
			pattern_counts[pattern_name] = int(pattern_counts.get(pattern_name, 0)) + 1
			if result.offense_build.effective_g >= READY_EFFECTIVE_G:
				ready_count += 1
	var normal_minutes := TOTAL_MINUTES - boss_minutes
	var label: String
	if offline:
		label = "Offline 0m Boss + 120m F9"
	elif boss_minutes < 0:
		label = "Adaptive: Boss until offense 5+2, then F9"
	else:
		label = "Online %dm Boss + %dm F9" % [boss_minutes, normal_minutes]
	var average_mixed_g := total_mixed_g / mixed_build_count if mixed_build_count > 0 else 0.0
	print("%s | boss avg %.1fm | normal %.1f | sets %.1f | score G%.2f | 5p %.1f%% | 5+2 %.1f%% | 4+4 %.1f%% | offense %.1f%% G%.2f | ready %.1f%% | %s" % [
		label,
		total_boss_minutes_used / SAMPLE_COUNT,
		total_normal_drops / SAMPLE_COUNT,
		total_set_drops / SAMPLE_COUNT,
		total_score_g / SAMPLE_COUNT,
		100.0 * five_piece_count / SAMPLE_COUNT,
		100.0 * five_two_count / SAMPLE_COUNT,
		100.0 * four_four_count / SAMPLE_COUNT,
		100.0 * offense_mixed_count / SAMPLE_COUNT,
		average_mixed_g,
		100.0 * ready_count / SAMPLE_COUNT,
		_pattern_summary(pattern_counts),
	])


func _simulate_player(sample: int, boss_minutes: int, offline: bool) -> Dictionary:
	var inventory = Inventory.new()
	inventory.rng.seed = 30000 + sample + boss_minutes * 1000 + (900000 if offline else 0)
	inventory.seed_reference_loadout(4, "rare")
	var set_drops := 0
	var first_set := inventory.grant_boss_drop(BOSS_FLOOR, true)
	set_drops += int(not String(first_set.set_id).is_empty())
	_auto_equip_newest(inventory)

	var boss_seconds_used := 0.0
	if not offline:
		var boss_seconds_limit := float(TOTAL_MINUTES if boss_minutes < 0 else boss_minutes) * 60.0
		while boss_seconds_used + BOSS_RUN_SECONDS <= boss_seconds_limit:
			if boss_minutes < 0 and _has_offense_five_two_items(inventory):
				break
			var item := inventory.grant_boss_drop(BOSS_FLOOR, false)
			set_drops += int(not String(item.set_id).is_empty())
			_auto_equip_newest(inventory)
			boss_seconds_used += BOSS_RUN_SECONDS

	var normal_seconds: float
	if offline:
		normal_seconds = float(TOTAL_MINUTES) * 60.0
	elif boss_minutes < 0:
		normal_seconds = float(TOTAL_MINUTES) * 60.0 - boss_seconds_used
	else:
		normal_seconds = float(TOTAL_MINUTES - boss_minutes) * 60.0
	var elapsed := 0.0
	var normal_drops := 0
	var kill_cycle := _normal_kill_cycle(inventory)
	while elapsed + kill_cycle <= normal_seconds:
		elapsed += kill_cycle
		var item := inventory.roll_normal_drop(NORMAL_FLOOR, offline)
		if item.is_empty():
			continue
		normal_drops += 1
		if _auto_equip_newest(inventory):
			kill_cycle = _normal_kill_cycle(inventory)

	var items := _all_items(inventory)
	var item_context := _build_item_context(items)
	var score_g := Evaluator.average_power_tier(inventory.equipped)
	var best_five_two := _best_pattern_group(item_context, _five_two_patterns())
	var best_four_four := _best_pattern_group(item_context, _four_four_patterns())
	var offense_build := _best_pattern_group(item_context, OFFENSE_PATTERNS)
	return {
		"normal_drops": normal_drops,
		"set_drops": set_drops,
		"score_g": score_g,
		"boss_minutes_used": boss_seconds_used / 60.0,
		"has_five": _has_any_five_piece(item_context),
		"has_five_two": best_five_two.valid,
		"has_four_four": best_four_four.valid,
		"offense_build": offense_build,
	}


func _auto_equip_newest(inventory) -> bool:
	if inventory.inventory.is_empty():
		return false
	if not inventory.is_potential_upgrade(inventory.inventory[-1]):
		return false
	return inventory.equip_newest_if_upgrade()


func _normal_kill_cycle(inventory) -> float:
	var gear_tier := Evaluator.average_power_tier(inventory.equipped)
	return Progression.estimated_normal_kill_time(NORMAL_FLOOR, gear_tier) \
		+ NORMAL_RESPAWN_SECONDS


func _has_offense_five_two_items(inventory) -> bool:
	var items := _all_items(inventory)
	return _can_assign_set_counts(items, "blood_mark", 5, "frenzy_tide", 2) \
		or _can_assign_set_counts(items, "frenzy_tide", 5, "blood_mark", 2)


func _can_assign_set_counts(
	items: Array[Dictionary],
	first_id: String,
	first_count: int,
	second_id: String,
	second_count: int,
) -> bool:
	var first_slots: Array[String] = []
	var second_slots: Array[String] = []
	for slot in Rules.ARMOR_SLOTS:
		if not _best_item(items, slot, first_id).is_empty():
			first_slots.append(slot)
		if not _best_item(items, slot, second_id).is_empty():
			second_slots.append(slot)
	if first_slots.size() < first_count or second_slots.size() < second_count:
		return false
	for selected_first in _combinations(first_slots, first_count):
		var available_second := 0
		for slot in second_slots:
			available_second += int(slot not in selected_first)
		if available_second >= second_count:
			return true
	return false


func _all_items(inventory) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for item in inventory.equipped.values():
		items.append(item)
	for item in inventory.inventory:
		items.append(item)
	return items


func _has_any_five_piece(context: Dictionary) -> bool:
	for set_id in SET_IDS:
		var covered := 0
		for slot in Rules.ARMOR_SLOTS:
			var by_category: Dictionary = context.armor[slot]
			if not Dictionary(by_category[set_id]).is_empty():
				covered += 1
		if covered >= 5:
			return true
	return false


func _five_two_patterns() -> Array[Dictionary]:
	var patterns: Array[Dictionary] = []
	for primary_id in SET_IDS:
		for secondary_id in SET_IDS:
			if primary_id == secondary_id:
				continue
			patterns.append({
				"name": "%s5+%s2" % [primary_id, secondary_id],
				"requirements": {primary_id: 5, secondary_id: 2},
			})
	return patterns


func _four_four_patterns() -> Array[Dictionary]:
	var patterns: Array[Dictionary] = []
	for first_index in range(SET_IDS.size()):
		for second_index in range(first_index + 1, SET_IDS.size()):
			var first_id: String = SET_IDS[first_index]
			var second_id: String = SET_IDS[second_index]
			patterns.append({
				"name": "%s4+%s4" % [first_id, second_id],
				"requirements": {first_id: 4, second_id: 4},
			})
	return patterns


func _best_pattern_group(context: Dictionary, patterns: Array) -> Dictionary:
	var best := {"valid": false, "score": -1.0, "effective_g": 0.0, "name": ""}
	for pattern in patterns:
		var candidate := _best_pattern_loadout(context, pattern)
		if candidate.valid and candidate.score > best.score:
			best = candidate
	return best


func _best_pattern_loadout(context: Dictionary, pattern: Dictionary) -> Dictionary:
	var requirement_ids: Array = pattern.requirements.keys()
	if requirement_ids.size() != 2:
		return {"valid": false, "score": -1.0, "effective_g": 0.0, "name": pattern.name}
	var first_id: String = requirement_ids[0]
	var second_id: String = requirement_ids[1]
	var first_count: int = pattern.requirements[first_id]
	var second_count: int = pattern.requirements[second_id]
	var best := {"valid": false, "score": -1.0, "effective_g": 0.0, "name": pattern.name}
	for first_slots in _combinations(Rules.ARMOR_SLOTS, first_count):
		var remaining_slots: Array[String] = []
		for slot in Rules.ARMOR_SLOTS:
			if slot not in first_slots:
				remaining_slots.append(slot)
		for second_slots in _combinations(remaining_slots, second_count):
			var assigned := {}
			for slot in first_slots:
				assigned[slot] = first_id
			for slot in second_slots:
				assigned[slot] = second_id
			var candidate := _build_loadout(context, assigned, pattern.name)
			if candidate.valid and candidate.score > best.score:
				best = candidate
	return best


func _build_loadout(context: Dictionary, assigned_sets: Dictionary, name: String) -> Dictionary:
	var equipped := {}
	for slot in Rules.ARMOR_SLOTS:
		var by_category: Dictionary = context.armor[slot]
		var item: Dictionary
		if assigned_sets.has(slot):
			item = by_category[String(assigned_sets[slot])]
		else:
			item = by_category.any
		if item.is_empty():
			return {"valid": false, "score": -1.0, "effective_g": 0.0, "name": name}
		equipped[slot] = item

	var weapon: Dictionary = context.weapon
	if weapon.is_empty():
		return {"valid": false, "score": -1.0, "effective_g": 0.0, "name": name}
	equipped["weapon"] = weapon
	var rings: Array = context.rings
	var trinkets: Array = context.trinkets
	if rings.size() < 2 or trinkets.size() < 2:
		return {"valid": false, "score": -1.0, "effective_g": 0.0, "name": name}
	equipped["ring_1"] = rings[0]
	equipped["ring_2"] = rings[1]
	equipped["trinket_1"] = trinkets[0]
	equipped["trinket_2"] = trinkets[1]
	var score := 0.0
	for item in equipped.values():
		score += Rules.item_score(item)
	return {
		"valid": true,
		"score": score,
		"effective_g": Evaluator.average_power_tier(equipped),
		"name": name,
	}


func _build_item_context(items: Array[Dictionary]) -> Dictionary:
	var armor := {}
	for slot in Rules.ARMOR_SLOTS:
		var by_category := {"any": _best_item(items, slot)}
		for set_id in SET_IDS:
			by_category[set_id] = _best_item(items, slot, set_id)
		armor[slot] = by_category
	return {
		"armor": armor,
		"weapon": _best_item(items, "weapon"),
		"rings": _best_items(items, "ring", 2),
		"trinkets": _best_items(items, "trinket", 2),
	}


func _best_item(items: Array[Dictionary], slot: String, set_id := "") -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1.0
	for item in items:
		if String(item.slot) != slot:
			continue
		if not set_id.is_empty() and String(item.set_id) != set_id:
			continue
		var score := Rules.item_score(item)
		if score > best_score:
			best = item
			best_score = score
	return best


func _best_items(items: Array[Dictionary], slot: String, count: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for item in items:
		if String(item.slot) == slot:
			candidates.append(item)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Rules.item_score(a) > Rules.item_score(b))
	return candidates.slice(0, mini(count, candidates.size()))


func _combinations(source: Array, count: int) -> Array:
	var results := []
	_collect_combinations(source, count, 0, [], results)
	return results


func _collect_combinations(source: Array, count: int, start: int, current: Array, results: Array) -> void:
	if current.size() == count:
		results.append(current.duplicate())
		return
	for index in range(start, source.size()):
		current.append(source[index])
		_collect_combinations(source, count, index + 1, current, results)
		current.pop_back()


func _pattern_summary(counts: Dictionary) -> String:
	if counts.is_empty():
		return "no offense mix"
	var parts := PackedStringArray()
	for pattern_name in counts:
		parts.append("%s %.0f%%" % [pattern_name, 100.0 * int(counts[pattern_name]) / SAMPLE_COUNT])
	return ", ".join(parts)
