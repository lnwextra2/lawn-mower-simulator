extends StaticBody3D

## A fixed spot where a light post can be unlocked. Invisible until the player
## holds a light-post upgrade, when its ghost shows to say "here's a spot". Throw
## the upgrade at it and it installs the real post + light, then it's spent.

## What gets built here on install. Defaults to the placeholder post in the scene.
@export var light_post_scene: PackedScene

@onready var ghost: Node3D = $Ghost

func _ready() -> void:
	add_to_group("light_post_slot")
	# Look-only layer: the player and cart walk straight through it, but a thrown
	# upgrade (which masks this layer) can still hit it.
	collision_layer = GameConfig.LAYER_LOOK_ONLY
	collision_mask = 0
	ghost.visible = false
	# Repaint the ghost model as a faint see-through glow, whatever mesh it is - so
	# a slot showing the real post model reads as a preview, not a solid one.
	_ghostify(ghost)

func _ghostify(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.9, 0.55, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.9, 0.55)
		mat.emission_energy_multiplier = 0.6
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_ghostify(child)

## The throw-target highlight for a slot is simply showing its ghost post - the
## same set_highlight(bool) the cart uses, so the player code lights it the same way.
func set_highlight(on: bool) -> void:
	ghost.visible = on

## A light-post upgrade landed here: build the real post + light and retire the
## slot. The post is parented to the world, not this slot, so it outlives it.
func receive_upgrade(_data: UpgradeData) -> void:
	if light_post_scene:
		var post := light_post_scene.instantiate()
		get_parent().add_child(post)
		post.global_position = global_position
	remove_from_group("light_post_slot")
	queue_free()
