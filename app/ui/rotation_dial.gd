extends Control

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal value_changed(value: float)
signal reset_requested

var property_key: String = ""
var minimum: float = -180.0
var maximum: float = 180.0
var step: float = 1.0
var label_text: String = "Yaw"
var _value: float = 0.0
var _dragging: bool = false
var _field: LineEdit
var _slider: HSlider
var _dial_host: Control
var _override_dot: Button

func _init(title: String, min_value: float, max_value: float, initial: float, step_value: float = 1.0, key: String = "") -> void:
	label_text = title
	property_key = key
	minimum = min_value
	maximum = max_value
	step = step_value
	custom_minimum_size = Vector2(0, 72)
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var heading: HBoxContainer = HBoxContainer.new()
	column.add_child(heading)
	_override_dot = Button.new()
	_override_dot.text = " "
	_override_dot.custom_minimum_size = Vector2(14, 14)
	_override_dot.focus_mode = Control.FOCUS_NONE
	_override_dot.add_theme_stylebox_override("normal", UiStyles.flat(Color("ffffff", 0.0), 2, false))
	_override_dot.pressed.connect(func() -> void: reset_requested.emit())
	heading.add_child(_override_dot)
	var title_label: Label = UiStyles.label(title, 11, UiStyles.TEXT)
	heading.add_child(title_label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	_field = LineEdit.new()
	_field.custom_minimum_size = Vector2(68, 26)
	_field.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_field.text_submitted.connect(_on_text_submitted)
	_field.focus_exited.connect(_on_focus_exited)
	_field.gui_input.connect(_on_field_gui_input)
	heading.add_child(_field)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	_dial_host = Control.new()
	_dial_host.custom_minimum_size = Vector2(52, 52)
	_dial_host.gui_input.connect(_on_dial_input)
	_dial_host.draw.connect(_draw_dial)
	row.add_child(_dial_host)
	_slider = HSlider.new()
	_slider.min_value = minimum
	_slider.max_value = maximum
	_slider.step = step
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.value_changed.connect(func(value: float) -> void: set_value(value, true, false))
	row.add_child(_slider)
	set_value(initial, false, false)

func set_overridden(value: bool) -> void:
	_override_dot.text = "●" if value else " "
	_override_dot.add_theme_color_override("font_color", UiStyles.ACCENT if value else UiStyles.TERTIARY)

func set_value(value: float, emit_signal: bool = true, sync_slider: bool = true) -> void:
	_value = clampf(value, minimum, maximum)
	_field.text = "%d°" % int(round(_value))
	if sync_slider:
		_slider.set_value_no_signal(_value)
	if _dial_host != null:
		_dial_host.queue_redraw()
	if emit_signal:
		value_changed.emit(_value)

func get_value() -> float:
	return _value

func _on_text_submitted(text: String) -> void:
	_apply_text(text)

func _on_focus_exited() -> void:
	_apply_text(_field.text)

func _apply_text(text: String) -> void:
	var cleaned: String = text.strip_edges().trim_suffix("°").strip_edges()
	if not cleaned.is_valid_float():
		_field.text = "%d°" % int(round(_value))
		return
	set_value(float(cleaned))

func _on_field_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and button.double_click:
			reset_requested.emit()
			accept_event()

func _on_dial_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			if _dragging:
				_apply_dial_delta(button.position)
	elif event is InputEventMouseMotion and _dragging:
		_apply_dial_delta((event as InputEventMouseMotion).position)

func _apply_dial_delta(local_pos: Vector2) -> void:
	var center: Vector2 = _dial_host.size * 0.5
	var degrees: float = rad_to_deg((local_pos - center).angle())
	set_value(snapped(degrees, step))

func _draw_dial() -> void:
	var center: Vector2 = _dial_host.size * 0.5
	var radius: float = minf(_dial_host.size.x, _dial_host.size.y) * 0.38
	_dial_host.draw_arc(center, radius, 0.0, TAU, 48, Color("ffffff", 0.10), 1.5, true)
	var needle: float = deg_to_rad(_value)
	var tip: Vector2 = center + Vector2(cos(needle), sin(needle)) * radius
	_dial_host.draw_line(center, tip, UiStyles.ACCENT, 2.0, true)
	_dial_host.draw_circle(center, 3.0, UiStyles.ACCENT)
