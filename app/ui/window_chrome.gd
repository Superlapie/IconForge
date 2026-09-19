extends Control
class_name WindowChrome

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal close_requested

static func enabled() -> bool:
	return (
		(OS.has_environment("ICONFORGE_CUSTOM_CHROME") and str(OS.get_environment("ICONFORGE_CUSTOM_CHROME")) == "1")
		or (OS.has_environment("ICONSTUDIO_CUSTOM_CHROME") and str(OS.get_environment("ICONSTUDIO_CUSTOM_CHROME")) == "1")
	)

func _ready() -> void:
	custom_minimum_size = Vector2(0, 34)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bar: PanelContainer = PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_theme_stylebox_override("panel", UiStyles.flat(UiStyles.SIDEBAR, 0, false))
	add_child(bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("margin_left", 12)
	row.add_theme_constant_override("margin_right", 8)
	bar.add_child(row)
	row.add_child(UiStyles.heading("Icon Forge", 13))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var close_button: Button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(28, 24)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(close_button)
