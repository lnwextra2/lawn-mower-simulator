extends Node

## Runtime home for everything upgrades have changed. The base numbers live in
## GameConfig as consts (can't be reassigned), so this layer holds the modifiers
## on top and the systems read `base <op> Upgrades.xxx`:
##   player speed  = PLAYER_SPEED * move_speed_mult
##   cart capacity = base + cart_capacity_bonus
##   sale price    = amount * sale_mult
## Consuming an upgrade pours its effect in here; nothing else stores upgrade
## state, so a future save only has to write these fields.

signal changed

var move_speed_mult: float = 1.0
var cart_capacity_bonus: float = 0.0
var sale_mult: float = 1.0
var magnet_enabled: bool = false
var regrow_mult: float = 1.0

## Back to a fresh run - called when a new game starts (no such flow yet, but the
## reset lives with the state it clears rather than being scattered later).
func reset() -> void:
	move_speed_mult = 1.0
	cart_capacity_bonus = 0.0
	sale_mult = 1.0
	magnet_enabled = false
	regrow_mult = 1.0
	changed.emit()

## Folds one upgrade's effect into the running totals. The upgrade object itself
## is consumed by whoever called this; here we only move numbers.
func apply(data: UpgradeData) -> void:
	match data.effect:
		UpgradeData.Effect.MOVE_SPEED:
			move_speed_mult += data.value
		UpgradeData.Effect.CART_CAPACITY:
			cart_capacity_bonus += data.value
		UpgradeData.Effect.CART_MAGNET:
			magnet_enabled = true
		UpgradeData.Effect.SALE_BONUS:
			sale_mult += data.value
		UpgradeData.Effect.REGROW_SPEED:
			regrow_mult += data.value
		_:
			push_warning("Upgrades.apply: effect %d not handled yet" % data.effect)
			return
	changed.emit()
