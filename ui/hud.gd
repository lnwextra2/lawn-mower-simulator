extends CanvasLayer

@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var carried_bar: ProgressBar = $CarriedBar
@onready var gold_label: Label = $GoldLabel
@onready var interact_prompt: Label = $InteractPrompt
@onready var tool_label: Label = $ToolLabel
@onready var lantern_label: Label = $LanternLabel

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	player.stamina_changed.connect(_on_stamina_changed)
	player.carried_grass_changed.connect(_on_carried_changed)
	Economy.gold_changed.connect(_on_gold_changed)
	player.look_target_changed.connect(_on_look_target_changed)
	player.held_tool_changed.connect(_on_held_tool_changed)
	player.tool_wear_changed.connect(_on_tool_wear_changed)
	player.tool_fuel_changed.connect(_on_tool_fuel_changed)
	player.lantern_changed.connect(_on_lantern_changed)

	_on_stamina_changed(player.stamina, GameConfig.STAMINA_MAX)
	_on_carried_changed(player.carried_grass, GameConfig.PLAYER_CARRY_CAPACITY)
	_on_gold_changed(Economy.gold)
	_on_held_tool_changed(player.held_tool)
	_on_tool_wear_changed(player.held_wear)
	_on_lantern_changed(player.lantern, player.lantern_lit, player.lantern_fuel)

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
	elif target.is_in_group("fuel_station"):
		interact_prompt.text = "[กด E ค้าง] เติม%s" % target.label()
		interact_prompt.visible = true
	else:
		interact_prompt.text = "[E] โต้ตอบ"
		interact_prompt.visible = true

## Kept together: the label always reads "<tool> — <condition>", so every signal
## rebuilds the whole line rather than each owning half of it. Which condition is
## shown depends on the tool - a hand tool has sharpness, an engine has fuel.
var _tool_name: String = ""
var _tool_sharpness: int = 100
var _tool_powered: bool = false
var _tool_fuel_pct: int = 0

func _on_held_tool_changed(tool: ToolData) -> void:
	_tool_name = tool.tool_name
	_tool_powered = tool.fuel_capacity > 0.0
	_refresh_tool_label()

func _on_tool_wear_changed(wear: float) -> void:
	_tool_sharpness = int(round((1.0 - wear) * 100.0))
	_refresh_tool_label()

func _on_tool_fuel_changed(fuel: float, capacity: float) -> void:
	_tool_fuel_pct = int(round(fuel / capacity * 100.0)) if capacity > 0.0 else 0
	_refresh_tool_label()

## Hidden entirely when you have no lantern - an empty readout for something
## you aren't carrying is just noise.
func _on_lantern_changed(lantern: LanternData, lit: bool, fuel: float) -> void:
	lantern_label.visible = lantern != null
	if lantern == null:
		return
	var pct := int(round(fuel / lantern.fuel_capacity * 100.0)) if lantern.fuel_capacity > 0.0 else 0
	lantern_label.text = "ตะเกียง: %s (น้ำมัน %d%%)" % ["ติด" if lit else "ดับ", pct]

func _refresh_tool_label() -> void:
	if _tool_powered:
		tool_label.text = "ถือ: %s (น้ำมัน %d%%)" % [_tool_name, _tool_fuel_pct]
	else:
		tool_label.text = "ถือ: %s (คม %d%%)" % [_tool_name, _tool_sharpness]
