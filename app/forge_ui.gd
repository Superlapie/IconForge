extends Control
class_name ForgeUi

const UiStylesScript = preload("res://app/ui/ui_styles.gd")
const AccordionSectionScript = preload("res://app/ui/accordion_section.gd")
const ScrubSliderScript = preload("res://app/ui/scrub_slider.gd")
const RotationDialScript = preload("res://app/ui/rotation_dial.gd")
const ViewportModeBarScript = preload("res://app/ui/viewport_mode_bar.gd")
const ViewportHudScript = preload("res://app/ui/viewport_hud.gd")
const PreviewDisplayScript = preload("res://app/ui/preview_display.gd")
const LivePreviewViewportScript = preload("res://app/ui/live_preview_viewport.gd")
const SourceAssetBrowserScript = preload("res://app/ui/source_asset_browser.gd")
const QualityPanelScript = preload("res://app/ui/quality_panel.gd")
const BottomTrayScript = preload("res://app/ui/bottom_tray.gd")
const EmptyWorkspaceScript = preload("res://app/ui/empty_workspace.gd")
const PresetPickerScript = preload("res://app/ui/preset_picker.gd")
const InspectorHostScript = preload("res://app/ui/inspector_host.gd")
const InheritanceRowScript = preload("res://app/ui/inheritance_row.gd")
const VariantsPanelScript = preload("res://app/ui/variants_panel.gd")
const HistoryPanelScript = preload("res://app/ui/history_panel.gd")
const BatchPanelScript = preload("res://app/ui/batch_panel.gd")
const LogPanelScript = preload("res://app/ui/log_panel.gd")
const RenderRecipePanelScript = preload("res://app/ui/render_recipe_panel.gd")
const CommandPaletteScript = preload("res://app/ui/command_palette.gd")
const ExportDrawerScript = preload("res://app/ui/export_drawer.gd")
const PresetCompareDialogScript = preload("res://app/ui/preset_compare_dialog.gd")
const CompareOverlayScript = preload("res://app/ui/compare_overlay.gd")
const LightingGizmoScript = preload("res://app/ui/lighting_gizmo.gd")
const WorkspaceLayoutScript = preload("res://app/ui/workspace_layout.gd")
const UiIconsScript = preload("res://app/ui/ui_icons.gd")
const WindowChromeScript = preload("res://app/ui/window_chrome.gd")
const PreviewCameraScript = preload("res://core/services/preview_camera.gd")
const GuiSessionScript = preload("res://app/ui/gui_session.gd")
const CliRecipeScript = preload("res://app/ui/cli_recipe.gd")

const RECENT_PATH: String = "user://iconforge/recent_sources.json"
const PREVIEW_DEBOUNCE_MS: int = 120
const INTERACTION_DEBOUNCE_MS: int = 100
const COMPARE_PRESETS: Array[String] = ["inventory_item", "weapon", "shop_thumbnail", "equipment_preview"]

signal source_drop_handled(result: Dictionary)
signal preview_updated(result: Dictionary)

var preset_service: PresetService = PresetService.new()
var render_service: RenderService = RenderService.new()
var batch_service: BatchService = BatchService.new()
var inspector: AssetInspector = AssetInspector.new()
var override_service: OverrideService = OverrideService.new()
var lighting_service: LightingRigService = LightingRigService.new()
var session: GuiSessionScript = GuiSessionScript.new()

var source_browser: SourceAssetBrowserScript
var preset_picker: PresetPickerScript
var inspector_host: InspectorHostScript
var preview_display: PreviewDisplayScript
var live_preview: LivePreviewViewportScript
var preview_canvas: PreviewCanvas
var checkerboard: Checkerboard
var viewport_hud: ViewportHudScript
var viewport_mode_bar: ViewportModeBarScript
var compare_overlay: CompareOverlayScript
var lighting_gizmo: LightingGizmoScript
var empty_workspace: EmptyWorkspaceScript
var bottom_tray: BottomTrayScript
var quality_panel: QualityPanelScript
var variants_panel: VariantsPanelScript
var history_panel: HistoryPanelScript
var batch_panel: BatchPanelScript
var log_panel: LogPanelScript
var render_recipe_panel: RenderRecipePanelScript
var command_palette: CommandPaletteScript
var export_drawer: ExportDrawerScript
var preset_compare_dialog: PresetCompareDialogScript
var inheritance_row: InheritanceRowScript
var composition_section: AccordionSectionScript
var source_detail: Label
var preset_detail: Label
var export_button: MenuButton
var save_override_button: Button
var workspace_toggle: Button
var undo_button: Button
var redo_button: Button
var rotation_controls: Dictionary = {}
var scrub_controls: Dictionary = {}
var info_labels: Dictionary = {}
var _root: VBoxContainer
var _toolbar: Control
var _main_split: HSplitContainer
var _sources_dock: Control
var _inspector_dock: Control
var _viewport_stage: Control
var _workspace_settings: Dictionary = {}
var _sources_collapsed: bool = false
var _inspector_collapsed: bool = false
var _sources_collapse_button: Button
var _inspector_collapse_button: Button
var sources: Array[String] = []
var active_source: String = ""
var active_preset: PresetDefinition
var active_override: Dictionary = {}
var preview_path: String = "user://iconforge/previews/current.png"
var export_format: String = "png"
var export_destination: String = "res://out"
var preview_quality: String = "full"
var workspace_mode: String = "single"
var viewport_maximized: bool = false
var compare_mode: String = "off"
var _render_serial: int = 0
var _preview_completion_serial: int = 0
var _preview_timer: Timer
var _interacting: bool = false
var _syncing_controls: bool = false
var _last_inspection: Dictionary = {}
var _undo_guard: bool = false
var _texture_a: Texture2D
var _texture_b: Texture2D
var last_drop_result: Dictionary = {}
var last_preview_result: Dictionary = {}
var last_drop_files: PackedStringArray = PackedStringArray()
var drop_event_received: bool = false
var sidecar_invalid: bool = false
var sidecar_error: Dictionary = {}
var _pending_export_settings: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("iconforge_gui")
	var window: Window = get_window()
	if not window.files_dropped.is_connected(_on_files_dropped):
		window.files_dropped.connect(_on_files_dropped)
	var viewport: Viewport = get_viewport()
	if not viewport.files_dropped.is_connected(_on_files_dropped):
		viewport.files_dropped.connect(_on_files_dropped)
	_preview_timer = Timer.new()
	_preview_timer.one_shot = true
	_preview_timer.wait_time = float(PREVIEW_DEBOUNCE_MS) / 1000.0
	_preview_timer.timeout.connect(_on_preview_debounce_timeout)
	add_child(_preview_timer)
	_build_ui()
	_apply_workspace_settings()
	if _main_split != null:
		_main_split.dragged.connect(_on_main_split_dragged)
	preset_service.load_all()
	preset_picker.setup(preset_service)
	_select_preset("inventory_item", false)
	_setup_commands()
	_update_ui_state()
	_load_recent_files()

func _build_ui() -> void:
	theme = UiStylesScript.build_theme()
	var background: ColorRect = ColorRect.new()
	background.color = UiStylesScript.CANVAS
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 0)
	add_child(_root)
	if WindowChromeScript.enabled():
		var chrome: Control = WindowChromeScript.new()
		chrome.close_requested.connect(func() -> void: get_window().hide())
		_root.add_child(chrome)
	_toolbar = _build_toolbar()
	_root.add_child(_toolbar)
	_main_split = HSplitContainer.new()
	_main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_split.add_theme_constant_override("separation", 0)
	_root.add_child(_main_split)
	_sources_dock = _build_sources_dock()
	_main_split.add_child(_sources_dock)
	_viewport_stage = _build_viewport_stage()
	_main_split.add_child(_viewport_stage)
	_inspector_dock = _build_inspector_dock()
	_main_split.add_child(_inspector_dock)
	_main_split.split_offset = 260
	bottom_tray = BottomTrayScript.new()
	quality_panel = QualityPanelScript.new()
	quality_panel.auto_fix_requested.connect(_on_auto_frame_requested)
	variants_panel = VariantsPanelScript.new()
	variants_panel.variant_selected.connect(_on_variant_selected)
	variants_panel.variant_saved.connect(_on_variant_saved)
	history_panel = HistoryPanelScript.new()
	history_panel.restore_requested.connect(_on_history_restore)
	batch_panel = BatchPanelScript.new()
	batch_panel.render_all_requested.connect(_run_batch_render)
	batch_panel.open_output_requested.connect(_open_output_folder)
	log_panel = LogPanelScript.new()
	bottom_tray.register_tab("quality", quality_panel)
	bottom_tray.register_tab("variants", variants_panel)
	bottom_tray.register_tab("history", history_panel)
	bottom_tray.register_tab("batch", batch_panel)
	bottom_tray.register_tab("log", log_panel)
	_root.add_child(bottom_tray)
	command_palette = CommandPaletteScript.new()
	add_child(command_palette)
	command_palette.command_invoked.connect(_on_command)
	export_drawer = ExportDrawerScript.new()
	add_child(export_drawer)
	export_drawer.export_confirmed.connect(_on_export_drawer_confirmed)
	preset_compare_dialog = PresetCompareDialogScript.new()
	add_child(preset_compare_dialog)
	preset_compare_dialog.preset_chosen.connect(_select_preset)

