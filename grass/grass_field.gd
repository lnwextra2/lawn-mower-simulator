extends MultiMeshInstance3D
class_name GrassField

## Per-blade state, ported from the HTML prototype's `data` array.
## UNCUT -> CUT (flattened, lying on the ground waiting to be picked up) ->
## COLLECTED (stubble, regrowing) -> UNCUT again once fully grown.
##
## Keeping "a pile" as state on the existing MultiMesh instances - rather than
## spawning pile objects - makes cutting idempotent per blade: a continuous tool
## (the trimmer) held over one patch can't spawn duplicate piles, and thousands
## of blades still cost one draw call no matter how much has been cut.
enum State { UNCUT, CUT, COLLECTED }

## Per-field, so the map can hold several fields of different sizes - the
## T-shaped layout: a starting field by the base, plus unlockable arms left,
## right and up. These were global in GameConfig, which only ever allowed one
## field.
@export var field_size: float = 38.0
@export var blade_count: int = 5000

const BLADE_MODEL := preload("res://assets/models/nature/tall_grass.glb")

const BLADE_BASE_Y := 0.0    ## where a blade meets the ground = the floor's top surface
							 ## (Floor's 1-tall box sits at y=-0.5, so its top is y=0)
## A cut blade falls over and lies on the ground at full length - it's the
## harvested grass itself lying there. Keeping it upright but short made it
## almost indistinguishable from a stub that's partway regrown.
const CUT_FALL_DEG := 93.0
const BLADE_SCALE := 0.7     ## overall size of one tuft; tune to taste
## Uniform tufts read as a planted crop (rows of rice) rather than an overgrown
## lawn. Randomising size, lean and shade per tuft is what makes it look unkempt.
const SCALE_VARIANCE := Vector2(0.65, 1.25)   ## min/max multiplier on BLADE_SCALE
const MAX_TILT_DEG := 14.0                    ## how far a tuft can lean over
const SHADE_VARIANCE := 0.18                  ## +/- brightness jitter on the green

const COLOR_UNCUT := GameConfig.COLOR_GRASS_STANDING
const COLOR_CUT := GameConfig.COLOR_GRASS_CUT

const STUBBLE_SCALE := 0.06   ## height of a freshly cleared blade, before it regrows
## Blades regrow at slightly different speeds so the field fills back in
## gradually instead of every blade popping to full height on the same tick.
const GROWTH_RATE_VARIANCE := Vector2(0.7, 1.3)
## Regrowth is spread over frames: only this many blades are advanced per frame,
## cycling through the field. Growing takes in-game days, so nothing visibly
## stutters, and a full field never costs a 5000-iteration loop in one frame.
const BLADES_PER_FRAME := 200

