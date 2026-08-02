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
## Extra auto-collect AREA (m^2) the magnet upgrades have added - area, not
## radius, so each magnet widens the reach LESS than the last (radius grows with
## the square root): built-in diminishing returns, no special-casing. The cart
## turns this into a radius.
var cart_collect_bonus: float = 0.0
var regrow_mult: float = 1.0

## Back to a fresh run - called when a new game starts (no such flow yet, but the
## reset lives with the state it clears rather than being scattered later).
func reset() -> void:
	move_speed_mult = 1.0
	cart_capacity_bonus = 0.0
	sale_mult = 1.0
	cart_collect_bonus = 0.0
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
			# Adds a flat chunk of AREA each time; the cart converts it to radius, so
			# the taper is automatic (see cart_collect_bonus).
			cart_collect_bonus += data.value
		UpgradeData.Effect.SALE_BONUS:
			sale_mult += data.value
		UpgradeData.Effect.REGROW_SPEED:
			regrow_mult += data.value
		_:
			push_warning("Upgrades.apply: effect %d not handled yet" % data.effect)
			return
	changed.emit()