func _build_toolbar() -> Control:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiStylesScript.flat(UiStylesScript.SIDEBAR, 0, false))
	bar.custom_minimum_size = Vector2(0, UiStylesScript.TOOLBAR_HEIGHT)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bar.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	row.add_child(UiStylesScript.heading("Icon Forge", 15))
	row.add_child(_vsep())
	undo_button = Button.new()
	undo_button.text = UiIconsScript.label("undo")
	undo_button.tooltip_text = "Undo (Ctrl+Z)"
	undo_button.custom_minimum_size = Vector2(28, UiStylesScript.ROW_HEIGHT)
	undo_button.pressed.connect(_undo)
	row.add_child(undo_button)
	redo_button = Button.new()
	redo_button.text = UiIconsScript.label("redo")
	redo_button.tooltip_text = "Redo (Ctrl+Y)"
	redo_button.custom_minimum_size = Vector2(28, UiStylesScript.ROW_HEIGHT)
	redo_button.pressed.connect(_redo)
	row.add_child(redo_button)
	row.add_child(_vsep())
	var add_button: Button = Button.new()
	add_button.text = UiIconsScript.label("add")
	add_button.custom_minimum_size = Vector2(56, UiStylesScript.ROW_HEIGHT)
	add_button.pressed.connect(_open_source_dialog)
	row.add_child(add_button)
	var samples_button: Button = Button.new()
	samples_button.text = "Samples"
	samples_button.custom_minimum_size = Vector2(72, UiStylesScript.ROW_HEIGHT)
	samples_button.pressed.connect(_load_fixture_sources)
	row.add_child(samples_button)
	workspace_toggle = Button.new()
	workspace_toggle.toggle_mode = true
	workspace_toggle.text = "Single"
	workspace_toggle.custom_minimum_size = Vector2(72, UiStylesScript.ROW_HEIGHT)
	workspace_toggle.toggled.connect(_on_workspace_toggled)
	row.add_child(workspace_toggle)
	var palette_button: Button = Button.new()
	palette_button.text = UiIconsScript.label("palette")
	palette_button.custom_minimum_size = Vector2(44, UiStylesScript.ROW_HEIGHT)
	palette_button.pressed.connect(_open_command_palette)
	row.add_child(palette_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	export_button = MenuButton.new()
	export_button.text = UiIconsScript.label("export")
	export_button.custom_minimum_size = Vector2(88, UiStylesScript.ROW_HEIGHT)
	var export_menu: PopupMenu = export_button.get_popup()
	export_menu.add_item("Export Current…", 0)
	export_menu.add_item("Quick Export PNG", 1)
	export_menu.add_item("Render All (Batch)", 2)
	export_menu.add_separator()
	export_menu.add_item("Copy CLI Command", 10)
	export_menu.add_item("Copy Effective Preset JSON", 11)
	export_menu.add_item("Copy Render Recipe", 12)
	export_menu.add_separator()
	export_menu.add_item("Open Output Folder", 20)
	export_menu.id_pressed.connect(_on_export_menu)
	row.add_child(export_button)
	return bar

func _build_sources_dock() -> Control:
	var dock: PanelContainer = PanelContainer.new()
	dock.add_theme_stylebox_override("panel", UiStylesScript.dock())
	dock.custom_minimum_size = Vector2(220, 0)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UiStylesScript.DOCK_PADDING)
	margin.add_theme_constant_override("margin_right", UiStylesScript.DOCK_PADDING)
	margin.add_theme_constant_override("margin_top", UiStylesScript.DOCK_PADDING)
	margin.add_theme_constant_override("margin_bottom", UiStylesScript.DOCK_PADDING)
	dock.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", UiStylesScript.SECTION_GAP)
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)
	header.add_child(UiStylesScript.section_title("Sources"))
	var header_spacer: Control = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	_sources_collapse_button = Button.new()
	_sources_collapse_button.text = UiIconsScript.label("collapse")
	_sources_collapse_button.tooltip_text = "Collapse sources dock"
	_sources_collapse_button.custom_minimum_size = Vector2(24, UiStylesScript.ROW_HEIGHT)
	_sources_collapse_button.pressed.connect(_toggle_sources_dock)
	header.add_child(_sources_collapse_button)
	source_browser = SourceAssetBrowserScript.new()
	source_browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	source_browser.source_selected.connect(_on_source_selected)
	source_browser.source_context_menu.connect(_on_source_context_menu)
	column.add_child(source_browser)
	source_detail = UiStylesScript.caption("No source selected")
	source_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_detail.custom_minimum_size = Vector2(0, 48)
	column.add_child(source_detail)
	return dock

func _build_viewport_stage() -> Control:
	var stage: Control = Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	stage.add_child(column)
	var toolbar_margin: MarginContainer = MarginContainer.new()
	toolbar_margin.add_theme_constant_override("margin_left", 10)
	toolbar_margin.add_theme_constant_override("margin_right", 10)
	toolbar_margin.add_theme_constant_override("margin_top", 8)
	toolbar_margin.add_theme_constant_override("margin_bottom", 4)
	column.add_child(toolbar_margin)
	viewport_mode_bar = ViewportModeBarScript.new()
	toolbar_margin.add_child(viewport_mode_bar)
	viewport_mode_bar.mode_changed.connect(_on_viewport_mode_changed)
	viewport_mode_bar.guides_toggled.connect(_on_guides_toggled)
	viewport_mode_bar.checker_changed.connect(_on_checker_changed)
	viewport_mode_bar.frame_requested.connect(_on_auto_frame_requested)
	viewport_mode_bar.reset_requested.connect(_reset_override)
	viewport_mode_bar.compare_toggled.connect(_on_compare_toggled)
	viewport_mode_bar.preview_quality_changed.connect(_on_preview_quality_changed)
	viewport_mode_bar.snapshot_requested.connect(_on_snapshot_requested)
	viewport_mode_bar.maximize_requested.connect(_toggle_viewport_maximize)
	var canvas_host: Control = Control.new()
	canvas_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_host.clip_contents = true
	column.add_child(canvas_host)
	checkerboard = Checkerboard.new()
	checkerboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_host.add_child(checkerboard)
	live_preview = LivePreviewViewportScript.new()
	live_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	live_preview.hide()
	canvas_host.add_child(live_preview)
	preview_display = PreviewDisplayScript.new()
	preview_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_host.add_child(preview_display)
	compare_overlay = CompareOverlayScript.new()
	compare_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_host.add_child(compare_overlay)
	preview_canvas = PreviewCanvas.new()
	preview_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_canvas.orbit_changed.connect(_on_orbit_changed)
	preview_canvas.zoom_changed.connect(_on_zoom_changed)
	preview_canvas.interaction_started.connect(_on_interaction_started)
	preview_canvas.interaction_ended.connect(_on_interaction_ended)
	canvas_host.add_child(preview_canvas)
	viewport_hud = ViewportHudScript.new()
	viewport_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_host.add_child(viewport_hud)
	lighting_gizmo = LightingGizmoScript.new()
	lighting_gizmo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lighting_gizmo.lighting_changed.connect(_on_lighting_changed)
	canvas_host.add_child(lighting_gizmo)
	empty_workspace = EmptyWorkspaceScript.new()
	empty_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	empty_workspace.open_files_requested.connect(_open_source_dialog)
	empty_workspace.try_samples_requested.connect(_load_fixture_sources)
	empty_workspace.recent_selected.connect(_open_recent_source)
	canvas_host.add_child(empty_workspace)
	preview_canvas.gui_input.connect(_on_viewport_context_input)
	return stage

