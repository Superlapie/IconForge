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
const ORIENTATION_STRATEGIES: Array[String] = [
	"preserve", "longest_axis_diagonal", "upright", "weapon_diagonal",
	"shield_frontal", "potion_three_quarter", "helmet_three_quarter",
	"creature_portrait", "character_full_body",
]
const BACKGROUND_MODES: Array[String] = ["transparent", "solid", "gradient"]
const CENTER_MODES: Array[String] = ["aabb", "origin"]
const FIT_MODES: Array[String] = ["contain", "cover"]
const ROTATION_ORDERS: Array[String] = ["xyz", "xzy", "yxz", "yzx", "zxy", "zyx"]

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
		"orientation_strategies": ORIENTATION_STRATEGIES.duplicate(),
		"background_modes": BACKGROUND_MODES.duplicate(),
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
	_validate_angle(override, "yaw", -360.0, 360.0, errors)
	_validate_angle(override, "pitch", -90.0, 90.0, errors)
	_validate_angle(override, "roll", -180.0, 180.0, errors)
	_validate_range(override, "occupancy", 0.05, 0.99, "OVERRIDE_OCCUPANCY_INVALID", errors)
	_validate_range(override, "padding", 0.0, 0.45, "OVERRIDE_PADDING_INVALID", errors)
	_validate_range(override, "scale", 0.05, 20.0, "OVERRIDE_VALUE_INVALID", errors)
	_validate_whole_range(override, "width", 16, 8192, "OVERRIDE_VALUE_INVALID", errors)
	_validate_whole_range(override, "height", 16, 8192, "OVERRIDE_VALUE_INVALID", errors)
	if override.has("background"):
		_validate_enum(override["background"], BACKGROUND_MODES, "background", "OVERRIDE_VALUE_INVALID", errors)
	if override.has("camera"):
		_validate_camera(override["camera"], errors)
	if override.has("lighting"):
		_validate_lighting(override["lighting"], errors)
	if override.has("composition"):
		_validate_composition(override["composition"], errors)
	if override.has("environment"):
		_validate_environment(override["environment"], errors)
	return errors

func _validate_camera(value: Variant, errors: Array) -> void:
	if not (value is Dictionary):
		errors.append({"code": "OVERRIDE_CAMERA_INVALID", "path": "camera", "message": "camera must be an object."})
		return
	var camera: Dictionary = value
	_reject_unknown_keys(camera, ALLOWED_CAMERA_KEYS, "camera", errors)
	_validate_angle(camera, "yaw", -360.0, 360.0, errors, "camera.yaw")
	_validate_angle(camera, "pitch", -90.0, 90.0, errors, "camera.pitch")
	_validate_angle(camera, "roll", -180.0, 180.0, errors, "camera.roll")
	_validate_range(camera, "fov", 5.0, 170.0, "OVERRIDE_CAMERA_VALUE_INVALID", errors, "camera.fov")
	_validate_range(camera, "distance", 0.001, 100000.0, "OVERRIDE_CAMERA_VALUE_INVALID", errors, "camera.distance")
	_validate_range(camera, "orthographic_size", 0.001, 100000.0, "OVERRIDE_CAMERA_VALUE_INVALID", errors, "camera.orthographic_size")
	_validate_range(camera, "occupancy", 0.05, 0.99, "OVERRIDE_CAMERA_VALUE_INVALID", errors, "camera.occupancy")
	_validate_range(camera, "padding", 0.0, 0.45, "OVERRIDE_CAMERA_VALUE_INVALID", errors, "camera.padding")
	for key in ["min_zoom", "max_zoom"]:
		_validate_range(camera, key, 0.001, 100000.0, "OVERRIDE_CAMERA_VALUE_INVALID", errors, "camera.%s" % key)
	if camera.has("min_zoom") and camera.has("max_zoom") and _finite_number(camera["min_zoom"]) and _finite_number(camera["max_zoom"]) and float(camera["min_zoom"]) > float(camera["max_zoom"]):
		errors.append({"code": "OVERRIDE_CAMERA_ZOOM_RANGE_INVALID", "path": "camera", "message": "camera.min_zoom cannot exceed camera.max_zoom."})
	if camera.has("orientation_strategy"):
		_validate_enum(camera["orientation_strategy"], ORIENTATION_STRATEGIES, "camera.orientation_strategy", "OVERRIDE_CAMERA_VALUE_INVALID", errors)
	if camera.has("auto_frame") and typeof(camera["auto_frame"]) != TYPE_BOOL:
		errors.append({"code": "OVERRIDE_CAMERA_VALUE_INVALID", "path": "camera.auto_frame", "message": "camera.auto_frame must be a boolean."})

func _validate_lighting(value: Variant, errors: Array) -> void:
	if not (value is Dictionary):
		errors.append({"code": "OVERRIDE_LIGHTING_INVALID", "path": "lighting", "message": "lighting must be an object."})
		return
	var lighting: Dictionary = value
	var allowed_keys: Array = LIGHTING_SCHEMA["keys"]
	_reject_unknown_keys(lighting, allowed_keys, "lighting", errors)
	if lighting.has("rig") and typeof(lighting["rig"]) != TYPE_STRING:
		errors.append({"code": "OVERRIDE_LIGHTING_INVALID", "path": "lighting.rig", "message": "lighting.rig must be a string."})
	_validate_range(lighting, "ambient_energy", 0.0, 16.0, "OVERRIDE_LIGHTING_INVALID", errors, "lighting.ambient_energy")
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
	_validate_range(light, "intensity", 0.0, 20.0, "OVERRIDE_LIGHTING_INVALID", errors, "%s.intensity" % path)
	if light.has("color"):
		_validate_color_array(light["color"], "%s.color" % path, "OVERRIDE_LIGHTING_INVALID", errors)
	if light.has("shadow") and typeof(light["shadow"]) != TYPE_BOOL:
		errors.append({"code": "OVERRIDE_LIGHTING_INVALID", "path": "%s.shadow" % path, "message": "%s.shadow must be a boolean." % path})

