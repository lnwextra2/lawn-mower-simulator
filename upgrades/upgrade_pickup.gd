extends RigidBody3D
class_name UpgradePickup

## An upgrade lying in the world, waiting to be picked up - the same
## data-with-a-body hybrid as ToolPickup, but carrying an UpgradeData. Once held,
## how it's spent depends on its mode (press to use, or throw at a target). It's
## consumed on use, so unlike a tool it never comes back to the world.

@export var upgrade_data: UpgradeData

@onready var placeholder: MeshInstance3D = $MeshInstance3D

## True once thrown at a target (a TARGET upgrade). While armed, hitting a body
## in its target group applies the upgrade there. A pickup just lying about (sold
## or dropped) is not armed - it's only a thing to walk up and grab.
var armed: bool = false
var _target_group: String = ""

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("upgrade_pickup")
	# Loose-item layer: falls onto the world and is aimable at, but isn't a wall.
	collision_layer = GameConfig.LAYER_LOOSE_ITEM
	collision_mask = GameConfig.LAYER_WORLD
	body_entered.connect(_on_body_entered)
	if upgrade_data and upgrade_data.world_model_scene:
		placeholder.visible = false
		add_child(upgrade_data.world_model_scene.instantiate())

## Called by the player right after throwing this at a target. Contact reporting
## is only switched on here, so an ordinary pickup costs nothing watching for hits.
func arm() -> void:
	armed = true
	_target_group = upgrade_data.target_group
	contact_monitor = true
	max_contacts_reported = 4

func _on_body_entered(body: Node) -> void:
	if armed and _target_group != "" and body.is_in_group(_target_group):
		Upgrades.apply(upgrade_data)
		queue_free()
