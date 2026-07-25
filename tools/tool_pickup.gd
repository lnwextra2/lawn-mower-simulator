extends StaticBody3D
class_name ToolPickup

## A tool lying in the world, waiting to be picked up. Carries the ToolData
## the player holds once they pick it up - the Approach-A data given a physical
## world presence (the hybrid we planned for). StaticBody3D so the look-at
## RayCast (which hits bodies) can detect it.

@export var tool_data: ToolData

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("tool_pickup")
