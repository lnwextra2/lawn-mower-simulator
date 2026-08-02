extends StaticBody3D
class_name DropOff

## Where grass gets sold. Works the way the repair bay does: put the goods on the
## pad, then press to sell what's sitting there - rather than pressing while
## holding an armful.
##
## Consistent with the rest of the game (nothing is transferred by menu), and it
## generalises: a cart parked on the pad can be emptied by the same action, which
## an "are you holding it?" check never could.
##
## The pad is a radius rather than an Area3D, because a grass heap has no
## collision at all - it's deliberately walk-through - so there is nothing for an
## area to overlap with.

@export var radius: float = 2.5

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("drop_off")
	# The pad is something you stand and park ON, so it must not act as a wall -
	# a cart being towed onto it would just bump off the edge. It sits on the
	# look-at layer instead: the interact ray still finds it, but nothing walks
	# into it.
	collision_layer = GameConfig.LAYER_LOOK_ONLY
	collision_mask = 0

## Heaps sitting on the pad. Read live, so throwing one more in updates the quote
## immediately and there's no tally to fall out of step with what's actually here.
func piles_on_pad() -> Array:
	var found: Array = []
	for pile in get_tree().get_nodes_in_group("grass_pile"):
		if pile.is_flying:
			continue
		if global_position.distance_to(pile.global_position) <= radius:
			found.append(pile)
	return found

## Carts parked on the pad. The same "put it here, then sell" action empties a
## cart as empties a heap - which is exactly why the pad works on what's standing
## on it rather than on what you happen to be holding.
func carts_on_pad() -> Array:
	var found: Array = []
	for cart in get_tree().get_nodes_in_group("cart"):
		if cart.cargo > 0.0 and global_position.distance_to(cart.global_position) <= radius:
			found.append(cart)
	return found

func total_grass() -> float:
	var total := 0.0
	for pile in piles_on_pad():
		total += pile.amount
	for cart in carts_on_pad():
		total += cart.cargo
	return total

func sell_all() -> bool:
	var piles := piles_on_pad()
	var carts := carts_on_pad()
	if piles.is_empty() and carts.is_empty():
		return false
	for pile in piles:
		Economy.sell(pile.amount)
		pile.queue_free()
	for cart in carts:
		Economy.sell(cart.unload())
	return true

func prompt() -> String:
	var grass := total_grass()
	if grass <= 0.0:
		return "โยนหญ้าลงบนแท่นเพื่อขาย"
	return "[E] ขายหญ้า %d — ได้ %d ทอง" % [
		int(round(grass)), int(grass * GameConfig.SELL_RATE * Upgrades.sale_mult)]
