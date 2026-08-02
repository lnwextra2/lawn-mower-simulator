extends WorldEnvironment

## Drives sky colour, ambient and the sun off DayNight.time CONTINUOUSLY, so the
## look eases from night to dawn to day instead of snapping at phase boundaries
## (the old version set four fixed looks on phase_changed, which stepped hard).
##
## Every look value is a Gradient or Curve sampled by time (0=midnight, 0.25=
## sunrise, 0.5=noon, 0.75=sunset). Leave the exports empty and sensible defaults
## are built in _ready from the old per-phase colours; assign your own in the
## Inspector to art-direct the whole day on a single gradient ramp.

## Sky/background colour across the day.
@export var sky_gradient: Gradient
## Sun (directional light) colour across the day - warm at the edges, white at noon.
@export var sun_gradient: Gradient
## Ambient fill colour - what lights surfaces the sun doesn't hit.
@export var ambient_gradient: Gradient
## Sun brightness across the day. Drops to 0 at night: a DirectionalLight doesn't
## attenuate, so any energy at all lights the whole field flat like daytime.
@export var sun_energy: Curve
## Ambient brightness across the day.
@export var ambient_energy: Curve
## Which compass line the sun rises and sets along, in degrees. Tilts the arc off
## dead east-west so shadows fall at an angle rather than straight down the axes.
@export var sun_yaw_deg: float = -30.0
## Below this sun energy, shadows are switched off - at night the hard directional
## shadow reads as daylight, so it goes with the light.
@export var shadow_cutoff: float = 0.05

@onready var sun: DirectionalLight3D = get_tree().get_first_node_in_group("sun_light")

func _ready() -> void:
	# Same environment setup as before: drive ambient and background from colours
	# we control, or night never actually gets dark.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.background_mode = Environment.BG_COLOR
	if sky_gradient == null or sun_gradient == null or ambient_gradient == null \
			or sun_energy == null or ambient_energy == null:
		_build_defaults()

func _process(_delta: float) -> void:
	var t := DayNight.time
	environment.background_color = sky_gradient.sample(t)
	environment.ambient_light_color = ambient_gradient.sample(t)
	environment.ambient_light_energy = ambient_energy.sample(t)
	if sun:
		sun.light_color = sun_gradient.sample(t)
		sun.light_energy = sun_energy.sample(t)
		sun.shadow_enabled = sun.light_energy > shadow_cutoff
		# The sun swings a full circle over a day: level with the horizon at
		# sunrise (t=0.25), overhead at noon (t=0.5), horizon again at sunset.
		# Its transform in the scene is overridden here every frame.
		var day_angle := (t - 0.25) * 360.0
		sun.rotation_degrees = Vector3(-day_angle, sun_yaw_deg, 0.0)

## Rebuilds the look from the old four-phase palette as smooth ramps, so it works
## out of the box. Points sit a little before/after each phase edge so the colour
## is already arriving as the phase turns over, rather than starting to move then.
func _build_defaults() -> void:
	var night_sky := Color(0.04, 0.04, 0.1)
	var warm := Color(1.0, 0.6, 0.33)      # dawn/dusk sky
	var day_sky := Color(0.53, 0.81, 0.92)
	sky_gradient = _grad(
		[0.0, 0.20, 0.28, 0.40, 0.60, 0.72, 0.80, 1.0],
		[night_sky, night_sky, warm, day_sky, day_sky, warm, night_sky, night_sky])

	var sun_warm := Color(1.0, 0.6, 0.35)
	sun_gradient = _grad(
		[0.20, 0.28, 0.40, 0.60, 0.72, 0.80],
		[sun_warm, sun_warm, Color.WHITE, Color.WHITE, sun_warm, sun_warm])

	ambient_gradient = _grad(
		[0.0, 0.28, 0.5, 0.72, 0.85],
		[Color(0.3, 0.35, 0.55), Color(1.0, 0.85, 0.7), Color.WHITE,
		 Color(1.0, 0.85, 0.7), Color(0.3, 0.35, 0.55)])

	# Sun energy peaks at 1.3, so the curve has to allow above 1.0.
	sun_energy = _curve(2.0,
		[Vector2(0.20, 0.0), Vector2(0.28, 0.9), Vector2(0.40, 1.3),
		 Vector2(0.60, 1.3), Vector2(0.72, 0.9), Vector2(0.80, 0.0)])
	ambient_energy = _curve(1.0,
		[Vector2(0.0, 0.15), Vector2(0.28, 0.35), Vector2(0.5, 0.3),
		 Vector2(0.72, 0.35), Vector2(0.85, 0.15)])

func _grad(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g

func _curve(max_value: float, points: Array) -> Curve:
	var c := Curve.new()
	c.max_value = max_value
	for p in points:
		c.add_point(p)
	return c
