extends MultiMeshInstance3D
class_name GrassField

## Per-blade state, ported from the HTML prototype's `data` array.
## UNCUT -> CUT (flattened, hay-tinted, lying on the ground waiting to be picked
## up) -> COLLECTED (flattened away).
##
## Keeping "a pile" as state on the existing MultiMesh instances - rather than
## spawning pile objects - makes cutting idempotent per blade: a continuous tool
## (the trimmer) held over one patch can't spawn duplicate piles, and 10000
## blades still cost one draw call no matter how much has been cut.
enum State { UNCUT, CUT, COLLECTED }

const BLADE_BASE_Y := 0.0    ## where a blade meets the ground = the floor's top surface
							 ## (Floor's 1-tall box sits at y=-0.5, so its top is y=0)
const BLADE_HALF := 0.4      ## half the 0.8-tall quad, i.e. its pivot offset
const PILE_SCALE_Y := 0.35   ## flattened mound left behind by cutting
const COLLECTED_SCALE_Y := 0.02

const COLOR_UNCUT := Color(0.13, 0.55, 0.13)
const COLOR_CUT := Color(0.77, 0.64, 0.35)   ## dry hay

var positions: PackedVector2Array
var yaws: PackedFloat32Array
var state: PackedByteArray

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.8)

	var material := StandardMaterial3D.new()
	# White albedo + per-instance colors: the instance color IS the blade colour
	# rather than a tint multiplied into a green base, so the hay tint of a cut
	# blade comes out as actual hay instead of murky green.
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true          # must be set before instance_count
	multimesh.mesh = quad
	multimesh.instance_count = GameConfig.GRASS_COUNT

	positions.resize(GameConfig.GRASS_COUNT)
	yaws.resize(GameConfig.GRASS_COUNT)
	state.resize(GameConfig.GRASS_COUNT)

	var half := GameConfig.GRASS_FIELD_SIZE / 2.0
	for i in GameConfig.GRASS_COUNT:
		positions[i] = Vector2(randf_range(-half, half), randf_range(-half, half))
		yaws[i] = randf_range(0.0, TAU)
		state[i] = State.UNCUT
		multimesh.set_instance_transform(i, _blade_transform(i, 1.0))
		multimesh.set_instance_color(i, COLOR_UNCUT)

## Rebuilds a blade's transform from scratch at the given vertical scale. Built
## fresh (not read-modify-write on the current transform) so repeated state
## changes can't compound scale. Shrinks toward the blade's base, not its centre -
## the quad is centre-pivoted, so scaling naively would leave a pile hovering.
func _blade_transform(i: int, scale_y: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaws[i]).scaled(Vector3(1.0, scale_y, 1.0))
	var origin := Vector3(positions[i].x, BLADE_BASE_Y + BLADE_HALF * scale_y, positions[i].y)
	return Transform3D(basis, origin)

## Cuts standing blades within `radius`, leaving them as piles on the ground.
## Returns how many were cut. Blades already cut are skipped, so holding a
## continuous tool over the same spot does nothing after the first pass.
func cut_near(world_pos: Vector3, radius: float) -> int:
	var radius_sq := radius * radius
	var center := Vector2(world_pos.x, world_pos.z)
	var count := 0
	for i in positions.size():
		if state[i] != State.UNCUT:
			continue
		if positions[i].distance_squared_to(center) <= radius_sq:
			state[i] = State.CUT
			multimesh.set_instance_transform(i, _blade_transform(i, PILE_SCALE_Y))
			multimesh.set_instance_color(i, COLOR_CUT)
			count += 1
	return count

## Picks up cut piles within `radius`, up to `max_amount`. Returns how much was
## actually collected, so the caller can stop at its carry capacity and leave the
## rest lying there.
func collect_near(world_pos: Vector3, radius: float, max_amount: int) -> int:
	if max_amount <= 0:
		return 0
	var radius_sq := radius * radius
	var center := Vector2(world_pos.x, world_pos.z)
	var collected := 0
	for i in positions.size():
		if collected >= max_amount:
			break
		if state[i] != State.CUT:
			continue
		if positions[i].distance_squared_to(center) <= radius_sq:
			state[i] = State.COLLECTED
			multimesh.set_instance_transform(i, _blade_transform(i, COLLECTED_SCALE_Y))
			collected += 1
	return collected
