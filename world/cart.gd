extends CharacterBody3D
class_name Cart

## The grass cart: grab it, and it follows you around gathering cut grass on its
## own. Capacity far beyond what you can carry in your arms, and it does the
## picking up for you - which is what makes it worth owning even though grass can
## already be ferried by hand.
##
## Towing is deliberately generic (anything can be the tower), because the
## end-game mower tows this same cart. It cuts, the cart collects.

signal cargo_changed(amount: float, capacity: float)

## Towing is a rope, not a fixed spot behind the tower. The cart sits wherever it
## is and only moves once the rope pulls taut, so turning on the spot doesn't
## drag it around, you can walk up and look at it, and backing away pulls it
## toward you without it trying to swing round behind your back.
const LEASH_LENGTH := 2.0
const LEASH_SPEED := 16.0      ## how briskly it takes up slack once taut
## Cap on how fast it can be dragged. Has to comfortably exceed a sprint, or the
## cart can never keep up and the rope sits permanently taut.
const MAX_TOW_SPEED := 11.0
## The tower can't outrun the rope: it's held back at this much past the rope's
## length (a little slack so the cart has room to catch up without locking the
## tower in place). Deliberately not a break-away - a cart that silently
## detaches when it snags means walking back to hunt for a cart full of grass,
## which is tedium. Being unable to walk on is instant, unmissable feedback,
## and jumping is always there as the way to let go on purpose.
const LEASH_LIMIT := LEASH_LENGTH * 1.6
const COLLECT_INTERVAL := 0.35 ## seconds between sweeps while moving
## Ground clearance: the cart rides on wheels, so low bumps in the world pass
## under it rather than stopping it dead. (Dropped tools don't block it at all -
## they're on a layer it doesn't collide with.)
const STEP_CLEARANCE := 0.22

@export var capacity: float = 600.0

var cargo: float = 0.0
var tower: Node3D = null
var _sweep_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _grass_field: GrassField = get_tree().get_first_node_in_group("grass_field")

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("cart")
	# Lift the body's collision clear of the ground so low things pass beneath it,
	# and snap it back down to the floor so it still sits on the ground properly.
	# Done here rather than in the scene so the clearance and the constant that
	# documents it can't drift apart.
	for child in get_children():
		if child is CollisionShape3D:
			child.position.y += STEP_CLEARANCE
	floor_snap_length = STEP_CLEARANCE * 2.0

func toggle_tow(by: Node3D) -> void:
	tower = null if tower else by

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if tower:
		# Horizontal only, so the tower jumping doesn't haul the cart off the
		# ground with it.
		var to_tower := tower.global_position - global_position
		to_tower.y = 0.0
		var slack := to_tower.length() - LEASH_LENGTH
		if slack > 0.0:
			# Only take up the slack. Nothing happens while the rope is loose,
			# which is what stops it sliding around as you merely turn.
			var dir := to_tower.normalized()
			var speed: float = minf(slack * LEASH_SPEED, MAX_TOW_SPEED)
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			var pull := dir
			# Face along the pull, so it looks dragged rather than sliding sideways.
			var want := atan2(pull.x, pull.z)
			rotation.y = lerp_angle(rotation.y, want, delta * 6.0)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

	move_and_slide()
	_sweep(delta)

## Sweeps up cut grass around itself as it goes - blades lying where they were
## cut, and heaps that have been thrown down. Doing this for you, continuously,
## is the cart's whole reason to exist: grass can already be moved by hand, but
## only by pressing for every single load.
func _sweep(delta: float) -> void:
	if cargo >= capacity:
		return
	_sweep_timer += delta
	if _sweep_timer < COLLECT_INTERVAL:
		return
	_sweep_timer = 0.0

	var room := capacity - cargo
	var picked := 0.0
	if _grass_field:
		picked += _grass_field.collect_near(global_position, GameConfig.CART_COLLECT_RADIUS, room)
	for pile in get_tree().get_nodes_in_group("grass_pile"):
		if picked >= room:
			break
		if pile.is_flying:
			continue
		if global_position.distance_to(pile.global_position) <= GameConfig.CART_COLLECT_RADIUS:
			picked += pile.take(room - picked)
	if picked > 0.0:
		cargo += picked
		cargo_changed.emit(cargo, capacity)

## Empties the cart, returning what came out - used by the sale pad.
func unload() -> float:
	var out := cargo
	cargo = 0.0
	cargo_changed.emit(cargo, capacity)
	return out

func prompt() -> String:
	var state := "ปล่อย" if tower else "ลาก"
	return "[E] %s เกวียน (%d / %d)" % [state, int(round(cargo)), int(capacity)]
