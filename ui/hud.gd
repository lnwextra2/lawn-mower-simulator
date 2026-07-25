extends CanvasLayer

@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var carried_bar: ProgressBar = $CarriedBar
@onready var gold_label: Label = $GoldLabel

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	player.stamina_changed.connect(_on_stamina_changed)
	player.carried_grass_changed.connect(_on_carried_changed)
	Economy.gold_changed.connect(_on_gold_changed)

	_on_stamina_changed(player.stamina, GameConfig.STAMINA_MAX)
	_on_carried_changed(player.carried_grass, GameConfig.PLAYER_CARRY_CAPACITY)
	_on_gold_changed(Economy.gold) 

func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = current

func _on_carried_changed(current: float, max_value: float) -> void:
	carried_bar.max_value = max_value
	carried_bar.value = current

func _on_gold_changed(current: int) -> void:
	gold_label.text = "Gold: %d" % current
