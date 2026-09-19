extends RefCounted
class_name OverrideService

const ALLOWED_TOP_LEVEL: Array[String] = [
	"yaw", "pitch", "roll", "occupancy", "padding", "scale",
	"camera", "lighting", "composition", "environment", "width", "height", "background",
]
const ALLOWED_CAMERA_KEYS: Array[String] = [
	"yaw", "pitch", "roll", "fov", "distance", "orthographic_size", "occupancy", "padding",
	"min_zoom", "max_zoom", "orientation_strategy", "auto_frame",
]
const ALLOWED_COMPOSITION_KEYS: Array[String] = [
	"center_mode", "vertical_bias", "horizontal_bias", "scale", "rotation_order", "fit",
]
const ALLOWED_ENVIRONMENT_KEYS: Array[String] = [
	"background", "color", "gradient_top", "gradient_bottom", "texture",
]

## Canonical sidecar lighting schema. Human/maintainer sidecars only.
## Safe-mode Machine API does not accept lighting fields.
const LIGHTING_SCHEMA: Dictionary = {
	"keys": ["rig", "ambient_energy", "key", "fill", "rim"],
	"light_types": ["key", "fill", "rim"],
	"light_keys": ["angle", "intensity", "color", "shadow"],
}

static func lighting_schema() -> Dictionary:
	return LIGHTING_SCHEMA.duplicate(true)

static func sidecar_schema() -> Dictionary:
	return {
		"top_level": ALLOWED_TOP_LEVEL.duplicate(),
		"camera": ALLOWED_CAMERA_KEYS.duplicate(),
		"composition": ALLOWED_COMPOSITION_KEYS.duplicate(),
		"environment": ALLOWED_ENVIRONMENT_KEYS.duplicate(),
		"lighting": lighting_schema(),
	}

func sidecar_path(source_path: String) -> String:
	var stem: String = source_path.get_file().get_basename()
	return source_path.get_base_dir().path_join("%s.icon.json" % stem)

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
	_reject_unknown_keys(override, ALLOWED_TOP_LEVEL, "", errors)
	for key in ["yaw", "pitch", "roll"]:
		if override.has(key) and not _finite_number(override[key]):
			errors.append({"code": "OVERRIDE_VALUE_INVALID", "path": key, "message": "%s must be a finite number." % key})
	if override.has("occupancy") and (not _finite_number(override["occupancy"]) or float(override["occupancy"]) < 0.05 or float(override["occupancy"]) > 0.99):
		errors.append({"code": "OVERRIDE_OCCUPANCY_INVALID", "path": "occupancy", "message": "occupancy must be between 0.05 and 0.99."})
	if override.has("padding") and (not _finite_number(override["padding"]) or float(override["padding"]) < 0.0 or float(override["padding"]) > 0.45):
		errors.append({"code": "OVERRIDE_PADDING_INVALID", "path": "padding", "message": "padding must be between 0 and 0.45."})
	if override.has("scale") and not _finite_number(override["scale"]):
		errors.append({"code": "OVERRIDE_VALUE_INVALID", "path": "scale", "message": "scale must be a finite number."})
	if override.has("width") and not _finite_number(override["width"]):
		errors.append({"code": "OVERRIDE_VALUE_INVALID", "path": "width", "message": "width must be a finite number."})
	if override.has("height") and not _finite_number(override["height"]):
		errors.append({"code": "OVERRIDE_VALUE_INVALID", "path": "height", "message": "height must be a finite number."})
	if override.has("background") and typeof(override["background"]) != TYPE_STRING:
		errors.append({"code": "OVERRIDE_VALUE_INVALID", "path": "background", "message": "background must be a string."})
	if override.has("camera"):
		_validate_camera(override["camera"], errors)
	if override.has("lighting"):
		_validate_lighting(override["lighting"], errors)
	if override.has("composition"):
		_validate_object(override["composition"], ALLOWED_COMPOSITION_KEYS, "composition", "OVERRIDE_VALUE_INVALID", "composition must be an object.", errors)
	if override.has("environment"):
		_validate_object(override["environment"], ALLOWED_ENVIRONMENT_KEYS, "environment", "OVERRIDE_VALUE_INVALID", "environment must be an object.", errors)
	return errors

