extends RefCounted
class_name ProductionQuality

const _ErrorCodes = preload("res://core/api/error_codes.gd")
const _Mapper = preload("res://core/api/error_mapper.gd")

var quality: QualityService = QualityService.new()

func validate_output(path: String, purpose_def: Dictionary, preset: PresetDefinition, frame_metrics: Dictionary = {}) -> Dictionary:
	var expected_size: Vector2i = Vector2i(
		int(purpose_def.get("expected_width", preset.data.get("resolution", {}).get("width", 256))),
		int(purpose_def.get("expected_height", preset.data.get("resolution", {}).get("height", 256)))
	)
	var target_occupancy: float = clampf(float(preset.data.get("camera", {}).get("occupancy", 0.82)), 0.05, 0.99)
	var analyze_alpha: bool = bool(purpose_def.get("transparent_required", true))
	var base: Dictionary = quality.inspect_image_file(path, expected_size, target_occupancy, analyze_alpha)
	var errors: Array = []
	for raw_error in base.get("errors", []):
		errors.append(_mapped_issue(raw_error))
	var warnings: Array = base.get("warnings", []).duplicate()
	var metrics: Dictionary = frame_metrics if not frame_metrics.is_empty() else base.get("metrics", {})
	if frame_metrics.is_empty() and analyze_alpha:
		metrics = base.get("metrics", {})
	var occupancy_min: float = float(purpose_def.get("occupancy_min", 0.40))
	var occupancy_max: float = float(purpose_def.get("occupancy_max", 0.98))

	if metrics.is_empty() and analyze_alpha and FileAccess.file_exists(path):
		var image: Image = Image.new()
		if image.load(path) == OK:
			metrics = ImageProcessor.new().silhouette_metrics(image)

	var occupancy: float = float(metrics.get("occupancy", -1.0))
	var has_framing_metrics: bool = bool(metrics.get("has_silhouette", false)) and occupancy >= 0.0
	if has_framing_metrics:
		if bool(metrics.get("clipped", false)):
			errors.append(_issue("OUTPUT_CLIPPED", "Silhouette touches the image border after bounded correction.", path))
		if occupancy < occupancy_min:
			errors.append(_issue("OCCUPANCY_LOW", "Occupancy %.3f is below purpose minimum %.3f." % [occupancy, occupancy_min], path))
		elif occupancy > occupancy_max:
			errors.append(_issue("OCCUPANCY_HIGH", "Occupancy %.3f exceeds purpose maximum %.3f." % [occupancy, occupancy_max], path))
	elif analyze_alpha:
		errors.append(_issue("OUTPUT_EMPTY", "Output contains no visible silhouette.", path))
	else:
		errors.append(_issue("VALIDATION_METADATA_REQUIRED", "Framing occupancy was not inferred from an opaque final image. Use the production manifest metrics.", path))

	if not analyze_alpha and FileAccess.file_exists(path):
		var opaque_error: Dictionary = _opaque_background_issue(path)
		if not opaque_error.is_empty():
			errors.append(opaque_error)

	var primary_code: String = ""
	if not errors.is_empty():
		primary_code = str(errors[0].get("code", "QUALITY_FAILED"))

	return {
		"success": errors.is_empty(),
		"status": "pass" if errors.is_empty() else "fail",
		"code": primary_code,
		"errors": errors,
		"warnings": warnings,
		"metrics": metrics,
		"path": path,
		"occupancy": float(metrics.get("occupancy", 0.0)),
		"clipped": bool(metrics.get("clipped", false)),
	}

func _mapped_issue(raw_error: Dictionary) -> Dictionary:
	var mapped: Dictionary = _Mapper.map_error(raw_error)
	return _issue(str(mapped.get("code", "QUALITY_FAILED")), str(raw_error.get("message", "Validation failed.")), str(raw_error.get("path", "")))

func _opaque_background_issue(path: String) -> Dictionary:
	var image: Image = Image.new()
	if image.load(path) != OK:
		return {}
	var samples: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(image.get_width() - 1, 0),
		Vector2i(0, image.get_height() - 1),
		Vector2i(image.get_width() - 1, image.get_height() - 1),
	]
	for sample in samples:
		if image.get_pixelv(sample).a < 0.95:
			return _issue("ALPHA_INVALID", "Opaque purpose output does not have an opaque background.", path)
	return {}

func _issue(code: String, message: String, path: String) -> Dictionary:
	return {"code": code, "message": message, "path": path, "recommended_action": _ErrorCodes.recommended_action(code)}
