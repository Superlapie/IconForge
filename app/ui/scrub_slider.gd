extends VBoxContainer

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal value_changed(value: float)
signal reset_requested

var property_key: String = ""
var minimum: float = 0.0
var maximum: float = 1.0
var step: float = 0.01
var suffix: String = ""
var _slider: HSlider
var _field: LineEdit
var _label: Label
var _override_dot: Button
var _updating: bool = false
var _overridden: bool = false

func _init(label_text: String, min_value: float, max_value: float, initial: float, step_value: float, value_suffix: String, key: String = "") -> void:
	property_key = key
	add_theme_constant_override("separation", 4)
	minimum = min_value
	maximum = max_value
	step = step_value
	suffix = value_suffix
	var heading: HBoxContainer = HBoxContainer.new()
	add_child(heading)
	_override_dot = Button.new()
	_override_dot.text = " "
	_override_dot.custom_minimum_size = Vector2(14, 14)
	_override_dot.focus_mode = Control.FOCUS_NONE
	_override_dot.add_theme_stylebox_override("normal", UiStyles.flat(Color("ffffff", 0.0), 2, false))
	_override_dot.pressed.connect(func() -> void: reset_requested.emit())
	heading.add_child(_override_dot)
	_label = UiStyles.label(label_text, 11, UiStyles.TEXT)
	heading.add_child(_label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	_field = LineEdit.new()
	_field.custom_minimum_size = Vector2(68, 26)
	_field.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_field.select_all_on_focus = true
	_field.text_submitted.connect(_on_text_submitted)
	_field.focus_exited.connect(_on_focus_exited)
	_field.gui_input.connect(_on_field_gui_input)
	heading.add_child(_field)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_slider = HSlider.new()
	_slider.min_value = minimum
	_slider.max_value = maximum
	_slider.step = step
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.custom_minimum_size = Vector2(0, 22)
	_slider.value_changed.connect(_on_slider_changed)
	row.add_child(_slider)
	set_value(initial, false)

func set_overridden(value: bool) -> void:
	_overridden = value
	_override_dot.text = "●" if value else " "
	_override_dot.add_theme_color_override("font_color", UiStyles.ACCENT if value else UiStyles.TERTIARY)
	_label.add_theme_color_override("font_color", UiStyles.ACCENT_HOT if value else UiStyles.TEXT)

func set_value(value: float, emit_signal: bool = true) -> void:
	_updating = true
	var clamped: float = clampf(value, minimum, maximum)
	_slider.value = clamped
	_field.text = _format(clamped)
	_updating = false
	if emit_signal:
		value_changed.emit(clamped)

func get_value() -> float:
	return _slider.value

func _on_slider_changed(value: float) -> void:
	if _updating:
		return
	_field.text = _format(value)
	value_changed.emit(value)

func _on_text_submitted(text: String) -> void:
	_apply_text(text)

func _on_focus_exited() -> void:
	_apply_text(_field.text)

func _apply_text(text: String) -> void:
	var cleaned: String = text.strip_edges()
	if suffix == "°":
		cleaned = cleaned.trim_suffix("°").strip_edges()
	elif suffix == "×":
		cleaned = cleaned.trim_suffix("×").strip_edges()
	elif suffix == "%":
		cleaned = cleaned.trim_suffix("%").strip_edges()
	if not String(cleaned).is_valid_float():
		_field.text = _format(_slider.value)
		return
	var parsed: float = float(cleaned)
	if suffix == "%":
		parsed /= 100.0
	set_value(parsed)

func _on_field_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and button.double_click:
			reset_requested.emit()
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var delta: float = motion.relative.x * step * 0.35
			if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_ALT):
				delta *= 0.15
			set_value(_slider.value + delta)

func _format(value: float) -> String:
	if suffix == "%":
		return "%d%%" % int(round(value * 100.0))
	if suffix == "×":
		return "%.2f×" % value
	if suffix == "°":
		return "%d°" % int(round(value))
	return str(snapped(value, step))
