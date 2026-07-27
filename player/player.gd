extends CharacterBody3D

signal stamina_changed(current: float, max_value: float)
signal carried_grass_changed(current: float, max_value: float)
signal look_target_changed(target: Node3D)
signal held_tool_changed(tool: ToolData)
signal tool_wear_changed(wear: float)
signal tool_fuel_changed(fuel: float, capacity: float)
signal lantern_changed(lantern: LanternData, lit: bool, fuel: float)

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
## Condition of the tool in hand, 0 sharp .. 1 fully blunt. Per-item, not on the
## shared ToolData resource. The sickle never goes into the world as a pickup, so
## its wear has nowhere else to live and is kept aside while another tool is out.
var held_wear: float = 0.0
var knife_wear: float = 0.0
## Fuel in the held tool, for powered ones. Hand tools leave it at 0 and ignore
## it - they dull instead. Per-item, same as wear.
var held_fuel: float = 0.0
var _cut_accum: float = 0.0   # paces a continuous tool's bites
var _fuel_owed: float = 0.0   # part-of-a-coin fuel cost, billed once it's whole
## How far a continuous tool has swung down from shouldered (0) to working (1).
## Eased rather than snapped, so raising and lowering the saw reads as a motion.
var deploy_amount: float = 0.0
var _powered_running: bool = false
const DEPLOY_SPEED: float = 6.0
## The lantern occupies the off hand, a slot of its own alongside the tool.
var lantern: LanternData = null
var lantern_lit: bool = false
var lantern_fuel: float = 0.0
## Clipped at the hip instead of held: a dim pool around your feet rather than a
## beam you can aim, but it leaves the hand free. The trade is the point.
var lantern_hipped: bool = false

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/RayCast3D
@onready var view_model: Node3D = $Camera3D/ViewModel          # slides (position), never rotated
@onready var swing_pivot: Node3D = $Camera3D/ViewModel/SwingPivot  # rotates (swing), axes stay camera-aligned
## The armful of grass. Parented to the BODY, not the camera: you hold it against
## your chest, so it turns with you but doesn't rise when you look up - looking at
## the sky shouldn't lift the load into view.
@onready var carry_model: Node3D = $CarryModel
## Two mounts for the one lantern. Held hangs off the camera so it lights where
## you look; hipped hangs off the body, so it stays at your waist and you only
## see it by looking down - the same split as the carried grass.
@onready var lantern_model: Node3D = $Camera3D/LanternModel
@onready var lantern_light: OmniLight3D = $Camera3D/LanternModel/LanternLight
@onready var lantern_hip: Node3D = $LanternHip
@onready var hip_light: OmniLight3D = $LanternHip/HipLight
const SWING_SPEED: float = 7.0   # matches the prototype's CONFIG.tools.scythe.swingSpeed
## How far into the swing (of its 0..PI arc) the blade bites. A quarter in, while
## it's sweeping across - matching the prototype.
const SWING_CUT_AT: float = PI / 4.0
var is_swinging: bool = false
var swing_timer: float = 0.0
var has_cut_this_swing: bool = false
## A click that arrived mid-swing, held until the swing ends so it isn't simply
## dropped. Deliberately a flag, not a queue: mashing shouldn't stack up swings
## that keep firing after you stop.
var swing_buffered: bool = false
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
	# Clear any pose the last tool left on the pivot, or a saw put away mid-cut
	# would hand its angle to whatever comes next.
	_powered_running = false
	deploy_amount = 0.0
	swing_pivot.rotation_degrees = Vector3.ZERO
	# A two-handed tool has to push the lantern off to the hip, so the lantern's
	# position is re-evaluated whenever what's in your hands changes.
	if is_node_ready():
		_rebuild_lantern_model()
		_refresh_lantern()

