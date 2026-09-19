extends VBoxContainer

const UiStyles = preload("res://app/ui/ui_styles.gd")

var _body: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	add_child(UiStyles.section_title("Render Recipe"))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	add_child(_body)

func update_recipe(source: String, preset: PresetDefinition, override: Dictionary, result: Dictionary) -> void:
	for child in _body.get_children():
		child.queue_free()
	if preset == null:
		_body.add_child(UiStyles.caption("No render yet."))
		return
	_add_line("Source", source.get_file() if not source.is_empty() else "—")
	_add_line("Preset", preset.get_display_name())
	var camera: Dictionary = preset.data.get("camera", {})
	_add_line("Yaw", "%.1f°" % float(override.get("yaw", camera.get("yaw", 0.0))))
	_add_line("Pitch", "%.1f°" % float(override.get("pitch", camera.get("pitch", -8.0))))
	_add_line("Roll", "%.1f°" % float(override.get("roll", camera.get("roll", 0.0))))
	_add_line("Occupancy", "%.0f%%" % (float(override.get("occupancy", camera.get("occupancy", 0.82))) * 100.0))
	if not result.is_empty():
		var actual: float = float(result.get("metrics", {}).get("occupancy", 0.0)) * 100.0
		_add_line("Actual", "%.1f%%" % actual)
		_add_line("Passes", str(result.get("render_passes", 1)))
	var lighting: Dictionary = preset.data.get("lighting", {})
	_add_line("Lighting", str(lighting.get("rig", "studio")))
	var resolution: Dictionary = preset.data.get("resolution", {})
	_add_line("Output", "%s×%s PNG" % [resolution.get("width", 256), resolution.get("height", 256)])

func _add_line(label: String, value: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	_body.add_child(row)
	var name_label: Label = UiStyles.label(label, 11, UiStyles.MUTED)
	name_label.custom_minimum_size = Vector2(72, 0)
	row.add_child(name_label)
	row.add_child(UiStyles.label(value, 11, UiStyles.TEXT))
