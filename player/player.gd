extends CharacterBody3D

signal stamina_changed(current: float, max_value: float)
signal carried_grass_changed(current: float, max_value: float)
signal look_target_changed(target: Node3D)
signal held_tool_changed(tool: ToolData)

const TOOL_PICKUP_SCENE := preload("res://tools/tool_pickup.tscn")

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
const SWING_SPEED: float = 7.0   # matches the prototype's CONFIG.tools.scythe.swingSpeed
var is_swinging: bool = false
var swing_timer: float = 0.0
var vm_rest_pos: Vector3
var current_target: Node3D = null
@onready var grass_field: GrassField = get_tree().get_first_node_in_group("grass_field")
@onready var drop_off: Node3D = get_tree().get_first_node_in_group("drop_off")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	held_tool = knife
	held_tool_changed.emit(held_tool)
	# Capture the idle slide position; the swing animates an offset from it.
	vm_rest_pos = view_model.position

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
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	#Handle Interaction
	if Input.is_action_just_pressed("attack"):
		# The whole point of Approach A: cut through the held tool's data, not a
		# hardcoded radius. Swapping tools swaps the reach with zero code change.
		var cut_count := grass_field.cut_near(global_position, held_tool.cut_radius)
		carried_grass = min(carried_grass + cut_count, GameConfig.PLAYER_CARRY_CAPACITY)
		carried_grass_changed.emit(carried_grass, GameConfig.PLAYER_CARRY_CAPACITY)
		start_swing()

	if Input.is_action_just_pressed("interact"):
		# E is context-sensitive: pick up a looked-at tool if hands are free
		# (holding only the knife); otherwise fall back to selling grass.
		if current_target and current_target.is_in_group("tool_pickup") and held_tool == knife:
			_pick_up_tool(current_target)
		elif carried_grass > 0.0:
			_try_sell()

	if Input.is_action_just_pressed("drop") and held_tool != knife:
		_drop_tool()

	_update_look_target()
	move_and_slide()

func _try_sell() -> void:
	var flat_player := Vector2(global_position.x, global_position.z)
	var flat_dropoff := Vector2(drop_off.global_position.x, drop_off.global_position.z)
	if flat_player.distance_to(flat_dropoff) <= GameConfig.DROPOFF_RADIUS:
		Economy.sell(carried_grass)
		carried_grass = 0.0
		carried_grass_changed.emit(carried_grass, GameConfig.PLAYER_CARRY_CAPACITY)

func _pick_up_tool(pickup: Node) -> void:
	held_tool = pickup.tool_data
	held_tool_changed.emit(held_tool)
	pickup.queue_free()
	# The looked-at node is gone now; clear the prompt this frame.
	current_target = null
	look_target_changed.emit(null)

func _drop_tool() -> void:
	# Put the held tool back into the world as a fresh pickup in front of us,
	# then fall back to the knife. The knife itself is never dropped.
	var pickup := TOOL_PICKUP_SCENE.instantiate()
	pickup.tool_data = held_tool
	get_parent().add_child(pickup)
	var drop_pos := global_position + (-global_transform.basis.z * 1.5)
	pickup.global_position = Vector3(drop_pos.x, 0.3, drop_pos.z)
	held_tool = knife
	held_tool_changed.emit(held_tool)

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
