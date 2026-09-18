extends Control
class_name StudioUi

signal source_drop_handled(result: Dictionary)
signal preview_updated(result: Dictionary)

const INK: Color = Color("080c17")
const SURFACE: Color = Color("10172a")
const SURFACE_RAISED: Color = Color("151e35")
const SURFACE_HOVER: Color = Color("1b2947")
const BORDER: Color = Color("263653")
const TEXT: Color = Color("e7edf8")
const MUTED: Color = Color("91a1bb")
const ACCENT: Color = Color("79a7ff")
const ACCENT_BRIGHT: Color = Color("a8c6ff")
const SUCCESS: Color = Color("5fe0ad")
const WARNING: Color = Color("ffc875")

var preset_service: PresetService = PresetService.new()
var render_service: RenderService = RenderService.new()
var inspector: AssetInspector = AssetInspector.new()
var override_service: OverrideService = OverrideService.new()

var source_list: ItemList
var preset_selector: OptionButton
var preview_texture: TextureRect
var preview_canvas: PreviewCanvas
var preview_hint: Label
var empty_state: Label
var status_label: Label
var source_detail: Label
var preset_detail: Label
var output_label: Label
var add_button: Button
var export_button: Button
var save_override_button: Button
var sliders: Dictionary = {}
var slider_labels: Dictionary = {}
var sources: Array[String] = []
var active_source: String = ""
var active_preset: PresetDefinition
var active_override: Dictionary = {}
var preview_path: String = "user://iconstudio/previews/current.png"
var _render_serial: int = 0
var last_drop_result: Dictionary = {}
var last_preview_result: Dictionary = {}
var last_drop_files: PackedStringArray = PackedStringArray()
var drop_event_received: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("iconstudio_gui")
	var window: Window = get_window()
	if not window.files_dropped.is_connected(_on_files_dropped):
		window.files_dropped.connect(_on_files_dropped)
	var viewport: Viewport = get_viewport()
	if not viewport.files_dropped.is_connected(_on_files_dropped):
		viewport.files_dropped.connect(_on_files_dropped)
	_build_ui()
	preset_service.load_all()
	_populate_presets()
	_load_fixture_sources()
	_update_ui_state()

func _build_ui() -> void:
	theme = _build_theme()
	var background: ColorRect = ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(_build_header())
	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	root.add_child(content)
	content.add_child(_build_sources_panel())
	content.add_child(_build_preview_panel())
	content.add_child(_build_inspector_panel())
	root.add_child(_build_footer())

func _build_header() -> Control:
	var panel: PanelContainer = _panel(SURFACE)
	panel.custom_minimum_size = Vector2(0, 70)
	var margin: MarginContainer = _inner(panel, 18, 18, 12, 12)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var brand: VBoxContainer = VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: Label = _label("ICON STUDIO", 20, TEXT)
	title.add_theme_color_override("font_shadow_color", Color(0.15, 0.35, 0.75, 0.45))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	brand.add_child(title)
	brand.add_child(_label("CONSISTENT GAME IMAGERY AT CONTENT SCALE", 10, MUTED))
	row.add_child(brand)
	var offline: Label = _pill("OFFLINE / DETERMINISTIC", SUCCESS)
	row.add_child(offline)
	add_button = _button("＋  Add source", ACCENT)
	add_button.pressed.connect(_open_source_dialog)
	row.add_child(add_button)
	export_button = _button("Export PNG", ACCENT_BRIGHT)
	export_button.pressed.connect(_export_current)
	row.add_child(export_button)
	return panel

