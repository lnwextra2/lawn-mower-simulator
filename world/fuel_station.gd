extends StaticBody3D
class_name FuelStation

## A tank at base you hold E at to fill up. Deliberately instant rather than
## routed through the repair box: refuelling and repairing have opposite natural
## timescales, and making a dry engine cost half a day would punish it out of all
## proportion. Being fixed to base is the point though - it's what keeps the walk
## home meaningful, and a portable can is a later, expensive upgrade.
##
## StaticBody3D so the player's look-at RayCast can find it, same as a pickup.

## Lamp oil and engine fuel aren't interchangeable in reality and aren't here, so
## a station serves exactly one of them.
enum Kind { LAMP_OIL, ENGINE }

@export var kind: Kind = Kind.ENGINE

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("fuel_station")

func label() -> String:
	return "น้ำมันก๊าด" if kind == Kind.LAMP_OIL else "น้ำมันเครื่อง"
