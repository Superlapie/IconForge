extends RefCounted
class_name RenderService

const MAX_CORRECTION_PASSES: int = 5
const AssetLoaderScript = preload("res://core/services/asset_loader.gd")

var inspector: AssetInspector = AssetInspector.new()
var framing: FramingService = FramingService.new()
var processor: ImageProcessor = ImageProcessor.new()
var quality: QualityService = QualityService.new()
var overrides: OverrideService = OverrideService.new()
var cache: CacheService = CacheService.new()
var lighting: LightingRigService = LightingRigService.new()
var loader: RefCounted = AssetLoaderScript.new()

func render(source_path: String, preset: PresetDefinition, override: Dictionary = {}, output_path: String = "", force: bool = false) -> Dictionary:
	var inspection: Dictionary = inspector.inspect(source_path)
	if not bool(inspection.get("success", false)):
		return {
			"success": false,
			"source": source_path,
			"preset": preset.get_id(),
			"error": inspection.get("error", {"code": "SOURCE_INSPECTION_FAILED", "message": "Asset inspection failed."})
		}
	var sidecar: Dictionary = overrides.load_for_source(source_path)
	if not bool(sidecar.get("success", false)):
		return {"success": false, "source": source_path, "preset": preset.get_id(), "error": sidecar.get("error")}
	var merged_override: Dictionary = PresetDefinition.deep_merge(sidecar.get("override", {}), override)
	var effective_preset: PresetDefinition = _effective_preset(preset, merged_override)
	var expected_size: Vector2i = _resolution(effective_preset)
	var analyze_alpha: bool = str(effective_preset.data.get("environment", {}).get("background", "transparent")) == "transparent"
	var cache_key: String = cache.build_key(source_path, effective_preset, merged_override)
	if not output_path.is_empty():
		var cached: Dictionary = cache.lookup(cache_key, output_path, force)
		if bool(cached.get("hit", false)):
			var cached_quality: Dictionary = quality.inspect_image_file(output_path, expected_size, _target_occupancy(effective_preset), analyze_alpha)
			if bool(cached_quality.get("success", false)):
				return {"success": true, "source": source_path, "output": output_path, "preset": preset.get_id(), "cache_hit": true, "warnings": cached_quality.get("warnings", []), "metrics": cached_quality.get("metrics", {})}
		if FileAccess.file_exists(output_path) and not force and not bool(effective_preset.data.get("output", {}).get("overwrite", false)):
			return {"success": false, "source": source_path, "output": output_path, "preset": preset.get_id(), "error": {"code": "OUTPUT_EXISTS", "message": "Output exists. Use --force to replace it or choose a new path.", "path": output_path}}

	var raw_result: Dictionary
	if inspection.get("kind", "3d") == "image":
		raw_result = _render_static_image(source_path, effective_preset)
	else:
		raw_result = await _render_3d(source_path, inspection, effective_preset, merged_override)
	if not bool(raw_result.get("success", false)):
		return raw_result

	var processed: Dictionary = processor.process(raw_result["image"], effective_preset, expected_size)
	if not bool(processed.get("success", false)):
		return {"success": false, "source": source_path, "preset": preset.get_id(), "error": {"code": "IMAGE_PROCESS_FAILED", "message": "Image processing failed.", "details": processed.get("warnings", [])}}
	var image: Image = processed["image"]
	var output_quality: Dictionary = quality.inspect_image(image, expected_size, _target_occupancy(effective_preset), output_path, analyze_alpha)
	if raw_result.has("metrics"):
		# Presentation layers such as a contact shadow can touch the output edge
		# even when the actual model silhouette is correctly framed. Quality gates
		# therefore use the captured pre-processing silhouette for 3D framing.
		var frame_quality: Dictionary = quality.inspect_image(raw_result["image"], Vector2i.ZERO, _target_occupancy(effective_preset), "", true)
		if analyze_alpha:
			output_quality["warnings"] = frame_quality.get("warnings", [])
		else:
			output_quality["metrics"] = raw_result["metrics"]
		if analyze_alpha:
			output_quality["metrics"] = frame_quality.get("metrics", raw_result["metrics"])
	var warnings: Array = []
	warnings.append_array(raw_result.get("warnings", []))
	warnings.append_array(processed.get("warnings", []))
	warnings.append_array(output_quality.get("warnings", []))
	for raw_warning in raw_result.get("warnings", []):
		if str(raw_warning.get("code", "")) == "OUTPUT_TRANSPARENT":
			var raw_errors: Array = output_quality.get("errors", [])
			raw_errors.append({"code": "OUTPUT_TRANSPARENT", "message": "The captured 3D source contains no visible silhouette.", "source": source_path})
			output_quality["errors"] = raw_errors
			output_quality["success"] = false
	if not output_path.is_empty():
		var save_error: Error = _save_png_atomic(image, output_path)
		if save_error != OK:
			return {"success": false, "source": source_path, "output": output_path, "preset": preset.get_id(), "error": {"code": "OUTPUT_WRITE_FAILED", "message": "Could not save PNG output.", "path": output_path, "godot_error": save_error}}
		cache.store(cache_key, source_path, output_path, preset.get_id(), output_quality.get("metrics", {}))
	return {
		"success": bool(output_quality.get("success", false)),
		"source": source_path,
		"output": output_path,
		"preset": preset.get_id(),
		"cache_hit": false,
		"warnings": warnings,
		"errors": output_quality.get("errors", []),
		"metrics": output_quality.get("metrics", {}),
		"inspection": inspection,
		"render_passes": raw_result.get("render_passes", 1)
	}

