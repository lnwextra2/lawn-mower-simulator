extends RigidBody3D
class_name ToolPickup

## A tool lying in the world, waiting to be picked up. Carries the ToolData
## the player holds once they pick it up - the Approach-A data given a physical
## world presence (the hybrid we planned for). RigidBody3D so a dropped tool
## arcs out and tumbles to rest under gravity (thrown by the player), and the
## look-at RayCast (which hits bodies) can still detect it.

@export var tool_data: ToolData

@onready var placeholder: MeshInstance3D = $MeshInstance3D
@onready var placeholder_collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("tool_pickup")
	# Show the tool's own ground model if it has one; otherwise keep the
	# placeholder box (e.g. tools without a model yet, like the trimmer).
	if tool_data and tool_data.world_model_scene:
		placeholder.visible = false
		var world_model := tool_data.world_model_scene.instantiate()
		add_child(world_model)
		# A RigidBody only uses CollisionShape3D nodes that are its DIRECT
		# children. Lift ALL the world model carries (e.g. a capsule for the
		# handle + a box for the blade -> they combine into one compound collider)
		# up to us and drop the placeholder box; if it ships none, keep the box so
		# the pickup still has collision and won't fall through the floor.
		if _lift_collisions_from(world_model) > 0:
			placeholder_collision.disabled = true

func _lift_collisions_from(node: Node) -> int:
	# Collect first, then reparent - mutating get_children() mid-loop skips nodes.
	var shapes: Array[Node] = []
	for child in node.get_children():
		if child is CollisionShape3D:
			shapes.append(child)
	for shape in shapes:
		node.remove_child(shape)
		add_child(shape)   # world model root sits at our origin, so local xforms stay valid
	return shapes.size()
