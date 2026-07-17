class_name TalentTreeModel
extends RefCounted


var tree_definition: Dictionary = {}
var point_budget := 0
var active_talent_ids: Array[String] = []
var battle_locked := false
var _nodes_by_id: Dictionary = {}


func configure(definition: Dictionary, budget_override := -1) -> void:
	tree_definition = definition.duplicate(true)
	assert(tree_definition.has("branches"), "Talent tree requires branches.")
	assert(tree_definition.has("nodes"), "Talent tree requires nodes.")
	point_budget = int(tree_definition["prototype_point_budget"]) \
		if budget_override < 0 else maxi(0, budget_override)
	active_talent_ids.clear()
	battle_locked = false
	_nodes_by_id.clear()
	var branch_ids: Array[String] = []
	for branch in tree_definition["branches"]:
		var branch_id := String(branch["id"])
		assert(not branch_id.is_empty(), "Talent branch id cannot be empty.")
		assert(branch_id not in branch_ids, "Duplicate talent branch: %s" % branch_id)
		branch_ids.append(branch_id)
	for node in tree_definition["nodes"]:
		var node_id := String(node["id"])
		assert(not node_id.is_empty(), "Talent id cannot be empty.")
		assert(not _nodes_by_id.has(node_id), "Duplicate talent id: %s" % node_id)
		_nodes_by_id[node_id] = (node as Dictionary).duplicate(true)
	for node_id in _nodes_by_id:
		var node: Dictionary = _nodes_by_id[node_id]
		assert(String(node["branch"]) in branch_ids, "Unknown branch for talent: %s" % node_id)
		assert(int(node["tier"]) >= 1, "Talent tier must be positive: %s" % node_id)
		assert(int(node.get("cost", 1)) > 0, "Talent cost must be positive: %s" % node_id)
		for prerequisite in node.get("prerequisites", []):
			var prerequisite_id := String(prerequisite)
			assert(_nodes_by_id.has(prerequisite_id), "Unknown prerequisite: %s" % prerequisite_id)
			assert(
				int(_nodes_by_id[prerequisite_id]["tier"]) < int(node["tier"]),
				"Talent prerequisite must be from an earlier tier: %s" % node_id,
			)


func points_spent() -> int:
	var total := 0
	for talent_id in active_talent_ids:
		total += int(_nodes_by_id[talent_id].get("cost", 1))
	return total


func points_remaining() -> int:
	return point_budget - points_spent()


func has_talent(talent_id: String) -> bool:
	return talent_id in active_talent_ids


func can_allocate(talent_id: String) -> bool:
	if battle_locked or has_talent(talent_id) or not _nodes_by_id.has(talent_id):
		return false
	var node: Dictionary = _nodes_by_id[talent_id]
	var cost := int(node.get("cost", 1))
	if points_remaining() < cost:
		return false
	if points_spent() < int(node.get("required_total_points", 0)):
		return false
	for prerequisite in node.get("prerequisites", []):
		if not has_talent(String(prerequisite)):
			return false
	var exclusive_group := String(node.get("exclusive_group", ""))
	if not exclusive_group.is_empty():
		for active_id in active_talent_ids:
			if String(_nodes_by_id[active_id].get("exclusive_group", "")) == exclusive_group:
				return false
	return true


func allocate(talent_id: String) -> bool:
	if not can_allocate(talent_id):
		return false
	active_talent_ids.append(talent_id)
	return true


func can_refund(talent_id: String) -> bool:
	if battle_locked or not has_talent(talent_id):
		return false
	for active_id in active_talent_ids:
		var prerequisites: Array = _nodes_by_id[active_id].get("prerequisites", [])
		if talent_id in prerequisites:
			return false
	return true


func refund(talent_id: String) -> bool:
	if not can_refund(talent_id):
		return false
	active_talent_ids.erase(talent_id)
	return true


func reset() -> bool:
	if battle_locked:
		return false
	active_talent_ids.clear()
	return true


func begin_battle() -> void:
	battle_locked = true


func end_battle() -> void:
	battle_locked = false


func node_definition(talent_id: String) -> Dictionary:
	if not _nodes_by_id.has(talent_id):
		return {}
	return (_nodes_by_id[talent_id] as Dictionary).duplicate(true)


func snapshot() -> Dictionary:
	return {
		"point_budget": point_budget,
		"points_spent": points_spent(),
		"points_remaining": points_remaining(),
		"active_talent_ids": active_talent_ids.duplicate(),
		"battle_locked": battle_locked,
	}