func _effective_preset(preset: PresetDefinition, override: Dictionary) -> PresetDefinition:
	var patch: Dictionary = override.duplicate(true)
	var camera_patch: Dictionary = patch.get("camera", {}).duplicate(true)
	for key in ["yaw", "pitch", "roll", "fov", "distance", "orthographic_size", "occupancy", "padding"]:
		if patch.has(key):
			camera_patch[key] = patch[key]
			patch.erase(key)
	if not camera_patch.is_empty():
		patch["camera"] = camera_patch
	var composition_patch: Dictionary = patch.get("composition", {}).duplicate(true)
	for key in ["scale", "vertical_bias", "horizontal_bias"]:
		if patch.has(key):
			composition_patch[key] = patch[key]
			patch.erase(key)
	if not composition_patch.is_empty():
		patch["composition"] = composition_patch
	if patch.has("width") or patch.has("height"):
		var resolution: Dictionary = preset.data.get("resolution", {}).duplicate(true)
		if patch.has("width"):
			resolution["width"] = int(patch["width"])
			patch.erase("width")
		if patch.has("height"):
			resolution["height"] = int(patch["height"])
			patch.erase("height")
		patch["resolution"] = resolution
	if patch.has("background"):
		var environment: Dictionary = preset.data.get("environment", {}).duplicate(true)
		environment["background"] = str(patch["background"])
		patch.erase("background")
		patch["environment"] = environment
	return preset.resolve(patch)

func _render_static_image(source_path: String, preset: PresetDefinition) -> Dictionary:
	var image: Image = Image.new()
	var error: Error = image.load(source_path)
	if error != OK:
		return {"success": false, "source": source_path, "error": {"code": "SOURCE_IMAGE_LOAD_FAILED", "message": "Could not decode image source.", "path": source_path}}
	var size: Vector2i = _resolution(preset) * int(preset.data.get("supersampling", 1))
	var fitted: Image = _fit_static_image(image, size, preset)
	return {"success": true, "image": fitted, "warnings": [], "render_passes": 1}

func _fit_static_image(source: Image, target_size: Vector2i, preset: PresetDefinition) -> Image:
	var image: Image = source.duplicate()
	var fit_mode: String = str(preset.data.get("composition", {}).get("fit", "contain"))
	var source_size: Vector2 = Vector2(image.get_width(), image.get_height())
	var target_vector: Vector2 = Vector2(target_size)
	var padding: float = clampf(float(preset.data.get("camera", {}).get("padding", 0.0)), 0.0, 0.45)
	var padded_target: Vector2 = target_vector * (1.0 - padding * 2.0)
	var scale_factor: float = minf(padded_target.x / maxf(source_size.x, 1.0), padded_target.y / maxf(source_size.y, 1.0))
	if fit_mode == "cover":
		scale_factor = maxf(padded_target.x / maxf(source_size.x, 1.0), padded_target.y / maxf(source_size.y, 1.0))
	var resized: Image = image.duplicate()
	resized.resize(maxi(1, int(source_size.x * scale_factor)), maxi(1, int(source_size.y * scale_factor)), Image.INTERPOLATE_LANCZOS)
	var canvas: Image = Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var offset: Vector2i = Vector2i((target_size.x - resized.get_width()) / 2, (target_size.y - resized.get_height()) / 2)
	canvas.blend_rect(resized, Rect2i(Vector2i.ZERO, resized.get_size()), offset)
	return canvas