func _validate_camera(value: Variant, errors: Array) -> void:
	if not (value is Dictionary):
		errors.append({"code": "OVERRIDE_CAMERA_INVALID", "path": "camera", "message": "camera must be an object."})
		return
	var camera: Dictionary = value
	_reject_unknown_keys(camera, ALLOWED_CAMERA_KEYS, "camera", errors)
	for key in ["min_zoom", "max_zoom"]:
		if camera.has(key) and (not _finite_number(camera[key]) or float(camera[key]) < 0.001 or float(camera[key]) > 100000.0):
			errors.append({"code": "OVERRIDE_CAMERA_VALUE_INVALID", "path": "camera.%s" % key, "message": "%s must be between 0.001 and 100000." % key})
	if camera.has("min_zoom") and camera.has("max_zoom") and _finite_number(camera["min_zoom"]) and _finite_number(camera["max_zoom"]) and float(camera["min_zoom"]) > float(camera["max_zoom"]):
		errors.append({"code": "OVERRIDE_CAMERA_ZOOM_RANGE_INVALID", "path": "camera", "message": "camera.min_zoom cannot exceed camera.max_zoom."})

func _validate_lighting(value: Variant, errors: Array) -> void:
	if not (value is Dictionary):
		errors.append({"code": "OVERRIDE_LIGHTING_INVALID", "path": "lighting", "message": "lighting must be an object."})
		return
	var lighting: Dictionary = value
	var allowed_keys: Array = LIGHTING_SCHEMA["keys"]
	_reject_unknown_keys(lighting, allowed_keys, "lighting", errors)
	if lighting.has("rig") and typeof(lighting["rig"]) != TYPE_STRING:
		errors.append({"code": "OVERRIDE_LIGHTING_INVALID", "path": "lighting.rig", "message": "lighting.rig must be a string."})
	if lighting.has("ambient_energy") and not _finite_number(lighting["ambient_energy"]):
		errors.append({"code": "OVERRIDE_LIGHTING_INVALID", "path": "lighting.ambient_energy", "message": "lighting.ambient_energy must be a finite number."})
	for light_type in LIGHTING_SCHEMA["light_types"]:
		if lighting.has(light_type):
			_validate_light(lighting[light_type], "lighting.%s" % str(light_type), errors)

func _validate_light(value: Variant, path: String, errors: Array) -> void:
	if not (value is Dictionary):
		errors.append({"code": "OVERRIDE_LIGHTING_INVALID", "path": path, "message": "%s must be an object." % path})
		return
	var light: Dictionary = value
	var allowed_keys: Array = LIGHTING_SCHEMA["light_keys"]
	_reject_unknown_keys(light, allowed_keys, path, errors)
	if light.has("angle"):
		_validate_number_array(light["angle"], "%s.angle" % path, 3, 3, "OVERRIDE_LIGHTING_ANGLE_INVALID", "angle must be a 3-number array.", errors)
	if light.has("intensity") and not _finite_number(light["intensity"]):
		errors.append({"code": "OVERRIDE_LIGHTING_INVALID", "path": "%s.intensity" % path, "message": "%s.intensity must be a finite number." % path})
	if light.has("color"):
		_validate_number_array(light["color"], "%s.color" % path, 3, 4, "OVERRIDE_LIGHTING_INVALID", "color must be a 3- or 4-number array.", errors)
	if light.has("shadow") and typeof(light["shadow"]) != TYPE_BOOL:
		errors.append({"code": "OVERRIDE_LIGHTING_INVALID", "path": "%s.shadow" % path, "message": "%s.shadow must be a boolean." % path})

func _validate_object(value: Variant, allowed: Array, path: String, invalid_code: String, invalid_message: String, errors: Array) -> void:
	if not (value is Dictionary):
		errors.append({"code": invalid_code, "path": path, "message": invalid_message})
		return
	_reject_unknown_keys(value, allowed, path, errors)

func _validate_number_array(value: Variant, path: String, min_size: int, max_size: int, code: String, message: String, errors: Array) -> void:
	if not (value is Array) or (value as Array).size() < min_size or (value as Array).size() > max_size:
		errors.append({"code": code, "path": path, "message": message})
		return
	var index: int = 0
	for item in value:
		if not _finite_number(item):
			errors.append({"code": code, "path": "%s[%d]" % [path, index], "message": "%s values must be finite numbers." % path})
		index += 1

func _reject_unknown_keys(container: Dictionary, allowed: Array, path: String, errors: Array) -> void:
	for key in container.keys():
		if allowed.has(str(key)):
			continue
		var field_path: String = str(key) if path.is_empty() else "%s.%s" % [path, str(key)]
		errors.append({"code": "OVERRIDE_UNKNOWN_FIELD", "path": field_path, "message": "Unknown sidecar field '%s'." % field_path})

func _finite_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value))
