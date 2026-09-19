extends SubViewportContainer
class_name LivePreviewViewport

const RenderStageScript = preload("res://core/services/render_stage.gd")
const PreviewCameraScript = preload("res://core/services/preview_camera.gd")

signal scene_ready
signal scene_failed(message: String)

var stage_builder: RenderStageScript = RenderStageScript.new()
var viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _object: Node3D
var _inspection: Dictionary = {}
var _preset: PresetDefinition
var _override: Dictionary = {}
var _camera_size: float = 1.0
var _packed_scene: PackedScene
var _is_3d: bool = false
var _interactive: bool = false

func _ready() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.handle_input_locally = false
	add_child(viewport)
	_stage = Node3D.new()
	_stage.name = "LivePreviewStage"
	viewport.add_child(_stage)

func clear_scene() -> void:
	_is_3d = false
	_inspection = {}
	_preset = null
	_override = {}
	_packed_scene = null
	_camera = null
	_object = null
	for child in _stage.get_children():
		child.queue_free()
	hide()

func is_active() -> bool:
	return _is_3d and _camera != null and _object != null

func load_scene(source_path: String, preset: PresetDefinition, override: Dictionary, inspection: Dictionary) -> Dictionary:
	clear_scene()
	if preset == null or not bool(inspection.get("success", false)):
		return {"success": false, "error": {"message": "Missing preset or inspection."}}
	if str(inspection.get("kind", "3d")) != "3d":
		return {"success": false, "error": {"message": "Live preview supports 3D sources only."}}
	var loaded: Dictionary = stage_builder.load_scene(source_path)
	if not bool(loaded.get("success", false)):
		scene_failed.emit(str(loaded.get("error", {}).get("message", "Could not load scene.")))
		return loaded
	_preset = preset
	_override = override.duplicate(true)
	_inspection = inspection.duplicate(true)
	_packed_scene = loaded["packed_scene"]
	var preview_size: Vector2i = _preview_render_size(preset, false)
	stage_builder.configure_viewport(viewport, preview_size, Viewport.MSAA_2X)
	var params: Dictionary = stage_builder.resolve_params(_preset, _inspection, _override)
	_camera_size = stage_builder.resolve_camera_size(params, _preset)
	var built: Dictionary = stage_builder.populate_stage(_stage, _packed_scene, _inspection, _preset, params, _camera_size, _override)
	if not bool(built.get("success", false)):
		scene_failed.emit(str(built.get("error", {}).get("message", "Could not build preview stage.")))
		return built
	_camera = built["camera"]
	_object = built["object"]
	_is_3d = true
	show()
	scene_ready.emit()
	return {"success": true}

func apply_override(override: Dictionary, preset: PresetDefinition = null) -> void:
	if not is_active():
		return
	if preset != null:
		_preset = preset
	_override = override.duplicate(true)
	var params: Dictionary = stage_builder.resolve_params(_preset, _inspection, _override)
	_camera_size = stage_builder.resolve_camera_size(params, _preset)
	stage_builder.update_stage(_camera, _object, _inspection, params, _camera_size)
	stage_builder.update_lights(_stage, _preset, _override)

func set_interactive(active: bool) -> void:
	if not is_active() or _preset == null:
		return
	_interactive = active
	var preview_size: Vector2i = _preview_render_size(_preset, active)
	if viewport.size != preview_size:
		stage_builder.configure_viewport(viewport, preview_size, Viewport.MSAA_2X if active else Viewport.MSAA_4X)

func get_effective_values() -> Dictionary:
	if _preset == null:
		return {}
	return {
		"yaw": PreviewCameraScript.effective_value(_override, _preset, "yaw"),
		"pitch": PreviewCameraScript.effective_value(_override, _preset, "pitch"),
		"roll": PreviewCameraScript.effective_value(_override, _preset, "roll"),
		"occupancy": PreviewCameraScript.effective_value(_override, _preset, "occupancy")
	}

func _preview_render_size(preset: PresetDefinition, interactive: bool) -> Vector2i:
	var resolution: Dictionary = preset.data.get("resolution", {})
	var width: int = int(_override.get("width", resolution.get("width", 256)))
	var height: int = int(_override.get("height", resolution.get("height", 256)))
	if interactive:
		return Vector2i(mini(512, width * 2), mini(512, height * 2))
	var supersampling: int = int(_override.get("supersampling", preset.data.get("supersampling", 2)))
	return Vector2i(width * supersampling, height * supersampling)
