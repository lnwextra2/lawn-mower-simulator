extends CharacterBody3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D = $Camera3D

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
	if direction:
		velocity.x = direction.x * GameConfig.PLAYER_SPEED
		velocity.z = direction.z * GameConfig.PLAYER_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, GameConfig.PLAYER_SPEED)
		velocity.z = move_toward(velocity.z, 0, GameConfig.PLAYER_SPEED)

	move_and_slide()
