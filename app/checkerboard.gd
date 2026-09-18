extends Control
class_name Checkerboard

@export var cell_size: int = 18
@export var light_color: Color = Color("151d32")
@export var dark_color: Color = Color("101629")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var columns: int = ceili(size.x / float(cell_size))
	var rows: int = ceili(size.y / float(cell_size))
	for y in rows:
		for x in columns:
			var color: Color = light_color if (x + y) % 2 == 0 else dark_color
			draw_rect(Rect2(x * cell_size, y * cell_size, cell_size, cell_size), color)

