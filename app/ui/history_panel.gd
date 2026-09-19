extends VBoxContainer

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal restore_requested(index: int)

var _list: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	add_child(UiStyles.section_title("Render History"))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)

func set_entries(entries: Array) -> void:
	for child in _list.get_children():
		child.queue_free()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var row: Button = Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s  %s" % [str(entry.get("time", "")), str(entry.get("summary", ""))]
		row.pressed.connect(func() -> void: restore_requested.emit(index))
		_list.add_child(row)
	if entries.is_empty():
		_list.add_child(UiStyles.caption("No history yet."))
