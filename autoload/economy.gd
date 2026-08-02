extends Node

signal gold_changed(current: int)

var gold: int = 0

func sell(amount: float) -> void:
	gold += int(amount * GameConfig.SELL_RATE * Upgrades.sale_mult)
	gold_changed.emit(gold)

## Spends `amount` if it's affordable, and reports whether it went through, so
## callers can stop what they're doing rather than push the player into debt.
func spend(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true
