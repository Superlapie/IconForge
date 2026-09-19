extends Control

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal open_files_requested
signal try_samples_requested
signal recent_selected(path: String)

var _drop_zone: PanelContainer
var _recent_box: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var spacer_top: Control = Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer_top)
	var title: Label = UiStyles.heading("Icon Forge", 17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var tagline: Label = UiStyles.label("Turn assets into game-ready imagery.", 13, UiStyles.MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	column.add_child(Control.new())
	_drop_zone = PanelContainer.new()
	_drop_zone.custom_minimum_size = Vector2(360, 120)
	_drop_zone.add_theme_stylebox_override("panel", UiStyles.inset(6))
	column.add_child(_drop_zone)
	var drop_margin: MarginContainer = MarginContainer.new()
	drop_margin.add_theme_constant_override("margin_left", 24)
	drop_margin.add_theme_constant_override("margin_right", 24)
	drop_margin.add_theme_constant_override("margin_top", 20)
	drop_margin.add_theme_constant_override("margin_bottom", 20)
	_drop_zone.add_child(drop_margin)
	var drop_col: VBoxContainer = VBoxContainer.new()
	drop_col.add_theme_constant_override("separation", 6)
	drop_col.alignment = BoxContainer.ALIGNMENT_CENTER
	drop_margin.add_child(drop_col)
	var drop_title: Label = UiStyles.label("Drop assets here", 14, UiStyles.TEXT)
	drop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop_col.add_child(drop_title)
	var formats: Label = UiStyles.caption("GLB · glTF · PNG · JPEG · WebP")
	formats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop_col.add_child(formats)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	var open_btn: Button = Button.new()
	open_btn.text = "Open Files"
	open_btn.custom_minimum_size = Vector2(120, UiStyles.ROW_HEIGHT)
	open_btn.pressed.connect(func() -> void: open_files_requested.emit())
	actions.add_child(open_btn)
	var samples_btn: Button = Button.new()
	samples_btn.text = "Try Samples"
	samples_btn.custom_minimum_size = Vector2(120, UiStyles.ROW_HEIGHT)
	samples_btn.pressed.connect(func() -> void: try_samples_requested.emit())
	actions.add_child(samples_btn)
	_recent_box = VBoxContainer.new()
	_recent_box.add_theme_constant_override("separation", 4)
	column.add_child(_recent_box)
	var spacer_bottom: Control = Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer_bottom)

func set_recent_files(paths: Array) -> void:
	for child in _recent_box.get_children():
		child.queue_free()
	if paths.is_empty():
		return
	_recent_box.add_child(UiStyles.caption("Recent"))
	for path in paths.slice(0, 5):
		var btn: Button = Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = str(path).get_file()
		btn.pressed.connect(func() -> void: recent_selected.emit(str(path)))
		_recent_box.add_child(btn)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _has_supported_files(data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("files"):
		get_viewport().gui_release_focus()

func _has_supported_files(data: Variant) -> bool:
	if not (data is Dictionary) or not data.has("files"):
		return false
	for raw_path in data["files"]:
		var path: String = str(raw_path)
		if path.begins_with("file://"):
			path = path.trim_prefix("file://").uri_decode()
		if FileAccess.file_exists(path) and IconForgeFileUtil.is_supported_source(path):
			return true
	return false
