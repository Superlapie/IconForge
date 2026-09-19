extends VBoxContainer

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal auto_fix_requested

var _rows: Dictionary = {}
var _fix_button: Button

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_add_section_header("Quality")
	_rows["framing"] = _add_row("Framing", "—")
	_rows["clipping"] = _add_row("Clipping", "—")
	_rows["alpha"] = _add_row("Alpha", "—")
	_rows["resolution"] = _add_row("Resolution", "—")
	_rows["correction"] = _add_row("Correction", "—")
	var fix_row: HBoxContainer = HBoxContainer.new()
	fix_row.add_theme_constant_override("separation", 8)
	add_child(fix_row)
	_fix_button = Button.new()
	_fix_button.text = "Auto Frame"
	_fix_button.visible = false
	_fix_button.pressed.connect(func() -> void: auto_fix_requested.emit())
	fix_row.add_child(_fix_button)

func update_from_render(result: Dictionary, preset: PresetDefinition) -> void:
	if result.is_empty() or preset == null:
		_set_row("framing", "—", UiStyles.MUTED)
		_set_row("clipping", "—", UiStyles.MUTED)
		_set_row("alpha", "—", UiStyles.MUTED)
		_set_row("resolution", "—", UiStyles.MUTED)
		_set_row("correction", "—", UiStyles.MUTED)
		if _fix_button:
			_fix_button.visible = false
		return
	var metrics: Dictionary = result.get("metrics", {})
	var warnings: Array = result.get("warnings", [])
	var errors: Array = result.get("errors", [])
	var target: float = float(preset.data.get("camera", {}).get("occupancy", 0.82))
	var actual: float = float(metrics.get("occupancy", 0.0))
	var passes: int = int(result.get("render_passes", 1))
	var width: int = int(preset.data.get("resolution", {}).get("width", 256))
	var height: int = int(preset.data.get("resolution", {}).get("height", 256))
	var framing_ok: bool = actual >= target * 0.96 and actual <= target * 1.08
	var framing_color: Color = UiStyles.SUCCESS if framing_ok else UiStyles.WARNING
	_set_row("framing", "%.1f%% / target %.0f%%" % [actual * 100.0, target * 100.0], framing_color, framing_ok)
	var clipped: bool = bool(metrics.get("clipped", false))
	_set_row("clipping", "%d clipped edge%s" % [1 if clipped else 0, "" if not clipped else "s"], UiStyles.WARNING if clipped else UiStyles.SUCCESS, not clipped)
	var has_alpha: bool = bool(metrics.get("has_silhouette", false))
	_set_row("alpha", "Valid transparency" if has_alpha else "No visible pixels", UiStyles.SUCCESS if has_alpha else UiStyles.ERROR, has_alpha)
	_set_row("resolution", "%d × %d" % [width, height], UiStyles.SUCCESS, true)
	_set_row("correction", "%d render pass%s" % [passes, "" if passes == 1 else "es"], UiStyles.MUTED, true)
	var needs_fix: bool = clipped or not framing_ok or not warnings.is_empty()
	if _fix_button:
		_fix_button.visible = needs_fix and bool(result.get("success", false))

func _add_section_header(text: String) -> void:
	add_child(UiStyles.section_title(text))

func _add_row(title: String, value: String) -> Dictionary:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 22)
	add_child(row)
	var icon: Label = UiStyles.label("○", 11, UiStyles.TERTIARY)
	icon.custom_minimum_size = Vector2(14, 0)
	row.add_child(icon)
	var name_label: Label = UiStyles.label(title, 11, UiStyles.TEXT)
	name_label.custom_minimum_size = Vector2(72, 0)
	row.add_child(name_label)
	var value_label: Label = UiStyles.label(value, 11, UiStyles.MUTED)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)
	return {"icon": icon, "value": value_label}

func _set_row(key: String, value: String, color: Color, ok: bool = true) -> void:
	if not _rows.has(key):
		return
	var row: Dictionary = _rows[key]
	row["value"].text = value
	row["value"].add_theme_color_override("font_color", color)
	row["icon"].text = "✓" if ok else "⚠"
	row["icon"].add_theme_color_override("font_color", UiStyles.SUCCESS if ok else UiStyles.WARNING)