func _build_sources_panel() -> Control:
	var panel: PanelContainer = _panel(SURFACE)
	panel.custom_minimum_size = Vector2(278, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var margin: MarginContainer = _inner(panel, 16, 16, 14, 14)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(_label("SOURCE ASSETS", 11, MUTED))
	var source_subtitle: Label = _label("Drop 3D or 2D files here", 12, TEXT)
	column.add_child(source_subtitle)
	source_list = ItemList.new()
	source_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	source_list.allow_reselect = true
	source_list.item_selected.connect(_on_source_selected)
	source_list.add_theme_constant_override("v_separation", 8)
	column.add_child(source_list)
	source_detail = _label("No source selected", 11, MUTED)
	source_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_detail.custom_minimum_size = Vector2(0, 62)
	column.add_child(source_detail)
	var hint: Label = _label("Supported  GLB  GLTF  PNG  JPEG  WEBP", 10, MUTED)
	column.add_child(hint)
	return panel

func _build_preview_panel() -> Control:
	var panel: PanelContainer = _panel(Color("0d1425"))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var outer: MarginContainer = _inner(panel, 18, 18, 14, 14)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	outer.add_child(column)
	var heading: HBoxContainer = HBoxContainer.new()
	column.add_child(heading)
	var preview_title: Label = _label("LIVE PREVIEW", 11, MUTED)
	heading.add_child(preview_title)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	preview_hint = _label("Drag to orbit  •  Wheel to zoom", 10, MUTED)
	heading.add_child(preview_hint)
	var frame: PanelContainer = _panel(Color("0a0f1c"))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(frame)
	var canvas: Control = Control.new()
	canvas.clip_contents = true
	frame.add_child(canvas)
	var checker: Checkerboard = Checkerboard.new()
	checker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(checker)
	preview_texture = TextureRect.new()
	preview_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(preview_texture)
	preview_canvas = PreviewCanvas.new()
	preview_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG
	preview_canvas.orbit_changed.connect(_on_orbit_changed)
	preview_canvas.zoom_changed.connect(_on_zoom_changed)
	canvas.add_child(preview_canvas)
	empty_state = _label("Select a source to begin", 15, MUTED)
	empty_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_state.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	empty_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(empty_state)
	var footer: HBoxContainer = HBoxContainer.new()
	column.add_child(footer)
	output_label = _label("Preview output is generated in user://iconstudio/previews", 10, MUTED)
	footer.add_child(output_label)
	return panel

func _build_inspector_panel() -> Control:
	var panel: PanelContainer = _panel(SURFACE)
	panel.custom_minimum_size = Vector2(332, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var margin: MarginContainer = _inner(panel, 16, 16, 14, 14)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 11)
	margin.add_child(column)
	column.add_child(_label("RENDER INSPECTOR", 11, MUTED))
	preset_selector = OptionButton.new()
	preset_selector.custom_minimum_size = Vector2(0, 38)
	preset_selector.item_selected.connect(_on_preset_selected)
	column.add_child(preset_selector)
	preset_detail = _label("", 11, MUTED)
	preset_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preset_detail.custom_minimum_size = Vector2(0, 48)
	column.add_child(preset_detail)
	column.add_child(_rule())
	column.add_child(_section_label("COMPOSITION OVERRIDE"))
	_add_slider(column, "Yaw", "yaw", -180.0, 180.0, 0.0, 1.0, "°")
	_add_slider(column, "Pitch", "pitch", -90.0, 90.0, -8.0, 1.0, "°")
	_add_slider(column, "Roll", "roll", -180.0, 180.0, 0.0, 1.0, "°")
	_add_slider(column, "Occupancy", "occupancy", 0.40, 0.95, 0.82, 0.01, "%")
	_add_slider(column, "Scale", "scale", 0.40, 1.60, 1.0, 0.01, "×")
	column.add_child(_rule())
	column.add_child(_section_label("PRESENTATION"))
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	var reset: Button = _button("Reset", Color("bfd2f5"))
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_reset_override)
	action_row.add_child(reset)
	save_override_button = _button("Save sidecar", Color("bfd2f5"))
	save_override_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_override_button.pressed.connect(_save_override)
	action_row.add_child(save_override_button)
	column.add_child(action_row)
	var quality_box: PanelContainer = _panel(Color("0c1322"))
	quality_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var quality_margin: MarginContainer = _inner(quality_box, 12, 12, 10, 10)
	var quality_column: VBoxContainer = VBoxContainer.new()
	quality_margin.add_child(quality_column)
	quality_column.add_child(_label("QUALITY GATES", 10, MUTED))
	quality_column.add_child(_label("•  auto-frame with bounded correction\n•  transparent alpha check\n•  clipping and occupancy warnings\n•  deterministic PNG export", 11, TEXT))
	column.add_child(quality_box)
	return panel