func _build_inspector_dock() -> Control:
	var dock: PanelContainer = PanelContainer.new()
	dock.add_theme_stylebox_override("panel", UiStylesScript.dock_right())
	dock.custom_minimum_size = Vector2(300, 0)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UiStylesScript.DOCK_PADDING)
	margin.add_theme_constant_override("margin_right", UiStylesScript.DOCK_PADDING)
	margin.add_theme_constant_override("margin_top", UiStylesScript.DOCK_PADDING)
	margin.add_theme_constant_override("margin_bottom", UiStylesScript.DOCK_PADDING)
	dock.add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var inspector_header: HBoxContainer = HBoxContainer.new()
	inspector_header.add_theme_constant_override("separation", 6)
	scroll.add_child(inspector_header)
	inspector_header.add_child(UiStylesScript.section_title("Inspector"))
	var inspector_spacer: Control = Control.new()
	inspector_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_header.add_child(inspector_spacer)
	_inspector_collapse_button = Button.new()
	_inspector_collapse_button.text = UiIconsScript.label("collapse")
	_inspector_collapse_button.tooltip_text = "Collapse inspector dock"
	_inspector_collapse_button.custom_minimum_size = Vector2(24, UiStylesScript.ROW_HEIGHT)
	_inspector_collapse_button.pressed.connect(_toggle_inspector_dock)
	inspector_header.add_child(_inspector_collapse_button)
	inspector_host = InspectorHostScript.new()
	scroll.add_child(inspector_host)
	preset_picker = PresetPickerScript.new()
	preset_picker.preset_selected.connect(_select_preset)
	preset_picker.compare_requested.connect(_run_preset_compare)
	inspector_host.add_child(preset_picker)
	preset_detail = UiStylesScript.caption("")
	preset_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_host.add_child(preset_detail)
	inheritance_row = InheritanceRowScript.new()
	inspector_host.add_child(inheritance_row)
	composition_section = AccordionSectionScript.new("Composition", true)
	inspector_host.add_section(composition_section, PackedStringArray(["composition", "rotation", "framing", "occupancy"]))
	var composition_body: VBoxContainer = composition_section.get_body()
	_add_rotation_dial(composition_body, "Yaw", "yaw", -180.0, 180.0, 0.0)
	_add_rotation_dial(composition_body, "Pitch", "pitch", -90.0, 90.0, -8.0)
	_add_rotation_dial(composition_body, "Roll", "roll", -180.0, 180.0, 0.0)
	_add_scrub_slider(composition_body, "Occupancy", "occupancy", 0.40, 0.95, 0.82, 0.01, "%")
	_add_scrub_slider(composition_body, "Scale", "scale", 0.40, 1.60, 1.0, 0.01, "×")
	_add_scrub_slider(composition_body, "Padding", "padding", 0.0, 0.45, 0.08, 0.01, "%")
	var camera_section: AccordionSectionScript = AccordionSectionScript.new("Camera", false)
	inspector_host.add_section(camera_section, PackedStringArray(["camera", "projection", "fov", "orthographic"]))
	var camera_body: VBoxContainer = camera_section.get_body()
	info_labels["projection"] = _add_info_row(camera_body, "Projection", "orthographic")
	info_labels["orientation"] = _add_info_row(camera_body, "Orientation", "—")
	info_labels["fov"] = _add_info_row(camera_body, "FOV", "—")
	info_labels["ortho"] = _add_info_row(camera_body, "Ortho size", "—")
	var lighting_section: AccordionSectionScript = AccordionSectionScript.new("Lighting", false)
	inspector_host.add_section(lighting_section, PackedStringArray(["lighting", "key", "fill", "rim", "shadow"]))
	var lighting_body: VBoxContainer = lighting_section.get_body()
	info_labels["lighting_rig"] = _add_info_row(lighting_body, "Rig", "—")
	info_labels["key_light"] = _add_info_row(lighting_body, "Key", "—")
	info_labels["fill_light"] = _add_info_row(lighting_body, "Fill", "—")
	info_labels["rim_light"] = _add_info_row(lighting_body, "Rim", "—")
	var background_section: AccordionSectionScript = AccordionSectionScript.new("Background", false)
	inspector_host.add_section(background_section, PackedStringArray(["background", "environment", "transparent"]))
	var background_body: VBoxContainer = background_section.get_body()
	info_labels["background"] = _add_info_row(background_body, "Mode", "transparent")
	var effects_section: AccordionSectionScript = AccordionSectionScript.new("Effects", false)
	inspector_host.add_section(effects_section, PackedStringArray(["effects", "outline", "shadow", "post"]))
	var effects_body: VBoxContainer = effects_section.get_body()
	info_labels["outline"] = _add_info_row(effects_body, "Outline", "off")
	info_labels["drop_shadow"] = _add_info_row(effects_body, "Drop shadow", "off")
	info_labels["sharpen"] = _add_info_row(effects_body, "Sharpen", "—")
	var output_section: AccordionSectionScript = AccordionSectionScript.new("Output", false)
	inspector_host.add_section(output_section, PackedStringArray(["output", "resolution", "export", "png"]))
	var output_body: VBoxContainer = output_section.get_body()
	info_labels["resolution"] = _add_info_row(output_body, "Resolution", "256×256")
	info_labels["supersampling"] = _add_info_row(output_body, "Supersampling", "2×")
	render_recipe_panel = RenderRecipePanelScript.new()
	output_body.add_child(render_recipe_panel)
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	var reset: Button = Button.new()
	reset.text = "Reset overrides"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_reset_override)
	action_row.add_child(reset)
	save_override_button = Button.new()
	save_override_button.text = "Save sidecar"
	save_override_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_override_button.pressed.connect(_save_override)
	action_row.add_child(save_override_button)
	output_body.add_child(action_row)
	return dock

func _add_info_row(parent: VBoxContainer, label_text: String, value_text: String) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var name_label: Label = UiStylesScript.label(label_text, 11, UiStylesScript.MUTED)
	name_label.custom_minimum_size = Vector2(88, 0)
	row.add_child(name_label)
	var value_label: Label = UiStylesScript.label(value_text, 11, UiStylesScript.TEXT)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)
	return value_label

func _add_rotation_dial(parent: VBoxContainer, label_text: String, key: String, minimum: float, maximum: float, value: float) -> void:
	var dial: RotationDialScript = RotationDialScript.new(label_text, minimum, maximum, value, 1.0, key)
	dial.value_changed.connect(_on_rotation_changed.bind(key))
	dial.reset_requested.connect(_reset_property.bind(key))
	parent.add_child(dial)
	rotation_controls[key] = dial
	inspector_host.register_property(key, dial, PackedStringArray([label_text, key]))

func _add_scrub_slider(parent: VBoxContainer, label_text: String, key: String, minimum: float, maximum: float, value: float, step: float, suffix: String) -> void:
	var scrub: ScrubSliderScript = ScrubSliderScript.new(label_text, minimum, maximum, value, step, suffix, key)
	scrub.value_changed.connect(_on_scrub_changed.bind(key))
	scrub.reset_requested.connect(_reset_property.bind(key))
	parent.add_child(scrub)
	scrub_controls[key] = scrub
	inspector_host.register_property(key, scrub, PackedStringArray([label_text, key]))

func _vsep() -> Control:
	var sep: ColorRect = ColorRect.new()
	sep.custom_minimum_size = Vector2(1, 24)
	sep.color = UiStylesScript.SEPARATOR
	return sep

func _select_preset(preset_id: String, record_history: bool = true) -> void:
	if record_history and not _undo_guard:
		_record_undo()
	active_preset = preset_service.get_preset(preset_id)
	if active_preset == null:
		return
	preset_picker.set_active_preset(preset_id, active_preset.get_display_name())
	if record_history:
		_reset_override(false)
	_reload_live_preview()
	_update_ui_state()
	_update_viewport_stats()
	_call_refresh_preview(true)

func _load_fixture_sources() -> void:
	var fixture_names: Array[String] = ["sword.gltf", "potion.gltf", "shield.gltf", "helmet.gltf", "creature.gltf"]
	for filename in fixture_names:
		var path: String = ProjectSettings.globalize_path("res://fixtures/%s" % filename)
		if FileAccess.file_exists(path):
			_add_source(path)
	if not sources.is_empty():
		source_browser.select_index(0)
		if empty_workspace != null:
			empty_workspace.hide()

func _load_recent_files() -> void:
	var recent_data: Dictionary = IconForgeFileUtil.read_json(RECENT_PATH)
	var recent: Array = recent_data.get("paths", [])
	if empty_workspace != null:
		empty_workspace.set_recent_files(recent)

func _remember_recent(path: String) -> void:
	var recent_data: Dictionary = IconForgeFileUtil.read_json(RECENT_PATH)
	var recent: Array = recent_data.get("paths", [])
	var normalized: String = _normalize_source_path(path)
	recent.erase(normalized)
	recent.insert(0, normalized)
	if recent.size() > 8:
		recent.resize(8)
	IconForgeFileUtil.write_json_atomic(RECENT_PATH, {"paths": recent})
	if empty_workspace != null:
		empty_workspace.set_recent_files(recent)

func _open_recent_source(path: String) -> void:
	handle_dropped_files(PackedStringArray([path]))

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
	return IconForgeFileUtil.normalize_path(path)

