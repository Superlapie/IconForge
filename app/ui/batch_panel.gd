extends VBoxContainer

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal render_all_requested
signal open_output_requested

var _progress: ProgressBar
var _summary: Label
var _list: VBoxContainer
var _render_button: Button

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var header: HBoxContainer = HBoxContainer.new()
	add_child(header)
	header.add_child(UiStyles.section_title("Batch Queue"))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_render_button = Button.new()
	_render_button.text = "Render All"
	_render_button.pressed.connect(func() -> void: render_all_requested.emit())
	header.add_child(_render_button)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 18)
	add_child(_progress)
	_summary = UiStyles.caption("No batch run yet.")
	add_child(_summary)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)
	var open_btn: Button = Button.new()
	open_btn.text = "Open Output Folder"
	open_btn.pressed.connect(func() -> void: open_output_requested.emit())
	add_child(open_btn)

func set_sources(sources: Array[String], preset_name: String) -> void:
	for child in _list.get_children():
		child.queue_free()
	for path in sources:
		_list.add_child(UiStyles.label("%s  •  %s" % [path.get_file(), preset_name], 11, UiStyles.MUTED))
	_summary.text = "%d assets queued" % sources.size()
	_progress.max_value = maxf(float(sources.size()), 1.0)
	_progress.value = 0.0

func set_progress(done: int, total: int, warnings: int, failures: int) -> void:
	_progress.max_value = maxf(float(total), 1.0)
	_progress.value = float(done)
	_summary.text = "%d / %d complete  •  %d warnings  •  %d failures" % [done, total, warnings, failures]
