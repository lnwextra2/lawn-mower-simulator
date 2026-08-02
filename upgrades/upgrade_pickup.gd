extends RigidBody3D
class_name UpgradePickup

## An upgrade lying in the world, waiting to be picked up - the same
## data-with-a-body hybrid as ToolPickup, but carrying an UpgradeData. Once held,
## how it's spent depends on its mode (press to use, or throw at a target). It's
## consumed on use, so unlike a tool it never comes back to the world.

@export var upgrade_data: UpgradeData

@onready var placeholder: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("upgrade_pickup")
	# Loose-item layer: falls onto the world and is aimable at, but isn't a wall.
	collision_layer = GameConfig.LAYER_LOOSE_ITEM
	collision_mask = GameConfig.LAYER_WORLD
	if upgrade_data and upgrade_data.world_model_scene:
		placeholder.visible = false
		add_child(upgrade_data.world_model_scene.instantiate())
