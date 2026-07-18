class_name FuryBattleModel
extends RefCounted


signal event_emitted(event: Dictionary)

const FuryRules = preload("res://src/gameplay/fury_rules.gd")
const CombatRules = preload("res://src/gameplay/combat_rules.gd")
const CharacterStats = preload("res://src/gameplay/character_stats.gd")

const RESPAWN_DELAY := 1.15
const ATTACK_CONTACT_DELAY := 0.27

var hero_stats = CharacterStats.new()
var hero_health := 0.0
var hero_rage := 0.0
var hero_shield := 0.0
var enemy_health := 0.0
var enemy_max_health := 0.0
var enemy_damage := 0.0
var enemy_attack_interval := 1.75
var floor_number := 1
var kills := 0

var _running := false
var _hero_timer := 0.0
var _enemy_timer := 0.0
var _respawn_timer := -1.0
var _cooldowns: Dictionary = {}
var _bleed_ticks := 0
var _bleed_timer := 0.0
var _bleed_damage := 0.0
var _pending_attacks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20260717
	for skill_id in FuryRules.skill_catalog():
		_cooldowns[skill_id] = 0.0


func start(starting_floor := 1) -> void:
	floor_number = maxi(1, starting_floor)
	kills = 0
	hero_health = hero_stats.max_health()
	hero_rage = 0.0
	hero_shield = 0.0
	_hero_timer = 0.55
	_respawn_timer = -1.0
	_pending_attacks.clear()
	_running = true
	_spawn_enemy()
	_emit("battle_started", {"floor": floor_number})


func tick(delta: float) -> void:
	if not _running:
		return
	for skill_id in _cooldowns:
		_cooldowns[skill_id] = maxf(0.0, _cooldowns[skill_id] - delta)
	if _respawn_timer >= 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_spawn_enemy()
		return

	_tick_pending_attacks(delta)
	_tick_bleed(delta)
	if enemy_health <= 0.0:
		return
	_hero_timer -= delta
	_enemy_timer -= delta
	if _hero_timer <= 0.0:
		_take_hero_action()
		_hero_timer = hero_stats.adjusted_time(CombatRules.BASE_ACTION_INTERVAL)
	if enemy_health > 0.0 and _enemy_timer <= 0.0:
		_enemy_attack()
		_enemy_timer = enemy_attack_interval


func snapshot() -> Dictionary:
	return {
		"hero_health": hero_health,
		"hero_max_health": hero_stats.max_health(),
		"hero_rage": hero_rage,
		"hero_shield": hero_shield,
		"enemy_health": enemy_health,
		"enemy_max_health": enemy_max_health,
		"floor": floor_number,
		"kills": kills,
	}


func _take_hero_action() -> void:
	# The presentation slice keeps the existing Fury formulas, while choosing a
	# readable priority that guarantees builder, spender and barrier all appear.
	if kills >= 2 and hero_shield <= 0.0 and hero_rage >= 20.0 \
	and _cooldowns["rage_barrier"] <= 0.0:
		_cast_barrier()
		return
	if hero_rage >= 50.0 and _cooldowns["single_spender"] <= 0.0:
		_cast_attack("single_spender")
		return
	if _cooldowns["rage_builder"] <= 0.0:
		_cast_attack("rage_builder")


func _cast_attack(skill_id: String) -> void:
	var skill: Dictionary = FuryRules.skill_catalog()[skill_id]
	var rage_before := hero_rage
	var cost: float = skill["base_rage_cost"]
	hero_rage = maxf(0.0, hero_rage - cost)
	var rage_gain := FuryRules.rage_gain(skill["base_rage_gain"], hero_stats.mastery)
	hero_rage = minf(FuryRules.MAX_RAGE, hero_rage + rage_gain)
	_cooldowns[skill_id] = skill["cooldown"]
	_emit("skill_cast_started", {
		"skill_id": skill_id,
		"skill_name": skill["name"],
		"rage_before": rage_before,
	})

	var damage: float = (
		hero_stats.attack_power()
		* skill["damage_multiplier"]
		* hero_stats.outgoing_multiplier()
	)
	if skill_id == "single_spender":
		damage *= FuryRules.mastery_damage_multiplier(hero_stats.mastery)
	var critical := _rng.randf() < hero_stats.critical_chance()
	if critical:
		damage *= 2.0
	_pending_attacks.append({
		"remaining": ATTACK_CONTACT_DELAY,
		"damage": damage,
		"source": skill_id,
		"critical": critical,
		"applies_bleed": skill_id == "rage_builder",
	})
	_emit("rage_changed", {"value": hero_rage, "delta": hero_rage - rage_before})


