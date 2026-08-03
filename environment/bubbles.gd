extends GPUParticles3D

## Soap bubbles drifting around the player. The emitter follows the player so a
## few are always nearby; particles use world coordinates (local_coords off on the
## node) so they hang in the air and trail behind as you move, instead of riding
## along locked to you.

@export var follow_player: bool = true

var _player: Node3D

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	GraphicsSettings.changed.connect(_apply_settings)
	_apply_settings()

func _process(_delta: float) -> void:
	if follow_player and _player:
		global_position = _player.global_position

## Count, on/off and rim glow come from the player's graphics settings.
func _apply_settings() -> void:
	amount = GraphicsSettings.bubble_amount
	emitting = GraphicsSettings.bubbles_enabled
	visible = GraphicsSettings.bubbles_enabled
	if material_override is ShaderMaterial:
		(material_override as ShaderMaterial).set_shader_parameter(
			"rim_glow", GraphicsSettings.bubble_rim_glow)
