extends HBoxContainer

const UiStyles = preload("res://app/ui/ui_styles.gd")

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_add_badge("Auto-frame", UiStyles.SUCCESS)
	_add_badge("Alpha", UiStyles.ACCENT)
	_add_badge("Occupancy", UiStyles.WARNING)
	_add_badge("PNG export", UiStyles.TEXT)

func _add_badge(text: String, color: Color) -> void:
	var badge: PanelContainer = PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiStyles.pill(color))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	badge.add_child(row)
	var dot: ColorRect = ColorRect.new()
	dot.custom_minimum_size = Vector2(7, 7)
	dot.color = color
	row.add_child(dot)
	row.add_child(UiStyles.label(text, 10, color))
