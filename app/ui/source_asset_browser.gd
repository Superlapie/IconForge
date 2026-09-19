extends Control

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal source_selected(index: int)
signal source_context_menu(index: int, position: Vector2)

enum ViewMode { LIST, GRID }

var view_mode: ViewMode = ViewMode.LIST
var selected_index: int = -1
var _scroll: ScrollContainer
var _list_box: VBoxContainer
var _grid_box: GridContainer
var _search: LineEdit
var _mode_button: Button
var _entries: Array[Dictionary] = []
var _thumbnails: Dictionary = {}
var _quality: Dictionary = {}
var _filter: String = ""

func _ready() -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)
	header.add_child(UiStyles.section_title("Assets"))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_mode_button = Button.new()
	_mode_button.text = "▦"
	_mode_button.tooltip_text = "Toggle grid view"
	_mode_button.custom_minimum_size = Vector2(28, 24)
	_mode_button.pressed.connect(_toggle_mode)
	header.add_child(_mode_button)
	_search = LineEdit.new()
	_search.placeholder_text = "Search assets…"
	_search.custom_minimum_size = Vector2(0, 26)
	_search.text_changed.connect(func(text: String) -> void:
		_filter = text.strip_edges().to_lower()
		_rebuild()
	)
	column.add_child(_search)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 4)
	_grid_box = GridContainer.new()
	_grid_box.columns = 2
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_box.add_theme_constant_override("h_separation", 6)
	_grid_box.add_theme_constant_override("v_separation", 6)
	_scroll.add_child(_list_box)

func add_source(path: String) -> void:
	var entry: Dictionary = {
		"path": path,
		"name": IconStudioFileUtil.source_name(path),
		"extension": path.get_extension().to_upper(),
		"kind": _kind_for_path(path)
	}
	_entries.append(entry)
	_rebuild()

func clear_sources() -> void:
	_entries.clear()
	_thumbnails.clear()
	_quality.clear()
	selected_index = -1
	_rebuild()

func select_index(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	selected_index = index
	_rebuild()
	source_selected.emit(index)

func set_thumbnail(path: String, texture: Texture2D) -> void:
	_thumbnails[path] = texture
	_rebuild()

func set_quality(path: String, ok: bool, occupancy: float = -1.0) -> void:
	_quality[path] = {"ok": ok, "occupancy": occupancy}
	_rebuild()

func get_entry_count() -> int:
	return _entries.size()

func _kind_for_path(path: String) -> String:
	var ext: String = path.get_extension().to_lower()
	if ext in ["glb", "gltf"]:
		return "3D"
	return "Image"

func _toggle_mode() -> void:
	view_mode = ViewMode.GRID if view_mode == ViewMode.LIST else ViewMode.LIST
	_mode_button.text = "☷" if view_mode == ViewMode.GRID else "▦"
	_rebuild()

func _filtered_indices() -> Array[int]:
	var indices: Array[int] = []
	for index in _entries.size():
		var entry: Dictionary = _entries[index]
		if _filter.is_empty():
			indices.append(index)
			continue
		var haystack: String = "%s %s %s" % [entry.get("name", ""), entry.get("extension", ""), entry.get("kind", "")]
		if haystack.to_lower().contains(_filter):
			indices.append(index)
	return indices

func _rebuild() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	for child in _grid_box.get_children():
		child.queue_free()
	if _scroll.get_child_count() > 0:
		_scroll.remove_child(_scroll.get_child(0))
	var host: Control = _grid_box if view_mode == ViewMode.GRID else _list_box
	_scroll.add_child(host)
	for index in _filtered_indices():
		var entry: Dictionary = _entries[index]
		var item: Control = _build_grid_item(entry, index) if view_mode == ViewMode.GRID else _build_list_item(entry, index)
		host.add_child(item)

func _build_list_item(entry: Dictionary, index: int) -> Control:
	var selected: bool = index == selected_index
	var row: Button = Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, 52)
	row.add_theme_stylebox_override("normal", UiStyles.flat(Color(UiStyles.ACCENT, 0.10) if selected else Color("ffffff", 0.02), 4, false))
	row.add_theme_stylebox_override("hover", UiStyles.flat(UiStyles.HOVER, 4, false))
	row.add_theme_stylebox_override("pressed", UiStyles.flat(Color(UiStyles.ACCENT, 0.12), 4, false))
	row.pressed.connect(func() -> void: select_index(index))
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			source_context_menu.emit(index, (event as InputEventMouseButton).global_position)
	)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(margin)
	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)
	var thumb: TextureRect = _thumbnail(entry)
	thumb.custom_minimum_size = Vector2(40, 40)
	content.add_child(thumb)
	var text_col: VBoxContainer = VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(text_col)
	var name_label: Label = UiStyles.label(str(entry.get("name", "")), 12, UiStyles.TEXT if selected else UiStyles.MUTED)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(name_label)
	var meta_row: HBoxContainer = HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 6)
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(meta_row)
	meta_row.add_child(UiStyles.caption(str(entry.get("kind", ""))))
	meta_row.add_child(_quality_badge(str(entry.get("path", ""))))
	return row

func _build_grid_item(entry: Dictionary, index: int) -> Control:
	var selected: bool = index == selected_index
	var card: Button = Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(108, 108)
	card.add_theme_stylebox_override("normal", UiStyles.flat(Color(UiStyles.ACCENT, 0.10) if selected else Color("ffffff", 0.02), 4, false))
	card.add_theme_stylebox_override("hover", UiStyles.flat(UiStyles.HOVER, 4, false))
	card.add_theme_stylebox_override("pressed", UiStyles.flat(Color(UiStyles.ACCENT, 0.12), 4, false))
	card.pressed.connect(func() -> void: select_index(index))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var thumb: TextureRect = _thumbnail(entry)
	thumb.custom_minimum_size = Vector2(92, 64)
	column.add_child(thumb)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	var name_label: Label = UiStyles.label(str(entry.get("name", "")), 10, UiStyles.TEXT if selected else UiStyles.MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(name_label)
	footer.add_child(_quality_badge(str(entry.get("path", ""))))
	return card

func _quality_badge(path: String) -> Label:
	var badge: Label = UiStyles.caption("·")
	if _quality.has(path):
		var info: Dictionary = _quality[path]
		if bool(info.get("ok", false)):
			badge.text = "✓"
			badge.add_theme_color_override("font_color", UiStyles.SUCCESS)
		else:
			badge.text = "⚠"
			badge.add_theme_color_override("font_color", UiStyles.WARNING)
	return badge

func _thumbnail(entry: Dictionary) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = str(entry.get("path", ""))
	if _thumbnails.has(path):
		rect.texture = _thumbnails[path]
	else:
		rect.texture = _placeholder_texture(str(entry.get("extension", "")))
	return rect

func _placeholder_texture(extension: String) -> ImageTexture:
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color("ffffff", 0.025))
	var accent: Color = UiStyles.ACCENT if extension in ["GLB", "GLTF"] else UiStyles.SUCCESS
	for y in range(18, 46):
		for x in range(18, 46):
			if (x + y) % 5 == 0:
				image.set_pixel(x, y, Color(accent, 0.22))
	return ImageTexture.create_from_image(image)
