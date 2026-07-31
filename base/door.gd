extends Node3D

## Sits on a pivot that wraps the door mesh (and its collider), offset to the
## hinge edge rather than the mesh center - swinging the whole pivot is what
## makes the door open around its edge instead of spinning in place.

# Which way the door swings open, in degrees. Flip the sign if it opens
# through the wall instead of away from it.
@export var open_angle_deg: float = 90.0
# How fast it swings - higher closes the ~90 degree arc quicker.
@export var speed: float = 5.0

var _open := false

func _process(delta: float) -> void:
	var target_deg := open_angle_deg if _open else 0.0
	rotation_degrees.y = lerp(rotation_degrees.y, target_deg, 1.0 - exp(-speed * delta))

func interact() -> void:
	_open = !_open
