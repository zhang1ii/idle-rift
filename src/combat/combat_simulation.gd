class_name CombatSimulation
extends RefCounted

signal battle_event(message: String)
signal equipment_dropped(item: EquipmentItem)
signal inventory_changed
signal equipment_changed

const Equipment = preload("res://src/equipment/equipment_item.gd")
const Generator = preload("res://src/equipment/equipment_generator.gd")
const Classes = preload("res://src/data/class_definition.gd")

const BASE_HERO_DAMAGE := 8.0
const BASE_HERO_HEALTH := 100.0
const DROP_CHANCE := 0.72
const ENEMY_NAMES: Array[String] = ["腐化鼠人", "墓穴游魂", "裂隙猎犬", "灰烬守卫"]

var rng := RandomNumberGenerator.new()
var generator: EquipmentGenerator
var inventory: Array[EquipmentItem] = []
var equipped: Dictionary = {}

var elapsed_time := 0.0
var selected_class_id: StringName = &"iron_vow"
var kill_count := 0
var gold := 0
var class_resource := 0.0
var blocked_attacks := 0
var counter_attacks := 0
var paused := false
var speed_multiplier := 1.0

var hero_health := BASE_HERO_HEALTH
var hero_attack_cooldown := 0.0
var enemy_attack_cooldown := 1.0
var respawn_delay := 0.0

var enemy_name := ""
var enemy_level := 1
var enemy_health := 1.0
var enemy_max_health := 1.0


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
		generator = Generator.new()
	else:
		rng.seed = seed_value
		generator = Generator.new(seed_value + 1)
	_spawn_enemy()


func tick(delta: float) -> void:
	if paused:
		return

	var step := delta * speed_multiplier
	elapsed_time += step
	if respawn_delay > 0.0:
		respawn_delay -= step
		if respawn_delay <= 0.0:
			_spawn_enemy()
		return

	hero_attack_cooldown -= step
	enemy_attack_cooldown -= step

	if hero_attack_cooldown <= 0.0:
		_hero_attack()
		hero_attack_cooldown += 1.0 / hero_attack_speed()

	if enemy_health > 0.0 and enemy_attack_cooldown <= 0.0:
		_enemy_attack()
		enemy_attack_cooldown += maxf(0.65, 1.35 - float(enemy_level) * 0.025)


func hero_damage() -> float:
	return BASE_HERO_DAMAGE + _equipped_stat(&"attack")


func hero_max_health() -> float:
	return BASE_HERO_HEALTH + _equipped_stat(&"health")


func hero_armor() -> float:
	return _equipped_stat(&"armor")


func hero_attack_speed() -> float:
	return clampf(1.0 + _equipped_stat(&"attack_speed") / 100.0, 0.4, 3.0)


func hero_critical_chance() -> float:
	return clampf(0.05 + _equipped_stat(&"critical_chance") / 100.0, 0.0, 0.75)


func hero_block_chance() -> float:
	if selected_class_id != &"iron_vow":
		return 0.0
	return clampf(0.22 + _equipped_stat(&"block_chance") / 100.0, 0.0, 0.75)


func class_definition() -> Dictionary:
	return Classes.get_definition(selected_class_id)


func current_rift_level() -> int:
	return 1 + floori(float(kill_count) / 5.0)


func kills_per_minute() -> float:
	if elapsed_time <= 0.0:
		return 0.0
	return float(kill_count) / elapsed_time * 60.0


func equip_item(item: EquipmentItem) -> bool:
	var inventory_index := inventory.find(item)
	if inventory_index < 0:
		return false

	var previous_max_health := hero_max_health()
	inventory.remove_at(inventory_index)
	if equipped.has(item.slot):
		inventory.append(equipped[item.slot])
	equipped[item.slot] = item
	var health_gain := hero_max_health() - previous_max_health
	hero_health = clampf(hero_health + maxf(0.0, health_gain), 1.0, hero_max_health())
	battle_event.emit("装备 %s，战斗属性已更新。" % item.display_name())
	inventory_changed.emit()
	equipment_changed.emit()
	return true


func equipped_item(slot: EquipmentItem.Slot) -> EquipmentItem:
	return equipped.get(slot) as EquipmentItem


func _hero_attack() -> void:
	var damage := hero_damage()
	var shield_slam := selected_class_id == &"iron_vow" and class_resource >= 100.0
	if shield_slam:
		damage *= 1.8
		class_resource = 0.0
		battle_event.emit("守势蓄满，发动裂盾猛击。")
	var critical := rng.randf() <= hero_critical_chance()
	if critical:
		damage *= 1.75
	enemy_health = maxf(0.0, enemy_health - damage)
	if enemy_health <= 0.0:
		_on_enemy_defeated(critical)


func _enemy_attack() -> void:
	var raw_damage := 4.5 + float(enemy_level) * 1.15
	var received := maxf(1.0, raw_damage - hero_armor() * 0.35)
	if rng.randf() <= hero_block_chance():
		received *= 0.25
		class_resource = minf(100.0, class_resource + 22.0)
		blocked_attacks += 1
		counter_attacks += 1
		var counter_multiplier := 0.65 + _equipped_stat(&"counter_damage") / 100.0
		enemy_health = maxf(0.0, enemy_health - hero_damage() * counter_multiplier)
		battle_event.emit("格挡攻击并立即反击。")
		if enemy_health <= 0.0:
			_on_enemy_defeated(false)
			return
	hero_health = maxf(0.0, hero_health - received)
	if hero_health <= 0.0:
		battle_event.emit("英雄倒下，2 秒后重新投入战斗。")
		hero_health = hero_max_health()
		enemy_health = enemy_max_health
		respawn_delay = 2.0


func _on_enemy_defeated(was_critical: bool) -> void:
	kill_count += 1
	gold += 2 + enemy_level
	var detail := " 暴击终结。" if was_critical else ""
	battle_event.emit("击败 %s。%s" % [enemy_name, detail])

	if inventory.is_empty() or rng.randf() <= DROP_CHANCE:
		var item := generator.generate(current_rift_level())
		inventory.append(item)
		equipment_dropped.emit(item)
		inventory_changed.emit()

	respawn_delay = 0.45


func _spawn_enemy() -> void:
	enemy_level = current_rift_level()
	var enemy_index := floori(float(kill_count) / 2.0) % ENEMY_NAMES.size()
	enemy_name = ENEMY_NAMES[enemy_index]
	enemy_max_health = roundf(25.0 * (1.0 + float(enemy_level) * 0.24))
	enemy_health = enemy_max_health
	hero_attack_cooldown = minf(hero_attack_cooldown, 0.18)
	enemy_attack_cooldown = 1.0


func _equipped_stat(stat_name: StringName) -> float:
	var total := 0.0
	for item in equipped.values():
		total += (item as EquipmentItem).total_stat(stat_name)
	return total
