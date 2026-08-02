extends StaticBody3D

## The bed. Sleeping skips 8 in-game hours of night in one go, once per night -
## NOT the whole night (design §11): you still have to live through the rest,
## so night keeps a slice that can't be slept past. Skipping only 8h of a ~12h
## night means bedding down early leaves ~4h on the far side when you wake.
##
## Deliberately not a full skip: a full skip would make night meaningless. This
## is why the number is a knob - the exposure that survives sleep is the whole
## point, so it's tuned, not incidental.

## How much of a day one sleep skips, as a fraction of the full cycle. 8h of a
## 24h day = 1/3. Tune this and the night's leftover exposure moves with it.
@export var nap_skip: float = 8.0 / 24.0
## Seconds to fade out, hold black, and fade back. The hold is where the skip
## actually happens, hidden behind black.
@export var fade_out: float = 0.6
@export var fade_hold: float = 0.5
@export var fade_in: float = 0.8

## One sleep per night. Set true on sleeping, cleared when a new day starts, so
## you can't chain naps through a single night.
var _napped_tonight: bool = false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("bed")
	DayNight.phase_changed.connect(_on_phase_changed)

## Sleeping is only offered at night, and only once. The daytime bed is just
## furniture - matching the old "a bed exists but can't always be slept in".
func can_sleep() -> bool:
	return DayNight.phase == DayNight.Phase.NIGHT and not _napped_tonight

func interact() -> void:
	if not can_sleep():
		return
	_napped_tonight = true
	# The time jump is hidden behind the black of the fade; the HUD owns the
	# overlay and calls us back at the darkest point to actually move the clock.
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("sleep_fade"):
		hud.sleep_fade(_advance_clock, fade_out, fade_hold, fade_in)
	else:
		_advance_clock()   # no HUD (e.g. a test scene): skip without the fade

func _advance_clock() -> void:
	DayNight.time = fmod(DayNight.time + nap_skip, 1.0)

func _on_phase_changed(new_phase: int) -> void:
	# A fresh day returns the right to sleep. Reset on DAY specifically so the
	# dawn you wake into doesn't immediately hand it back mid-night.
	if new_phase == DayNight.Phase.DAY:
		_napped_tonight = false

func prompt() -> String:
	if DayNight.phase != DayNight.Phase.NIGHT:
		return "เตียง (นอนได้ตอนกลางคืน)"
	if _napped_tonight:
		return "นอนไปแล้วคืนนี้"
	return "[E] นอน (ข้าม 8 ชม.)"
