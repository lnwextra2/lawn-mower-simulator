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

func total_grass() -> float:
	var total := 0.0
	for pile in piles_on_pad():
		total += pile.amount
	return total

func sell_all() -> bool:
	var piles := piles_on_pad()
	if piles.is_empty():
		return false
	for pile in piles:
		Economy.sell(pile.amount)
		pile.queue_free()
	return true

func prompt() -> String:
	var grass := total_grass()
	if grass <= 0.0:
		return "โยนหญ้าลงบนแท่นเพื่อขาย"
	return "[E] ขายหญ้า %d — ได้ %d ทอง" % [
		int(round(grass)), int(grass * GameConfig.SELL_RATE)]
