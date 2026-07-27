extends StaticBody3D
class_name ShopStand

## One item on display in the shop, with its price floating over it.
##
## What's on the stand is a display model only - it was never a pickup, so
## walking off with unpaid stock isn't something that has to be forbidden, it
## simply isn't possible. Paying spawns the real item over at the collection
## point instead, like ordering at a counter and picking the goods up outside.

@export var item: ToolData
@export var price: int = 100
## Sells once and then stands empty - for the things there's no point owning two
## of. Leave off for stock that's always available.
@export var unique: bool = false

var sold: bool = false

@onready var display: Node3D = $Display
@onready var price_label: Label3D = $PriceLabel

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("shop_stand")
	if item and item.world_model_scene:
		display.add_child(item.world_model_scene.instantiate())
	_refresh()

func buy() -> bool:
	if sold or item == null:
		return false
	var counter := get_tree().get_first_node_in_group("shop_collect")
	if counter == null:
		push_error("ShopStand: no node in group 'shop_collect' to deliver to")
		return false
	if not Economy.spend(price):
		return false

	var pickup := preload("res://tools/tool_pickup.tscn").instantiate()
	pickup.tool_data = item
	# Sold new: sharp, and with a full tank if it takes one.
	pickup.tool_wear = 0.0
	pickup.fuel = item.fuel_capacity
	counter.add_child(pickup)
	pickup.global_position = counter.global_position + Vector3(0, 0.6, 0)

	if unique:
		sold = true
		for child in display.get_children():
			child.queue_free()
	_refresh()
	return true

func _refresh() -> void:
	price_label.visible = not sold
	if not sold and item:
		price_label.text = "%s\n%d ทอง" % [item.tool_name, price]

func prompt() -> String:
	if sold or item == null:
		return "หมดแล้ว"
	return "[E] ซื้อ %s — %d ทอง" % [item.tool_name, price]
