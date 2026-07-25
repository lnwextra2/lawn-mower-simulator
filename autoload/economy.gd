extends Node

signal gold_changed(current: int)

var gold: int = 0

func sell(amount: float) -> void:
	gold += int(amount * GameConfig.SELL_RATE)
	gold_changed.emit(gold)
