extends CharacterBody3D
class_name Creature

## Base for the little fantasy creatures (design §14). It wanders: picks a random
## heading, ambles that way facing where it's going, and turns to a new one every
## so often, staying within a radius of where it spawned. A hit knocks it flying -
## launched along the ground and lobbed up, tumbling - and while flying it stops
## colliding with the player (so standing on one mid-flight can't catapult you);
## once it lands and slows it gets up and wanders again.
##
## Species-specific behaviour layers on top later; this is the "alive and moving"
## placeholder, a ball until it gets a model.

@export var speed: float = 1.7
## Seconds between picking a new heading (jittered a little each time).
@export var turn_interval: float = 2.5
## Stays within this distance of its spawn point; past it, it heads back.
@export var wander_radius: float = 15.0
## How briskly it turns to face where it's walking.
@export var turn_speed: float = 8.0
## Upward launch a hit gives, as a fraction of the hit force.
@export var launch_up: float = 0.6
## How fast it slows horizontally while flying.
@export var air_drag: float = 1.5

enum State { WANDER, LAUNCHED }
var _state: State = State.WANDER
var _base_layer: int
var _dir: Vector3 = Vector3.FORWARD
var _timer: float = 0.0
var _home: Vector3
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	add_to_group("creature")
	_home = global_position
	_base_layer = collision_layer
	_pick_direction()
	# No shadows: several creatures casting into the directional shadow map hitches
	# the camera on a turn, the same as the grass and props did.
	_kill_shadows(self)

func _kill_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_kill_shadows(child)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if _state == State.LAUNCHED:
		_process_launched(delta)
	else:
		_process_wander(delta)
	move_and_slide()

## Sends the creature flying away from `from_pos`: knocked back along the ground
## and lobbed up. Stops colliding with the player while flying.
func hit(from_pos: Vector3, force: float) -> void:
	var dir := global_position - from_pos
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	velocity = dir * force + Vector3(0.0, force * launch_up, 0.0)
	collision_layer = 0
	_state = State.LAUNCHED

func _process_wander(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_pick_direction()
	velocity.x = _dir.x * speed
	velocity.z = _dir.z * speed
	# Face the way it's walking.
	if _dir.length() > 0.01:
		var want := atan2(_dir.x, _dir.z)
		rotation.y = lerp_angle(rotation.y, want, delta * turn_speed)

func _process_launched(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, air_drag * delta)
	velocity.z = move_toward(velocity.z, 0.0, air_drag * delta)
	rotation.x += delta * 12.0
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() < 0.5:
		rotation.x = 0.0
		collision_layer = _base_layer
		_state = State.WANDER
		_pick_direction()

func _pick_direction() -> void:
	# Too far from home? Head back. Otherwise wander at random.
	if global_position.distance_to(_home) > wander_radius:
		var back := _home - global_position
		back.y = 0.0
		_dir = back.normalized()
	else:
		var angle := randf() * TAU
		_dir = Vector3(sin(angle), 0.0, cos(angle))
	_timer = turn_interval * randf_range(0.7, 1.3)
