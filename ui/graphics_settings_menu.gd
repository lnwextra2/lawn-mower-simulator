extends CanvasLayer

## In-game graphics options. Builds its rows straight from GraphicsSettings.META,
## so adding a setting needs no changes here. Escape toggles the menu and the
## mouse; each control writes back through GraphicsSettings.set_value, which
## applies it live and saves it.

@onready var _list: VBoxContainer = $Panel/Margin/Scroll/List

func _ready() -> void:
	layer = 10   # above the HUD
	visible = false
	_build()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED

func _build() -> void:
	var title := Label.new()
	title.text = "ตั้งค่าภาพ   [Esc ปิด]"
	title.add_theme_font_size_override("font_size", 22)
	_list.add_child(title)

	var section := ""
	for key in GraphicsSettings.KEYS:
		var m: Dictionary = GraphicsSettings.META[key]
		if m.section != section:
			section = m.section
			var head := Label.new()
			head.text = "— %s —" % section
			head.add_theme_font_size_override("font_size", 18)
			_list.add_child(head)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = m.label
		label.custom_minimum_size.x = 150
		row.add_child(label)
		row.add_child(_make_control(key, m))
		_list.add_child(row)

func _make_control(key: String, m: Dictionary) -> Control:
	if m.type == "bool":
		var cb := CheckBox.new()
		cb.button_pressed = GraphicsSettings.get(key)
		cb.toggled.connect(func(v: bool): GraphicsSettings.set_value(key, v))
		return cb
	var slider := HSlider.new()
	slider.min_value = m.min
	slider.max_value = m.max
	slider.step = m.step
	slider.value = GraphicsSettings.get(key)
	slider.custom_minimum_size.x = 220
	var is_int: bool = m.type == "int"
	slider.value_changed.connect(func(v: float):
		GraphicsSettings.set_value(key, int(v) if is_int else v))
	return slider
