extends RefCounted
class_name ProductionQuality

const _ErrorCodes = preload("res://core/api/error_codes.gd")

## Authoritative production contract validation for safe-mode outputs.

var quality: QualityService = QualityService.new()

func validate_output(path: String, purpose_def: Dictionary, preset: PresetDefinition, _inspection: Dictionary = {}) -> Dictionary:
	var expected_size: Vector2i = Vector2i(
		int(preset.data.get("resolution", {}).get("width", 256)),
		int(preset.data.get("resolution", {}).get("height", 256))
	)
	var target_occupancy: float = clampf(float(preset.data.get("camera", {}).get("occupancy", 0.82)), 0.05, 0.99)
	var analyze_alpha: bool = bool(purpose_def.get("transparent_required", true))
	var base: Dictionary = quality.inspect_image_file(path, expected_size, target_occupancy, analyze_alpha)
	var errors: Array = base.get("errors", []).duplicate()
	var warnings: Array = base.get("warnings", []).duplicate()
	var metrics: Dictionary = base.get("metrics", {})
	var occupancy_min: float = float(purpose_def.get("occupancy_min", 0.40))
	var occupancy_max: float = float(purpose_def.get("occupancy_max", 0.98))

	if analyze_alpha and not bool(metrics.get("has_silhouette", false)):
		errors.append(_issue("OUTPUT_EMPTY", "Output contains no visible silhouette.", path))

	var occupancy: float = float(metrics.get("occupancy", 0.0))
	if bool(metrics.get("has_silhouette", false)):
		if bool(metrics.get("clipped", false)):
			errors.append(_issue("OUTPUT_CLIPPED", "Silhouette touches the image border after bounded correction.", path))
		if occupancy < occupancy_min:
			errors.append(_issue("OCCUPANCY_LOW", "Occupancy %.3f is below purpose minimum %.3f." % [occupancy, occupancy_min], path))
		elif occupancy > occupancy_max:
			errors.append(_issue("OCCUPANCY_HIGH", "Occupancy %.3f exceeds purpose maximum %.3f." % [occupancy, occupancy_max], path))

	if analyze_alpha and str(preset.data.get("environment", {}).get("background", "transparent")) != "transparent":
		errors.append(_issue("ALPHA_INVALID", "Purpose requires transparent background.", path))

	var status: String = "pass"
	var primary_code: String = ""
	if not errors.is_empty():
		status = "fail"
		primary_code = str(errors[0].get("code", "QUALITY_FAILED"))

	return {
		"success": errors.is_empty(),
		"status": status,
		"code": primary_code,
		"errors": errors,
		"warnings": warnings,
		"metrics": metrics,
		"path": path,
		"occupancy": occupancy,
		"clipped": bool(metrics.get("clipped", false)),
	}

func _issue(code: String, message: String, path: String) -> Dictionary:
	return {"code": code, "message": message, "path": path, "recommended_action": _ErrorCodes.recommended_action(code)}