func _add_source(path: String) -> bool:
	var normalized_path: String = _normalize_source_path(path)
	if not FileAccess.file_exists(normalized_path) or not IconForgeFileUtil.is_supported_source(normalized_path) or sources.has(normalized_path):
		return false
	sources.append(normalized_path)
	source_browser.add_source(normalized_path)
	if empty_workspace != null:
		empty_workspace.hide()
	batch_panel.set_sources(sources, active_preset.get_display_name() if active_preset != null else "—")
	return true

func handle_dropped_files(files: PackedStringArray) -> Dictionary:
	var accepted: Array[String] = []
	var rejected: Array[String] = []
	var duplicates: Array[String] = []
	for raw_path in files:
		var normalized_path: String = _normalize_source_path(str(raw_path))
		if not FileAccess.file_exists(normalized_path) or not IconForgeFileUtil.is_supported_source(normalized_path):
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
			source_browser.select_index(selected_index)
	if not accepted.is_empty():
		_set_status("Added %d source%s" % [accepted.size(), "" if accepted.size() == 1 else "s"])
		for path in accepted:
			_remember_recent(path)
	elif not duplicates.is_empty():
		_set_status("Source already loaded.")
	else:
		_set_status("No supported source files dropped.")
	var result: Dictionary = {"success": not accepted.is_empty(), "accepted": accepted, "rejected": rejected, "duplicates": duplicates}
	last_drop_result = result
	source_drop_handled.emit(result)
	return result

func _on_source_context_menu(index: int, at_position: Vector2) -> void:
	if index < 0 or index >= sources.size():
		return
	var menu: PopupMenu = PopupMenu.new()
	menu.add_item("Render", 0)
	menu.add_item("Save Sidecar", 1)
	menu.add_item("Reset Overrides", 2)
	menu.add_item("Copy Path", 3)
	menu.add_item("Remove", 4)
	menu.id_pressed.connect(func(id: int) -> void:
		match id:
			0:
				source_browser.select_index(index)
				_call_refresh_preview(true)
			1:
				source_browser.select_index(index)
				_save_override()
			2:
				source_browser.select_index(index)
				_reset_override()
			3:
				_copy_to_clipboard(sources[index])
			4:
				sources.remove_at(index)
				source_browser.clear_sources()
				for path in sources:
					source_browser.add_source(path)
		menu.queue_free()
	)
	add_child(menu)
	menu.position = Vector2i(at_position)
	menu.popup()

func _on_source_selected(index: int) -> void:
	if index < 0 or index >= sources.size():
		return
	if not _undo_guard:
		_record_undo()
	active_source = sources[index]
	if empty_workspace != null:
		empty_workspace.hide()
	var sidecar_result: Dictionary = override_service.load_for_source(active_source)
	sidecar_invalid = not bool(sidecar_result.get("success", false)) and bool(sidecar_result.get("found", false))
	sidecar_error = sidecar_result.get("error", {}) if sidecar_invalid else {}
	if sidecar_invalid:
		active_override = {}
		source_detail.text = "%s\nSidecar invalid — %s" % [active_source.get_file(), str(sidecar_error.get("message", "Override sidecar failed validation."))]
		_set_status("Sidecar invalid — fix %s before preview, export, or save." % override_service.sidecar_path(active_source).get_file())
		variants_panel.set_variants(session.get_variants(active_source))
		_sync_controls_from_override()
		_update_ui_state()
		return
	active_override = sidecar_result.get("override", {}).duplicate(true)
	var result: Dictionary = inspector.inspect(active_source)
	_last_inspection = result.duplicate(true)
	if bool(result.get("success", false)):
		source_detail.text = "%s\n%s  •  %s tris  •  %s meshes" % [active_source.get_file(), _dimensions_text(result.get("dimensions", [])), _format_number(int(result.get("triangle_count", 0))), str(result.get("mesh_count", 0))]
		_set_status("Ready — %s" % active_source.get_file())
	else:
		source_detail.text = str(result.get("error", {}).get("message", "Unable to inspect source."))
	variants_panel.set_variants(session.get_variants(active_source))
	_sync_controls_from_override()
	_reload_live_preview()
	_update_ui_state()
	_update_viewport_stats()
	_call_refresh_preview(true)

func _on_rotation_changed(value: float, key: String) -> void:
	if _syncing_controls:
		return
	active_override[key] = value
	_on_override_changed(key)

func _on_scrub_changed(value: float, key: String) -> void:
	if _syncing_controls:
		return
	active_override[key] = value
	_on_override_changed(key)

func _on_override_changed(key: String, schedule_hq: bool = true) -> void:
	_update_modified_state()
	inheritance_row.update_inheritance(active_preset, active_override, key)
	_update_viewport_stats()
	if live_preview != null and live_preview.is_active():
		live_preview.apply_override(active_override, active_preset)
	if schedule_hq:
		_call_refresh_preview()

func _on_orbit_changed(delta: Vector2) -> void:
	if active_preset == null:
		return
	active_override = PreviewCameraScript.apply_orbit_delta(active_override, active_preset, delta)
	_sync_orbit_controls()
	_on_override_changed("yaw", false)

func _on_zoom_changed(delta: float) -> void:
	if active_preset == null:
		return
	active_override = PreviewCameraScript.apply_zoom_delta(active_override, active_preset, delta)
	_syncing_controls = true
	_set_scrub_value("occupancy", float(active_override["occupancy"]))
	_syncing_controls = false
	_on_override_changed("occupancy", false)
	_schedule_hq_preview()

func _on_lighting_changed(light_type: String, angle: Vector3) -> void:
	if active_preset == null:
		return
	_record_undo()
	if not active_override.has("lighting"):
		active_override["lighting"] = {}
	if not active_override["lighting"].has(light_type):
		active_override["lighting"][light_type] = {}
	active_override["lighting"][light_type]["angle"] = [angle.x, angle.y, angle.z]
	_update_modified_state()
	inheritance_row.update_inheritance(active_preset, active_override, "lighting.%s" % light_type)
	if live_preview != null and live_preview.is_active():
		live_preview.apply_override(active_override, active_preset)
	_schedule_hq_preview()

func _on_interaction_started() -> void:
	_interacting = true
	if live_preview != null and live_preview.is_active():
		live_preview.set_interactive(true)
	if viewport_hud != null:
		viewport_hud.set_status("Orbiting live preview")

func _on_interaction_ended() -> void:
	_interacting = false
	if live_preview != null and live_preview.is_active():
		live_preview.set_interactive(false)
	if viewport_hud != null:
		viewport_hud.set_status("Finalizing preview…")
	_schedule_hq_preview()

func _schedule_hq_preview() -> void:
	_preview_timer.stop()
	_preview_timer.wait_time = float(INTERACTION_DEBOUNCE_MS) / 1000.0
	_call_refresh_preview()

func _sync_orbit_controls() -> void:
	_syncing_controls = true
	_set_rotation_value("yaw", float(active_override.get("yaw", PreviewCameraScript.preset_value(active_preset, "yaw"))))
	_set_rotation_value("pitch", float(active_override.get("pitch", PreviewCameraScript.preset_value(active_preset, "pitch"))))
	_syncing_controls = false

func _reload_live_preview() -> void:
	if live_preview == null or active_preset == null or active_source.is_empty():
		return
	if not bool(_last_inspection.get("success", false)) or str(_last_inspection.get("kind", "3d")) != "3d":
		live_preview.clear_scene()
		preview_display.show()
		return
	var loaded: Dictionary = live_preview.load_scene(active_source, active_preset, active_override, _last_inspection)
	if bool(loaded.get("success", false)):
		preview_display.hide()
	else:
		live_preview.clear_scene()
		preview_display.show()

func _on_viewport_mode_changed(mode_name: String) -> void:
	if preview_display != null:
		preview_display.set_view_mode(mode_name)

func _on_guides_toggled(enabled: bool) -> void:
	if viewport_hud != null:
		viewport_hud.show_grid = enabled
		viewport_hud.show_safe_zone = enabled
		viewport_hud.queue_redraw()

func _on_checker_changed(mode_name: String) -> void:
	if checkerboard != null:
		checkerboard.set_display_mode(mode_name)

func _on_compare_toggled(enabled: bool) -> void:
	compare_mode = "split" if enabled else "off"
	if compare_overlay != null:
		compare_overlay.set_mode(compare_mode)
		compare_overlay.set_textures(_texture_a if _texture_a != null else preview_display.get_base_texture(), _texture_b)

func _on_preview_quality_changed(mode: String) -> void:
	preview_quality = mode
	_call_refresh_preview(true)

func _on_snapshot_requested(slot: String) -> void:
	var state: Dictionary = _capture_state()
	session.store_snapshot(slot, state)
	if slot == "A":
		_texture_a = preview_display.get_base_texture()
	else:
		_texture_b = preview_display.get_base_texture()
	if compare_overlay != null:
		compare_overlay.set_textures(_texture_a, _texture_b)
	_set_status("Snapshot %s stored" % slot)