func _render_3d(source_path: String, inspection: Dictionary, preset: PresetDefinition, override: Dictionary) -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"success": false, "source": source_path, "error": {"code": "RENDER_NO_SCENE_TREE", "message": "Godot scene tree is unavailable for 3D rendering."}}
	var loaded: Dictionary = loader.load_packed_scene(source_path)
	if not bool(loaded.get("success", false)):
		return loaded
	var packed_scene: PackedScene = loaded["packed_scene"]
	var params: Dictionary = framing.resolve_camera(preset, inspection, override)
	var is_perspective: bool = str(params.get("projection", "orthographic")) == "perspective"
	var current_size: float = float(params["distance"] if is_perspective else params["orthographic_size"])
	var min_zoom: float = float(preset.data.get("camera", {}).get("min_zoom", 0.1))
	var max_zoom: float = float(preset.data.get("camera", {}).get("max_zoom", 100.0))
	var target_occupancy: float = _target_occupancy(preset)
	var last_frame: Image = null
	var last_metrics: Dictionary = {}
	var passes: int = 0
	var warnings: Array = []
	for pass_index in MAX_CORRECTION_PASSES:
		passes = pass_index + 1
		var frame_result: Dictionary = await _render_3d_frame(tree, packed_scene, inspection, preset, params, current_size)
		if not bool(frame_result.get("success", false)):
			return frame_result
		last_frame = frame_result["image"]
		last_metrics = processor.silhouette_metrics(last_frame)
		var clipped: bool = bool(last_metrics.get("clipped", false))
		var actual: float = float(last_metrics.get("occupancy", 0.0))
		if not clipped and actual >= target_occupancy * 0.96 and actual <= target_occupancy * 1.08:
			break
		var next_size: float = framing.correction_size(current_size, target_occupancy, actual, clipped, min_zoom, max_zoom)
		if is_equal_approx(next_size, current_size):
			break
		current_size = next_size
	if last_frame == null:
		return {"success": false, "source": source_path, "error": {"code": "RENDER_EMPTY", "message": "3D renderer produced no frame."}}
	if not bool(last_metrics.get("has_silhouette", false)):
		warnings.append({"code": "OUTPUT_TRANSPARENT", "message": "3D renderer produced a fully transparent frame."})
	elif bool(last_metrics.get("clipped", false)):
		warnings.append({"code": "OUTPUT_CLIPPED", "message": "Bounded auto-framing passes could not fully clear the image border."})
	return {"success": true, "source": source_path, "image": last_frame, "warnings": warnings, "metrics": last_metrics, "render_passes": passes}

func _render_3d_frame(tree: SceneTree, packed_scene: PackedScene, inspection: Dictionary, preset: PresetDefinition, params: Dictionary, ortho_size: float) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	var render_size: Vector2i = _resolution(preset) * int(preset.data.get("supersampling", 1))
	viewport.size = render_size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	tree.root.add_child(viewport)
	var stage: Node3D = Node3D.new()
	stage.name = "RenderStage"
	viewport.add_child(stage)
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.92, 1.0)
	environment.ambient_light_energy = float(preset.data.get("lighting", {}).get("ambient_energy", 0.45))
	environment_node.environment = environment
	stage.add_child(environment_node)
	_add_lights(stage, lighting.resolve(preset.data.get("lighting", {})))
	var object: Node3D = packed_scene.instantiate() as Node3D
	if object == null:
		viewport.queue_free()
		return {"success": false, "error": {"code": "RENDER_SOURCE_INSTANTIATE_FAILED", "message": "Godot could not instantiate the imported 3D scene."}}
	object.position = -_array_to_vector(inspection.get("center", [0.0, 0.0, 0.0]))
	object.rotation_degrees = params["orientation"]
	object.scale = Vector3.ONE * float(params.get("scale", 1.0))
	stage.add_child(object)
	var camera: Camera3D = Camera3D.new()
	camera.name = "StudioCamera"
	camera.current = true
	camera.near = 0.01
	camera.far = 10000.0
	var original_center: Vector3 = _array_to_vector(inspection.get("center", [0.0, 0.0, 0.0]))
	var target: Vector3 = params["target"] - original_center
	var projection: String = str(params.get("projection", "orthographic"))
	if projection == "perspective":
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = float(params.get("fov", 34.0))
		camera.position = target + Vector3(0.0, 0.0, ortho_size)
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = ortho_size
		camera.position = target + Vector3(0.0, 0.0, maxf(float(params.get("radius", 1.0)) * 4.0, 2.0))
	stage.add_child(camera)
	camera.look_at(target, Vector3.UP)
	await tree.process_frame
	await tree.process_frame
	RenderingServer.force_draw()
	await tree.process_frame
	var image: Image = viewport.get_texture().get_image()
	viewport.free()
	return {"success": true, "image": image}

func _add_lights(stage: Node3D, lighting: Dictionary) -> void:
	for type in ["key", "fill", "rim"]:
		var definition: Dictionary = lighting.get(type, {})
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.name = "%sLight" % type.capitalize()
		light.rotation_degrees = _array_to_vector(definition.get("angle", [0.0, 0.0, 0.0]))
		light.light_energy = float(definition.get("intensity", 0.5))
		light.light_color = _color_from_array(definition.get("color", [1.0, 1.0, 1.0]))
		light.shadow_enabled = bool(definition.get("shadow", false))
		stage.add_child(light)

func _save_png_atomic(image: Image, path: String) -> Error:
	var directory_error: Error = IconStudioFileUtil.ensure_directory(path)
	if directory_error != OK:
		return directory_error
	var temp_path: String = "%s.tmp.%s.png" % [path, str(Time.get_ticks_usec())]
	var save_error: Error = image.save_png(temp_path)
	if save_error != OK:
		return save_error
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))

func _resolution(preset: PresetDefinition) -> Vector2i:
	var resolution: Dictionary = preset.data.get("resolution", {})
	return Vector2i(int(resolution.get("width", 256)), int(resolution.get("height", 256)))

func _target_occupancy(preset: PresetDefinition) -> float:
	return clampf(float(preset.data.get("camera", {}).get("occupancy", 0.82)), 0.05, 0.99)

func _array_to_vector(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func _color_from_array(value: Variant) -> Color:
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]) if value.size() > 3 else 1.0)
	return Color.WHITE