var positions: PackedVector2Array
var yaws: PackedFloat32Array
var scales: PackedFloat32Array
var tilts: PackedVector2Array   ## per-tuft lean, radians about X and Z
var state: PackedByteArray
## How grown a blade is, 0..1. While standing it's the blade's height; the moment
## it's cut the value freezes, and that's what the cut grass is worth - so a
## half-grown blade yields half as much. Reset to 0 when collected, then climbs.
var growth: PackedFloat32Array
var growth_rates: PackedFloat32Array
var _grow_cursor: int = 0
## The mesh's lowest local Y. Scaling has to keep the blade's base planted, and
## an imported model's pivot isn't necessarily at its base, so read it rather
## than assume it.
var _blade_bottom: float = 0.0
## Blade positions are local to this node; the yard is in world space. This
## offset converts between them, so the yard is dodged correctly no matter where
## the field node is placed.
var _world_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("grass_field")   # so every placed field is found, however it's instanced
	var blade_mesh := extract_mesh(BLADE_MODEL)
	if blade_mesh == null:
		push_error("GrassField: no mesh found in %s" % BLADE_MODEL.resource_path)
		return
	_blade_bottom = blade_mesh.get_aabb().position.y

	var material := StandardMaterial3D.new()
	# White albedo + per-instance colors: the instance color IS the blade colour
	# rather than a tint multiplied into a green base, so the hay tint of a cut
	# blade comes out as actual hay instead of murky green. Applied as the node's
	# material_override so the imported model's own material (which doesn't read
	# instance colors) is bypassed without mutating the shared imported resource.
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material

	_world_origin = Vector2(global_position.x, global_position.z)

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true          # must be set before instance_count
	multimesh.mesh = blade_mesh
	multimesh.instance_count = blade_count

	positions.resize(blade_count)
	yaws.resize(blade_count)
	scales.resize(blade_count)
	tilts.resize(blade_count)
	state.resize(blade_count)
	growth.resize(blade_count)
	growth_rates.resize(blade_count)

	var half := field_size / 2.0
	var max_tilt := deg_to_rad(MAX_TILT_DEG)
	for i in blade_count:
		positions[i] = _scatter_outside_yard(half)
		yaws[i] = randf_range(0.0, TAU)
		scales[i] = randf_range(SCALE_VARIANCE.x, SCALE_VARIANCE.y)
		tilts[i] = Vector2(randf_range(-max_tilt, max_tilt), randf_range(-max_tilt, max_tilt))
		state[i] = State.UNCUT
		growth[i] = 1.0   # the field starts fully grown
		growth_rates[i] = randf_range(GROWTH_RATE_VARIANCE.x, GROWTH_RATE_VARIANCE.y)
		multimesh.set_instance_transform(i, _blade_transform(i, 1.0))
		# Jitter the shade so the field isn't one flat sheet of the same green.
		var shade := 1.0 + randf_range(-SHADE_VARIANCE, SHADE_VARIANCE)
		multimesh.set_instance_color(i, Color(
			COLOR_UNCUT.r * shade, COLOR_UNCUT.g * shade, COLOR_UNCUT.b * shade))

func _process(delta: float) -> void:
	var count: int = mini(BLADES_PER_FRAME, positions.size())
	if count <= 0:
		return
	var full_growth_seconds := GameConfig.GRASS_REGROW_DAYS * GameConfig.DAY_NIGHT_CYCLE_DURATION
	# Each blade is only visited once per pass, so it must be advanced by the time
	# a whole pass takes, not by one frame's delta.
	var per_visit := delta * float(positions.size()) / float(count)
	var step := per_visit / full_growth_seconds

	for _n in count:
		_grow_cursor = (_grow_cursor + 1) % positions.size()
		var i := _grow_cursor
		if state[i] != State.COLLECTED:
			continue
		growth[i] = minf(1.0, growth[i] + step * growth_rates[i])
		if growth[i] >= 1.0:
			state[i] = State.UNCUT   # back to being mowable grass
		multimesh.set_instance_transform(i, _blade_transform(i, lerpf(STUBBLE_SCALE, 1.0, growth[i])))

## Picks a spot in the field that isn't inside the yard, so no grass grows up
## through the base buildings. Rejection sampling: the yard is a small part of
## the field, so a retry is rare and the loop is bounded anyway. Checks in world
## space (local + this field's origin), so a field placed away from the base
## simply never lands in the yard.
func _scatter_outside_yard(half: float) -> Vector2:
	for _attempt in 16:
		var p := Vector2(randf_range(-half, half), randf_range(-half, half))
		var w := p + _world_origin
		var inside := w.x >= GameConfig.YARD_MIN.x and w.x <= GameConfig.YARD_MAX.x \
			and w.y >= GameConfig.YARD_MIN.y and w.y <= GameConfig.YARD_MAX.y
		if not inside:
			return p
	# Gave up: push it to the field edge rather than leave a blade in the yard.
	return Vector2(-half, -half)

## Pulls the first mesh out of an imported model scene, so a MultiMesh can
## render it. Frees the temporary instance it has to build to look inside.
## Static and shared: GrassPile builds its heaps from the same blade model.
static func extract_mesh(model: PackedScene) -> Mesh:
	var probe := model.instantiate()
	var found: Mesh = null
	if probe is MeshInstance3D:
		found = probe.mesh
	else:
		for node in probe.find_children("*", "MeshInstance3D", true, false):
			found = node.mesh
			break
	probe.free()
	return found