func _toggle_viewport_maximize() -> void:
	viewport_maximized = not viewport_maximized
	_toolbar.visible = not viewport_maximized
	_sources_dock.visible = not viewport_maximized
	_inspector_dock.visible = not viewport_maximized
	bottom_tray.visible = not viewport_maximized
	if viewport_hud != null:
		viewport_hud.set_status("Press Esc to exit maximize" if viewport_maximized else "Orbit to adjust yaw and pitch")

func _on_auto_frame_requested() -> void:
	if active_preset == null:
		return
	_record_undo()
	var target: float = float(active_preset.data.get("camera", {}).get("occupancy", 0.82))
	active_override["occupancy"] = target
	_set_scrub_value("occupancy", target)
	_on_override_changed("occupancy")
	_call_refresh_preview(true)

func _on_export_menu(id: int) -> void:
	match id:
		0:
			export_drawer.open_at(export_button, _export_defaults())
		1:
			export_format = "png"
			_export_current()
		2:
			_run_batch_render()
		10:
			_copy_to_clipboard(CliRecipeScript.build_render_command(active_source, active_preset.get_id() if active_preset else "", active_override))
		11:
			_copy_to_clipboard(CliRecipeScript.build_effective_preset_json(active_preset, active_override))
		12:
			bottom_tray.expand_tab("quality")
		20:
			_open_output_folder()

func _on_export_drawer_confirmed(settings: Dictionary) -> void:
	export_destination = str(settings.get("destination", export_destination))
	_pending_export_settings = settings.duplicate(true)
	export_format = "png"
	_export_current()
	_pending_export_settings = {}

static func build_export_override(base: Dictionary, settings: Dictionary) -> Dictionary:
	var export_override: Dictionary = base.duplicate(true)
	if settings.has("width"):
		export_override["width"] = int(settings.get("width", 256))
	if settings.has("height"):
		export_override["height"] = int(settings.get("height", 256))
	if settings.has("supersampling"):
		export_override["supersampling"] = int(settings.get("supersampling", 2))
	if settings.has("transparent"):
		export_override["background"] = "transparent" if bool(settings.get("transparent", true)) else "gradient"
	return export_override

func _export_defaults() -> Dictionary:
	var width: int = 256
	var height: int = 256
	if active_preset != null:
		width = int(active_preset.data.get("resolution", {}).get("width", 256))
		height = int(active_preset.data.get("resolution", {}).get("height", 256))
	return {"width": width, "height": height, "destination": ProjectSettings.globalize_path(export_destination)}

func _call_refresh_preview(immediate: bool = false) -> void:
	_render_serial += 1
	if not immediate:
		_preview_timer.wait_time = float(PREVIEW_DEBOUNCE_MS) / 1000.0
	_preview_timer.stop()
	if immediate:
		call_deferred("_refresh_preview", _render_serial)
		return
	_preview_timer.start()

func _on_preview_debounce_timeout() -> void:
	call_deferred("_refresh_preview", _render_serial)

func _preview_render_override() -> Dictionary:
	var merged: Dictionary = active_override.duplicate(true)
	match preview_quality:
		"fast":
			merged["supersampling"] = 1
		"export":
			merged["supersampling"] = int(active_preset.data.get("supersampling", 2)) if active_preset != null else 2
	return merged

func _refresh_preview(serial: int) -> void:
	if serial != _render_serial or active_source.is_empty() or active_preset == null:
		return
	var requested_serial: int = serial
	_set_status("Rendering preview…")
	if viewport_hud != null:
		viewport_hud.set_render_status("Rendering latest change…")
	var result: Dictionary = await render_service.render(active_source, active_preset, _preview_render_override(), preview_path, true)
	if requested_serial != _render_serial:
		return
	_preview_completion_serial = requested_serial
	if viewport_hud != null:
		viewport_hud.set_render_status("")
	if bool(result.get("success", false)):
		if empty_workspace != null:
			empty_workspace.hide()
		var image: Image = Image.new()
		if image.load(preview_path) == OK:
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			source_browser.set_thumbnail(active_source, texture)
			if live_preview != null and live_preview.is_active():
				preview_display.hide()
			else:
				preview_display.show()
				preview_display.set_texture(texture)
		var occupancy: float = float(result.get("metrics", {}).get("occupancy", 0.0))
		var target: float = float(active_preset.data.get("camera", {}).get("occupancy", 0.82))
		source_browser.set_quality(active_source, occupancy >= target * 0.96 and occupancy <= target * 1.08, occupancy)
		if viewport_hud != null:
			viewport_hud.set_occupancy(target, occupancy)
		_set_status("Preview ready — %.1f%% occupancy" % (occupancy * 100.0))
	else:
		_set_status("Render error — %s" % str(result.get("error", {}).get("message", "Unknown error")))
	_update_viewport_stats()
	quality_panel.update_from_render(result, active_preset)
	render_recipe_panel.update_recipe(active_source, active_preset, active_override, result)
	last_preview_result = result
	preview_updated.emit(result)
	_update_tray_summary(result)
	var summary: String = "%s  %.1f%% occupancy" % [active_preset.get_display_name(), float(result.get("metrics", {}).get("occupancy", 0.0)) * 100.0]
	session.record_render({"time": Time.get_time_string_from_system(), "summary": summary, "state": _capture_state(), "result": result.duplicate(true)})
	session.append_log("%s  %s" % [Time.get_time_string_from_system(), summary])
	history_panel.set_entries(session.render_history)
	log_panel.set_lines(session.render_log)
	if lighting_gizmo != null and active_preset != null:
		var merged_lighting: Dictionary = PresetDefinition.deep_merge(active_preset.data.get("lighting", {}), active_override.get("lighting", {}))
		lighting_gizmo.set_lighting(lighting_service.resolve(merged_lighting))

func _update_tray_summary(result: Dictionary) -> void:
	if bottom_tray == null or active_source.is_empty() or result.is_empty():
		return
	var occupancy: float = float(result.get("metrics", {}).get("occupancy", 0.0)) * 100.0
	bottom_tray.set_summary("✓ %s   %.1f%%   %d pass%s" % [active_source.get_file(), occupancy, int(result.get("render_passes", 1)), "" if int(result.get("render_passes", 1)) == 1 else "es"])

func _capture_state() -> Dictionary:
	return {
		"source": active_source,
		"preset_id": active_preset.get_id() if active_preset != null else "",
		"override": active_override.duplicate(true)
	}

func _apply_state(state: Dictionary) -> void:
	_undo_guard = true
	if state.has("source") and not str(state["source"]).is_empty() and sources.has(state["source"]):
		active_source = str(state["source"])
		source_browser.select_index(sources.find(active_source))
	if state.has("preset_id") and not str(state["preset_id"]).is_empty():
		var preset_id: String = str(state["preset_id"])
		active_preset = preset_service.get_preset(preset_id)
		if active_preset != null:
			preset_picker.set_active_preset(preset_id, active_preset.get_display_name())
	active_override = state.get("override", {}).duplicate(true)
	if not active_source.is_empty():
		var inspection: Dictionary = inspector.inspect(active_source)
		_last_inspection = inspection.duplicate(true)
	_sync_controls_from_override()
	_update_ui_state()
	_update_viewport_stats()
	_reload_live_preview()
	_undo_guard = false
	_call_refresh_preview(true)

func _record_undo() -> void:
	if _undo_guard:
		return
	session.push_undo(_capture_state())

func _undo() -> void:
	if not session.can_undo():
		return
	var previous: Dictionary = session.undo(_capture_state())
	_apply_state(previous)

func _redo() -> void:
	if not session.can_redo():
		return
	var next_state: Dictionary = session.redo(_capture_state())
	_apply_state(next_state)

func _reset_property(key: String) -> void:
	_record_undo()
	active_override.erase(key)
	_sync_controls_from_override()
	_on_override_changed(key)
	_call_refresh_preview(true)

func _reset_override(refresh: bool = true) -> void:
	_record_undo()
	active_override.clear()
	if active_preset == null:
		return
	_sync_controls_from_preset()
	_update_modified_state()
	_update_viewport_stats()
	if live_preview != null and live_preview.is_active():
		live_preview.apply_override(active_override, active_preset)
	if refresh:
		_call_refresh_preview(true)

func _sync_controls_from_preset() -> void:
	if active_preset == null:
		return
	_set_rotation_value("yaw", float(active_preset.data.get("camera", {}).get("yaw", 0.0)))
	_set_rotation_value("pitch", float(active_preset.data.get("camera", {}).get("pitch", -8.0)))
	_set_rotation_value("roll", float(active_preset.data.get("camera", {}).get("roll", 0.0)))
	_set_scrub_value("occupancy", float(active_preset.data.get("camera", {}).get("occupancy", 0.82)))
	_set_scrub_value("scale", float(active_preset.data.get("composition", {}).get("scale", 1.0)))
	_set_scrub_value("padding", float(active_preset.data.get("camera", {}).get("padding", 0.08)))

