class_name FuryTalentRules
extends RefCounted


static func bleed_damage_multiplier(tree: Dictionary, active: Array) -> float:
	return _product_effect(tree, active, "bleed_damage_multiplier")


static func builder_rage_bonus(tree: Dictionary, active: Array) -> float:
	return _sum_effect(tree, active, "builder_flat_rage_bonus")


static func max_health_multiplier(tree: Dictionary, active: Array) -> float:
	return _product_effect(tree, active, "max_health_multiplier")


static func dot_heal_conversion_ratio(tree: Dictionary, active: Array) -> float:
	return _override_effect(tree, active, "dot_heal_conversion_ratio", 0.75)


static func dot_heal_cap_ratio(tree: Dictionary, active: Array) -> float:
	return _override_effect(tree, active, "dot_heal_cap_ratio", 0.35)


static func bleed_leech_ratio(tree: Dictionary, active: Array) -> float:
	return _sum_effect(tree, active, "bleed_leech_ratio")


static func burst_charge_bonus(tree: Dictionary, active: Array) -> int:
	return int(_sum_effect(tree, active, "burst_charge_bonus"))


static func spender_damage_multiplier(tree: Dictionary, active: Array) -> float:
	return _product_effect(tree, active, "spender_damage_multiplier")


static func remaining_bleed_burst_ratio(tree: Dictionary, active: Array) -> float:
	return _sum_effect(tree, active, "remaining_bleed_burst_ratio")


static func burst_spender_refund_ratio(tree: Dictionary, active: Array) -> float:
	return _sum_effect(tree, active, "burst_spender_refund_ratio")


static func steady_rage_enabled(active: Array) -> bool:
	return "steady_rage" in active


static func haste_to_barrier_rate(tree: Dictionary, active: Array) -> float:
	return _sum_effect(tree, active, "haste_to_power_per_percent")


static func barrier_break_refund_ratio(tree: Dictionary, active: Array) -> float:
	return _sum_effect(tree, active, "barrier_break_rage_refund_ratio")


static func barrier_damage_reduction(tree: Dictionary, active: Array) -> float:
	return _sum_effect(tree, active, "barrier_damage_reduction")


static func barrier_reduction_duration(tree: Dictionary, active: Array) -> float:
	return _sum_effect(tree, active, "barrier_reduction_duration")


static func _active_nodes(tree: Dictionary, active: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in tree["nodes"]:
		if String(node["id"]) in active:
			result.append(node as Dictionary)
	return result


static func _sum_effect(tree: Dictionary, active: Array, key: String) -> float:
	var total := 0.0
	for node in _active_nodes(tree, active):
		var effects: Dictionary = node.get("effects", {})
		if effects.has(key):
			total += float(effects[key])
	return total


static func _product_effect(tree: Dictionary, active: Array, key: String) -> float:
	var product := 1.0
	for node in _active_nodes(tree, active):
		var effects: Dictionary = node.get("effects", {})
		if effects.has(key):
			product *= float(effects[key])
	return product


static func _override_effect(
	tree: Dictionary,
	active: Array,
	key: String,
	default_value: float,
) -> float:
	var value := default_value
	for node in _active_nodes(tree, active):
		var effects: Dictionary = node.get("effects", {})
		if effects.has(key):
			value = float(effects[key])
	return value
