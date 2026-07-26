extends CharacterBody3D

signal stamina_changed(current: float, max_value: float)
signal carried_grass_changed(current: float, max_value: float)
signal look_target_changed(target: Node3D)
signal held_tool_changed(tool: ToolData)

const TOOL_PICKUP_SCENE := preload("res://tools/tool_pickup.tscn")
const GRASS_PILE_SCENE := preload("res://world/grass_pile.tscn")

## The default belt-clipped tool (a rice sickle). Assigned in the Inspector to
## knife.tres. It's the "empty hands" state - always held when nothing else is,
## and can't be dropped.
@export var knife: ToolData

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var stamina: float = GameConfig.STAMINA_MAX
var carried_grass: float = 0.0
var held_tool: ToolData

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/RayCast3D
@onready var view_model: Node3D = $Camera3D/ViewModel          # slides (position), never rotated
@onready var swing_pivot: Node3D = $Camera3D/ViewModel/SwingPivot  # rotates (swing), axes stay camera-aligned
## The armful of grass. Parented to the BODY, not the camera: you hold it against
## your chest, so it turns with you but doesn't rise when you look up - looking at
## the sky shouldn't lift the load into view.
@onready var carry_model: Node3D = $CarryModel
const SWING_SPEED: float = 7.0   # matches the prototype's CONFIG.tools.scythe.swingSpeed
var is_swinging: bool = false
var swing_timer: float = 0.0
var vm_rest_pos: Vector3
var current_target: Node3D = null
@onready var grass_field: GrassField = get_tree().get_first_node_in_group("grass_field")
@onready var drop_off: Node3D = get_tree().get_first_node_in_group("drop_off")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Capture the idle slide position; the swing animates an offset from it.
	vm_rest_pos = view_model.position
	# Swap the in-hand model whenever the held tool changes (connect before the
	# first emit so the starting tool's model gets spawned too).
	held_tool_changed.connect(_swap_view_model)
	held_tool = knife
	held_tool_changed.emit(held_tool)
	# Same clump builder as the world heaps, so the armful matches what you picked up.
	GrassPile.build_clump(carry_model)
	_update_carry_model()   # start with empty arms: grass hidden, tool shown

