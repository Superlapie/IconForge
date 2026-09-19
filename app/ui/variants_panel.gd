extends VBoxContainer

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal variant_selected(index: int)
signal variant_saved(index: int)

var _list: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	add_child(UiStyles.section_title("Variants"))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)

func set_variants(entries: Array) -> void:
	for child in _list.get_children():
		child.queue_free()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_list.add_child(row)
		var btn: Button = Button.new()
		btn.text = "%s  %s" % [str(entry.get("id", "?")), str(entry.get("name", ""))]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: variant_selected.emit(index))
		row.add_child(btn)
		var save: Button = Button.new()
		save.text = "★"
		save.custom_minimum_size = Vector2(28, 24)
		save.pressed.connect(func() -> void: variant_saved.emit(index))
		row.add_child(save)
