extends Node3D
class_name GrassPile

## A heap of grass the player put down. Unlike cut grass - which stays as state
## on the GrassField's blades so a continuous tool can't spawn piles every frame -
## dropping is a discrete, player-driven act, so a real object is fine here and
## lets grass be placed anywhere, including ground that was never cut.
##
## Thrown heaps arc through the air under their own integration rather than as a
## physics body: a heap must stay walk-through (unlike dropped tools, which are
## deliberately solid), and hand-rolled motion can't be knocked around by
## anything it passes.
##
## Landing next to an existing heap merges into it rather than littering
## separate objects, and the heap grows to show it.

const MERGE_RADIUS := 1.2
## A heap is built from the same blade model as the field, so cut grass looks
## like the grass it came from. Blades are laid over at steep angles and jumbled
## together, reading as a raked-up pile rather than something still growing.
const CLUMP_BLADES := 32
## The heap is a BUNDLE, not a spray: every blade lies roughly parallel along one
## axis, packed into a rough cylinder - the shape raked-up grass actually makes,
## and the shape a sheaf of hay has. Blades fanning out in all directions looked
## like a firework, and carried in front of the camera they stabbed straight at
## the viewer and blocked the whole screen.
const BUNDLE_LENGTH := 1.7                      ## how long the bundle runs along its axis
const BUNDLE_RADIUS := 0.4                     ## how thick the bundle is
const BUNDLE_SPREAD_DEG := 16.0                 ## how far a blade may stray from parallel
const CLUMP_BLADE_SCALE := Vector2(0.55, 0.95)  ## min/max size of a blade in the bundle
const CLUMP_SHADE_VARIANCE := 0.18   ## per-blade brightness jitter, as in the field
const SIZE_PER_UNIT := 0.28   ## overall heap size; scales the cube-root curve below
const MIN_SIZE := 0.35
const MAX_SIZE := 4.0         ## a full day's mowing should look like a real haystack
const FLATTEN := 0.7          ## vertical squash; the clump's dome profile already
							  ## keeps it low, so this only nudges it flatter

@export var amount: int = 0

var is_flying: bool = false
var _velocity: Vector3 = Vector3.ZERO
var _spin: Vector3 = Vector3.ZERO
var _thrower_rid: RID
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## The visual, built in code so the scene is just this node plus the script -
## nothing to wire up or keep in sync in the editor.
var mesh: MultiMeshInstance3D

func _ready() -> void:
	add_to_group("grass_pile")
	mesh = build_clump(self)
	_refresh_visual()
	set_physics_process(is_flying)

## Builds a jumbled clump of laid-over grass blades under `parent` and returns
## the node holding it. Shared by the world heaps and the player's carried
## armful, so the grass in your arms is the same grass that's on the ground.
## One MultiMesh per heap, so a heap costs one draw call however many blades.
static func build_clump(parent: Node3D) -> MultiMeshInstance3D:
	var blade := GrassField.extract_mesh(GrassField.BLADE_MODEL)
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true          # must be set before instance_count
	mm.mesh = blade
	mm.instance_count = CLUMP_BLADES

	var spread := deg_to_rad(BUNDLE_SPREAD_DEG)
	for i in CLUMP_BLADES:
		# Blades grow along +Y, so lay one down along +X first - that's the
		# bundle's axis - then let it stray a little so the bundle isn't a comb.
		var basis := Basis(Vector3.BACK, -PI / 2.0)
		basis = Basis(Vector3.UP, randf_range(-spread, spread)) \
			* Basis(Vector3.RIGHT, randf_range(-spread, spread)) * basis
		basis = basis * Basis(Vector3.UP, randf_range(0.0, TAU))   # spin each blade on its own length

		# Scatter along the bundle's length, and around its axis in a disc, so the
		# blades pack into a cylinder rather than a flat mat.
		var along := randf_range(-0.5, 0.5) * BUNDLE_LENGTH
		var around := randf_range(0.0, TAU)
		var r := sqrt(randf()) * BUNDLE_RADIUS
		# Lifted by the bundle's radius so the cylinder rests ON the ground rather
		# than half-buried in it (the heap's own origin sits at ground level).
		var offset := Vector3(along, BUNDLE_RADIUS + cos(around) * r, sin(around) * r)

		var s := randf_range(CLUMP_BLADE_SCALE.x, CLUMP_BLADE_SCALE.y)
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * s), offset))
		# Jitter each blade's shade, same as the field does. One flat colour across
		# the whole clump kills every bit of depth and it reads as a solid blob.
		var shade := 1.0 + randf_range(-CLUMP_SHADE_VARIANCE, CLUMP_SHADE_VARIANCE)
		var c := GameConfig.COLOR_GRASS_CUT
		mm.set_instance_color(i, Color(c.r * shade, c.g * shade, c.b * shade))

	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE           # white base: the instance colour IS the colour
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = mat
	parent.add_child(mmi)
	return mmi

