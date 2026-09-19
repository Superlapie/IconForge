extends Control

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal mode_changed(mode: String)
signal guides_toggled(enabled: bool)
signal checker_changed(mode: String)
signal frame_requested
signal reset_requested
signal compare_toggled(enabled: bool)
signal preview_quality_changed(mode: String)
signal snapshot_requested(slot: String)
signal maximize_requested

const VIEW_MODES: Array[String] = ["lit", "alpha", "normal"]
const CHECKER_MODES: Array[String] = ["checker", "dark", "light", "split"]
const PREVIEW_QUALITIES: Array[String] = ["fast", "full", "export"]

var active_mode: String = "lit"
var checker_mode: String = "checker"
var preview_quality: String = "full"
var guides_enabled: bool = false
var compare_enabled: bool = false
var _buttons: Dictionary = {}
var _checker_button: MenuButton
var _quality_button: MenuButton

func _ready() -> void:
	custom_minimum_size = Vector2(0, 32)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	row.add_child(_tool_button("Orbit", true))
	var frame_btn: Button = _tool_button("Frame")
	frame_btn.pressed.connect(func() -> void: frame_requested.emit())
	row.add_child(frame_btn)
	var reset_btn: Button = _tool_button("Reset")
	reset_btn.pressed.connect(func() -> void: reset_requested.emit())
	row.add_child(reset_btn)
	row.add_child(_separator())
	_checker_button = MenuButton.new()
	_checker_button.text = "Checker"
	_checker_button.custom_minimum_size = Vector2(0, 26)
	var checker_menu: PopupMenu = _checker_button.get_popup()
	for index in CHECKER_MODES.size():
		checker_menu.add_item(CHECKER_MODES[index].capitalize(), index)
	checker_menu.id_pressed.connect(_on_checker_selected)
	row.add_child(_checker_button)
	var guides_btn: Button = _tool_button("Guides")
	guides_btn.toggle_mode = true
	guides_btn.toggled.connect(func(enabled: bool) -> void:
		guides_enabled = enabled
		guides_toggled.emit(enabled)
	)
	row.add_child(guides_btn)
	var compare_btn: Button = _tool_button("Compare")
	compare_btn.toggle_mode = true
	compare_btn.toggled.connect(func(enabled: bool) -> void:
		compare_enabled = enabled
		compare_toggled.emit(enabled)
	)
	row.add_child(compare_btn)
	row.add_child(_separator())
	_quality_button = MenuButton.new()
	_quality_button.text = "Preview: Full"
	_quality_button.custom_minimum_size = Vector2(0, 26)
	var quality_menu: PopupMenu = _quality_button.get_popup()
	for index in PREVIEW_QUALITIES.size():
		quality_menu.add_item(PREVIEW_QUALITIES[index].capitalize(), index)
	quality_menu.id_pressed.connect(_on_quality_selected)
	row.add_child(_quality_button)
	for mode_name in VIEW_MODES:
		var button: Button = _tool_button(mode_name.capitalize())
		button.toggle_mode = true
		button.pressed.connect(_on_mode_pressed.bind(mode_name))
		row.add_child(button)
		_buttons[mode_name] = button
	row.add_child(_separator())
	var snap_a: Button = _tool_button("A")
	snap_a.pressed.connect(func() -> void: snapshot_requested.emit("A"))
	row.add_child(snap_a)
	var snap_b: Button = _tool_button("B")
	snap_b.pressed.connect(func() -> void: snapshot_requested.emit("B"))
	row.add_child(snap_b)
	var max_btn: Button = _tool_button("Max")
	max_btn.pressed.connect(func() -> void: maximize_requested.emit())
	row.add_child(max_btn)
	_set_active("lit")

func _tool_button(text: String, active: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 26)
	button.add_theme_stylebox_override("normal", UiStyles.toolbar_button(active))
	button.add_theme_stylebox_override("hover", UiStyles.toolbar_button(active))
	button.add_theme_stylebox_override("pressed", UiStyles.toolbar_button(active))
	return button

func _separator() -> Control:
	var sep: ColorRect = ColorRect.new()
	sep.custom_minimum_size = Vector2(1, 18)
	sep.color = UiStyles.SEPARATOR
	return sep

func _on_mode_pressed(mode_name: String) -> void:
	_set_active(mode_name)
	mode_changed.emit(mode_name)

func _on_checker_selected(id: int) -> void:
	if id < 0 or id >= CHECKER_MODES.size():
		return
	checker_mode = CHECKER_MODES[id]
	_checker_button.text = checker_mode.capitalize()
	checker_changed.emit(checker_mode)

func _on_quality_selected(id: int) -> void:
	if id < 0 or id >= PREVIEW_QUALITIES.size():
		return
	preview_quality = PREVIEW_QUALITIES[id]
	_quality_button.text = "Preview: %s" % preview_quality.capitalize()
	preview_quality_changed.emit(preview_quality)

func _set_active(mode_name: String) -> void:
	active_mode = mode_name
	for key in _buttons.keys():
		var button: Button = _buttons[key]
		var active: bool = key == mode_name
		button.button_pressed = active
		button.add_theme_stylebox_override("normal", UiStyles.toolbar_button(active))
		button.add_theme_stylebox_override("hover", UiStyles.toolbar_button(active))
		button.add_theme_stylebox_override("pressed", UiStyles.toolbar_button(active))
