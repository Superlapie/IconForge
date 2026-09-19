extends Control

const UiStyles = preload("res://app/ui/ui_styles.gd")
const UiMotionScript = preload("res://app/ui/ui_motion.gd")

signal tab_selected(tab_name: String)

var expanded: bool = false
var _summary: Label
var _drawer: VBoxContainer
var _tabs: HBoxContainer
var _content: Control
var _active_tab: String = "quality"
var _expand_button: Button
var _tab_buttons: Dictionary = {}
var _tab_contents: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(0, 28)
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiStyles.flat(UiStyles.RAISED, 0, false))
	bar.custom_minimum_size = Vector2(0, 28)
	column.add_child(bar)
	var bar_margin: MarginContainer = MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", 12)
	bar_margin.add_theme_constant_override("margin_right", 12)
	bar_margin.add_theme_constant_override("margin_top", 5)
	bar_margin.add_theme_constant_override("margin_bottom", 5)
	bar.add_child(bar_margin)
	var bar_row: HBoxContainer = HBoxContainer.new()
	bar_margin.add_child(bar_row)
	_summary = UiStyles.label("Ready", 11, UiStyles.MUTED)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar_row.add_child(_summary)
	_expand_button = Button.new()
	_expand_button.text = "▴"
	_expand_button.focus_mode = Control.FOCUS_NONE
	_expand_button.custom_minimum_size = Vector2(24, 18)
	_expand_button.pressed.connect(_toggle_expanded)
	bar_row.add_child(_expand_button)
	_drawer = VBoxContainer.new()
	_drawer.visible = false
	column.add_child(_drawer)
	var sep: ColorRect = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = UiStyles.SEPARATOR
	_drawer.add_child(sep)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 0)
	_drawer.add_child(_tabs)
	for tab_name in ["Variants", "History", "Quality", "Batch", "Log"]:
		var tab_btn: Button = Button.new()
		tab_btn.text = tab_name
		tab_btn.focus_mode = Control.FOCUS_NONE
		tab_btn.custom_minimum_size = Vector2(0, 26)
		var tab_id: String = tab_name.to_lower()
		tab_btn.pressed.connect(_select_tab.bind(tab_id))
		_tabs.add_child(tab_btn)
		_tab_buttons[tab_id] = tab_btn
	_content = Control.new()
	_content.custom_minimum_size = Vector2(0, 140)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drawer.add_child(_content)

func register_tab(tab_name: String, node: Control) -> void:
	_tab_contents[tab_name] = node
	node.visible = false
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(node)
	if tab_name == _active_tab:
		_show_tab(tab_name)

func set_summary(text: String) -> void:
	_summary.text = text

func expand_tab(tab_name: String) -> void:
	_select_tab(tab_name)
	if not expanded:
		_toggle_expanded()

func _toggle_expanded() -> void:
	expanded = not expanded
	_drawer.visible = expanded
	_expand_button.text = "▾" if expanded else "▴"
	var target_height: float = 28.0 if not expanded else 180.0
	UiMotionScript.tween_minimum_height(self, target_height)
	if expanded:
		_show_tab(_active_tab)

func _select_tab(tab_name: String) -> void:
	_active_tab = tab_name
	for key in _tab_buttons.keys():
		var btn: Button = _tab_buttons[key]
		btn.add_theme_color_override("font_color", UiStyles.ACCENT_HOT if key == tab_name else UiStyles.MUTED)
	_show_tab(tab_name)
	tab_selected.emit(tab_name)

func _show_tab(tab_name: String) -> void:
	for key in _tab_contents.keys():
		var node: Control = _tab_contents[key]
		node.visible = key == tab_name
