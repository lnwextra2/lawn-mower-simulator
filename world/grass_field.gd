extends MultiMeshInstance3D

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

	var half := GameConfig.GRASS_FIELD_SIZE / 2.0
	for i in GameConfig.GRASS_COUNT:
		var x := randf_range(-half, half)
		var z := randf_range(-half, half)
		var yaw := randf_range(0.0, TAU)

		var xform := Transform3D().rotated(Vector3.UP, yaw)
		xform.origin = Vector3(x, -0.4, z)
		multimesh.set_instance_transform(i, xform)
