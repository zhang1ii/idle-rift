class_name EquipmentEvaluator
extends RefCounted


const Rules = preload("res://src/gameplay/equipment_rules.gd")

const REFERENCE_RARE_AFFIX_MULTIPLIER := 0.925


static func effective_item_tier(item: Dictionary) -> float:
	var unit_budget := Rules.item_budget(1, item.slot)
	var reference_score: float = (
		unit_budget.primary
		+ unit_budget.stamina * 0.35
		+ unit_budget.secondary * REFERENCE_RARE_AFFIX_MULTIPLIER * 0.60
	)
	if reference_score <= 0.0:
		return 0.0
	return Rules.item_score(item) / reference_score


static func average_power_tier(equipped: Dictionary) -> float:
	if equipped.is_empty():
		return 0.0
	var total := 0.0
	for target in Rules.EQUIPMENT_TARGETS:
		if equipped.has(target):
			total += effective_item_tier(equipped[target])
	return total / Rules.EQUIPMENT_TARGETS.size()