func _sync_controls_from_override() -> void:
	if active_preset == null:
		return
	_set_rotation_value("yaw", float(active_override.get("yaw", active_preset.data.get("camera", {}).get("yaw", 0.0))))
	_set_rotation_value("pitch", float(active_override.get("pitch", active_preset.data.get("camera", {}).get("pitch", -8.0))))
	_set_rotation_value("roll", float(active_override.get("roll", active_preset.data.get("camera", {}).get("roll", 0.0))))
	_set_scrub_value("occupancy", float(active_override.get("occupancy", active_preset.data.get("camera", {}).get("occupancy", 0.82))))
	_set_scrub_value("scale", float(active_override.get("scale", active_preset.data.get("composition", {}).get("scale", 1.0))))
	_set_scrub_value("padding", float(active_override.get("padding", active_preset.data.get("camera", {}).get("padding", 0.08))))
	_update_modified_state()

func _update_modified_state() -> void:
	if active_preset == null:
		return
	var modified_any: bool = false
	for key in rotation_controls.keys():
		var overridden: bool = _is_overridden(key)
		rotation_controls[key].set_overridden(overridden)
		if overridden:
			modified_any = true
	for key in scrub_controls.keys():
		var overridden: bool = _is_overridden(key)
		scrub_controls[key].set_overridden(overridden)
		if overridden:
			modified_any = true
	if composition_section != null:
		composition_section.set_modified(modified_any)
	inheritance_row.update_inheritance(active_preset, active_override, "occupancy")

func _is_overridden(key: String) -> bool:
	if not active_override.has(key):
		return false
	return absf(float(active_override[key]) - _preset_value_for_key(key)) > 0.001

func _preset_value_for_key(key: String) -> float:
	if active_preset == null:
		return 0.0
	match key:
		"yaw":
			return float(active_preset.data.get("camera", {}).get("yaw", 0.0))
		"pitch":
			return float(active_preset.data.get("camera", {}).get("pitch", -8.0))
		"roll":
			return float(active_preset.data.get("camera", {}).get("roll", 0.0))
		"occupancy":
			return float(active_preset.data.get("camera", {}).get("occupancy", 0.82))
		"padding":
			return float(active_preset.data.get("camera", {}).get("padding", 0.08))
		"scale":
			return float(active_preset.data.get("composition", {}).get("scale", 1.0))
	return 0.0

func _update_ui_state() -> void:
	var has_source: bool = not active_source.is_empty() and active_preset != null
	export_button.disabled = not has_source
	save_override_button.disabled = not has_source
	undo_button.disabled = not session.can_undo()
	redo_button.disabled = not session.can_redo()
	if empty_workspace != null:
		empty_workspace.visible = not has_source and sources.is_empty()
	if active_preset == null:
		return
	preset_detail.text = "%s  •  %s" % [str(active_preset.data.get("description", "")), str(active_preset.data.get("projection", "orthographic"))]
	_update_info_labels()

func _update_info_labels() -> void:
	if active_preset == null:
		return
	var camera: Dictionary = active_preset.data.get("camera", {})
	var lighting: Dictionary = active_preset.data.get("lighting", {})
	var environment: Dictionary = active_preset.data.get("environment", {})
	var post: Dictionary = active_preset.data.get("post_process", {})
	var resolution: Dictionary = active_preset.data.get("resolution", {})
	info_labels["projection"].text = str(active_preset.data.get("projection", "orthographic"))
	info_labels["orientation"].text = str(camera.get("orientation_strategy", "preserve"))
	info_labels["fov"].text = "%.1f°" % float(camera.get("fov", 34.0))
	info_labels["ortho"].text = "%.2f" % float(camera.get("orthographic_size", 2.4))
	info_labels["lighting_rig"].text = str(lighting.get("rig", "studio"))
	info_labels["key_light"].text = "%.2f" % float(lighting.get("key", {}).get("intensity", 1.0))
	info_labels["fill_light"].text = "%.2f" % float(lighting.get("fill", {}).get("intensity", 0.5))
	info_labels["rim_light"].text = "%.2f" % float(lighting.get("rim", {}).get("intensity", 0.5))
	info_labels["background"].text = str(environment.get("background", "transparent"))
	info_labels["outline"].text = "on" if bool(post.get("outline", {}).get("enabled", false)) else "off"
	info_labels["drop_shadow"].text = "on" if bool(post.get("drop_shadow", {}).get("enabled", false)) else "off"
	info_labels["sharpen"].text = "%.2f" % float(post.get("sharpen", 0.0))
	info_labels["resolution"].text = "%s×%s" % [resolution.get("width", 256), resolution.get("height", 256)]
	info_labels["supersampling"].text = "%s×" % str(active_preset.data.get("supersampling", 2))

func _run_preset_compare() -> void:
	if active_source.is_empty() or active_preset == null:
		return
	var results: Array = []
	for preset_id in COMPARE_PRESETS:
		var preset: PresetDefinition = preset_service.get_preset(preset_id)
		if preset == null:
			continue
		var temp_path: String = "user://iconforge/previews/compare_%s.png" % preset_id
		var result: Dictionary = await render_service.render(active_source, preset, active_override, temp_path, true)
		results.append({
			"preset": preset_id,
			"display_name": preset.get_display_name(),
			"metrics": result.get("metrics", {}),
			"success": result.get("success", false)
		})
	preset_compare_dialog.show_results(results)

func _run_batch_render() -> void:
	if sources.is_empty() or active_preset == null:
		return
	var output_dir: String = ProjectSettings.globalize_path(export_destination)
	IconForgeFileUtil.ensure_directory(output_dir)
	batch_panel.set_sources(sources, active_preset.get_display_name())
	var result: Dictionary = await batch_service.render_sources(sources, active_preset, output_dir, {
		"force": true,
		"manifest": true,
		"manifest_path": output_dir.path_join("manifest.json"),
		"override": {},
	})
	var summary: Dictionary = result.get("summary", {})
	var failure_count: int = int(summary.get("failed", 0))
	var warning_count: int = int(summary.get("warnings", 0))
	batch_panel.set_progress(sources.size(), sources.size(), warning_count, failure_count)
	for render in result.get("renders", []):
		if str(render.get("source", "")) == active_source and bool(result.get("success", false)):
			source_browser.set_thumbnail(active_source, preview_display.get_base_texture())
			break
	bottom_tray.expand_tab("batch")
	_set_status("Batch complete — %d/%d" % [int(summary.get("success", 0)), sources.size()])

func _on_variant_selected(index: int) -> void:
	if active_source.is_empty():
		return
	var entries: Array = session.get_variants(active_source)
	if index < 0 or index >= entries.size():
		return
	_record_undo()
	active_override = entries[index].get("override", {}).duplicate(true)
	_sync_controls_from_override()
	_call_refresh_preview(true)

func _on_variant_saved(index: int) -> void:
	if active_source.is_empty():
		return
	var entries: Array = session.get_variants(active_source)
	if index < 0 or index >= entries.size():
		return
	entries[index]["override"] = active_override.duplicate(true)
	session.set_variants(active_source, entries)
	variants_panel.set_variants(entries)
	_set_status("Saved variant %s" % str(entries[index].get("id", "?")))

func _on_history_restore(index: int) -> void:
	if index < 0 or index >= session.render_history.size():
		return
	var entry: Dictionary = session.render_history[index]
	_apply_state(entry.get("state", {}))

func _on_workspace_toggled(batch_enabled: bool) -> void:
	workspace_mode = "batch" if batch_enabled else "single"
	workspace_toggle.text = "Batch" if batch_enabled else "Single"
	if batch_enabled:
		bottom_tray.expand_tab("batch")
		batch_panel.set_sources(sources, active_preset.get_display_name() if active_preset != null else "—")

func _setup_commands() -> void:
	command_palette.set_commands([
		{"id": "frame", "label": "Frame Selected Asset", "keywords": "frame auto"},
		{"id": "reset_framing", "label": "Reset Camera Framing", "keywords": "reset camera"},
		{"id": "export", "label": "Export Current", "keywords": "export png"},
		{"id": "batch", "label": "Batch Render", "keywords": "batch render all"},
		{"id": "preset_compare", "label": "Compare Presets", "keywords": "preset compare"},
		{"id": "save_sidecar", "label": "Save Sidecar", "keywords": "save override"},
		{"id": "copy_cli", "label": "Copy CLI Command", "keywords": "cli recipe agent"},
		{"id": "toggle_guides", "label": "Toggle Guides", "keywords": "guides grid"},
		{"id": "toggle_maximize", "label": "Maximize Viewport", "keywords": "maximize space"},
		{"id": "toggle_sources", "label": "Toggle Sources Dock", "keywords": "sources dock panel"},
		{"id": "toggle_inspector", "label": "Toggle Inspector Dock", "keywords": "inspector dock panel"},
		{"id": "load_samples", "label": "Load Sample Assets", "keywords": "samples fixtures"}
	])

