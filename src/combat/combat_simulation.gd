class_name CombatSimulation
extends RefCounted

signal battle_event(message: String)
signal equipment_dropped(item: EquipmentItem)
signal inventory_changed
signal equipment_changed

const Equipment = preload("res://src/equipment/equipment_item.gd")
const Generator = preload("res://src/equipment/equipment_generator.gd")
const Repository = preload("res://src/data/game_data_repository.gd")
const State = preload("res://src/combat/combat_state.gd")

var rng := RandomNumberGenerator.new()
var generator: EquipmentGenerator
var game_data: GameDataRepository
var state: CombatState

var inventory: Array[EquipmentItem]:
	get: return state.inventory
var equipped: Dictionary:
	get: return state.equipped
var elapsed_time: float:
	get: return state.elapsed_time
var selected_class_id: StringName:
	get: return state.selected_class_id
	set(value): state.selected_class_id = value
var kill_count: int:
	get: return state.kill_count
var gold: int:
	get: return state.gold
var class_resource: float:
	get: return state.class_resource
var blocked_attacks: int:
	get: return state.blocked_attacks
var counter_attacks: int:
	get: return state.counter_attacks
var paused: bool:
	get: return state.paused
	set(value): state.paused = value
var speed_multiplier: float:
	get: return state.speed_multiplier
	set(value): state.speed_multiplier = value
var hero_health: float:
	get: return state.hero_health
var enemy_name: String:
	get: return state.enemy_name
var enemy_level: int:
	get: return state.enemy_level
var enemy_health: float:
	get: return state.enemy_health
var enemy_max_health: float:
	get: return state.enemy_max_health


func _init(seed_value: int = 0, repository: GameDataRepository = null, initial_state: CombatState = null) -> void:
	game_data = repository if repository != null else Repository.new()
	state = initial_state if initial_state != null else State.new()
	if seed_value == 0:
		rng.randomize()
		generator = Generator.new(0, game_data)
	else:
		rng.seed = seed_value
		generator = Generator.new(seed_value + 1, game_data)
	if initial_state == null:
		state.selected_class_id = StringName(game_data.classes()["default_class_id"])
		state.hero_health = hero_max_health()
	_spawn_enemy()


func tick(delta: float) -> void:
	if state.paused:
		return

	var step := delta * state.speed_multiplier
	state.elapsed_time += step
	if state.respawn_delay > 0.0:
		state.respawn_delay -= step
		if state.respawn_delay <= 0.0:
			_spawn_enemy()
		return

	state.hero_attack_cooldown -= step
	state.enemy_attack_cooldown -= step

	if state.hero_attack_cooldown <= 0.0:
		_hero_attack()
		state.hero_attack_cooldown += 1.0 / hero_attack_speed()

	if state.enemy_health > 0.0 and state.enemy_attack_cooldown <= 0.0:
		_enemy_attack()
		var attack_data: Dictionary = game_data.combat()["enemy_attack"]
		state.enemy_attack_cooldown += maxf(
			float(attack_data["minimum_interval"]),
			float(attack_data["interval_base"]) - float(state.enemy_level) * float(attack_data["interval_per_level"])
		)


func hero_damage() -> float:
	return float(game_data.combat()["hero"]["base_damage"]) + _equipped_stat(&"attack")


func hero_max_health() -> float:
	return float(game_data.combat()["hero"]["base_health"]) + _equipped_stat(&"health")


func hero_armor() -> float:
	return _equipped_stat(&"armor")


func hero_attack_speed() -> float:
	var hero_data: Dictionary = game_data.combat()["hero"]
	return clampf(
		1.0 + _equipped_stat(&"attack_speed") / 100.0,
		float(hero_data["minimum_attack_speed"]),
		float(hero_data["maximum_attack_speed"])
	)


func hero_critical_chance() -> float:
	return clampf(float(game_data.combat()["hero"]["base_critical_chance"]) + _equipped_stat(&"critical_chance") / 100.0, 0.0, 0.75)


func hero_block_chance() -> float:
	if state.selected_class_id != &"iron_vow":
		return 0.0
	var mechanics: Dictionary = class_definition()["mechanics"]
	return clampf(float(mechanics["base_block_chance"]) + _equipped_stat(&"block_chance") / 100.0, 0.0, 0.75)


func class_definition() -> Dictionary:
	return game_data.class_definition(state.selected_class_id)


func current_rift_level() -> int:
	return 1 + floori(float(state.kill_count) / float(game_data.combat()["rift"]["kills_per_level"]))


func kills_per_minute() -> float:
	if state.elapsed_time <= 0.0:
		return 0.0
	return float(state.kill_count) / state.elapsed_time * 60.0


