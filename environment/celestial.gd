extends Node3D

## The visible sun and moon discs. They ride a dome that follows the player (so
## they sit infinitely far off with no parallax) and turns with the day, matching
## the sun light in lighting_controller. The moon is fixed opposite the sun, so
## as one sets the other rises. Each disc fades out as it dips below the horizon
## instead of hanging in the ground.
##
## Discs are built in code so their look is all exported knobs - no material
## resource to dig into. They're unshaded, so they glow the same whatever the
## light is doing (the sun shouldn't dim itself).

@export var sun_color: Color = Color(1.0, 0.85, 0.4)
@export var moon_color: Color = Color(0.9, 0.93, 1.0)
@export var sun_radius: float = 18.0
@export var moon_radius: float = 13.0
## How far off the discs sit. Well beyond the map so they read as sky, not props.
@export var distance: float = 300.0
## Must match lighting_controller's sun_yaw_deg, or the disc and its light part
## ways. Kept as its own knob rather than read across so this scene stands alone.
@export var sun_yaw_deg: float = -30.0
## Height band over the horizon across which a disc fades in/out, so it doesn't
## pop on/off at the ground line.
@export var horizon_fade: float = 40.0
## Follow the player so the sky never gets closer. Off = dome stays at the origin.
@export var follow_player: bool = true

var _sun_disc: MeshInstance3D
var _moon_disc: MeshInstance3D
var _player: Node3D

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	# Sun sits in the +Z of the dome (the direction the light comes FROM); the
	# moon directly opposite it.
	_sun_disc = _make_disc(sun_radius, sun_color, distance)
	_moon_disc = _make_disc(moon_radius, moon_color, -distance)

func _process(_delta: float) -> void:
	if follow_player and _player:
		global_position = _player.global_position
	# Same swing as the sun light: horizon at sunrise (t=0.25), overhead at noon.
	var day_angle := (DayNight.time - 0.25) * 360.0
	rotation_degrees = Vector3(-day_angle, sun_yaw_deg, 0.0)
	_fade_at_horizon(_sun_disc)
	_fade_at_horizon(_moon_disc)

## An unshaded, ground-anchored sphere at (0,0,z) in the dome's local space, so
## rotating the dome carries it around the arc.
func _make_disc(radius: float, color: Color, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Never let a disc get culled early or occluded by fog/depth quirks at range.
	mat.disable_receive_shadows = true
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.0, z)
	# Discs are decoration only - keep them off every physics/collision path.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _fade_at_horizon(disc: MeshInstance3D) -> void:
	var mat := disc.material_override as StandardMaterial3D
	var height := disc.global_position.y - global_position.y
	var a := clampf(height / horizon_fade, 0.0, 1.0)
	mat.albedo_color.a = a
	disc.visible = a > 0.0
