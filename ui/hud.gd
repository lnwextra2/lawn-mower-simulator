extends CanvasLayer

@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var carried_bar: ProgressBar = $CarriedBar
@onready var gold_label: Label = $GoldLabel
@onready var interact_prompt: Label = $InteractPrompt
@onready var tool_label: Label = $ToolLabel

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	player.stamina_changed.connect(_on_stamina_changed)
	player.carried_grass_changed.connect(_on_carried_changed)
	Economy.gold_changed.connect(_on_gold_changed)
	player.look_target_changed.connect(_on_look_target_changed)
	player.held_tool_changed.connect(_on_held_tool_changed)
	player.tool_wear_changed.connect(_on_tool_wear_changed)

	_on_stamina_changed(player.stamina, GameConfig.STAMINA_MAX)
	_on_carried_changed(player.carried_grass, GameConfig.PLAYER_CARRY_CAPACITY)
	_on_gold_changed(Economy.gold)
	_on_held_tool_changed(player.held_tool)
	_on_tool_wear_changed(player.held_wear)

func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = current

func _on_carried_changed(current: float, max_value: float) -> void:
	carried_bar.max_value = max_value
	carried_bar.value = current

func _on_gold_changed(current: int) -> void:
	gold_label.text = "Gold: %d" % current

func _on_look_target_changed(target: Node3D) -> void:
	if target == null:
		interact_prompt.visible = false
	elif target.is_in_group("tool_pickup"):
		interact_prompt.text = "[E] เก็บ %s" % target.tool_data.tool_name
		interact_prompt.visible = true
	else:
		interact_prompt.text = "[E] โต้ตอบ"
		interact_prompt.visible = true

## Kept together: the label always reads "<tool> — <sharpness>", so both signals
## rebuild the whole line rather than each owning half of it.
var _tool_name: String = ""
var _tool_sharpness: int = 100

func _on_held_tool_changed(tool: ToolData) -> void:
	_tool_name = tool.tool_name
	_refresh_tool_label()

func _on_tool_wear_changed(wear: float) -> void:
	_tool_sharpness = int(round((1.0 - wear) * 100.0))
	_refresh_tool_label()

func _refresh_tool_label() -> void:
	tool_label.text = "ถือ: %s (คม %d%%)" % [_tool_name, _tool_sharpness]