func equip_item(item: EquipmentItem) -> bool:
	var inventory_index := state.inventory.find(item)
	if inventory_index < 0:
		return false

	var previous_max_health := hero_max_health()
	state.inventory.remove_at(inventory_index)
	if state.equipped.has(item.slot):
		state.inventory.append(state.equipped[item.slot])
	state.equipped[item.slot] = item
	var health_gain := hero_max_health() - previous_max_health
	state.hero_health = clampf(state.hero_health + maxf(0.0, health_gain), 1.0, hero_max_health())
	battle_event.emit("装备 %s，战斗属性已更新。" % item.display_name())
	inventory_changed.emit()
	equipment_changed.emit()
	return true


func equipped_item(slot: EquipmentItem.Slot) -> EquipmentItem:
	return state.equipped.get(slot) as EquipmentItem


func _hero_attack() -> void:
	var damage := hero_damage()
	var mechanics: Dictionary = class_definition()["mechanics"]
	var resource_max := float(mechanics.get("resource_max", 100.0))
	var shield_slam := state.selected_class_id == &"iron_vow" and state.class_resource >= resource_max
	if shield_slam:
		damage *= float(mechanics["shield_slam_multiplier"])
		state.class_resource = 0.0
		battle_event.emit("守势蓄满，发动裂盾猛击。")
	var critical := rng.randf() <= hero_critical_chance()
	if critical:
		damage *= float(game_data.combat()["hero"]["critical_damage_multiplier"])
	state.enemy_health = maxf(0.0, state.enemy_health - damage)
	if state.enemy_health <= 0.0:
		_on_enemy_defeated(critical)


func _enemy_attack() -> void:
	var attack_data: Dictionary = game_data.combat()["enemy_attack"]
	var raw_damage := float(attack_data["damage_base"]) + float(state.enemy_level) * float(attack_data["damage_per_level"])
	var received := maxf(1.0, raw_damage - hero_armor() * float(attack_data["armor_reduction_factor"]))
	if rng.randf() <= hero_block_chance():
		var mechanics: Dictionary = class_definition()["mechanics"]
		received *= float(mechanics["blocked_damage_multiplier"])
		state.class_resource = minf(float(mechanics["resource_max"]), state.class_resource + float(mechanics["resource_per_block"]))
		state.blocked_attacks += 1
		state.counter_attacks += 1
		var counter_multiplier := float(mechanics["counter_damage_multiplier"]) + _equipped_stat(&"counter_damage") / 100.0
		state.enemy_health = maxf(0.0, state.enemy_health - hero_damage() * counter_multiplier)
		battle_event.emit("格挡攻击并立即反击。")
		if state.enemy_health <= 0.0:
			_on_enemy_defeated(false)
			return
	state.hero_health = maxf(0.0, state.hero_health - received)
	if state.hero_health <= 0.0:
		battle_event.emit("英雄倒下，2 秒后重新投入战斗。")
		state.hero_health = hero_max_health()
		state.enemy_health = state.enemy_max_health
		state.respawn_delay = float(game_data.combat()["rift"]["hero_defeat_delay"])


func _on_enemy_defeated(was_critical: bool) -> void:
	state.kill_count += 1
	var rewards: Dictionary = game_data.combat()["rewards"]
	state.gold += int(rewards["gold_base"]) + state.enemy_level * int(rewards["gold_per_enemy_level"])
	var detail := " 暴击终结。" if was_critical else ""
	battle_event.emit("击败 %s。%s" % [state.enemy_name, detail])

	if state.inventory.is_empty() or rng.randf() <= float(rewards["drop_chance"]):
		var item := generator.generate(current_rift_level())
		state.inventory.append(item)
		equipment_dropped.emit(item)
		inventory_changed.emit()

	state.respawn_delay = float(game_data.combat()["rift"]["respawn_delay"])


func _spawn_enemy() -> void:
	var rift_data: Dictionary = game_data.combat()["rift"]
	state.enemy_level = current_rift_level()
	var enemies := game_data.enemies()
	var enemy_index := floori(float(state.kill_count) / float(rift_data["enemy_rotation_kills"])) % enemies.size()
	var enemy_definition: Dictionary = enemies[enemy_index]
	state.enemy_id = enemy_definition["id"]
	state.enemy_name = enemy_definition["name"]
	state.enemy_max_health = roundf(float(rift_data["enemy_health_base"]) * (1.0 + float(state.enemy_level) * float(rift_data["enemy_health_per_level"])))
	state.enemy_health = state.enemy_max_health
	state.hero_attack_cooldown = minf(state.hero_attack_cooldown, 0.18)
	state.enemy_attack_cooldown = 1.0


func _equipped_stat(stat_name: StringName) -> float:
	var total := 0.0
	for item in state.equipped.values():
		total += (item as EquipmentItem).total_stat(stat_name)
	return total
