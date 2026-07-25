extends WorldEnvironment

@onready var sun: DirectionalLight3D = get_tree().get_first_node_in_group("sun_light")

func _ready() -> void:
	# Drive ambient from an explicit color we control, not the default
	# background/sky source - otherwise ambient_light_energy fights whatever
	# the engine derives from the clear color and night never gets dark.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Flat colored sky we recolor per phase. Without this the background stays
	# the default gray all cycle, so night reads as "overcast day", never night.
	environment.background_mode = Environment.BG_COLOR
	DayNight.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(DayNight.phase)

func _on_phase_changed(phase: DayNight.Phase) -> void:
	match phase:
		DayNight.Phase.DAWN, DayNight.Phase.DUSK:
			sun.light_energy = 0.9
			sun.light_color = Color(1.0, 0.6, 0.35)
			sun.shadow_enabled = true
			environment.background_color = Color(1.0, 0.6, 0.33)
			environment.ambient_light_color = Color(1.0, 0.85, 0.7)
			environment.ambient_light_energy = 0.35
		DayNight.Phase.DAY:
			sun.light_energy = 1.3
			sun.light_color = Color(1.0, 1.0, 1.0)
			sun.shadow_enabled = true
			environment.background_color = Color(0.53, 0.81, 0.92)
			environment.ambient_light_color = Color(1.0, 1.0, 1.0)
			environment.ambient_light_energy = 0.3
		DayNight.Phase.NIGHT:
			# Sun effectively off: a DirectionalLight3D doesn't attenuate, so
			# even a tiny energy lights the whole field evenly - and its hard
			# shadows read as daylight. Kill both; navigate by faint ambient.
			sun.light_energy = 0.0
			sun.shadow_enabled = false
			environment.background_color = Color(0.04, 0.04, 0.1)
			environment.ambient_light_color = Color(0.3, 0.35, 0.55)
			environment.ambient_light_energy = 0.15
