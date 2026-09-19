extends VBoxContainer

const UiStyles = preload("res://app/ui/ui_styles.gd")

func _ready() -> void:
	add_theme_constant_override("separation", 4)

func set_lines(lines: PackedStringArray) -> void:
	for child in get_children():
		child.queue_free()
	if lines.is_empty():
		add_child(UiStyles.caption("No log entries."))
		return
	for line in lines.slice(0, 20):
		add_child(UiStyles.label(line, 10, UiStyles.TERTIARY))
