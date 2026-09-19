extends Button

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal preset_selected(preset_id: String)
signal compare_requested

var _popup: PopupPanel
var _preset_service: PresetService
var _active_id: String = ""

func setup(preset_service: PresetService) -> void:
	_preset_service = preset_service
	text = "Inventory Item"
	custom_minimum_size = Vector2(0, UiStyles.ROW_HEIGHT)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not pressed.is_connected(_toggle_popup):
		pressed.connect(_toggle_popup)
	_build_popup()

func set_active_preset(preset_id: String, display_name: String) -> void:
	_active_id = preset_id
	text = display_name

func _build_popup() -> void:
	if _popup != null:
		_popup.queue_free()
	_popup = PopupPanel.new()
	_popup.add_theme_stylebox_override("panel", UiStyles.flat(UiStyles.RAISED, 6, false))
	add_child(_popup)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_popup.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(320, 0)
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(UiStyles.section_title("Presets"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for entry in _preset_service.list_presets():
		var card: Button = Button.new()
		card.custom_minimum_size = Vector2(96, 72)
		card.text = str(entry.get("display_name", entry.get("id", "")))
		card.pressed.connect(_select_preset.bind(str(entry.get("id", ""))))
		grid.add_child(card)
	var compare_btn: Button = Button.new()
	compare_btn.text = "Compare Presets…"
	compare_btn.pressed.connect(func() -> void:
		_popup.hide()
		compare_requested.emit()
	)
	column.add_child(compare_btn)

func _toggle_popup() -> void:
	if _popup == null:
		return
	if _popup.visible:
		_popup.hide()
	else:
		_popup.popup(Rect2i(Vector2i(global_position) + Vector2i(0, int(size.y)), Vector2i(340, 300)))

func _select_preset(preset_id: String) -> void:
	_active_id = preset_id
	var preset: PresetDefinition = _preset_service.get_preset(preset_id)
	if preset != null:
		text = preset.get_display_name()
	_popup.hide()
	preset_selected.emit(preset_id)
