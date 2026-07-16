class_name EquipmentGenerator
extends RefCounted

const Equipment = preload("res://src/equipment/equipment_item.gd")
const Repository = preload("res://src/data/game_data_repository.gd")

var rng := RandomNumberGenerator.new()
var game_data: GameDataRepository


func _init(seed_value: int = 0, repository: GameDataRepository = null) -> void:
	game_data = repository if repository != null else Repository.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value


func generate(item_level: int) -> EquipmentItem:
	var item := Equipment.new() as EquipmentItem
	var equipment_data := game_data.equipment()
	var slots: Array = equipment_data["slots"]
	var slot_definition: Dictionary = slots[rng.randi_range(0, slots.size() - 1)]
	var rarity_definition := _roll_rarity_definition()

	item.id = "%d-%d" % [Time.get_ticks_usec(), rng.randi()]
	item.item_level = maxi(1, item_level)
	item.slot = int(slot_definition["enum"])
	item.rarity = int(rarity_definition["enum"])
	item.base_stats = _roll_base_stats(slot_definition, item.item_level)
	item.affixes = _roll_affixes(rarity_definition, item.item_level)
	return item


func _roll_rarity_definition() -> Dictionary:
	var roll := rng.randf()
	var cumulative := 0.0
	var rarities: Array = game_data.equipment()["rarities"]
	for definition in rarities:
		cumulative += float(definition["weight"])
		if roll <= cumulative:
			return definition
	return rarities.back()


func _roll_base_stats(slot_definition: Dictionary, item_level: int) -> Dictionary:
	var per_level := float(game_data.equipment()["scaling"]["base_stat_per_level"])
	var scale := 1.0 + float(item_level - 1) * per_level
	var result := {}
	for stat_definition in slot_definition["base_stats"]:
		var stat_name := StringName(stat_definition["stat"])
		result[stat_name] = roundi(rng.randf_range(
			float(stat_definition["minimum"]),
			float(stat_definition["maximum"])
		) * scale)
	return result


func _roll_affixes(rarity_definition: Dictionary, item_level: int) -> Array[Dictionary]:
	var minimum := int(rarity_definition["affix_min"])
	var maximum := int(rarity_definition["affix_max"])
	var count := rng.randi_range(minimum, maximum) if maximum > 0 else 0
	var available: Array = game_data.equipment()["affixes"].duplicate(true)
	var result: Array[Dictionary] = []
	var per_level := float(game_data.equipment()["scaling"]["affix_per_level"])
	var level_scale := 1.0 + float(item_level - 1) * per_level
	for index in range(count):
		var chosen_index := rng.randi_range(0, available.size() - 1)
		var definition: Dictionary = available.pop_at(chosen_index)
		result.append({
			"stat": StringName(definition["stat"]),
			"name": definition["name"],
			"value": roundi(rng.randf_range(
				float(definition["minimum"]),
				float(definition["maximum"])
			) * level_scale),
		})
	return result
