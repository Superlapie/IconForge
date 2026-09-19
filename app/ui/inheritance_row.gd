extends VBoxContainer

const UiStyles = preload("res://app/ui/ui_styles.gd")

func update_inheritance(preset: PresetDefinition, override: Dictionary, key: String) -> void:
	for child in get_children():
		child.queue_free()
	if preset == null:
		return
	var preset_value: String = _format_key(preset, key)
	var override_value: String = "—"
	var effective_value: String = preset_value
	if override.has(key):
		override_value = _format_raw(key, override[key])
		effective_value = override_value
	add_child(_row("Preset", preset_value))
	add_child(_row("Override", override_value))
	add_child(_row("Effective", effective_value))

func _row(label: String, value: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = UiStyles.label(label, 10, UiStyles.TERTIARY)
	name_label.custom_minimum_size = Vector2(64, 0)
	row.add_child(name_label)
	row.add_child(UiStyles.label(value, 10, UiStyles.TEXT))
	return row

func _format_key(preset: PresetDefinition, key: String) -> String:
	var camera: Dictionary = preset.data.get("camera", {})
	var composition: Dictionary = preset.data.get("composition", {})
	match key:
		"yaw", "pitch", "roll":
			return "%.1f°" % float(camera.get(key, 0.0))
		"occupancy":
			return "%.0f%%" % (float(camera.get("occupancy", 0.82)) * 100.0)
		"scale":
			return "%.2f×" % float(composition.get("scale", 1.0))
	return "—"

func _format_raw(key: String, value: Variant) -> String:
	if key == "occupancy":
		return "%.0f%%" % (float(value) * 100.0)
	if key in ["yaw", "pitch", "roll"]:
		return "%.1f°" % float(value)
	if key == "scale":
		return "%.2f×" % float(value)
	return str(value)
