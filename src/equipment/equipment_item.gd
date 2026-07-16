class_name EquipmentItem
extends RefCounted

const Repository = preload("res://src/data/game_data_repository.gd")

static var _repository := Repository.new() as GameDataRepository

enum Slot {
	WEAPON,
	HELM,
	ARMOR,
	RING,
	AMULET,
}

enum Rarity {
	COMMON,
	MAGIC,
	RARE,
}

var id: String
var slot: Slot
var rarity: Rarity
var item_level: int
var base_stats: Dictionary = {}
var affixes: Array[Dictionary] = []


func total_stat(stat_name: StringName) -> float:
	var total := float(base_stats.get(stat_name, 0.0))
	for affix in affixes:
		if affix.get("stat", &"") == stat_name:
			total += float(affix.get("value", 0.0))
	return total


func power_score() -> int:
	return roundi(
		total_stat(&"attack") * 4.0
		+ total_stat(&"health") * 0.35
		+ total_stat(&"armor") * 1.4
		+ total_stat(&"attack_speed") * 1.8
		+ total_stat(&"critical_chance") * 2.2
		+ total_stat(&"block_chance") * 2.0
		+ total_stat(&"counter_damage") * 1.5
	)


func display_name() -> String:
	return "%s %s" % [rarity_prefix(rarity), slot_name(slot)]


func short_description() -> String:
	var lines: Array[String] = ["物品等级 %d · 战力 %d" % [item_level, power_score()]]
	for stat_name in base_stats:
		lines.append(_format_stat(stat_name, float(base_stats[stat_name])))
	for affix in affixes:
		lines.append(_format_stat(affix["stat"], float(affix["value"])))
	return "\n".join(lines)


static func slot_name(value: Slot) -> String:
	return String(_repository.slot_definition(value)["name"])


static func rarity_prefix(value: Rarity) -> String:
	return String(_repository.rarity_definition(value)["prefix"])


static func rarity_color(value: Rarity) -> Color:
	return Color(String(_repository.rarity_definition(value)["color"]))


static func stat_label(stat_name: StringName) -> String:
	match stat_name:
		&"attack":
			return "攻击"
		&"health":
			return "生命"
		&"armor":
			return "护甲"
		&"attack_speed":
			return "攻速"
		&"critical_chance":
			return "暴击"
		&"block_chance":
			return "格挡"
		&"counter_damage":
			return "反击伤害"
	return String(stat_name)


func _format_stat(stat_name: StringName, value: float) -> String:
	if stat_name in [&"attack_speed", &"critical_chance", &"block_chance", &"counter_damage"]:
		return "+%d%% %s" % [roundi(value), stat_label(stat_name)]
	return "+%d %s" % [roundi(value), stat_label(stat_name)]