func _build_footer() -> Control:
	var panel: PanelContainer = _panel(Color("0c1322"))
	panel.custom_minimum_size = Vector2(0, 36)
	var margin: MarginContainer = _inner(panel, 12, 12, 7, 7)
	var row: HBoxContainer = HBoxContainer.new()
	margin.add_child(row)
	status_label = _label("Ready — choose a source", 11, MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status_label)
	row.add_child(_label("Godot render core  •  PNG  •  offline", 10, MUTED))
	return panel

func _add_slider(parent: VBoxContainer, label_text: String, key: String, minimum: float, maximum: float, value: float, step: float, suffix: String) -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var heading: HBoxContainer = HBoxContainer.new()
	var label: Label = _label(label_text, 11, TEXT)
	heading.add_child(label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(spacer)
	var value_label: Label = _label("", 11, ACCENT_BRIGHT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(value_label)
	row.add_child(heading)
	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 22)
	slider.value_changed.connect(_on_slider_changed.bind(key, suffix))
	row.add_child(slider)
	parent.add_child(row)
	sliders[key] = slider
	slider_labels[key] = value_label
	_update_slider_label(key, value, suffix)

func _populate_presets() -> void:
	preset_selector.clear()
	for entry in preset_service.list_presets():
		preset_selector.add_item(str(entry.get("display_name", entry.get("id", ""))))
		preset_selector.set_item_metadata(preset_selector.item_count - 1, str(entry.get("id", "")))
	if preset_selector.item_count > 0:
		var preferred_index: int = 0
		for index in preset_selector.item_count:
			if str(preset_selector.get_item_metadata(index)) == "inventory_item":
				preferred_index = index
		preset_selector.select(preferred_index)
		active_preset = preset_service.get_preset(str(preset_selector.get_item_metadata(preferred_index)))

func _load_fixture_sources() -> void:
	var fixture_names: Array[String] = ["sword.gltf", "potion.gltf", "shield.gltf", "helmet.gltf", "creature.gltf"]
	for filename in fixture_names:
		var path: String = ProjectSettings.globalize_path("res://fixtures/%s" % filename)
		if FileAccess.file_exists(path):
			_add_source(path)
	if not sources.is_empty():
		source_list.select(0)
		_on_source_selected(0)

func _normalize_source_path(raw_path: String) -> String:
	var path: String = raw_path.strip_edges()
	if path.begins_with("file://"):
		path = path.trim_prefix("file://").uri_decode()
		if OS.get_name() == "Windows" and path.begins_with("/") and path.length() > 2 and path.substr(2, 1) == ":":
			path = path.substr(1)
	if path.begins_with("res://") or path.begins_with("user://"):
		path = ProjectSettings.globalize_path(path)
	elif not path.is_absolute_path():
		path = ProjectSettings.globalize_path(path)
	return IconStudioFileUtil.normalize_path(path)

func _add_source(path: String) -> bool:
	var normalized_path: String = _normalize_source_path(path)
	if not FileAccess.file_exists(normalized_path) or not IconStudioFileUtil.is_supported_source(normalized_path) or sources.has(normalized_path):
		return false
	sources.append(normalized_path)
	source_list.add_item(IconStudioFileUtil.source_name(normalized_path))
	source_list.set_item_tooltip(source_list.item_count - 1, normalized_path)
	return true

func handle_dropped_files(files: PackedStringArray) -> Dictionary:
	var accepted: Array[String] = []
	var rejected: Array[String] = []
	var duplicates: Array[String] = []
	for raw_path in files:
		var normalized_path: String = _normalize_source_path(str(raw_path))
		if not FileAccess.file_exists(normalized_path) or not IconStudioFileUtil.is_supported_source(normalized_path):
			rejected.append(str(raw_path))
		elif sources.has(normalized_path):
			duplicates.append(normalized_path)
		elif _add_source(normalized_path):
			accepted.append(normalized_path)

	var selected_path: String = ""
	if not accepted.is_empty():
		selected_path = accepted[0]
	elif not duplicates.is_empty():
		selected_path = duplicates[0]
	if not selected_path.is_empty():
		var selected_index: int = sources.find(selected_path)
		if selected_index >= 0:
			source_list.select(selected_index)
			_on_source_selected(selected_index)

	if not accepted.is_empty():
		status_label.text = "Added %d source%s — rendering preview…" % [accepted.size(), "" if accepted.size() == 1 else "s"]
		preview_hint.text = "Drop complete — preview is updating"
	elif not duplicates.is_empty():
		status_label.text = "Source already loaded — showing existing preview."
		preview_hint.text = "Drag to orbit  •  Wheel to zoom"
	else:
		status_label.text = "No supported source files dropped."
		preview_hint.text = "Drop GLB, glTF, PNG, JPEG, or WebP files"
	var result: Dictionary = {
		"success": not accepted.is_empty(),
		"accepted": accepted,
		"rejected": rejected,
		"duplicates": duplicates
	}
	last_drop_result = result
	source_drop_handled.emit(result)
	return result

func _on_source_selected(index: int) -> void:
	if index < 0 or index >= sources.size():
		return
	active_source = sources[index]
	if empty_state != null:
		empty_state.hide()
	var result: Dictionary = inspector.inspect(active_source)
	if bool(result.get("success", false)):
		source_detail.text = "%s\n%s  •  %s tris  •  %s meshes" % [active_source.get_file(), _dimensions_text(result.get("dimensions", [])), _format_number(int(result.get("triangle_count", 0))), str(result.get("mesh_count", 0))]
		status_label.text = "Ready — %s" % active_source.get_file()
	else:
		source_detail.text = str(result.get("error", {}).get("message", "Unable to inspect source."))
	_update_ui_state()
	_call_refresh_preview()

func _on_preset_selected(index: int) -> void:
	if index < 0:
		return
	var preset_id: String = str(preset_selector.get_item_metadata(index))
	active_preset = preset_service.get_preset(preset_id)
	_reset_override(false)
	_update_ui_state()
	_call_refresh_preview()

func _on_slider_changed(value: float, key: String, suffix: String) -> void:
	active_override[key] = value
	_update_slider_label(key, value, suffix)
	_call_refresh_preview()

func _on_orbit_changed(delta: Vector2) -> void:
	if active_preset == null:
		return
	var yaw: float = float(active_override.get("yaw", active_preset.data.get("camera", {}).get("yaw", 0.0)))
	var pitch: float = float(active_override.get("pitch", active_preset.data.get("camera", {}).get("pitch", -8.0)))
	active_override["yaw"] = yaw + delta.x * 0.45
	active_override["pitch"] = clampf(pitch + delta.y * 0.35, -90.0, 90.0)
	_set_slider_value("yaw", float(active_override["yaw"]))
	_set_slider_value("pitch", float(active_override["pitch"]))
	_call_refresh_preview()

func _on_zoom_changed(delta: float) -> void:
	var occupancy: float = float(active_override.get("occupancy", active_preset.data.get("camera", {}).get("occupancy", 0.82)))
	active_override["occupancy"] = clampf(occupancy + delta, 0.4, 0.95)
	_set_slider_value("occupancy", float(active_override["occupancy"]))
	_call_refresh_preview()

func _call_refresh_preview() -> void:
	_render_serial += 1
	var serial: int = _render_serial
	call_deferred("_refresh_preview", serial)

func _refresh_preview(serial: int) -> void:
	if serial != _render_serial or active_source.is_empty() or active_preset == null:
		return
	status_label.text = "Rendering preview…"
	preview_hint.text = "Rendering deterministic frame"
	var result: Dictionary = await render_service.render(active_source, active_preset, active_override, preview_path, true)
	if serial != _render_serial:
		return
	if bool(result.get("success", false)):
		if empty_state != null:
			empty_state.hide()
		var image: Image = Image.new()
		if image.load(preview_path) == OK:
			preview_texture.texture = ImageTexture.create_from_image(image)
		var occupancy: float = float(result.get("metrics", {}).get("occupancy", 0.0)) * 100.0
		status_label.text = "Preview ready — %.1f%% occupancy  •  %d correction pass%s" % [occupancy, int(result.get("render_passes", 1)), "" if int(result.get("render_passes", 1)) == 1 else "es"]
		preview_hint.text = "Drag to orbit  •  Wheel to zoom"
	else:
		status_label.text = "Render error — %s" % str(result.get("error", {}).get("message", "Unknown renderer error"))
		preview_hint.text = "Preview unavailable"
	last_preview_result = result
	preview_updated.emit(result)

func run_drop_e2e(source_path: String, screenshot_path: String = "") -> Dictionary:
	var normalized_source: String = _normalize_source_path(source_path)
	var before_count: int = sources.size()
	last_drop_result = {}
	last_preview_result = {}
	get_window().files_dropped.emit(PackedStringArray([normalized_source]))
	await get_tree().process_frame
	var drop_result: Dictionary = last_drop_result.duplicate(true)
	var preview_result: Dictionary = await _wait_for_preview_result(30000)
	var image_valid: bool = false
	if FileAccess.file_exists(preview_path):
		var image: Image = Image.new()
		image_valid = image.load(preview_path) == OK and image.get_size() == Vector2i(256, 256)
	var screenshot_error: Error = OK
	if not screenshot_path.is_empty():
		IconStudioFileUtil.ensure_directory(screenshot_path)
		screenshot_error = get_viewport().get_texture().get_image().save_png(screenshot_path)
	last_drop_result = {}
	get_window().files_dropped.emit(PackedStringArray([normalized_source, normalized_source + ".unsupported"]))
	await get_tree().process_frame
	var duplicate_result: Dictionary = last_drop_result.duplicate(true)
	var accepted_ok: bool = bool(drop_result.get("success", false)) and Array(drop_result.get("accepted", [])).has(normalized_source)
	var selected_ok: bool = active_source == normalized_source
	var preview_ok: bool = bool(preview_result.get("success", false)) and image_valid
	var duplicate_handling_ok: bool = Array(duplicate_result.get("duplicates", [])).has(normalized_source) and not Array(duplicate_result.get("rejected", [])).is_empty()
	var result: Dictionary = {
		"success": accepted_ok and selected_ok and preview_ok and duplicate_handling_ok and screenshot_error == OK,
		"source": normalized_source,
		"source_count_before": before_count,
		"source_count_after": sources.size(),
		"drop": drop_result,
		"duplicate_drop": duplicate_result,
		"preview": preview_result,
		"preview_path": ProjectSettings.globalize_path(preview_path),
		"preview_image_valid": image_valid,
		"screenshot": screenshot_path,
		"screenshot_error": screenshot_error
	}
	return result

func run_native_drop_wait(expected_source_path: String, screenshot_path: String = "", timeout_ms: int = 30000) -> Dictionary:
	var expected_source: String = _normalize_source_path(expected_source_path)
	last_preview_result = {}
	var started_at: int = Time.get_ticks_msec()
	while not drop_event_received and Time.get_ticks_msec() - started_at < timeout_ms:
		await get_tree().process_frame
	var drop_result: Dictionary = last_drop_result.duplicate(true)
	last_preview_result = {}
	var preview_started_at: int = Time.get_ticks_msec()
	while (last_preview_result.is_empty() or str(last_preview_result.get("source", "")) != expected_source) and Time.get_ticks_msec() - preview_started_at < timeout_ms:
		await get_tree().process_frame
	var preview_result: Dictionary = last_preview_result.duplicate(true)
	var image_valid: bool = false
	if FileAccess.file_exists(preview_path):
		var image: Image = Image.new()
		image_valid = image.load(preview_path) == OK and image.get_size() == Vector2i(256, 256)
	var screenshot_error: Error = OK
	if not screenshot_path.is_empty():
		IconStudioFileUtil.ensure_directory(screenshot_path)
		screenshot_error = get_viewport().get_texture().get_image().save_png(screenshot_path)
	var accepted: Array = drop_result.get("accepted", [])
	var result: Dictionary = {
		"success": bool(drop_result.get("success", false)) and accepted.has(expected_source) and active_source == expected_source and bool(preview_result.get("success", false)) and image_valid and screenshot_error == OK,
		"expected_source": expected_source,
		"observed_files": last_drop_files,
		"drop": drop_result,
		"preview": preview_result,
		"preview_path": ProjectSettings.globalize_path(preview_path),
		"preview_image_valid": image_valid,
		"screenshot": screenshot_path,
		"screenshot_error": screenshot_error
	}
	return result

func _wait_for_preview_result(timeout_ms: int) -> Dictionary:
	var started_at: int = Time.get_ticks_msec()
	while last_preview_result.is_empty() and Time.get_ticks_msec() - started_at < timeout_ms:
		await get_tree().process_frame
	return last_preview_result.duplicate(true)

func _export_current() -> void:
	if active_source.is_empty() or active_preset == null:
		status_label.text = "Choose a source before exporting."
		return
	var output_dir: String = ProjectSettings.globalize_path("res://out")
	var output_path: String = output_dir.path_join("%s_%s.png" % [IconStudioFileUtil.source_name(active_source), active_preset.get_id()])
	status_label.text = "Exporting PNG…"
	var result: Dictionary = await render_service.render(active_source, active_preset, active_override, output_path, true)
	if bool(result.get("success", false)):
		output_label.text = "Exported  %s" % output_path
		status_label.text = "Export complete — %s" % output_path.get_file()
	else:
		status_label.text = "Export failed — %s" % str(result.get("error", {}).get("message", "Unknown renderer error"))

func _save_override() -> void:
	if active_source.is_empty():
		return
	var result: Dictionary = override_service.save_for_source(active_source, active_override)
	status_label.text = "Saved %s" % result.get("path", "override") if bool(result.get("success", false)) else "Could not save sidecar"

func _reset_override(refresh: bool = true) -> void:
	active_override.clear()
	if sliders.is_empty():
		return
	_set_slider_value("yaw", float(active_preset.data.get("camera", {}).get("yaw", 0.0)))
	_set_slider_value("pitch", float(active_preset.data.get("camera", {}).get("pitch", -8.0)))
	_set_slider_value("roll", float(active_preset.data.get("camera", {}).get("roll", 0.0)))
	_set_slider_value("occupancy", float(active_preset.data.get("camera", {}).get("occupancy", 0.82)))
	_set_slider_value("scale", float(active_preset.data.get("composition", {}).get("scale", 1.0)))
	if refresh:
		_call_refresh_preview()

func _open_source_dialog() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.title = "Add source assets"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.glb, *.gltf ; 3D models", "*.png, *.jpg, *.jpeg, *.webp ; Images"])
	dialog.files_selected.connect(func(paths: PackedStringArray) -> void:
		handle_dropped_files(paths)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.72)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("files"):
		for raw_path in data["files"]:
			var path: String = _normalize_source_path(str(raw_path))
			if FileAccess.file_exists(path) and IconStudioFileUtil.is_supported_source(path):
				return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		var files: PackedStringArray = PackedStringArray()
		for raw_path in data.get("files", []):
			files.append(str(raw_path))
		handle_dropped_files(files)

func _on_files_dropped(files: PackedStringArray) -> void:
	last_drop_files = files.duplicate()
	drop_event_received = true
	handle_dropped_files(files)

func _update_ui_state() -> void:
	var has_source: bool = not active_source.is_empty() and active_preset != null
	export_button.disabled = not has_source
	save_override_button.disabled = not has_source
	if active_preset != null:
		preset_detail.text = "%s\n%s" % [str(active_preset.data.get("description", "")), "%s×%s  •  %s  •  %s" % [active_preset.data.get("resolution", {}).get("width", 256), active_preset.data.get("resolution", {}).get("height", 256), active_preset.data.get("projection", "orthographic"), str(active_preset.data.get("environment", {}).get("background", "transparent"))]]

func _set_slider_value(key: String, value: float) -> void:
	if not sliders.has(key):
		return
	var slider: HSlider = sliders[key]
	slider.set_value_no_signal(value)
	_update_slider_label(key, value, "%" if key == "occupancy" else ("×" if key == "scale" else "°"))

func _update_slider_label(key: String, value: float, suffix: String) -> void:
	if not slider_labels.has(key):
		return
	var text: String
	if suffix == "%":
		text = "%d%%" % int(round(value * 100.0))
	elif suffix == "×":
		text = "%.2f×" % value
	else:
		text = "%d°" % int(round(value))
	slider_labels[key].text = text

func _dimensions_text(dimensions: Array) -> String:
	if dimensions.size() < 3:
		return "unknown bounds"
	return "%.2f × %.2f × %.2f" % [float(dimensions[0]), float(dimensions[1]), float(dimensions[2])]

func _format_number(value: int) -> String:
	return "%.1fk" % (float(value) / 1000.0) if value >= 1000 else str(value)

func _build_theme() -> Theme:
	var result: Theme = Theme.new()
	result.default_font_size = 13
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_pressed_color", "Button", Color.WHITE)
	result.set_color("font_color", "LineEdit", TEXT)
	result.set_color("font_color", "OptionButton", TEXT)
	result.set_color("font_color", "ItemList", TEXT)
	result.set_color("font_selected_color", "ItemList", Color.WHITE)
	result.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.35))
	result.set_constant("outline_size", "Label", 2)
	result.set_constant("item_start_padding", "ItemList", 12)
	result.set_constant("item_end_padding", "ItemList", 12)
	result.set_constant("item_margin", "ItemList", 6)
	result.set_stylebox("normal", "Button", _style(SURFACE_RAISED, BORDER, 8, 1))
	result.set_stylebox("hover", "Button", _style(SURFACE_HOVER, ACCENT, 8, 1))
	result.set_stylebox("pressed", "Button", _style(Color("22365c"), ACCENT_BRIGHT, 8, 1))
	result.set_stylebox("normal", "OptionButton", _style(SURFACE_RAISED, BORDER, 8, 1))
	result.set_stylebox("hover", "OptionButton", _style(SURFACE_HOVER, ACCENT, 8, 1))
	result.set_stylebox("normal", "LineEdit", _style(Color("0c1322"), BORDER, 6, 1))
	result.set_stylebox("focus", "LineEdit", _style(Color("0c1322"), ACCENT, 6, 1))
	result.set_stylebox("normal", "ItemList", _style(Color("0c1322"), BORDER, 8, 1))
	result.set_stylebox("selected", "ItemList", _style(Color("20345b"), ACCENT, 8, 1))
	result.set_stylebox("focus", "ItemList", _style(Color("20345b"), ACCENT, 8, 1))
	result.set_stylebox("grabber_area_highlight", "HSlider", _style(ACCENT, ACCENT, 4, 0))
	return result

func _style(color: Color, border_color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _panel(color: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color, BORDER, 10, 1))
	return panel

func _inner(panel: Control, left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	panel.add_child(margin)
	return margin

func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _pill(text: String, color: Color) -> Label:
	var label: Label = _label("  " + text + "  ", 10, color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _style(Color(color, 0.10), Color(color, 0.35), 12, 1))
	return label

func _button(text: String, color: Color) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_color_override("font_color", color)
	button.add_theme_font_size_override("font_size", 12)
	button.custom_minimum_size = Vector2(0, 36)
	return button

func _section_label(text: String) -> Label:
	return _label(text, 10, MUTED)

func _rule() -> HSeparator:
	var separator: HSeparator = HSeparator.new()
	separator.add_theme_stylebox_override("separator", _style(BORDER, Color(0, 0, 0, 0), 0, 0))
	return separator
