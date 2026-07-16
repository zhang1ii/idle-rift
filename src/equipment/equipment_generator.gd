class_name EquipmentGenerator
extends RefCounted

const Equipment = preload("res://src/equipment/equipment_item.gd")

const AFFIX_POOL: Array[Dictionary] = [
	{"stat": &"attack", "name": "进攻", "minimum": 2.0, "maximum": 5.0},
	{"stat": &"health", "name": "活力", "minimum": 8.0, "maximum": 18.0},
	{"stat": &"armor", "name": "坚韧", "minimum": 2.0, "maximum": 7.0},
	{"stat": &"attack_speed", "name": "迅捷", "minimum": 3.0, "maximum": 9.0},
	{"stat": &"critical_chance", "name": "锐利", "minimum": 2.0, "maximum": 6.0},
	{"stat": &"block_chance", "name": "招架", "minimum": 3.0, "maximum": 8.0},
	{"stat": &"counter_damage", "name": "报偿", "minimum": 8.0, "maximum": 18.0},
]

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value


func generate(item_level: int) -> EquipmentItem:
	var item := Equipment.new() as EquipmentItem
	item.id = "%d-%d" % [Time.get_ticks_usec(), rng.randi()]
	item.item_level = maxi(1, item_level)
	item.slot = rng.randi_range(Equipment.Slot.WEAPON, Equipment.Slot.AMULET)
	item.rarity = _roll_rarity()
	item.base_stats = _base_stats_for(item.slot, item.item_level)
	item.affixes = _roll_affixes(item.rarity, item.item_level)
	return item


func _roll_rarity() -> EquipmentItem.Rarity:
	var roll := rng.randf()
	if roll < 0.15:
		return Equipment.Rarity.RARE
	if roll < 0.45:
		return Equipment.Rarity.MAGIC
	return Equipment.Rarity.COMMON


func _base_stats_for(slot: EquipmentItem.Slot, item_level: int) -> Dictionary:
	var scale := 1.0 + float(item_level - 1) * 0.12
	match slot:
		Equipment.Slot.WEAPON:
			return {&"attack": roundi(rng.randf_range(4.0, 7.0) * scale)}
		Equipment.Slot.HELM:
			return {&"health": roundi(rng.randf_range(10.0, 16.0) * scale)}
		Equipment.Slot.ARMOR:
			return {
				&"health": roundi(rng.randf_range(14.0, 22.0) * scale),
				&"armor": roundi(rng.randf_range(2.0, 5.0) * scale),
			}
		Equipment.Slot.RING:
			return {&"critical_chance": roundi(rng.randf_range(2.0, 4.0) * scale)}
		Equipment.Slot.AMULET:
			return {&"attack_speed": roundi(rng.randf_range(3.0, 6.0) * scale)}
	return {}


func _roll_affixes(rarity: EquipmentItem.Rarity, item_level: int) -> Array[Dictionary]:
	var count := 0
	match rarity:
		Equipment.Rarity.MAGIC:
			count = rng.randi_range(1, 2)
		Equipment.Rarity.RARE:
			count = 3

	var available: Array[Dictionary] = AFFIX_POOL.duplicate(true)
	var result: Array[Dictionary] = []
	var level_scale := 1.0 + float(item_level - 1) * 0.08
	for index in range(count):
		var chosen_index := rng.randi_range(0, available.size() - 1)
		var definition: Dictionary = available.pop_at(chosen_index)
		result.append({
			"stat": definition["stat"],
			"name": definition["name"],
			"value": roundi(rng.randf_range(definition["minimum"], definition["maximum"]) * level_scale),
		})
	return result
