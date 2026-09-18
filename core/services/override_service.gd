extends RefCounted
class_name OverrideService

func sidecar_path(source_path: String) -> String:
	return source_path.get_basename() + ".icon.json"

func load_for_source(source_path: String, explicit_path: String = "") -> Dictionary:
	var path: String = explicit_path if not explicit_path.is_empty() else sidecar_path(source_path)
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"success": true, "found": false, "path": path, "override": {}}
	var override: Dictionary = IconStudioFileUtil.read_json(path)
	if override.is_empty():
		return {"success": false, "found": true, "path": path, "error": {"code": "OVERRIDE_INVALID", "message": "Override sidecar is empty or invalid JSON.", "path": path}}
	var errors: Array = validate(override)
	if not errors.is_empty():
		return {"success": false, "found": true, "path": path, "error": {"code": "OVERRIDE_INVALID", "message": "Override sidecar failed validation.", "path": path, "details": errors}}
	return {"success": true, "found": true, "path": path, "override": override}

func save_for_source(source_path: String, override: Dictionary) -> Dictionary:
	var errors: Array = validate(override)
	if not errors.is_empty():
		return {"success": false, "error": {"code": "OVERRIDE_INVALID", "message": "Override failed validation.", "details": errors}}
	var path: String = sidecar_path(source_path)
	var error: Error = IconStudioFileUtil.write_json_atomic(path, override)
	if error != OK:
		return {"success": false, "error": {"code": "OVERRIDE_WRITE_FAILED", "message": "Could not write asset-specific override.", "path": path, "godot_error": error}}
	return {"success": true, "path": path, "override": override}

func validate(override: Dictionary) -> Array:
	var errors: Array = []
	for key in ["yaw", "pitch", "roll"]:
		if override.has(key) and not _finite_number(override[key]):
			errors.append({"code": "OVERRIDE_VALUE_INVALID", "path": key, "message": "%s must be a finite number." % key})
	if override.has("occupancy") and (not _finite_number(override["occupancy"]) or float(override["occupancy"]) < 0.05 or float(override["occupancy"]) > 0.99):
		errors.append({"code": "OVERRIDE_OCCUPANCY_INVALID", "path": "occupancy", "message": "occupancy must be between 0.05 and 0.99."})
	if override.has("padding") and (not _finite_number(override["padding"]) or float(override["padding"]) < 0.0 or float(override["padding"]) > 0.45):
		errors.append({"code": "OVERRIDE_PADDING_INVALID", "path": "padding", "message": "padding must be between 0 and 0.45."})
	if override.has("camera"):
		if not (override["camera"] is Dictionary):
			errors.append({"code": "OVERRIDE_CAMERA_INVALID", "path": "camera", "message": "camera must be an object."})
		else:
			var camera: Dictionary = override["camera"]
			for key in ["min_zoom", "max_zoom"]:
				if camera.has(key) and (not _finite_number(camera[key]) or float(camera[key]) < 0.001 or float(camera[key]) > 100000.0):
					errors.append({"code": "OVERRIDE_CAMERA_VALUE_INVALID", "path": "camera.%s" % key, "message": "%s must be between 0.001 and 100000." % key})
			if camera.has("min_zoom") and camera.has("max_zoom") and _finite_number(camera["min_zoom"]) and _finite_number(camera["max_zoom"]) and float(camera["min_zoom"]) > float(camera["max_zoom"]):
				errors.append({"code": "OVERRIDE_CAMERA_ZOOM_RANGE_INVALID", "path": "camera", "message": "camera.min_zoom cannot exceed camera.max_zoom."})
	return errors

func _finite_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value))
