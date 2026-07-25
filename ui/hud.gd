extends CanvasLayer

@onready var stamina_bar: ProgressBar = $StaminaBar

func _ready() -> void:
	var player := get_node("../Player")
	player.stamina_changed.connect(_on_stamina_changed)
	_on_stamina_changed(player.stamina, GameConfig.STAMINA_MAX)

func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = current