func _swap_view_model(tool: ToolData) -> void:
	for child in swing_pivot.get_children():
		child.queue_free()
	if tool and tool.view_model_scene:
		swing_pivot.add_child(tool.view_model_scene.instantiate())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * GameConfig.MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * GameConfig.MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = GameConfig.PLAYER_JUMP_VELOCITY
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_sprinting := Input.is_action_pressed("sprint") and stamina > 0.0 and direction != Vector3.ZERO
	if is_sprinting:
		stamina = max(0.0, stamina - GameConfig.STAMINA_DRAIN_RATE * delta)
	else:
		stamina = min(GameConfig.STAMINA_MAX, stamina + GameConfig.STAMINA_REGEN_RATE * delta)
	stamina_changed.emit(stamina, GameConfig.STAMINA_MAX)

	var current_speed := GameConfig.PLAYER_SPRINT_SPEED if is_sprinting else GameConfig.PLAYER_SPEED
	# Getting up to walking pace is near-instant, but the stretch above it ramps
	# slowly: sprinting stays a commitment you build up to (so things that read
	# your speed, like a thrown armful, can't be maxed out the instant you press
	# it) without walking feeling like it has to wait to start.
	var target := direction * current_speed
	var rate: float
	if not direction:
		rate = GameConfig.PLAYER_DECELERATION
	elif Vector2(velocity.x, velocity.z).length() < GameConfig.PLAYER_SPEED:
		rate = GameConfig.PLAYER_WALK_ACCELERATION
	else:
		rate = GameConfig.PLAYER_SPRINT_ACCELERATION
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)

	#Handle Interaction
	# Carrying an armful of grass occupies both hands: the tool is still yours,
	# it just can't be used until you put the grass down (drop key).
	if Input.is_action_just_pressed("attack") and carried_grass <= 0.0:
		# The whole point of Approach A: cut through the held tool's data, not a
		# hardcoded radius. Swapping tools swaps the reach with zero code change.
		# Cut grass is left lying on the ground as piles rather than going straight
		# into the bag, so cutting while full doesn't destroy it - you come back
		# and pick it up.
		grass_field.cut_near(global_position, held_tool.cut_radius)
		start_swing()

	if Input.is_action_just_pressed("collect"):
		var room: int = int(GameConfig.PLAYER_CARRY_CAPACITY - carried_grass)
		# Grass on the ground comes in two forms: blades we cut in place, and
		# heaps we (or a future cart) put down. Scoop both.
		var picked := grass_field.collect_near(global_position, GameConfig.COLLECT_RADIUS, room)
		for pile in get_tree().get_nodes_in_group("grass_pile"):
			if picked >= room:
				break
			if pile.is_flying:
				continue   # can't catch one mid-air
			if global_position.distance_to(pile.global_position) <= GameConfig.COLLECT_RADIUS:
				picked += pile.take(room - picked)
		if picked > 0:
			carried_grass += picked
			carried_grass_changed.emit(carried_grass, GameConfig.PLAYER_CARRY_CAPACITY)
			_update_carry_model()

	if Input.is_action_just_pressed("interact"):
		# E is context-sensitive: pick up a looked-at tool if hands are free
		# (holding only the knife); otherwise fall back to selling grass.
		if current_target and current_target.is_in_group("tool_pickup") and held_tool == knife:
			_pick_up_tool(current_target)
		elif carried_grass > 0.0:
			_try_sell()

	if Input.is_action_just_pressed("drop"):
		# Grass first: it's what's blocking the tool, so the same key that frees
		# your hands shouldn't also throw the tool away.
		if carried_grass > 0.0:
			_drop_grass()
		elif held_tool != knife:
			_drop_tool()

	_update_look_target()
	move_and_slide()

func _drop_grass() -> void:
	# Toss the whole armful out in front of us - it can land anywhere, cut ground
	# or not, and merges with whatever heap it lands next to.
	var pile := GRASS_PILE_SCENE.instantiate()
	pile.amount = int(carried_grass)
	get_parent().add_child(pile)
	var forward := -global_transform.basis.z
	pile.global_position = global_position + forward * 0.6 + Vector3(0, 1.2, 0)
	# Carry your own momentum into the throw, so sprinting flings it further - and
	# running backwards throws it shorter. Upward motion counts too (jump-throwing
	# sends it higher), but downward motion is dropped: being mid-fall shouldn't
	# spike your grass into the dirt.
	var momentum := Vector3(velocity.x, maxf(velocity.y, 0.0), velocity.z) \
		* GameConfig.GRASS_THROW_MOMENTUM
	pile.throw(forward * GameConfig.GRASS_THROW_FORCE
		+ Vector3(0, GameConfig.GRASS_THROW_LIFT, 0) + momentum, get_rid())
	carried_grass = 0.0
	carried_grass_changed.emit(carried_grass, GameConfig.PLAYER_CARRY_CAPACITY)
	_update_carry_model()

## Shows the armful only while carrying, and swells it toward full capacity so
## the load reads at a glance.
func _update_carry_model() -> void:
	var fill := carried_grass / GameConfig.PLAYER_CARRY_CAPACITY
	carry_model.visible = carried_grass > 0.0
	# Full width, half the height: squashed vertically the same way a heap on the
	# ground is, so it spreads across the bottom of the view instead of standing
	# up in front of the face. Position it low and far in player.tscn to control
	# how much of the screen it takes.
	var size := lerpf(0.6, 1.0, fill)
	carry_model.scale = Vector3(size, size * GrassPile.FLATTEN, size)
	# The tool is stowed while both arms are full.
	view_model.visible = carried_grass <= 0.0

