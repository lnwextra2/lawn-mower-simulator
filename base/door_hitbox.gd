extends StaticBody3D

## Goes on the door's own StaticBody3D (the thing the interact ray actually
## hits). The rotating pivot with door.gd lives a few nodes up, wrapping the
## mesh - so this just walks up to it rather than duplicating the open/close
## state here.

const DoorScript := preload("res://base/door.gd")

func interact() -> void:
	var door := _find_door()
	if door:
		door.interact()

func _find_door() -> Node:
	var n := get_parent()
	while n:
		if n.get_script() == DoorScript:
			return n
		n = n.get_parent()
	return null