## Rebuilds a blade's transform from scratch at the given vertical scale. Built
## fresh (not read-modify-write on the current transform) so repeated state
## changes can't compound scale. The vertical offset keeps the mesh's lowest
## point on the ground at any scale, so a flattened pile sits on the floor
## instead of hovering or sinking.
## `fall` (radians) tips the blade over onto the ground - 0 leaves it standing.
func _blade_transform(i: int, scale_y: float, fall: float = 0.0) -> Transform3D:
	var s := BLADE_SCALE * scales[i]
	var scale := Vector3(s, s * scale_y, s)
	# Spin about Y, then lean the whole tuft over in world space so it looks
	# wind-blown rather than planted in a row.
	var basis := Basis(Vector3.RIGHT, tilts[i].x) * Basis(Vector3.FORWARD, tilts[i].y) \
		* Basis(Vector3.UP, yaws[i])
	if fall != 0.0:
		# Topple it in the direction it happens to face, about the horizontal axis
		# across that direction.
		var axis := Vector3(-sin(yaws[i]), 0.0, cos(yaws[i]))
		basis = Basis(axis, fall) * basis
	basis = basis.scaled(scale)
	# Standing blades sit on their base; as one tips over, its base swings down to
	# the ground, so the offset fades out with the fall angle.
	var y := BLADE_BASE_Y - _blade_bottom * scale.y * cos(fall)
	return Transform3D(basis, Vector3(positions[i].x, y, positions[i].y))

## Cuts blades within `radius`, leaving them lying on the ground. Returns the
## total amount of grass cut - part-grown blades are worth what they've grown, so
## mowing a patch that's only half regrown yields half as much. Blades already
## cut are skipped, so holding a continuous tool over one spot does nothing after
## the first pass.
## `min_growth` is the shortest blade the tool can still catch - a blunt blade
## skims over short grass instead of biting it.
func cut_near(world_pos: Vector3, radius: float, min_growth: float = 0.0) -> float:
	var radius_sq := radius * radius
	# Blade positions are local to this node; bring the query into the same space
	# (assumes fields are only translated, never rotated or scaled).
	var center := Vector2(world_pos.x, world_pos.z) - _world_origin
	var total := 0.0
	for i in positions.size():
		if state[i] != State.UNCUT and state[i] != State.COLLECTED:
			continue   # already cut and lying there
		if growth[i] < min_growth:
			continue   # too short for this blade to get under
		if positions[i].distance_squared_to(center) <= radius_sq:
			state[i] = State.CUT
			total += growth[i]   # growth freezes here: this is what it's worth
			# Falls at its full grown length - it IS the cut grass lying there.
			# tilts[i].x is already a small per-blade random angle, reused here so
			# blades don't all land at exactly the same pitch.
			multimesh.set_instance_transform(i,
				_blade_transform(i, growth[i], deg_to_rad(CUT_FALL_DEG) + tilts[i].x))
			multimesh.set_instance_color(i, COLOR_CUT)
	return total

## Picks up cut grass within `radius`, up to `max_amount`. Returns how much was
## actually collected, so the caller can stop at its carry capacity and leave the
## rest lying there. Collected blades reset to stubble and start regrowing.
func collect_near(world_pos: Vector3, radius: float, max_amount: float) -> float:
	if max_amount <= 0.0:
		return 0.0
	var radius_sq := radius * radius
	var center := Vector2(world_pos.x, world_pos.z) - _world_origin   # into local space
	var collected := 0.0
	for i in positions.size():
		if collected >= max_amount:
			break
		if state[i] != State.CUT:
			continue
		if positions[i].distance_squared_to(center) <= radius_sq:
			collected += growth[i]
			state[i] = State.COLLECTED
			growth[i] = 0.0
			multimesh.set_instance_transform(i, _blade_transform(i, STUBBLE_SCALE))
			multimesh.set_instance_color(i, COLOR_UNCUT)
	return collected
