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

const BLADE_MODEL := preload("res://assets/models/tall_grass.glb")

const BLADE_BASE_Y := 0.0    ## where a blade meets the ground = the floor's top surface
							 ## (Floor's 1-tall box sits at y=-0.5, so its top is y=0)
const PILE_SCALE_Y := 0.35   ## flattened mound left behind by cutting
const COLLECTED_SCALE_Y := 0.02
const BLADE_SCALE := 0.7     ## overall size of one tuft; tune to taste
## Uniform tufts read as a planted crop (rows of rice) rather than an overgrown
## lawn. Randomising size, lean and shade per tuft is what makes it look unkempt.
const SCALE_VARIANCE := Vector2(0.65, 1.25)   ## min/max multiplier on BLADE_SCALE
const MAX_TILT_DEG := 14.0                    ## how far a tuft can lean over
const SHADE_VARIANCE := 0.18                  ## +/- brightness jitter on the green

const COLOR_UNCUT := GameConfig.COLOR_GRASS_STANDING
const COLOR_CUT := GameConfig.COLOR_GRASS_CUT

var positions: PackedVector2Array
var yaws: PackedFloat32Array
var scales: PackedFloat32Array
var tilts: PackedVector2Array   ## per-tuft lean, radians about X and Z
var state: PackedByteArray
## The mesh's lowest local Y. Scaling has to keep the blade's base planted, and
## an imported model's pivot isn't necessarily at its base, so read it rather
## than assume it.
var _blade_bottom: float = 0.0

func _ready() -> void:
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

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true          # must be set before instance_count
	multimesh.mesh = blade_mesh
	multimesh.instance_count = GameConfig.GRASS_COUNT

	positions.resize(GameConfig.GRASS_COUNT)
	yaws.resize(GameConfig.GRASS_COUNT)
	scales.resize(GameConfig.GRASS_COUNT)
	tilts.resize(GameConfig.GRASS_COUNT)
	state.resize(GameConfig.GRASS_COUNT)

	var half := GameConfig.GRASS_FIELD_SIZE / 2.0
	var max_tilt := deg_to_rad(MAX_TILT_DEG)
	for i in GameConfig.GRASS_COUNT:
		positions[i] = Vector2(randf_range(-half, half), randf_range(-half, half))
		yaws[i] = randf_range(0.0, TAU)
		scales[i] = randf_range(SCALE_VARIANCE.x, SCALE_VARIANCE.y)
		tilts[i] = Vector2(randf_range(-max_tilt, max_tilt), randf_range(-max_tilt, max_tilt))
		state[i] = State.UNCUT
		multimesh.set_instance_transform(i, _blade_transform(i, 1.0))
		# Jitter the shade so the field isn't one flat sheet of the same green.
		var shade := 1.0 + randf_range(-SHADE_VARIANCE, SHADE_VARIANCE)
		multimesh.set_instance_color(i, Color(
			COLOR_UNCUT.r * shade, COLOR_UNCUT.g * shade, COLOR_UNCUT.b * shade))

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
func _blade_transform(i: int, scale_y: float) -> Transform3D:
	var s := BLADE_SCALE * scales[i]
	var scale := Vector3(s, s * scale_y, s)
	# Spin about Y, then lean the whole tuft over in world space so it looks
	# wind-blown rather than planted in a row.
	var basis := Basis(Vector3.RIGHT, tilts[i].x) * Basis(Vector3.FORWARD, tilts[i].y) \
		* Basis(Vector3.UP, yaws[i])
	basis = basis.scaled(scale)
	var y := BLADE_BASE_Y - _blade_bottom * scale.y
	return Transform3D(basis, Vector3(positions[i].x, y, positions[i].y))

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
