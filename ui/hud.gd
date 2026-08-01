extends CanvasLayer

@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var carried_bar: ProgressBar = $CarriedBar
@onready var gold_label: Label = $GoldLabel
@onready var interact_prompt: Label = $InteractPrompt
@onready var tool_label: Label = $ToolLabel
@onready var lantern_label: Label = $LanternLabel
@onready var damage_vignette: ColorRect = $DamageVignette

## The red the screen holds at each level of hurt, indexed by hearts LOST
## (0 = full health = clean, up to MAX). This is the health readout - tune these
## by eye. Non-linear on purpose: barely-there at first, alarming at the end.
@export var vignette_by_missing: Array[float] = [0.0, 0.25, 0.55, 1.0]
## Extra red kicked in the instant a hit lands, on top of the resting level,
## then it drains away - so a hit reads as a hit even if health barely moved.
@export var hit_flash: float = 0.4
@export var hit_flash_fade: float = 1.5   ## how fast the flash drains (per second)
## On the last heart the vignette breathes, like a pulse. Amount adds/subtracts
## on top of the resting red; speed is beats-ish per second.
@export var heartbeat_amount: float = 0.12
@export var heartbeat_speed: float = 4.0

var _vignette_base: float = 0.0   ## resting red from current hearts
var _vignette_flash: float = 0.0  ## decaying kick from the latest hit
var _heartbeat: bool = false      ## last heart -> breathe
var _beat_time: float = 0.0

var _player: Node = null

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	_player = player
	player.stamina_changed.connect(_on_stamina_changed)
	player.carried_grass_changed.connect(_on_carried_changed)
	Economy.gold_changed.connect(_on_gold_changed)
	player.look_target_changed.connect(_on_look_target_changed)
	player.held_tool_changed.connect(_on_held_tool_changed)
	player.tool_wear_changed.connect(_on_tool_wear_changed)
	player.tool_fuel_changed.connect(_on_tool_fuel_changed)
	player.lantern_changed.connect(_on_lantern_changed)
	player.health_changed.connect(_on_health_changed)

	_on_health_changed(player.hearts, player.MAX_HEARTS, 0)
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

var _looked_at: Node3D = null

func _on_look_target_changed(target: Node3D) -> void:
	_looked_at = target
	if target == null:
		# A cart under tow trails behind you and can never be looked at, so the
		# only place to advertise letting go of it is here, with nothing in view.
		if _player and _player.towed_cart:
			interact_prompt.text = "[E] ปล่อยเกวียน"
			interact_prompt.visible = true
		else:
			interact_prompt.visible = false
	elif target.is_in_group("tool_pickup"):
		interact_prompt.text = "[E] เก็บ %s" % target.tool_data.tool_name
		interact_prompt.visible = true
	elif target.is_in_group("fuel_station"):
		interact_prompt.text = "[กด E ค้าง] เติม%s" % target.label()
		interact_prompt.visible = true
	elif target.is_in_group("repair_box") or target.is_in_group("shop_stand") \
			or target.is_in_group("drop_off") or target.is_in_group("cart"):
		interact_prompt.text = target.prompt()
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

## The repair bay's line changes without the look target changing - a countdown
## ticking, or a tool landing in the bay and moving the price - so it's rebuilt
## every frame while you're looking at one. Cheap, and never shows a stale quote.
func _process(delta: float) -> void:
	_update_vignette(delta)
	if _looked_at and (_looked_at.is_in_group("repair_box") or _looked_at.is_in_group("drop_off") \
			or _looked_at.is_in_group("cart")):
		interact_prompt.text = _looked_at.prompt()
	elif _looked_at == null and _player:
		# Grabbing or letting go of the cart changes this line without the look
		# target changing, so it's re-evaluated here rather than only on change.
		_on_look_target_changed(null)

## Resting red is set the moment hearts change; here we add the decaying hit
## flash and, on the last heart, a breathing pulse - then push the sum into the
## shader. Done every frame because flash and heartbeat are time-based.
func _on_health_changed(current: int, max_hearts: int, took: int) -> void:
	var missing := clampi(max_hearts - current, 0, vignette_by_missing.size() - 1)
	_vignette_base = vignette_by_missing[missing]
	_heartbeat = current == 1
	if took > 0:
		_vignette_flash = hit_flash

func _update_vignette(delta: float) -> void:
	var mat := damage_vignette.material as ShaderMaterial
	if mat == null:
		return
	_vignette_flash = move_toward(_vignette_flash, 0.0, hit_flash_fade * delta)
	var beat := 0.0
	if _heartbeat:
		_beat_time += delta
		beat = (sin(_beat_time * heartbeat_speed) * 0.5 + 0.5) * heartbeat_amount
	var shown: float = clampf(_vignette_base + _vignette_flash + beat, 0.0, 1.0)
	mat.set_shader_parameter("intensity", shown)

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
