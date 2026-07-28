extends StaticBody3D
class_name ShopStand

## One item on display in the shop, with its price floating over it.
##
## What's on the stand is a display model only - it was never a pickup, so
## walking off with unpaid stock isn't something that has to be forbidden, it
## simply isn't possible. Paying spawns the real thing at the collection point
## instead, like ordering at a counter and picking the goods up outside.
##
## Sells two shapes of thing:
##  - a ToolData, delivered as a ToolPickup (tools, the lantern)
##  - any scene, delivered as itself (the cart, and whatever comes later)
## Set whichever fits; the ToolData path wins if both are filled in.

## For anything that's carried in hand.
@export var item: ToolData
## For products that are their own object rather than something you hold.
@export var product_scene: PackedScene
## What sits on the stand. Falls back to the tool's ground model. Must be inert
## scenery - handing it a live product would put a working cart in the shop,
## which the sale pad would then happily try to empty.
@export var display_scene: PackedScene
## Shown on the price tag. Falls back to the tool's name.
@export var product_name: String = ""
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
	var shown: PackedScene = display_scene
	if shown == null and item:
		shown = item.world_model_scene
	if shown:
		display.add_child(shown.instantiate())
	_refresh()

func title() -> String:
	if product_name != "":
		return product_name
	return item.tool_name if item else "สินค้า"

func buy() -> bool:
	if sold or (item == null and product_scene == null):
		return false
	var counter := get_tree().get_first_node_in_group("shop_collect")
	if counter == null:
		push_error("ShopStand: no node in group 'shop_collect' to deliver to")
		return false
	if not Economy.spend(price):
		return false

	var goods: Node3D
	if item:
		goods = preload("res://tools/tool_pickup.tscn").instantiate()
		goods.tool_data = item
		# Sold new: sharp, and with a full tank if it takes one.
		goods.tool_wear = 0.0
		goods.fuel = item.fuel_capacity
	else:
		goods = product_scene.instantiate()
	counter.add_child(goods)
	goods.global_position = counter.global_position + Vector3(0, 0.6, 0)

	if unique:
		sold = true
		for child in display.get_children():
			child.queue_free()
	_refresh()
	return true

func _refresh() -> void:
	price_label.visible = not sold
	if not sold:
		price_label.text = "%s\n%d ทอง" % [title(), price]

func prompt() -> String:
	if sold:
		return "หมดแล้ว"
	return "[E] ซื้อ %s — %d ทอง" % [title(), price]
