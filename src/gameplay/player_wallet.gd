class_name PlayerWallet
extends RefCounted


var gold := 0


func _init(starting_gold := 0) -> void:
	gold = maxi(0, starting_gold)


func deposit(amount: int) -> int:
	var accepted := maxi(0, amount)
	gold += accepted
	return accepted


func can_afford(amount: int) -> bool:
	return amount >= 0 and gold >= amount


func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	gold -= amount
	return true
