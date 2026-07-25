extends CharacterBody3D

signal stamina_changed(current: float, max_value: float)
signal carried_grass_changed(current: float, max_value: float)
signal look_target_changed(target: Node3D)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var stamina: float = GameConfig.STAMINA_MAX
var carried_grass: float = 0.0

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/RayCast3D
var current_target: Node3D = null
@onready var grass_field: GrassField = get_tree().get_first_node_in_group("grass_field")
@onready var drop_off: Node3D = get_tree().get_first_node_in_group("drop_off")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
		var cut_count := grass_field.cut_near(global_position, GameConfig.HAND_CUT_RADIUS)
		carried_grass = min(carried_grass + cut_count, GameConfig.PLAYER_CARRY_CAPACITY)
		carried_grass_changed.emit(carried_grass, GameConfig.PLAYER_CARRY_CAPACITY)
		
	if Input.is_action_just_pressed("interact") and carried_grass > 0.0:
		var flat_player := Vector2(global_position.x, global_position.z)
		var flat_dropoff := Vector2(drop_off.global_position.x, drop_off.global_position.z)
		if flat_player.distance_to(flat_dropoff) <= GameConfig.DROPOFF_RADIUS:
			Economy.sell(carried_grass)
			carried_grass = 0.0
			carried_grass_changed.emit(carried_grass, GameConfig.PLAYER_CARRY_CAPACITY)
	
	_update_look_target()
	move_and_slide()

func _update_look_target() -> void:
	var target: Node3D = null
	if interact_ray.is_colliding():
		var hit := interact_ray.get_collider()
		if hit is Node and hit.is_in_group("interactable"):
			target = hit
	if target != current_target:
		current_target = target
		look_target_changed.emit(current_target)
