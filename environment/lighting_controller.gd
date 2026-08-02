extends WorldEnvironment

## Drives a ProceduralSky, ambient and the sun off DayNight.time CONTINUOUSLY, so
## the whole look eases from night to dawn to day instead of snapping at phase
## boundaries. The sky is a real gradient dome now (deep overhead, bright at the
## horizon) with the sun drawn in it, not a flat background colour.
##
## Every look value is a Gradient or Curve sampled by time (0=midnight, 0.25=
## sunrise, 0.5=noon, 0.75=sunset). Leave the exports empty and sensible defaults
## are built in _ready; assign your own to art-direct the whole day.

## Colour high overhead (deepest part of the sky).
@export var sky_top_gradient: Gradient
## Colour down at the horizon (brighter, hazier).
@export var sky_horizon_gradient: Gradient
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

var _sky_mat: ProceduralSkyMaterial

func _ready() -> void:
	# Real sky dome as the background; the ProceduralSkyMaterial also draws a sun
	# glow at the DirectionalLight's direction, so the sun's disc rides the sky as
	# it rotates. Ambient stays a colour we control, or night never gets dark.
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sun_angle_max = 8.0
	_sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if sky_top_gradient == null or sky_horizon_gradient == null or sun_gradient == null \
			or ambient_gradient == null or sun_energy == null or ambient_energy == null:
		_build_defaults()

func _process(_delta: float) -> void:
	var t := DayNight.time
	var top := sky_top_gradient.sample(t)
	var horizon := sky_horizon_gradient.sample(t)
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = horizon
	# Ground half of the dome (below the horizon line) held at the horizon colour,
	# NOT darkening down to the deep top colour - so looking below the horizon
	# (mid-jump, over the floor's edge) shows bright sky, not a dark band.
	_sky_mat.ground_horizon_color = horizon
	_sky_mat.ground_bottom_color = horizon
	environment.ambient_light_color = ambient_gradient.sample(t)
	environment.ambient_light_energy = ambient_energy.sample(t)
	if sun:
		sun.light_color = sun_gradient.sample(t)
		sun.light_energy = sun_energy.sample(t)
		sun.shadow_enabled = sun.light_energy > shadow_cutoff
		# The sun swings a full circle over a day: level with the horizon at
		# sunrise (t=0.25), overhead at noon (t=0.5), horizon again at sunset.
		var day_angle := (t - 0.25) * 360.0
		sun.rotation_degrees = Vector3(-day_angle, sun_yaw_deg, 0.0)

## Rebuilds the look from a bright, clear-sky palette. Points sit a little
## before/after each phase edge so the colour is already arriving as the phase
## turns over. Sky leans Frutiger-Aero: saturated blue up high, pale near the
## horizon by day; warm orange horizon at dawn/dusk; near-black at night.
func _build_defaults() -> void:
	var night_top := Color(0.02, 0.03, 0.09)
	var night_hor := Color(0.05, 0.07, 0.14)
	var dawn_top := Color(0.35, 0.35, 0.55)
	var dawn_hor := Color(1.0, 0.6, 0.35)
	var day_top := Color(0.25, 0.55, 0.95)
	var day_hor := Color(0.72, 0.88, 1.0)
	var offs := [0.0, 0.20, 0.28, 0.40, 0.60, 0.72, 0.80, 1.0]
	sky_top_gradient = _grad(offs,
		[night_top, night_top, dawn_top, day_top, day_top, dawn_top, night_top, night_top])
	sky_horizon_gradient = _grad(offs,
		[night_hor, night_hor, dawn_hor, day_hor, day_hor, dawn_hor, night_hor, night_hor])

	var sun_warm := Color(1.0, 0.6, 0.35)
	sun_gradient = _grad(
		[0.20, 0.28, 0.40, 0.60, 0.72, 0.80],
		[sun_warm, sun_warm, Color.WHITE, Color.WHITE, sun_warm, sun_warm])

	ambient_gradient = _grad(
		[0.0, 0.28, 0.5, 0.72, 0.85],
		[Color(0.3, 0.35, 0.55), Color(1.0, 0.85, 0.7), Color.WHITE,
		 Color(1.0, 0.85, 0.7), Color(0.3, 0.35, 0.55)])

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
