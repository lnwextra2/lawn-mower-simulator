extends Node3D

## Drop as a child of a lamp model (world lantern, light post) to make its lit
## parts self-glow, using the same brightness-threshold shader as the held
## lantern: bright texels (flame, glass) emit, the dark frame stays a normal
## object. Steady - it's a light that's on, not toggled. Tune the threshold per
## model, since a lantern and a post-lamp bake their bright parts differently.

const GLOW_SHADER := preload("res://tools/lantern_glow.gdshader")

@export var glow_energy: float = 2.0
@export_range(0.0, 1.0) var glow_threshold: float = 0.4
@export_range(0.0, 1.0) var glow_softness: float = 0.15

func _ready() -> void:
	_apply(get_parent())

func _apply(node: Node) -> void:
	if node == self:
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var base := mi.get_active_material(i)
			var tex: Texture2D = base.albedo_texture if base is StandardMaterial3D else null
			var mat := ShaderMaterial.new()
			mat.shader = GLOW_SHADER
			mat.set_shader_parameter("tex", tex)
			mat.set_shader_parameter("glow", glow_energy)
			mat.set_shader_parameter("threshold", glow_threshold)
			mat.set_shader_parameter("softness", glow_softness)
			mi.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply(child)
