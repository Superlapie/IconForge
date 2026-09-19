extends Control
class_name Checkerboard

@export var cell_size: int = 16
@export var light_color: Color = Color("1A1C20")
@export var dark_color: Color = Color("121418")

var display_mode: String = "checker"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_display_mode(mode: String) -> void:
	display_mode = mode
	queue_redraw()

func _draw() -> void:
	match display_mode:
		"dark":
			draw_rect(Rect2(Vector2.ZERO, size), Color("0A0B0D"), true)
		"light":
			draw_rect(Rect2(Vector2.ZERO, size), Color("D8DADF"), true)
		"split":
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * 0.5, size.y)), Color("0A0B0D"), true)
			draw_rect(Rect2(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y)), Color("D8DADF"), true)
		_:
			var columns: int = ceili(size.x / float(cell_size))
			var rows: int = ceili(size.y / float(cell_size))
			for y in rows:
				for x in columns:
					var color: Color = light_color if (x + y) % 2 == 0 else dark_color
					draw_rect(Rect2(x * cell_size, y * cell_size, cell_size, cell_size), color)
