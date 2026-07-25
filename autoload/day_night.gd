extends Node

enum Phase { DAWN, DAY, DUSK, NIGHT }

signal phase_changed(new_phase: Phase)

var time: float = GameConfig.DAY_NIGHT_START_TIME
var phase: Phase = Phase.NIGHT

func _ready() -> void:
	phase = _phase_for_time(time)

func _process(delta: float) -> void:
	time += delta / GameConfig.DAY_NIGHT_CYCLE_DURATION
	if time >= 1.0:
		time -= 1.0

	var new_phase := _phase_for_time(time)
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)

func _phase_for_time(t: float) -> Phase:
	if t >= 0.22 and t < 0.35:
		return Phase.DAWN
	if t >= 0.35 and t < 0.65:
		return Phase.DAY
	if t >= 0.65 and t < 0.78:
		return Phase.DUSK
	return Phase.NIGHT
