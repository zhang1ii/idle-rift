extends SceneTree


const Repository = preload("res://src/data/game_data_repository.gd")
const SkillCycleQueue = preload("res://src/gameplay/skill_cycle_queue.gd")
const PotionEconomy = preload("res://src/gameplay/potion_economy.gd")


func _init() -> void:
	_test_skill_cycle()
	_test_potion_economy()
	print("Skill and potion tests passed: pure cyclic order and rising multi-source economy.")
	quit()


func _test_skill_cycle() -> void:
	var queue = SkillCycleQueue.new()
	assert(queue.configure(
		["builder", "burst", "heal", "spender", "barrier", "aoe", "future_skill"],
		["builder", "burst", "heal", "spender", "barrier"],
	))
	assert(queue.catalog_ids.size() == 7)
	assert(queue.equipped_ids.size() == 5)
	assert(queue.begin_battle())
	assert(not queue.swap_in(0, "aoe"))

	var first := queue.next_available({"heal": true})
	assert(first.skill_id == "heal")
	assert(first.skipped == ["builder", "burst"])
	assert(first.next_cursor == 3)

	var second := queue.next_available({"barrier": true})
	assert(second.skill_id == "barrier")
	assert(second.skipped == ["spender"])
	assert(second.next_cursor == 0)

	var waiting := queue.next_available({})
	assert(waiting.skill_id.is_empty())
	assert(waiting.skipped.size() == 5)
	assert(waiting.next_cursor == 0)

	queue.end_battle()
	assert(queue.swap_in(0, "aoe"))
	assert(queue.swap_slots(0, 4))
	assert(queue.equipped_ids == ["barrier", "burst", "heal", "spender", "aoe"])


func _test_potion_economy() -> void:
	var potion_config: Dictionary = Repository.new().first_rift()["potion"]
	assert(not potion_config["in_combat_allowed"])
	var economy = PotionEconomy.new(potion_config, 1000, 8)
	assert(economy.potion_count == 3)
	assert(economy.shop_price() == 20)

	var first_purchase := economy.buy_potion()
	assert(first_purchase.success)
	assert(first_purchase.price == 20)
	assert(first_purchase.next_price == 23)
	var second_purchase := economy.buy_potion()
	assert(second_purchase.success)
	assert(second_purchase.price == 23)

	economy.unlock_shop_tier(2)
	assert(economy.shop_price() == 39)
	var crafted := economy.craft_potion()
	assert(crafted.success)
	assert(crafted.crafted == 1)
	assert(economy.material_count == 4)

	var drops := economy.grant_enemy_rewards(0.005, 0.05)
	assert(drops.potion_dropped)
	assert(drops.materials_dropped == 1)
	assert(economy.grant_boss_reward() == 2)
	assert(economy.consume_potions(2) == 2)