func _on_command(command_id: String) -> void:
	match command_id:
		"frame":
			_on_auto_frame_requested()
		"reset_framing":
			_reset_override()
		"export":
			export_drawer.open_at(export_button, _export_defaults())
		"batch":
			_run_batch_render()
		"preset_compare":
			_run_preset_compare()
		"save_sidecar":
			_save_override()
		"copy_cli":
			_copy_to_clipboard(CliRecipeScript.build_render_command(active_source, active_preset.get_id() if active_preset else "", active_override))
		"toggle_guides":
			_on_guides_toggled(not viewport_mode_bar.guides_enabled)
		"toggle_maximize":
			_toggle_viewport_maximize()
		"toggle_sources":
			_toggle_sources_dock()
		"toggle_inspector":
			_toggle_inspector_dock()
		"load_samples":
			_load_fixture_sources()

func _open_command_palette() -> void:
	command_palette.open_centered()

func _copy_to_clipboard(text: String) -> void:
	DisplayServer.clipboard_set(text)
	_set_status("Copied to clipboard")

func _open_output_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path(export_destination))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_ESCAPE and viewport_maximized:
			_toggle_viewport_maximize()
			get_viewport().set_input_as_handled()
			return
		if key_event.ctrl_pressed or key_event.meta_pressed:
			match key_event.keycode:
				KEY_K:
					_open_command_palette()
					get_viewport().set_input_as_handled()
				KEY_Z:
					_undo()
					get_viewport().set_input_as_handled()
				KEY_Y:
					_redo()
					get_viewport().set_input_as_handled()
				KEY_S:
					_save_override()
					get_viewport().set_input_as_handled()
				KEY_E:
					export_drawer.open_at(export_button, _export_defaults())
					get_viewport().set_input_as_handled()
				KEY_O:
					_open_source_dialog()
					get_viewport().set_input_as_handled()
		match key_event.keycode:
			KEY_F:
				_on_auto_frame_requested()
			KEY_R:
				if not key_event.ctrl_pressed:
					_reset_override()
			KEY_G:
				_on_guides_toggled(not viewport_mode_bar.guides_enabled)
			KEY_B:
				if key_event.alt_pressed:
					_on_snapshot_requested("B")
				elif not key_event.ctrl_pressed:
					_on_checker_changed("dark" if checkerboard.display_mode == "checker" else "checker")
			KEY_SPACE:
				_toggle_viewport_maximize()
			KEY_A:
				if key_event.alt_pressed:
					_on_snapshot_requested("A")

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
		IconForgeFileUtil.ensure_directory(screenshot_path)
		screenshot_error = get_viewport().get_texture().get_image().save_png(screenshot_path)
	last_drop_result = {}
	get_window().files_dropped.emit(PackedStringArray([normalized_source, normalized_source + ".unsupported"]))
	await get_tree().process_frame
	var duplicate_result: Dictionary = last_drop_result.duplicate(true)
	var accepted_ok: bool = bool(drop_result.get("success", false)) and Array(drop_result.get("accepted", [])).has(normalized_source)
	var selected_ok: bool = active_source == normalized_source
	var preview_ok: bool = bool(preview_result.get("success", false)) and image_valid
	var duplicate_handling_ok: bool = Array(duplicate_result.get("duplicates", [])).has(normalized_source) and not Array(duplicate_result.get("rejected", [])).is_empty()
	return {
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
		IconForgeFileUtil.ensure_directory(screenshot_path)
		screenshot_error = get_viewport().get_texture().get_image().save_png(screenshot_path)
	var accepted: Array = drop_result.get("accepted", [])
	return {
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

func _wait_for_preview_result(timeout_ms: int) -> Dictionary:
	var started_at: int = Time.get_ticks_msec()
	while last_preview_result.is_empty() and Time.get_ticks_msec() - started_at < timeout_ms:
		await get_tree().process_frame
	return last_preview_result.duplicate(true)

func _export_current() -> void:
	if sidecar_invalid:
		_set_status("Cannot export — sidecar is invalid.")
		return
	if active_source.is_empty() or active_preset == null:
		_set_status("Choose a source before exporting.")
		return
	var settings: Dictionary = _pending_export_settings
	var overwrite: bool = true if settings.is_empty() else bool(settings.get("overwrite", false))
	var export_override: Dictionary = build_export_override(active_override, settings if not settings.is_empty() else _export_defaults())
	var output_dir: String = ProjectSettings.globalize_path(export_destination)
	IconForgeFileUtil.ensure_directory(output_dir)
	var output_path: String = output_dir.path_join("%s_%s.%s" % [IconForgeFileUtil.source_name(active_source), active_preset.get_id(), export_format])
	if not overwrite and FileAccess.file_exists(output_path):
		_set_status("Export skipped — output exists.")
		return
	_set_status("Exporting…")
	var result: Dictionary = await render_service.render(active_source, active_preset, export_override, output_path, overwrite or settings.is_empty())
	if not bool(result.get("success", false)):
		_set_status("Export failed — %s" % str(result.get("error", {}).get("message", "Unknown error")))
		return
	_set_status("Export complete — %s" % output_path.get_file())

func _save_override() -> void:
	if active_source.is_empty():
		return
	if sidecar_invalid:
		_set_status("Cannot save sidecar — current sidecar is invalid. Fix the file first.")
		return
	var result: Dictionary = override_service.save_for_source(active_source, active_override)
	_set_status("Saved sidecar" if bool(result.get("success", false)) else "Could not save sidecar")

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
			if FileAccess.file_exists(path) and IconForgeFileUtil.is_supported_source(path):
				return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		var files: PackedStringArray = PackedStringArray()
		for raw_path in data.get("files", []):
			files.append(str(raw_path))
		handle_dropped_files(files)

func _on_viewport_context_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		var menu: PopupMenu = PopupMenu.new()
		menu.add_item("Frame Asset", 0)
		menu.add_item("Reset Camera", 1)
		menu.add_submenu_node_item("Background", _background_submenu())
		menu.add_item("Toggle Guides", 2)
		menu.add_item("Capture Compare A", 3)
		menu.add_item("Capture Compare B", 4)
		menu.id_pressed.connect(func(id: int) -> void:
			match id:
				0:
					_on_auto_frame_requested()
				1:
					_reset_override()
				2:
					_on_guides_toggled(not viewport_mode_bar.guides_enabled)
				3:
					_on_snapshot_requested("A")
				4:
					_on_snapshot_requested("B")
			menu.queue_free()
		)
		add_child(menu)
		menu.position = Vector2i(DisplayServer.mouse_get_position())
		menu.popup()

func _background_submenu() -> PopupMenu:
	var submenu: PopupMenu = PopupMenu.new()
	var modes: Array[String] = ["checker", "dark", "light", "split"]
	for index in modes.size():
		submenu.add_item(modes[index].capitalize(), index)
	submenu.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < modes.size():
			_on_checker_changed(modes[id])
	)
	return submenu

func _on_files_dropped(files: PackedStringArray) -> void:
	last_drop_files = files.duplicate()
	drop_event_received = true
	handle_dropped_files(files)

func _set_rotation_value(key: String, value: float) -> void:
	if rotation_controls.has(key):
		rotation_controls[key].set_value(value, false)

func _set_scrub_value(key: String, value: float) -> void:
	if scrub_controls.has(key):
		scrub_controls[key].set_value(value, false)

func _update_viewport_stats() -> void:
	if viewport_hud == null or active_preset == null:
		return
	var yaw: float = float(active_override.get("yaw", active_preset.data.get("camera", {}).get("yaw", 0.0)))
	var pitch: float = float(active_override.get("pitch", active_preset.data.get("camera", {}).get("pitch", -8.0)))
	var roll: float = float(active_override.get("roll", active_preset.data.get("camera", {}).get("roll", 0.0)))
	var focal: String = "Ortho %.2f" % float(active_preset.data.get("camera", {}).get("orthographic_size", 2.4)) if str(active_preset.data.get("projection", "orthographic")) == "orthographic" else "FOV %.1f°" % float(active_preset.data.get("camera", {}).get("fov", 34.0))
	var rig: String = str(active_preset.data.get("lighting", {}).get("rig", "studio"))
	viewport_hud.set_camera_stats(yaw, pitch, roll, focal, rig)
	var width: int = int(active_override.get("width", active_preset.data.get("resolution", {}).get("width", 256)))
	var height: int = int(active_override.get("height", active_preset.data.get("resolution", {}).get("height", 256)))
	var ss: int = int(active_override.get("supersampling", active_preset.data.get("supersampling", 2)))
	viewport_hud.set_output_stats("%d²" % width if width == height else "%d×%d" % [width, height], str(active_preset.data.get("projection", "orthographic")).to_upper(), "%d× SS" % ss)
	viewport_hud.set_occupancy(float(active_override.get("occupancy", active_preset.data.get("camera", {}).get("occupancy", 0.82))), float(last_preview_result.get("metrics", {}).get("occupancy", -1.0)))

func _set_status(text: String) -> void:
	if bottom_tray != null and not text.begins_with("Rendering"):
		bottom_tray.set_summary(text)

func _dimensions_text(dimensions: Array) -> String:
	if dimensions.size() < 3:
		return "unknown bounds"
	return "%.2f × %.2f × %.2f" % [float(dimensions[0]), float(dimensions[1]), float(dimensions[2])]

func _format_number(value: int) -> String:
	return "%.1fk" % (float(value) / 1000.0) if value >= 1000 else str(value)

func get_render_serial_for_test() -> int:
	return _render_serial

func _apply_workspace_settings() -> void:
	_workspace_settings = WorkspaceLayoutScript.load_settings()
	if _main_split != null:
		_main_split.split_offset = int(_workspace_settings.get("split_offset", 260))
	_set_sources_collapsed(bool(_workspace_settings.get("sources_collapsed", false)), false)
	_set_inspector_collapsed(bool(_workspace_settings.get("inspector_collapsed", false)), false)

func _persist_workspace_settings() -> void:
	_workspace_settings["split_offset"] = _main_split.split_offset if _main_split != null else int(_workspace_settings.get("split_offset", 260))
	_workspace_settings["sources_collapsed"] = _sources_collapsed
	_workspace_settings["inspector_collapsed"] = _inspector_collapsed
	WorkspaceLayoutScript.save_settings(_workspace_settings)

func _on_main_split_dragged(offset: int) -> void:
	_workspace_settings["split_offset"] = offset
	WorkspaceLayoutScript.save_settings(_workspace_settings)

func _toggle_sources_dock() -> void:
	_set_sources_collapsed(not _sources_collapsed)

func _toggle_inspector_dock() -> void:
	_set_inspector_collapsed(not _inspector_collapsed)

func _set_sources_collapsed(collapsed: bool, persist: bool = true) -> void:
	_sources_collapsed = collapsed
	if source_browser != null:
		source_browser.visible = not collapsed
	if source_detail != null:
		source_detail.visible = not collapsed
	if _sources_dock != null:
		_sources_dock.custom_minimum_size.x = 36 if collapsed else 220
	if _sources_collapse_button != null:
		_sources_collapse_button.text = UiIconsScript.label("expand" if collapsed else "collapse")
	if persist:
		_persist_workspace_settings()

func _set_inspector_collapsed(collapsed: bool, persist: bool = true) -> void:
	_inspector_collapsed = collapsed
	if inspector_host != null:
		inspector_host.visible = not collapsed
	if _inspector_dock != null:
		_inspector_dock.custom_minimum_size.x = 36 if collapsed else 280
	if _inspector_collapse_button != null:
		_inspector_collapse_button.text = UiIconsScript.label("expand" if collapsed else "collapse")
	if persist:
		_persist_workspace_settings()

func get_preview_completion_serial_for_test() -> int:
	return _preview_completion_serial

func get_override_for_test() -> Dictionary:
	return active_override.duplicate(true)

func is_live_preview_active_for_test() -> bool:
	return live_preview != null and live_preview.is_active()

func get_live_preview_values_for_test() -> Dictionary:
	if live_preview == null:
		return {}
	return live_preview.get_effective_values()

func apply_orbit_delta_for_test(delta: Vector2) -> void:
	_on_orbit_changed(delta)

func apply_zoom_delta_for_test(delta: float) -> void:
	_on_zoom_changed(delta)

func simulate_interaction_end_for_test() -> void:
	_on_interaction_ended()

func trigger_preview_refresh_for_test(immediate: bool = false) -> void:
	_call_refresh_preview(immediate)

func _wait_for_render_serial(serial: int, timeout_ms: int) -> bool:
	var started_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < timeout_ms:
		if _preview_completion_serial >= serial:
			return true
		await get_tree().process_frame
	return false

func run_interaction_e2e(source_path: String) -> Dictionary:
	var normalized_source: String = _normalize_source_path(source_path)
	last_preview_result = {}
	_preview_completion_serial = 0
	get_window().files_dropped.emit(PackedStringArray([normalized_source]))
	await get_tree().process_frame
	var live_wait_started: int = Time.get_ticks_msec()
	while not is_live_preview_active_for_test() and Time.get_ticks_msec() - live_wait_started < 15000:
		await get_tree().process_frame
	var live_active: bool = is_live_preview_active_for_test()
	var initial_serial: int = _render_serial
	await _wait_for_render_serial(initial_serial, 30000)
	var serial_before_orbit: int = _render_serial
	var yaw_before: float = float(active_override.get("yaw", PreviewCameraScript.preset_value(active_preset, "yaw")))
	var pitch_before: float = float(active_override.get("pitch", PreviewCameraScript.preset_value(active_preset, "pitch")))
	var occupancy_before: float = float(active_override.get("occupancy", PreviewCameraScript.preset_value(active_preset, "occupancy")))
	_on_interaction_started()
	apply_orbit_delta_for_test(Vector2(24.0, -12.0))
	var expected_yaw: float = yaw_before + 24.0 * PreviewCameraScript.YAW_SENSITIVITY
	var expected_pitch: float = clampf(pitch_before + -12.0 * PreviewCameraScript.PITCH_SENSITIVITY, -90.0, 90.0)
	var orbit_override_ok: bool = is_equal_approx(float(active_override["yaw"]), expected_yaw) and is_equal_approx(float(active_override["pitch"]), expected_pitch)
	var live_values: Dictionary = get_live_preview_values_for_test()
	var orbit_live_ok: bool = is_equal_approx(float(live_values.get("yaw", 0.0)), expected_yaw) and is_equal_approx(float(live_values.get("pitch", 0.0)), expected_pitch)
	var no_hq_during_drag: bool = _render_serial == serial_before_orbit
	apply_zoom_delta_for_test(3.0)
	var expected_occupancy: float = clampf(occupancy_before + 3.0 * PreviewCameraScript.ZOOM_SENSITIVITY, 0.4, 0.95)
	var zoom_override_ok: bool = is_equal_approx(float(active_override["occupancy"]), expected_occupancy)
	var zoom_live_ok: bool = is_equal_approx(float(get_live_preview_values_for_test().get("occupancy", 0.0)), expected_occupancy)
	simulate_interaction_end_for_test()
	var debounce_ok: bool = not _preview_timer.is_stopped() or _preview_completion_serial >= _render_serial
	var interaction_serial: int = _render_serial
	var interaction_preview_ok: bool = await _wait_for_render_serial(interaction_serial, 30000)
	var stale_start_yaw: float = float(active_override["yaw"])
	trigger_preview_refresh_for_test(true)
	await get_tree().process_frame
	apply_orbit_delta_for_test(Vector2(40.0, 0.0))
	var stale_serial: int = _render_serial
	trigger_preview_refresh_for_test(true)
	var stale_cancel_ok: bool = await _wait_for_render_serial(stale_serial, 30000)
	var stale_state_ok: bool = is_equal_approx(float(active_override["yaw"]), stale_start_yaw + 40.0 * PreviewCameraScript.YAW_SENSITIVITY)
	var stale_live_ok: bool = is_equal_approx(float(get_live_preview_values_for_test().get("yaw", 0.0)), float(active_override["yaw"]))
	return {
		"success": live_active and orbit_override_ok and orbit_live_ok and no_hq_during_drag and zoom_override_ok and zoom_live_ok and debounce_ok and interaction_preview_ok and stale_cancel_ok and stale_state_ok and stale_live_ok,
		"source": normalized_source,
		"live_active": live_active,
		"orbit_override_ok": orbit_override_ok,
		"orbit_live_ok": orbit_live_ok,
		"no_hq_during_drag": no_hq_during_drag,
		"zoom_override_ok": zoom_override_ok,
		"zoom_live_ok": zoom_live_ok,
		"debounce_ok": debounce_ok,
		"interaction_preview_ok": interaction_preview_ok,
		"stale_cancel_ok": stale_cancel_ok,
		"stale_state_ok": stale_state_ok,
		"stale_live_ok": stale_live_ok,
		"override": get_override_for_test(),
		"live_values": get_live_preview_values_for_test()
	}
