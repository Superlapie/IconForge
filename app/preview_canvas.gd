extends Control
class_name PreviewCanvas

signal orbit_changed(delta: Vector2)
signal zoom_changed(delta: float)
signal interaction_started
signal interaction_ended

var _dragging: bool = false
var _last_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_DRAG

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and not _dragging:
				_dragging = true
				_last_position = button.position
				interaction_started.emit()
			elif not button.pressed and _dragging:
				_dragging = false
				interaction_ended.emit()
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_changed.emit(1.0)
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_changed.emit(-1.0)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var delta: Vector2 = motion.relative
		if delta.length_squared() > 0.0:
			orbit_changed.emit(delta)
		accept_event()