## True while the mouse is locked to the game. When it isn't, the player has
## stepped out (Esc) and neither looking nor gameplay input should register.
func has_mouse_focus() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# Esc frees the cursor so the window can actually be used or closed - without
	# it the mouse is trapped and Alt+F4 is the only way out.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	# Clicking back into the window re-locks it.
	if event is InputEventMouseButton and event.pressed and not has_mouse_focus():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and has_mouse_focus():
		rotate_y(-event.relative.x * GameConfig.MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * GameConfig.MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# With the cursor released the game reads as paused: no walking, no swinging,
	# and in particular the click that re-locks the mouse mustn't also swing the
	# tool. Gravity and move_and_slide still run so the body stays settled.
	var active := has_mouse_focus()

	if active and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = GameConfig.PLAYER_JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if active else Vector2.ZERO
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_sprinting := active and Input.is_action_pressed("sprint") and stamina > 0.0 and direction != Vector3.ZERO
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
	if not active:
		_update_look_target()
		move_and_slide()
		return

	# Carrying an armful of grass occupies both hands: the tool is still yours,
	# it just can't be used until you put the grass down (drop key).
	if carried_grass <= 0.0:
		if held_tool.continuous:
			# A powered tool runs while the trigger is held, burning fuel only
			# while it's actually working - so how much you spend is your call.
			_run_powered_tool(delta, Input.is_action_pressed("attack"))
		elif Input.is_action_just_pressed("attack"):
			# Only asks for a swing. The cut itself fires mid-swing (see
			# _update_swing), so a swing already in progress swallows the click and
			# the animation is its own cooldown - no separate timer to keep in sync.
			start_swing()

	if Input.is_action_just_pressed("collect"):
		var room: float = GameConfig.PLAYER_CARRY_CAPACITY - carried_grass
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
			# Filling your arms clips the lantern to your hip for good, not just
			# until you set the grass down: what you do next is almost always swing
			# a tool or push the cart, and both want the hand free. Springing back
			# would mean re-clipping it nearly every trip.
			lantern_hipped = true
			swing_buffered = false   # arms are full now; don't swing once they're free
			_update_carry_model()
	
	# A fuel tank is filled by HOLDING E: fuel flows and gold drains for as long as
	# you hold it, so "as much as I can afford" is a judgement you make with your
	# finger, not a sum the game does for you. It takes the key outright while
	# you're looking at one, so a tap can't also sell your grass.
	if current_target and current_target.is_in_group("fuel_station"):
		if Input.is_action_pressed("interact"):
			_refuel_from(current_target, delta)
	elif Input.is_action_just_pressed("interact"):
		# E is context-sensitive: pick up a looked-at tool if hands are free
		# (holding only the knife); otherwise fall back to selling grass.
		if current_target and current_target.is_in_group("tool_pickup") and _can_pick_up(current_target):
			_pick_up_item(current_target)
		elif carried_grass > 0.0:
			_try_sell()

	if Input.is_action_just_pressed("toggle_lantern"):
		_toggle_lantern()

	if Input.is_action_just_pressed("swap_lantern"):
		_swap_lantern_position()

	if Input.is_action_just_pressed("drop"):
		# Grass first: it's what's blocking the tool, so the same key that frees
		# your hands shouldn't also throw away what you're holding. Then the tool,
		# then the lantern - the lantern is the thing you least often want to put
		# down at night, so it's last in line.
		if carried_grass > 0.0:
			_drop_grass()
		elif held_tool != knife:
			_drop_tool()
		elif lantern:
			_drop_lantern()

	_update_look_target()
	move_and_slide()

func _drop_grass() -> void:
	# Toss the whole armful out in front of us - it can land anywhere, cut ground
	# or not, and merges with whatever heap it lands next to.
	var pile := GRASS_PILE_SCENE.instantiate()
	pile.amount = carried_grass
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
	# The tool is stowed while both arms are full, and the lantern moves to the
	# hip - you can't hold a light and an armful of grass in the same hands.
	view_model.visible = carried_grass <= 0.0
	_rebuild_lantern_model()
	_refresh_lantern()

## Pours fuel into whatever this station serves, charging as it goes. Stops on
## its own when the tank is full or the money runs out.
func _refuel_from(station: Node, delta: float) -> void:
	# Cost accrues in fractions of a coin, and is only charged once a whole coin
	# is owed - otherwise a continuous flow could never bill an integer currency.
	var space := 0.0
	if station.kind == FuelStation.Kind.LAMP_OIL:
		if lantern == null:
			return
		space = lantern.fuel_capacity - lantern_fuel
	else:
		if held_tool.fuel_capacity <= 0.0:
			return   # nothing in hand that burns this
		space = held_tool.fuel_capacity - held_fuel
	if space <= 0.0:
		return

	var poured: float = minf(GameConfig.FUEL_FILL_RATE * delta, space)
	_fuel_owed += poured * GameConfig.FUEL_PRICE_PER_UNIT
	var coins := int(_fuel_owed)
	if coins > 0:
		if not Economy.spend(coins):
			_fuel_owed = 0.0
			return   # out of money: the flow simply stops
		_fuel_owed -= coins

	if station.kind == FuelStation.Kind.LAMP_OIL:
		lantern_fuel += poured
		_refresh_lantern()
	else:
		held_fuel += poured
		tool_fuel_changed.emit(held_fuel, held_tool.fuel_capacity)

func _try_sell() -> void:
	var flat_player := Vector2(global_position.x, global_position.z)
	var flat_dropoff := Vector2(drop_off.global_position.x, drop_off.global_position.z)
	if flat_player.distance_to(flat_dropoff) <= GameConfig.DROPOFF_RADIUS:
		Economy.sell(carried_grass)
		carried_grass = 0.0
		carried_grass_changed.emit(carried_grass, GameConfig.PLAYER_CARRY_CAPACITY)
		_update_carry_model()

## A lantern goes in the off hand, so it can be picked up while holding a tool.
## A tool needs the main hand free, i.e. nothing but the default knife in it.
func _can_pick_up(pickup: Node) -> bool:
	if pickup.tool_data is LanternData:
		return lantern == null
	return held_tool == knife

## Blunts the tool in proportion to how much grass it actually bit through, so a
## swing at nothing costs nothing. Powered tools set wear_per_grass to 0 and are
## simply unaffected - they run at full power until they run dry instead.
func _wear_tool(grass_cut: float) -> void:
	if held_tool.wear_per_grass <= 0.0 or grass_cut <= 0.0:
		return
	held_wear = minf(1.0, held_wear + held_tool.wear_per_grass * grass_cut)
	tool_wear_changed.emit(held_wear)

func _pick_up_item(pickup: Node) -> void:
	var data: ToolData = pickup.tool_data
	if data is LanternData:
		lantern = data
		lantern_fuel = pickup.fuel   # a lantern keeps the fuel it was left with
		lantern_lit = pickup.lantern_lit
		_rebuild_lantern_model()
		_refresh_lantern()
	else:
		# Park the sickle's condition before swapping it out - it has no pickup in
		# the world to carry its wear for it.
		if held_tool == knife:
			knife_wear = held_wear
		held_tool = data
		held_wear = pickup.tool_wear   # a tool keeps the condition it was left in
		held_fuel = pickup.fuel        # and whatever was left in its tank
		_cut_accum = 0.0
		held_tool_changed.emit(held_tool)
		tool_wear_changed.emit(held_wear)
		tool_fuel_changed.emit(held_fuel, held_tool.fuel_capacity)
	pickup.queue_free()
	# The looked-at node is gone now; clear the prompt this frame.
	current_target = null
	look_target_changed.emit(null)

func _drop_lantern() -> void:
	# A set-down lantern keeps burning where it lies with the fuel it had - you
	# can put it down as a light source instead of carrying it.
	_spawn_pickup(lantern, lantern_fuel, lantern_lit)
	lantern = null
	lantern_lit = false
	lantern_fuel = 0.0
	lantern_hipped = false   # the next one you pick up starts in hand
	_rebuild_lantern_model()
	_refresh_lantern()

## Works whenever you have the lantern on you, in hand or clipped at your side -
## you can reach it either way. Only an empty tank stops you.
func _toggle_lantern() -> void:
	if lantern == null or lantern_fuel <= 0.0:
		return
	lantern_lit = not lantern_lit
	_refresh_lantern()

## Moves the lantern between hand and hip. The flame stays as it was - moving it
## doesn't put it out. Pressing this with your arms full of grass still sets your
## preference; it just doesn't take effect until your hands are free again.
func _swap_lantern_position() -> void:
	if lantern == null:
		return
	lantern_hipped = not lantern_hipped
	_rebuild_lantern_model()
	_refresh_lantern()

## Where the lantern actually is. Picking grass up sets lantern_hipped, so it
## stays clipped after you set the grass down; the other two terms are hard
## constraints Tab can't override - full arms, or a tool that needs both hands.
func _lantern_at_hip() -> bool:
	return lantern_hipped or carried_grass > 0.0 or (held_tool and held_tool.two_handed)

func _update_lantern(delta: float) -> void:
	if lantern == null or not lantern_lit:
		return
	lantern_fuel = maxf(0.0, lantern_fuel - delta * lantern.fuel_per_second)
	if lantern_fuel <= 0.0:
		lantern_lit = false   # burnt out
	_refresh_lantern()

## Spawns (or clears) the lantern's in-hand model. Separate from _refresh_lantern
## because that runs every frame while burning - rebuilding a model 60 times a
## second would be silly. Only picking one up or putting it down changes what's
## in your hand.
func _rebuild_lantern_model() -> void:
	for mount in [lantern_model, lantern_hip]:
		for child in mount.get_children():
			if child is OmniLight3D:
				continue   # the mount's light belongs to the mount, not the lantern
			child.queue_free()
	if lantern and lantern.view_model_scene:
		var mount: Node3D = lantern_hip if _lantern_at_hip() else lantern_model
		mount.add_child(lantern.view_model_scene.instantiate())

## Pushes the lantern's state onto the visuals. Hiding a mount hides its light
## too, so only the mount the lantern is actually on can shine.
func _refresh_lantern() -> void:
	var carried := lantern != null
	var at_hip := _lantern_at_hip()
	lantern_model.visible = carried and not at_hip
	lantern_hip.visible = carried and at_hip
	lantern_light.visible = lantern_lit
	hip_light.visible = lantern_lit
	if lantern:
		lantern_light.light_energy = lantern.held_energy
		lantern_light.omni_range = lantern.held_range
		lantern_light.light_color = lantern.light_color
		# At the hip it's a dim pool around you, not a beam you can aim.
		hip_light.light_energy = lantern.hung_energy
		hip_light.omni_range = lantern.hung_range
		hip_light.light_color = lantern.light_color
	lantern_changed.emit(lantern, lantern_lit, lantern_fuel)

func _drop_tool() -> void:
	_spawn_pickup(held_tool, held_fuel, false, held_wear)
	held_tool = knife
	held_wear = knife_wear   # back to the sickle, in whatever state you left it
	held_fuel = 0.0          # the sickle has no tank
	held_tool_changed.emit(held_tool)
	tool_wear_changed.emit(held_wear)
	tool_fuel_changed.emit(held_fuel, held_tool.fuel_capacity)

## Tosses `data` out into the world as a pickup, like a CS weapon drop: spawned
## at hand height with a forward+up impulse and a little spin, then left to
## RigidBody physics. Shared by dropping a tool and dropping the lantern.
func _spawn_pickup(data: ToolData, fuel: float = 0.0, lit: bool = false, wear: float = 0.0) -> Node:
	var pickup := TOOL_PICKUP_SCENE.instantiate()
	# Everything the pickup reads in _ready must be set BEFORE add_child, because
	# add_child runs _ready immediately - assigning afterwards is too late and the
	# pickup would come up with defaults (an unlit, empty lantern).
	pickup.tool_data = data
	pickup.fuel = fuel
	pickup.lantern_lit = lit
	pickup.tool_wear = wear
	get_parent().add_child(pickup)
	var forward := -global_transform.basis.z
	pickup.global_position = global_position + forward * 0.6 + Vector3(0, 1.3, 0)
	# Thrown in your own frame, not the world's: the item leaves your hands at the
	# same angle relative to you every time, whichever way you happen to be facing.
	# Which way that is (head to the right, say) is set by the world model scene's
	# own pose, so it's adjustable without touching this.
	pickup.global_rotation.y = global_rotation.y
	# It spawns right on top of us, so a long item (the scythe) would jam into
	# the player's body and spike the physics. Ignore player<->pickup collision
	# while it's thrown, then restore it a moment later so we can still bump the
	# item once it has cleared us.
	pickup.add_collision_exception_with(self)
	get_tree().create_timer(0.5).timeout.connect(_restore_pickup_collision.bind(pickup))
	pickup.apply_central_impulse(forward * 4.0 + Vector3(0, 2.5, 0))
	# Tumble about ONE axis - your right, so it turns end over end along the arc
	# it's already travelling. The old version torqued all three axes at random,
	# and a long item has so little inertia about its short axes that it just
	# whirled. A little randomness on top keeps two throws from looking identical.
	pickup.apply_torque_impulse(global_transform.basis.x
		* GameConfig.TOOL_THROW_SPIN * randf_range(0.75, 1.25))
	return pickup

func _restore_pickup_collision(pickup: Node) -> void:
	if is_instance_valid(pickup):
		pickup.remove_collision_exception_with(self)

func _process(delta: float) -> void:
	_update_swing(delta)
	_update_lantern(delta)
	_update_deploy(delta)

## Eases a continuous tool between shouldered and levelled-at-the-grass. Safe to
## share SwingPivot with the swing animation: a continuous tool never swings, so
## the two never drive this rotation at the same time.
func _update_deploy(delta: float) -> void:
	if held_tool == null or not held_tool.continuous:
		return
	deploy_amount = move_toward(deploy_amount, 1.0 if _powered_running else 0.0, delta * DEPLOY_SPEED)
	swing_pivot.rotation_degrees.x = held_tool.deploy_angle_deg * deploy_amount

func start_swing() -> void:
	# A click during a swing is remembered rather than thrown away, and fires the
	# moment the swing ends. Without this, clicking a fraction early does nothing
	# at all and mowing feels like it keeps catching on something.
	if is_swinging:
		swing_buffered = true
		return
	is_swinging = true
	swing_timer = 0.0
	has_cut_this_swing = false

## Runs a powered cutting tool while its trigger is held: burns fuel, and bites
## at a fixed rate out at the end of its reach.
func _run_powered_tool(delta: float, trigger_held: bool) -> void:
	_powered_running = trigger_held and held_fuel > 0.0
	if not _powered_running:
		_cut_accum = 0.0
		return
	held_fuel = maxf(0.0, held_fuel - delta * held_tool.fuel_per_second)
	# Running low doesn't fail randomly - it bites at half speed, a steady
	# stutter you can hear coming, so running dry is a decision (push on, or
	# start walking back) rather than an ambush.
	var rate := held_tool.cuts_per_second
	if held_fuel < held_tool.fuel_capacity * GameConfig.TOOL_LOW_FUEL_FRACTION:
		rate *= 0.5
	_cut_accum += delta * rate
	while _cut_accum >= 1.0:
		_cut_accum -= 1.0
		_cut_with_tool()
	tool_fuel_changed.emit(held_fuel, held_tool.fuel_capacity)

## Does the actual cutting, once per swing, at the point the blade is sweeping
## through the grass. A blunt tool reaches less far and can't get under short
## grass, so wear is felt as "I clear less per swing" - never as a swing that
## randomly failed.
func _cut_with_tool() -> void:
	# A long-handled tool bites out ahead of you rather than around you, which is
	# what lets you clear ground before walking into it.
	var at := global_position
	if held_tool.cut_offset > 0.0:
		at += -global_transform.basis.z * held_tool.cut_offset
	var cut := grass_field.cut_near(at,
		held_tool.cut_radius * lerpf(1.0, GameConfig.TOOL_WORN_RADIUS_FACTOR, held_wear),
		lerpf(0.0, GameConfig.TOOL_WORN_MIN_GROWTH, held_wear))
	_wear_tool(cut)

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
	# Cut when the blade is actually sweeping through, not on the button press,
	# so the grass falls in time with the swing you can see.
	if not has_cut_this_swing and swing_timer > SWING_CUT_AT:
		_cut_with_tool()
		has_cut_this_swing = true
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
		# Chain straight into a click that landed mid-swing. The next swing starts
		# from sin(0), which is the rest pose we just restored, so there's no
		# visible snap between the two.
		if swing_buffered:
			swing_buffered = false
			start_swing()

func _update_look_target() -> void:
	var target: Node3D = null
	if interact_ray.is_colliding():
		var hit := interact_ray.get_collider()
		if hit is Node and hit.is_in_group("interactable"):
			target = hit
	if target != current_target:
		current_target = target
		look_target_changed.emit(current_target)