func _tick_pending_attacks(delta: float) -> void:
	for index in range(_pending_attacks.size() - 1, -1, -1):
		var pending: Dictionary = _pending_attacks[index]
		pending["remaining"] = float(pending["remaining"]) - delta
		if pending["remaining"] > 0.0:
			_pending_attacks[index] = pending
			continue
		_pending_attacks.remove_at(index)
		if enemy_health <= 0.0:
			continue
		_apply_enemy_damage(
			float(pending["damage"]),
			String(pending["source"]),
			bool(pending["critical"]),
			false,
		)
		if bool(pending["applies_bleed"]) and enemy_health > 0.0:
			_apply_bleed(0.18)


func _cast_barrier() -> void:
	var skill: Dictionary = FuryRules.skill_catalog()["rage_barrier"]
	var rage_spent := hero_rage
	_emit("skill_cast_started", {
		"skill_id": "rage_barrier",
		"skill_name": skill["name"],
		"rage_before": rage_spent,
	})
	hero_shield = minf(
		FuryRules.barrier_cap(hero_stats.max_health()),
		hero_shield + FuryRules.barrier_amount(rage_spent),
	)
	hero_rage = 0.0
	_cooldowns["rage_barrier"] = skill["cooldown"]
	_emit("shield_changed", {"value": hero_shield, "gained": hero_shield})
	_emit("rage_changed", {"value": hero_rage, "delta": -rage_spent})


func _apply_bleed(tick_multiplier: float) -> void:
	_bleed_ticks = FuryRules.BLEED_TICKS
	_bleed_timer = FuryRules.BLEED_INTERVAL
	_bleed_damage = (
		hero_stats.attack_power()
		* tick_multiplier
		* hero_stats.outgoing_multiplier()
		* FuryRules.mastery_damage_multiplier(hero_stats.mastery)
	)
	_emit("bleed_applied", {"ticks": _bleed_ticks})


func _tick_bleed(delta: float) -> void:
	if _bleed_ticks <= 0 or enemy_health <= 0.0:
		return
	_bleed_timer -= delta
	if _bleed_timer > 0.0:
		return
	_bleed_timer += FuryRules.BLEED_INTERVAL
	_bleed_ticks -= 1
	_apply_enemy_damage(_bleed_damage, "bleed", false, true)


func _apply_enemy_damage(
	damage: float,
	source: String,
	critical: bool,
	is_dot: bool,
) -> void:
	var applied := minf(enemy_health, damage)
	enemy_health = maxf(0.0, enemy_health - damage)
	_emit("enemy_damaged", {
		"amount": applied,
		"source": source,
		"critical": critical,
		"is_dot": is_dot,
		"health": enemy_health,
		"max_health": enemy_max_health,
	})
	if enemy_health <= 0.0:
		_defeat_enemy()


func _enemy_attack() -> void:
	var incoming := enemy_damage * hero_stats.damage_taken_multiplier()
	var absorbed := minf(hero_shield, incoming)
	hero_shield -= absorbed
	var health_damage := incoming - absorbed
	hero_health = maxf(0.0, hero_health - health_damage)
	_emit("hero_damaged", {
		"amount": health_damage,
		"absorbed": absorbed,
		"health": hero_health,
		"max_health": hero_stats.max_health(),
	})
	if absorbed > 0.0:
		_emit("shield_changed", {"value": hero_shield, "gained": 0.0})
	if hero_health <= 0.0:
		_running = false
		_emit("hero_defeated", {})


func _defeat_enemy() -> void:
	kills += 1
	_bleed_ticks = 0
	_pending_attacks.clear()
	_respawn_timer = RESPAWN_DELAY
	_emit("enemy_defeated", {
		"kills": kills,
		"loot_quality": "稀有" if kills % 4 == 0 else "普通",
	})


func _spawn_enemy() -> void:
	var stats := CombatRules.enemy_stats(floor_number)
	enemy_max_health = stats["max_health"]
	enemy_health = enemy_max_health
	enemy_damage = stats["damage"]
	enemy_attack_interval = stats["attack_interval"]
	_enemy_timer = enemy_attack_interval
	_respawn_timer = -1.0
	_emit("enemy_spawned", {
		"name": "裂隙战獒",
		"health": enemy_health,
		"max_health": enemy_max_health,
	})


func _emit(type: String, payload: Dictionary) -> void:
	var event := payload.duplicate(true)
	event["type"] = type
	event_emitted.emit(event)
