extends Control

const UiStyles = preload("res://app/ui/ui_styles.gd")

var compare_mode: String = "off"
var split_ratio: float = 0.5
var texture_a: Texture2D
var texture_b: Texture2D
var _dragging: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func set_textures(a: Texture2D, b: Texture2D) -> void:
	texture_a = a
	texture_b = b
	queue_redraw()

func set_mode(mode: String) -> void:
	compare_mode = mode
	visible = mode != "off"
	mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if compare_mode != "split":
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
	elif event is InputEventMouseMotion and _dragging:
		split_ratio = clampf((event as InputEventMouseMotion).position.x / maxf(size.x, 1.0), 0.1, 0.9)
		queue_redraw()

func _draw() -> void:
	if compare_mode == "off":
		return
	if texture_a == null and texture_b == null:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if compare_mode == "hold_b" and texture_b != null:
		draw_texture_rect(texture_b, rect, false)
		return
	if compare_mode == "split" and texture_a != null and texture_b != null:
		var split_x: float = size.x * split_ratio
		draw_texture_rect(texture_a, Rect2(Vector2.ZERO, Vector2(split_x, size.y)), false)
		draw_texture_rect(texture_b, Rect2(Vector2(split_x, 0), Vector2(size.x - split_x, size.y)), false)
		draw_line(Vector2(split_x, 0), Vector2(split_x, size.y), UiStyles.ACCENT, 2.0, true)
		return
	if texture_a != null:
		draw_texture_rect(texture_a, rect, false)
