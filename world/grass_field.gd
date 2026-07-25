extends MultiMeshInstance3D
class_name GrassField

var positions: PackedVector2Array
var cut: PackedByteArray

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.8)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.13, 0.55, 0.13)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = GameConfig.GRASS_COUNT

	positions.resize(GameConfig.GRASS_COUNT)
	cut.resize(GameConfig.GRASS_COUNT)

	var half := GameConfig.GRASS_FIELD_SIZE / 2.0
	for i in GameConfig.GRASS_COUNT:
		var x := randf_range(-half, half)
		var z := randf_range(-half, half)
		var yaw := randf_range(0.0, TAU)

		positions[i] = Vector2(x, z)

		var xform := Transform3D().rotated(Vector3.UP, yaw)
		xform.origin = Vector3(x, 0.4, z)
		multimesh.set_instance_transform(i, xform)

func cut_near(world_pos: Vector3, radius: float) -> int:
	var radius_sq := radius * radius
	var center := Vector2(world_pos.x, world_pos.z)
	var cut_count := 0
	for i in positions.size():
		if cut[i] == 1:
			continue
		if positions[i].distance_squared_to(center) <= radius_sq:
			cut[i] = 1
			multimesh.set_instance_transform(i, Transform3D().scaled(Vector3.ZERO))
			cut_count += 1
	return cut_count