func _validate_composition(value: Variant, errors: Array) -> void:
	if not (value is Dictionary):
		errors.append({"code": "OVERRIDE_VALUE_INVALID", "path": "composition", "message": "composition must be an object."})
		return
	var composition: Dictionary = value
	_reject_unknown_keys(composition, ALLOWED_COMPOSITION_KEYS, "composition", errors)
	if composition.has("center_mode"):
		_validate_enum(composition["center_mode"], CENTER_MODES, "composition.center_mode", "OVERRIDE_VALUE_INVALID", errors)
	_validate_range(composition, "vertical_bias", -2.0, 2.0, "OVERRIDE_VALUE_INVALID", errors, "composition.vertical_bias")
	_validate_range(composition, "horizontal_bias", -2.0, 2.0, "OVERRIDE_VALUE_INVALID", errors, "composition.horizontal_bias")
	_validate_range(composition, "scale", 0.05, 20.0, "OVERRIDE_VALUE_INVALID", errors, "composition.scale")
	if composition.has("rotation_order"):
		_validate_enum(composition["rotation_order"], ROTATION_ORDERS, "composition.rotation_order", "OVERRIDE_VALUE_INVALID", errors)
	if composition.has("fit"):
		_validate_enum(composition["fit"], FIT_MODES, "composition.fit", "OVERRIDE_VALUE_INVALID", errors)

func _validate_environment(value: Variant, errors: Array) -> void:
	if not (value is Dictionary):
		errors.append({"code": "OVERRIDE_VALUE_INVALID", "path": "environment", "message": "environment must be an object."})
		return
	var environment: Dictionary = value
	_reject_unknown_keys(environment, ALLOWED_ENVIRONMENT_KEYS, "environment", errors)
	if environment.has("background"):
		_validate_enum(environment["background"], BACKGROUND_MODES, "environment.background", "OVERRIDE_VALUE_INVALID", errors)
	for color_key in ["color", "gradient_top", "gradient_bottom"]:
		if environment.has(color_key):
			_validate_color_array(environment[color_key], "environment.%s" % color_key, "OVERRIDE_VALUE_INVALID", errors)
	if environment.has("texture") and typeof(environment["texture"]) != TYPE_STRING:
		errors.append({"code": "OVERRIDE_VALUE_INVALID", "path": "environment.texture", "message": "environment.texture must be a string."})

func _validate_angle(container: Dictionary, key: String, minimum: float, maximum: float, errors: Array, path: String = "") -> void:
	_validate_range(container, key, minimum, maximum, "OVERRIDE_VALUE_INVALID", errors, path if not path.is_empty() else key)

func _validate_range(container: Dictionary, key: String, minimum: float, maximum: float, code: String, errors: Array, path: String = "") -> void:
	if not container.has(key):
		return
	var field_path: String = path if not path.is_empty() else key
	if not _finite_number(container[key]):
		errors.append({"code": code, "path": field_path, "message": "%s must be a finite number." % field_path})
		return
	var value: float = float(container[key])
	if value < minimum or value > maximum:
		errors.append({"code": code, "path": field_path, "message": "%s must be between %s and %s." % [field_path, str(minimum), str(maximum)]})

func _validate_whole_range(container: Dictionary, key: String, minimum: int, maximum: int, code: String, errors: Array, path: String = "") -> void:
	if not container.has(key):
		return
	var field_path: String = path if not path.is_empty() else key
	if not _whole_number(container[key]):
		errors.append({"code": code, "path": field_path, "message": "%s must be a whole number." % field_path})
		return
	var value: int = int(round(float(container[key])))
	if value < minimum or value > maximum:
		errors.append({"code": code, "path": field_path, "message": "%s must be between %d and %d." % [field_path, minimum, maximum]})

func _validate_enum(value: Variant, allowed: Array, path: String, code: String, errors: Array) -> void:
	if typeof(value) != TYPE_STRING or not allowed.has(str(value)):
		errors.append({"code": code, "path": path, "message": "%s must be one of: %s." % [path, ", ".join(PackedStringArray(allowed))]})

func _validate_color_array(value: Variant, path: String, code: String, errors: Array) -> void:
	_validate_number_array(value, path, 3, 4, code, "color must be a 3- or 4-number array.", errors)
	if not (value is Array):
		return
	var index: int = 0
	for item in value:
		if _finite_number(item):
			var channel: float = float(item)
			if channel < 0.0 or channel > 1.0:
				errors.append({"code": code, "path": "%s[%d]" % [path, index], "message": "%s channel values must be between 0 and 1." % path})
		index += 1

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

func _whole_number(value: Variant) -> bool:
	if not _finite_number(value):
		return false
	return is_equal_approx(float(value), round(float(value)))
