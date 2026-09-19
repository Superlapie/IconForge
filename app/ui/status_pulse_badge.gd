extends Control

const UiStyles = preload("res://app/ui/ui_styles.gd")

var label_text: String = "OFFLINE / DETERMINISTIC"
var pulse_color: Color = UiStyles.SUCCESS
var _dot: Control
var _phase: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 34)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_dot = Control.new()
	_dot.custom_minimum_size = Vector2(18, 18)
	_dot.draw.connect(_draw_dot)
	row.add_child(_dot)
	var label: Label = UiStyles.label("  " + label_text + "  ", 10, pulse_color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", UiStyles.pill(pulse_color))
	row.add_child(label)
	set_process(true)

func _process(delta: float) -> void:
	_phase += delta * 3.0
	if _dot != null:
		_dot.queue_redraw()

func _draw_dot() -> void:
	var center: Vector2 = _dot.size * 0.5
	var pulse: float = 0.35 + abs(sin(_phase)) * 0.45
	_dot.draw_circle(center, 5.0, Color(pulse_color, pulse))
	_dot.draw_arc(center, 8.0, 0.0, TAU, 24, Color(pulse_color, 0.35), 1.5, true)