func _try_sell() -> void:
	var flat_player := Vector2(global_position.x, global_position.z)
	var flat_dropoff := Vector2(drop_off.global_position.x, drop_off.global_position.z)
	if flat_player.distance_to(flat_dropoff) <= GameConfig.DROPOFF_RADIUS:
		Economy.sell(carried_grass)
		carried_grass = 0.0
		carried_grass_changed.emit(carried_grass, GameConfig.PLAYER_CARRY_CAPACITY)
		_update_carry_model()

func _pick_up_tool(pickup: Node) -> void:
	held_tool = pickup.tool_data
	held_tool_changed.emit(held_tool)
	pickup.queue_free()
	# The looked-at node is gone now; clear the prompt this frame.
	current_target = null
	look_target_changed.emit(null)

func _drop_tool() -> void:
	# Toss the held tool out like CS: spawn it at hand height, then hand it a
	# forward+up impulse (plus a little spin) and let RigidBody physics arc it
	# out and tumble to rest. The knife itself is never dropped.
	var pickup := TOOL_PICKUP_SCENE.instantiate()
	pickup.tool_data = held_tool
	get_parent().add_child(pickup)
	var forward := -global_transform.basis.z
	pickup.global_position = global_position + forward * 0.6 + Vector3(0, 1.3, 0)
	pickup.rotation.y = randf_range(0.0, TAU)   # vary facing so it doesn't always land the same way
	# It spawns right on top of us, so a long tool (the scythe) would jam into
	# the player's body and spike the physics. Ignore player<->pickup collision
	# while it's thrown, then restore it a moment later so we can still bump the
	# tool once it has cleared us.
	pickup.add_collision_exception_with(self)
	get_tree().create_timer(0.5).timeout.connect(_restore_pickup_collision.bind(pickup))
	pickup.apply_central_impulse(forward * 4.0 + Vector3(0, 2.5, 0))
	pickup.apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.2)
	held_tool = knife
	held_tool_changed.emit(held_tool)

func _restore_pickup_collision(pickup: Node) -> void:
	if is_instance_valid(pickup):
		pickup.remove_collision_exception_with(self)

func _process(delta: float) -> void:
	_update_swing(delta)

func start_swing() -> void:
	# Edge-trigger guard: ignore new clicks mid-swing so they don't chain,
	# matching the prototype's consumeAttack() one-shot.
	if is_swinging:
		return
	is_swinging = true
	swing_timer = 0.0

func _update_swing(delta: float) -> void:
	# Port of the prototype's sin-driven scythe swing. One sin() ramps 0->1->0
	# over swing_timer 0..PI and drives BOTH position and rotation off the same
	# value, so slide-across and yaw stay in sync and the return is built in -
	# no separate out/back tweens to seam or fight over the property.
	if not is_swinging:
		return
	swing_timer += delta * SWING_SPEED
	var sf := sin(swing_timer)
	var progress := swing_timer / PI   # 0 -> 1 across the swing (monotonic)
	# SLIDE on view_model (camera space, un-rotated) -> always screen-aligned no
	# matter how the sickle model is oriented. -X = screen-left, small -Y dip.
	# Z: +Z is toward the camera (player). Using sf*progress makes the pull-in
	# peak LATE in the swing but still return to 0 at the end, so no reset pop.
	var pull_in := 0.7 * sf * progress
	view_model.position = vm_rest_pos + Vector3(-1.0 * sf, -0.07 * sf + 0.25, pull_in)
	# SWING on swing_pivot (rest rotation 0) -> its axes stay camera-aligned, so
	# Y is a clean horizontal yaw sweep independent of the sickle's own pose.
	swing_pivot.rotation_degrees = Vector3(0, rad_to_deg(2.5) * sf, -70)
	if swing_timer >= PI:
		is_swinging = false
		view_model.position = vm_rest_pos
		swing_pivot.rotation_degrees = Vector3.ZERO

func _update_look_target() -> void:
	var target: Node3D = null
	if interact_ray.is_colliding():
		var hit := interact_ray.get_collider()
		if hit is Node and hit.is_in_group("interactable"):
			target = hit
	if target != current_target:
		current_target = target
		look_target_changed.emit(current_target)
