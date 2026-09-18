extends RefCounted
class_name QualityService

func inspect_image_file(path: String, expected_size: Vector2i = Vector2i.ZERO, target_occupancy: float = 0.82, analyze_alpha: bool = true) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"success": false, "errors": [{"code": "OUTPUT_MISSING", "message": "Output image does not exist.", "path": path}], "warnings": [], "metrics": {}}
	var image: Image = Image.new()
	var load_error: Error = image.load(path)
	if load_error != OK:
		return {"success": false, "errors": [{"code": "OUTPUT_INVALID", "message": "Output image could not be decoded.", "path": path}], "warnings": [], "metrics": {}}
	return inspect_image(image, expected_size, target_occupancy, path, analyze_alpha)

func inspect_image(image: Image, expected_size: Vector2i = Vector2i.ZERO, target_occupancy: float = 0.82, path: String = "", analyze_alpha: bool = true) -> Dictionary:
	var metrics: Dictionary = ImageProcessor.new().silhouette_metrics(image) if analyze_alpha else {"has_silhouette": true, "occupancy": -1.0, "clipped": false, "background": true}
	var errors: Array = []
	var warnings: Array = []
	if expected_size != Vector2i.ZERO and image.get_size() != expected_size:
		errors.append(_issue("OUTPUT_RESOLUTION_MISMATCH", "Expected %dx%d, got %dx%d." % [expected_size.x, expected_size.y, image.get_width(), image.get_height()], path))
	if not analyze_alpha:
		return {"success": errors.is_empty(), "errors": errors, "warnings": warnings, "metrics": metrics, "path": path}
	if not bool(metrics.get("has_silhouette", false)):
		errors.append(_issue("OUTPUT_TRANSPARENT", "Output contains no visible pixels above the alpha threshold.", path))
	else:
		var occupancy: float = float(metrics.get("occupancy", 0.0))
		if bool(metrics.get("clipped", false)):
			warnings.append(_issue("OUTPUT_CLIPPED", "Silhouette touches the image border; camera correction may be needed.", path))
		if occupancy < target_occupancy * 0.55:
			warnings.append(_issue("OUTPUT_OCCUPANCY_LOW", "Silhouette occupancy %.1f%% is substantially below target %.1f%%." % [occupancy * 100.0, target_occupancy * 100.0], path))
		elif occupancy > minf(target_occupancy * 1.18, 0.98):
			warnings.append(_issue("OUTPUT_OCCUPANCY_HIGH", "Silhouette occupancy %.1f%% is above target %.1f%%." % [occupancy * 100.0, target_occupancy * 100.0], path))
	return {"success": errors.is_empty(), "errors": errors, "warnings": warnings, "metrics": metrics, "path": path}

func _issue(code: String, message: String, path: String) -> Dictionary:
	return {"code": code, "message": message, "path": path}
