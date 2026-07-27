extends RigidBody3D
class_name ToolPickup

## A tool lying in the world, waiting to be picked up. Carries the ToolData
## the player holds once they pick it up - the Approach-A data given a physical
## world presence (the hybrid we planned for). RigidBody3D so a dropped tool
## arcs out and tumbles to rest under gravity (thrown by the player), and the
## look-at RayCast (which hits bodies) can still detect it.

@export var tool_data: ToolData

## Fuel left in this particular item - a lantern's oil or a saw's petrol. Like
## wear, it belongs to the item and not to the shared ToolData, so an item you
## put down still has what was in it when you come back.
@export var fuel: float = 0.0
## Lantern only: a lantern set down keeps burning where it lies.
@export var lantern_lit: bool = false

## How blunt this particular tool is, 0..1. Condition belongs to the item, not to
## the shared ToolData resource, so it travels with the pickup: drop a worn
## scythe and it's still worn when you come back for it.
@export var tool_wear: float = 0.0

@onready var placeholder: MeshInstance3D = $MeshInstance3D
@onready var placeholder_collision: CollisionShape3D = $CollisionShape3D

var _light: OmniLight3D = null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("tool_pickup")
	set_process(false)   # only a burning lantern needs a per-frame tick
	# Sits on the loose-item layer: still falls onto the world and is still
	# aimable, but isn't a wall to anything driving past.
	collision_layer = GameConfig.LAYER_LOOSE_ITEM
	collision_mask = GameConfig.LAYER_WORLD
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
	if tool_data is LanternData:
		_light_up()

## A lantern left burning on the ground actually lights the ground around it -
## that's the point of being able to set it down.
func _light_up() -> void:
	var data: LanternData = tool_data
	_light = OmniLight3D.new()
	_light.light_color = data.light_color
	_light.light_energy = data.held_energy
	_light.omni_range = data.held_range
	_light.position = Vector3(0, 0.25, 0)
	_light.visible = lantern_lit and fuel > 0.0
	add_child(_light)
	set_process(true)

## A lantern burns its own oil wherever it is, not just in the player's hands.
## Without this, setting one down turned it into a free permanent light and the
## whole fuel economy could be sidestepped by never picking it up again.
func _process(delta: float) -> void:
	if not lantern_lit or fuel <= 0.0:
		return
	fuel = maxf(0.0, fuel - delta * tool_data.fuel_per_second)
	if fuel <= 0.0:
		lantern_lit = false   # burnt out where it stands
		_light.visible = false

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
