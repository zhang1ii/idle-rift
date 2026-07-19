class_name PotionEconomy
extends RefCounted


const Wallet = preload("res://src/gameplay/player_wallet.gd")

var potion_config: Dictionary
var potion_count := 0
var wallet: PlayerWallet
var material_count := 0
var shop_tier := 1
var total_shop_purchases := 0

var gold: int:
	get:
		return wallet.gold


func _init(
	configuration: Dictionary,
	starting_gold := 0,
	starting_materials := 0,
	shared_wallet: PlayerWallet = null,
) -> void:
	potion_config = configuration.duplicate(true)
	assert(potion_config.has("economy"), "Potion economy configuration is required.")
	potion_count = int(potion_config.get("starting_count", 0))
	wallet = shared_wallet if shared_wallet != null else Wallet.new()
	wallet.deposit(starting_gold)
	material_count = maxi(0, starting_materials)


func unlock_shop_tier(tier: int) -> void:
	shop_tier = maxi(shop_tier, maxi(1, tier))


func shop_price() -> int:
	var shop: Dictionary = potion_config["economy"]["shop"]
	var base_price := float(shop["base_price"])
	var tier_multiplier := 1.0 + float(shop["tier_growth"]) * float(shop_tier - 1)
	var purchase_multiplier := 1.0 \
		+ float(shop["purchase_growth"]) * float(total_shop_purchases)
	return maxi(1, ceili(base_price * tier_multiplier * purchase_multiplier))


func buy_potion() -> Dictionary:
	var price := shop_price()
	if not wallet.can_afford(price):
		return {
			"success": false,
			"reason": "insufficient_gold",
			"price": price,
		}
	wallet.spend(price)
	potion_count += 1
	total_shop_purchases += 1
	return {
		"success": true,
		"price": price,
		"next_price": shop_price(),
		"potion_count": potion_count,
		"gold": gold,
	}


func craft_potion() -> Dictionary:
	var craft: Dictionary = potion_config["economy"]["craft"]
	var material_cost := int(craft["material_cost"])
	var gold_cost := int(craft["gold_cost"])
	var output := int(craft["output"])
	if material_count < material_cost:
		return {"success": false, "reason": "insufficient_materials"}
	if not wallet.can_afford(gold_cost):
		return {"success": false, "reason": "insufficient_gold"}
	material_count -= material_cost
	wallet.spend(gold_cost)
	potion_count += output
	return {
		"success": true,
		"crafted": output,
		"potion_count": potion_count,
		"gold": gold,
		"materials": material_count,
	}


func grant_enemy_rewards(potion_roll: float, material_roll: float) -> Dictionary:
	var economy: Dictionary = potion_config["economy"]
	var potion_dropped := potion_roll < float(economy["direct_drop_chance"])
	var materials_dropped := 0
	if material_roll < float(economy["material_drop_chance"]):
		materials_dropped = int(economy["material_per_drop"])
	if potion_dropped:
		potion_count += 1
	material_count += materials_dropped
	return {
		"potion_dropped": potion_dropped,
		"materials_dropped": materials_dropped,
		"potion_count": potion_count,
		"materials": material_count,
	}


func grant_boss_reward() -> int:
	var reward := int(potion_config["economy"]["boss_potion_reward"])
	potion_count += reward
	return reward


func consume_potions(requested: int) -> int:
	var consumed := mini(potion_count, maxi(0, requested))
	potion_count -= consumed
	return consumed


func snapshot() -> Dictionary:
	return {
		"potion_count": potion_count,
		"gold": gold,
		"material_count": material_count,
		"shop_tier": shop_tier,
		"total_shop_purchases": total_shop_purchases,
		"shop_price": shop_price(),
	}
