extends Control
class_name PreviewCanvas

signal orbit_changed(delta: Vector2)
signal zoom_changed(delta: float)

var _dragging: bool = false
var _last_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_DRAG

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			_last_position = button.position
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_changed.emit(0.025)
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_changed.emit(-0.025)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var delta: Vector2 = motion.position - _last_position
		_last_position = motion.position
		orbit_changed.emit(delta)
		accept_event()

