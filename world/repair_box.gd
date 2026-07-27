extends StaticBody3D
class_name RepairBox

## The maintenance bay at base: throw worn tools into the bay, press the panel,
## the door shuts on them for a while, and they're serviced when it opens again.
##
## Works like a washing machine rather than a vending machine - the tools never
## leave the world. They lie in the bay exactly where they landed the whole time;
## the door just puts them out of reach while the work happens. Nothing is
## consumed and nothing is respawned, so an item can't be duplicated or lost, and
## whatever you can see in there is exactly what's being worked on.
##
## The wait is meant to be long enough that you leave and work rather than stand
## there, and nothing new can be started until the batch is done - so "how much
## do I dare send at once?" is the decision, since a tool in the bay is a tool
## you don't have.

enum State { IDLE, WORKING }

## What one fully-worn item costs, and how long it takes. Both scale with how
## worn the item actually is, over a flat minimum - if time were flat it would be
## correct to run everything into the ground before servicing, i.e. to play
## permanently with blunt tools.
const PRICE_PER_WEAR := 60.0
const SECONDS_PER_WEAR := 90.0
const MIN_SECONDS := 15.0
## Every item after the first is quicker, rewarding a planned maintenance run.
const BATCH_DISCOUNT := 0.65
const DOOR_TRAVEL := 1.7     ## how far the shutter slides down to close
const DOOR_SECONDS := 0.8

signal state_changed

var state: State = State.IDLE
var seconds_left: float = 0.0

@onready var bay: Area3D = $Bay
@onready var door: Node3D = $Door
@onready var _door_open_y: float = door.position.y

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("repair_box")
	# Tools live on the loose-item layer, so the bay has to watch that layer or it
	# would never see anything thrown into it.
	bay.collision_mask = GameConfig.LAYER_LOOSE_ITEM
	set_process(false)

## Everything currently sitting in the bay that there's any point servicing.
## Read live rather than tracked on enter/exit: whatever is in there right now is
## the truth, with no bookkeeping to fall out of sync.
func items_in_bay() -> Array:
	var found: Array = []
	for body in bay.get_overlapping_bodies():
		if body is ToolPickup and body.tool_data and body.tool_wear > 0.0:
			found.append(body)
	return found

func quoted_price() -> int:
	var total := 0.0
	for item in items_in_bay():
		total += item.tool_wear * PRICE_PER_WEAR
	return int(ceil(total))

func quoted_seconds() -> float:
	var total := 0.0
	var items := items_in_bay()
	for i in items.size():
		var one: float = MIN_SECONDS + items[i].tool_wear * SECONDS_PER_WEAR
		total += one if i == 0 else one * BATCH_DISCOUNT
	return total

func start() -> bool:
	if state != State.IDLE:
		return false
	var items := items_in_bay()
	if items.is_empty():
		return false
	var price := quoted_price()
	if price > 0 and not Economy.spend(price):
		return false

	seconds_left = quoted_seconds()
	state = State.WORKING
	for item in items:
		# Out of reach and out of the way: dropping them from the interactable
		# group is what actually stops you fishing a tool back out mid-service,
		# and freezing stops them drifting around behind the shutter.
		item.remove_from_group("interactable")
		item.freeze = true
	_move_door(_door_open_y - DOOR_TRAVEL)
	set_process(true)
	state_changed.emit()
	return true

func _process(delta: float) -> void:
	seconds_left -= delta
	if seconds_left <= 0.0:
		_finish()
	state_changed.emit()

## Opens up again with everything inside serviced. The tools haven't moved -
## they're the same objects, lying where they were thrown.
func _finish() -> void:
	state = State.IDLE
	seconds_left = 0.0
	set_process(false)
	for body in bay.get_overlapping_bodies():
		if body is ToolPickup:
			body.tool_wear = 0.0
			body.freeze = false
			if not body.is_in_group("interactable"):
				body.add_to_group("interactable")
	_move_door(_door_open_y)
	state_changed.emit()

func _move_door(to_y: float) -> void:
	var tween := create_tween()
	tween.tween_property(door, "position:y", to_y, DOOR_SECONDS)

## One line describing what the bay wants from you, shown as the interact prompt.
func prompt() -> String:
	if state == State.WORKING:
		return "กำลังซ่อม... %d วิ" % int(ceil(seconds_left))
	var items := items_in_bay()
	if items.is_empty():
		return "โยนอุปกรณ์ที่สึกลงในช่อง"
	return "[E] ซ่อม %d ชิ้น — %d ทอง (%d วิ)" % [
		items.size(), quoted_price(), int(ceil(quoted_seconds()))]