## Sends the heap on an arc; it settles (and merges) wherever it actually hits
## the ground. `thrower_rid` is excluded from the ground check so a heap tossed
## from hand height doesn't immediately "land" on the thrower's own body.
func throw(initial_velocity: Vector3, thrower_rid: RID) -> void:
	_velocity = initial_velocity
	_thrower_rid = thrower_rid
	_spin = Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
	is_flying = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	var from := global_position
	_velocity.y -= _gravity * delta
	var to := from + _velocity * delta
	# Cast along this frame's whole motion (not just a height test) so the heap
	# finds the real surface: thrown mid-jump, off a slope, or into a wall.
	# Casting the segment also means a fast throw can't tunnel through thin
	# geometry between frames.
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_thrower_rid]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		var normal: Vector3 = hit.normal
		if normal.y > 0.5:
			# Facing up enough to stand on: this is ground, settle here.
			global_position = hit.position
			_land()
			return
		# A wall: stop dead against it and slide down to the floor, rather than
		# passing through or sticking to the face mid-air. Back off by the heap's
		# own radius - its origin is at its centre, so sitting exactly on the hit
		# point would bury half the heap in the wall.
		global_position = hit.position + normal * _visual_radius()
		_velocity = Vector3(0.0, minf(_velocity.y, 0.0), 0.0)
		return
	global_position = to
	rotation += _spin * delta

func _land() -> void:
	# Level out, but keep a random facing: the bundle has a direction now, and
	# every heap pointing the same way would look placed rather than dropped.
	rotation = Vector3(0.0, randf_range(0.0, TAU), 0.0)
	is_flying = false
	set_physics_process(false)
	# Merge into whatever it landed next to, so thrown grass gathers up instead
	# of leaving a field of little heaps.
	var neighbour := find_near(get_tree(), global_position, MERGE_RADIUS, self)
	if neighbour:
		neighbour.add(amount)
		queue_free()

## Finds a settled heap within `radius` of `pos`, ignoring `exclude` and anything
## still in the air. Shared by landing (to merge) and by anyone looking for a
## heap to take from, so "which heap counts as here" is defined in one place.
static func find_near(tree: SceneTree, pos: Vector3, radius: float, exclude: GrassPile = null) -> GrassPile:
	var best: GrassPile = null
	var best_dist := radius
	for pile in tree.get_nodes_in_group("grass_pile"):
		if pile == exclude or pile.is_flying:
			continue
		var dist: float = pos.distance_to(pile.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = pile
	return best

func add(extra: int) -> void:
	amount += extra
	_refresh_visual()

## Removes up to `max_amount` from the heap and returns how much was actually
## taken. The heap deletes itself once empty.
func take(max_amount: int) -> int:
	var taken: int = mini(amount, max_amount)
	amount -= taken
	if amount <= 0:
		queue_free()
	else:
		_refresh_visual()
	return taken

## Half the heap's widest horizontal extent, at its current size. Read from the
## mesh rather than hardcoded so reshaping or rescaling the heap stays correct.
func _visual_radius() -> float:
	var extents := mesh.get_aabb().size * mesh.scale
	return maxf(extents.x, extents.z) * 0.5

func _refresh_visual() -> void:
	# Cube root, because a heap is a volume: doubling its width would hold eight
	# times the grass, so width should grow far slower than the amount. (sqrt
	# grew it much too fast - one armful already looked like a haystack.)
	var size := pow(float(amount), 1.0 / 3.0) * SIZE_PER_UNIT
	size = clampf(size, MIN_SIZE, MAX_SIZE)
	# Squashed vertically so it reads as a heap of clippings, not a ball.
	mesh.scale = Vector3(size, size * FLATTEN, size)
