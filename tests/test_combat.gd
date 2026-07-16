extends SceneTree

const Combat = preload("res://src/combat/combat_simulation.gd")
const Equipment = preload("res://src/equipment/equipment_item.gd")
const Repository = preload("res://src/data/game_data_repository.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_idle_combat(failures)
	_test_equipment_generation(failures)
	_test_game_data_and_state_separation(failures)

	if failures.is_empty():
		print("PASS: combat and equipment tests")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _test_idle_combat(failures: Array[String]) -> void:
	var simulation := Combat.new(41021) as CombatSimulation
	for frame in range(2400):
		simulation.tick(0.05)

	_expect(simulation.kill_count > 0, "Auto combat should defeat enemies.", failures)
	_expect(not simulation.inventory.is_empty(), "Defeated enemies should produce loot.", failures)
	_expect(simulation.gold > 0, "Defeated enemies should produce gold.", failures)
	_expect(simulation.current_rift_level() > 1, "Kills should advance the rift level.", failures)
	_expect(simulation.blocked_attacks > 0, "Iron Vow should block incoming attacks.", failures)
	_expect(simulation.counter_attacks == simulation.blocked_attacks, "Every Iron Vow block should counterattack.", failures)


func _test_equipment_generation(failures: Array[String]) -> void:
	var simulation := Combat.new(9227) as CombatSimulation
	var weapon: EquipmentItem
	for attempt in range(100):
		var candidate := simulation.generator.generate(3)
		if candidate.slot == Equipment.Slot.WEAPON:
			weapon = candidate
			break

	_expect(weapon != null, "Generator should produce every equipment slot.", failures)
	if weapon == null:
		return

	var damage_before := simulation.hero_damage()
	simulation.inventory.append(weapon)
	var equipped := simulation.equip_item(weapon)
	_expect(equipped, "Inventory equipment should be equippable.", failures)
	_expect(simulation.hero_damage() > damage_before, "Weapon should immediately increase hero damage.", failures)
	_expect(simulation.equipped_item(Equipment.Slot.WEAPON) == weapon, "Equipped slot should contain the selected item.", failures)


func _test_game_data_and_state_separation(failures: Array[String]) -> void:
	var repository := Repository.new() as GameDataRepository
	var simulation := Combat.new(3107, repository) as CombatSimulation
	_expect(repository.enemies().size() == 4, "Enemy definitions should load from gameplay data.", failures)
	_expect(simulation.class_definition()["name"] == "铁誓卫", "Class definitions should load through the repository.", failures)
	_expect(is_equal_approx(simulation.hero_damage(), float(repository.combat()["hero"]["base_damage"])), "Combat should consume configured hero damage.", failures)
	simulation.tick(1.0)
	var snapshot := simulation.state.snapshot()
	_expect(snapshot["schema_version"] == 1, "Runtime state should expose a versioned save snapshot.", failures)
	_expect(snapshot["elapsed_time"] > 0.0, "Runtime state should be independent and serializable.", failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
