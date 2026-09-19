extends PopupPanel

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal export_confirmed(settings: Dictionary)

var _width: SpinBox
var _height: SpinBox
var _supersampling: OptionButton
var _destination: LineEdit
var _transparent: CheckBox
var _overwrite: CheckBox

func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyles.flat(UiStyles.RAISED, 6, false))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(320, 0)
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(UiStyles.heading("Export", 14))
	var res_row: HBoxContainer = HBoxContainer.new()
	column.add_child(res_row)
	res_row.add_child(UiStyles.label("Resolution", 11))
	_width = SpinBox.new()
	_width.min_value = 16
	_width.max_value = 4096
	_width.value = 256
	res_row.add_child(_width)
	res_row.add_child(UiStyles.label("×", 11))
	_height = SpinBox.new()
	_height.min_value = 16
	_height.max_value = 4096
	_height.value = 256
	res_row.add_child(_height)
	_supersampling = OptionButton.new()
	_supersampling.add_item("1×")
	_supersampling.add_item("2×")
	_supersampling.add_item("4×")
	_supersampling.select(1)
	column.add_child(_supersampling)
	_destination = LineEdit.new()
	_destination.placeholder_text = "/game/assets/icons/"
	column.add_child(_destination)
	_transparent = CheckBox.new()
	_transparent.text = "Transparent"
	_transparent.button_pressed = true
	column.add_child(_transparent)
	_overwrite = CheckBox.new()
	_overwrite.text = "Overwrite existing"
	column.add_child(_overwrite)
	var export_btn: Button = Button.new()
	export_btn.text = "Export"
	export_btn.pressed.connect(_confirm)
	column.add_child(export_btn)

func open_at(anchor: Control, defaults: Dictionary = {}) -> void:
	if defaults.has("width"):
		_width.value = int(defaults["width"])
	if defaults.has("height"):
		_height.value = int(defaults["height"])
	if defaults.has("destination"):
		_destination.text = str(defaults["destination"])
	popup(Rect2i(Vector2i(anchor.global_position) + Vector2i(0, int(anchor.size.y)), Vector2i(340, 280)))

func _confirm() -> void:
	export_confirmed.emit({
		"width": int(_width.value),
		"height": int(_height.value),
		"supersampling": [1, 2, 4][_supersampling.selected],
		"destination": _destination.text.strip_edges(),
		"transparent": _transparent.button_pressed,
		"overwrite": _overwrite.button_pressed
	})
	hide()
