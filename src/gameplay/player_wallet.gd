class_name PlayerWallet
extends RefCounted


var gold := 0
var rift_tokens := 0


func _init(starting_gold := 0, starting_tokens := 0) -> void:
	gold = maxi(0, starting_gold)
	rift_tokens = maxi(0, starting_tokens)


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

func deposit_tokens(amount: int) -> int:
	var accepted := maxi(0, amount)
	rift_tokens += accepted
	return accepted

func can_afford_tokens(amount: int) -> bool:
	return amount >= 0 and rift_tokens >= amount

func spend_tokens(amount: int) -> bool:
	if not can_afford_tokens(amount):
		return false
	rift_tokens -= amount
	return true
