extends Control

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal lighting_changed(light_type: String, angle: Vector3)

var lighting: Dictionary = {}
var _dragging_type: String = ""
var _drag_origin: Vector2 = Vector2.ZERO
var _drag_start_angle: Vector3 = Vector3.ZERO
var _wheel: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_wheel = Control.new()
	_wheel.name = "LightingWheel"
	_wheel.mouse_filter = Control.MOUSE_FILTER_STOP
	_wheel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wheel.offset_left = -144
	_wheel.offset_top = 8
	_wheel.offset_right = -8
	_wheel.offset_bottom = 152
	_wheel.gui_input.connect(_on_wheel_input)
	add_child(_wheel)

func set_lighting(data: Dictionary) -> void:
	lighting = data.duplicate(true)
	queue_redraw()

func get_resolved_lighting() -> Dictionary:
	return lighting

func _process(_delta: float) -> void:
	queue_redraw()

func _on_wheel_input(event: InputEvent) -> void:
	if lighting.is_empty():
		return
	var origin: Vector2 = _wheel_origin()
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				var picked: String = _pick_handle(origin, button.position)
				if picked.is_empty():
					return
				_dragging_type = picked
				_drag_origin = button.position
				_drag_start_angle = _light_angle(picked)
				_wheel.accept_event()
			elif not button.pressed and not _dragging_type.is_empty():
				_dragging_type = ""
				_wheel.accept_event()
	elif event is InputEventMouseMotion and not _dragging_type.is_empty():
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var delta: Vector2 = motion.position - _drag_origin
		var next_angle: Vector3 = _drag_start_angle + Vector3(-delta.y * 0.35, delta.x * 0.35, 0.0)
		next_angle.x = clampf(next_angle.x, -85.0, 85.0)
		next_angle.y = fmod(next_angle.y + 180.0, 360.0) - 180.0
		if not lighting.has(_dragging_type):
			lighting[_dragging_type] = {}
		lighting[_dragging_type]["angle"] = [next_angle.x, next_angle.y, next_angle.z]
		lighting_changed.emit(_dragging_type, next_angle)
		queue_redraw()
		_wheel.accept_event()

func _wheel_origin() -> Vector2:
	return Vector2(_wheel.size.x - 64, 64)

func _pick_handle(origin: Vector2, at: Vector2) -> String:
	for type in ["key", "fill", "rim"]:
		var handle: Vector2 = origin + _light_direction(type) * 24.0
		if handle.distance_to(at) <= 10.0:
			return type
	return ""

func _light_angle(type: String) -> Vector3:
	return _array_to_vector(lighting.get(type, {}).get("angle", [0.0, 0.0, 0.0]))

func _light_direction(type: String) -> Vector2:
	var angle: Vector3 = _light_angle(type)
	return Vector2(angle.y, -angle.x).normalized()

func _draw() -> void:
	if lighting.is_empty() or _wheel == null:
		return
	var origin: Vector2 = _wheel.position + _wheel_origin()
	draw_circle(origin, 28.0, Color("ffffff", 0.04))
	draw_arc(origin, 28.0, 0.0, TAU, 48, Color("ffffff", 0.10), 1.0, true)
	draw_circle(origin, 4.0, UiStyles.ACCENT)
	for type in ["key", "fill", "rim"]:
		var dir: Vector2 = _light_direction(type) * 24.0
		var color: Color = UiStyles.ACCENT if type == "key" else (UiStyles.SUCCESS if type == "fill" else UiStyles.AXIS_Z)
		draw_line(origin, origin + dir, Color(color, 0.85), 2.0, true)
		draw_circle(origin + dir, 5.0, color)
		draw_string(ThemeDB.fallback_font, origin + dir + Vector2(4, -4), type.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiStyles.MUTED)

func _array_to_vector(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
