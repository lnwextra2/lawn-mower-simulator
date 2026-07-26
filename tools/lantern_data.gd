extends ToolData
class_name LanternData

## A lantern. Extends ToolData because from the world's point of view the two are
## the same thing - a held item with an in-hand model and a ground model - so it
## reuses the existing pickup/drop system untouched. It does inherit cut_radius,
## which is meaningless here; the player routes a LanternData to the lantern slot
## instead of the tool slot, so it is never used to cut.

## Seconds of burn time on a full tank.
@export var fuel_capacity: float = 240.0

## Held in hand: bright, and aimed where you look.
@export var held_energy: float = 4.0
@export var held_range: float = 14.0
## Hung at your side: dimmer, just a pool around you, and it can't be aimed.
@export var hung_energy: float = 1.6
@export var hung_range: float = 7.0

@export var light_color: Color = Color(1.0, 0.85, 0.55)
