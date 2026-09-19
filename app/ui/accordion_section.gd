extends VBoxContainer

const UiMotionScript = preload("res://app/ui/ui_motion.gd")
const UiStyles = preload("res://app/ui/ui_styles.gd")

signal toggled(expanded: bool)

var expanded: bool = true
var modified: bool = false
var _header: Button
var _caret: Label
var _title: Label
var _modified_dot: Label
var _body: VBoxContainer

func _init(title: String, start_expanded: bool = true) -> void:
	add_theme_constant_override("separation", 4)
	expanded = start_expanded
	_header = Button.new()
	_header.custom_minimum_size = Vector2(0, 26)
	_header.focus_mode = Control.FOCUS_NONE
	_header.add_theme_stylebox_override("normal", UiStyles.flat(Color("ffffff", 0.0), 0, false))
	_header.add_theme_stylebox_override("hover", UiStyles.flat(Color("ffffff", 0.03), 0, false))
	_header.add_theme_stylebox_override("pressed", UiStyles.flat(Color("ffffff", 0.05), 0, false))
	_header.pressed.connect(_on_toggle)
	add_child(_header)
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	header_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(header_row)
	_caret = UiStyles.label("▼", 10, UiStyles.TERTIARY)
	header_row.add_child(_caret)
	_title = UiStyles.label(title, 12, UiStyles.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_title)
	_modified_dot = UiStyles.label("", 10, UiStyles.ACCENT)
	header_row.add_child(_modified_dot)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", UiStyles.PROPERTY_GAP)
	_body.visible = expanded
	add_child(_body)
	_refresh_caret()

func get_body() -> VBoxContainer:
	return _body

func set_modified(value: bool) -> void:
	modified = value
	_modified_dot.text = "●" if modified else ""

func set_expanded(value: bool) -> void:
	expanded = value
	_body.visible = expanded
	_refresh_caret()
	if is_inside_tree():
		UiMotionScript.tween_property(_body, "modulate:a", 1.0 if expanded else 0.0, 0.16)
	toggled.emit(expanded)

func _on_toggle() -> void:
	set_expanded(not expanded)

func _refresh_caret() -> void:
	_caret.text = "▼" if expanded else "▶"
