extends RefCounted
class_name PresetDefinition

## Canonical, versioned render preset.  The dictionary is intentionally kept as
## the source of truth so it can be round-tripped through JSON without losing
## fields that a newer CLI may add.

const CURRENT_SCHEMA_VERSION: int = 1

var data: Dictionary = {}
var source_path: String = ""

func _init(raw: Dictionary = {}, path: String = "") -> void:
	source_path = path
	data = normalize(migrate(raw))

static func migrate(raw: Dictionary) -> Dictionary:
	var migrated: Dictionary = raw.duplicate(true)
	var version: int = int(migrated.get("schema_version", 0))

	if version <= 0:
		# Early prototypes used flat camera fields.  Keeping this migration makes
		# hand-authored presets safe to bring forward.
		var camera: Dictionary = migrated.get("camera", {}).duplicate(true)
		for key in ["yaw", "pitch", "roll", "fov", "distance", "orthographic_size", "occupancy", "padding"]:
			if migrated.has(key) and not camera.has(key):
				camera[key] = migrated[key]
				migrated.erase(key)
		migrated["camera"] = camera
		migrated["schema_version"] = CURRENT_SCHEMA_VERSION
	elif version < CURRENT_SCHEMA_VERSION:
		migrated["schema_version"] = CURRENT_SCHEMA_VERSION

	return migrated

static func normalize(raw: Dictionary) -> Dictionary:
	var defaults: Dictionary = default_data(str(raw.get("id", "custom")))
	var result: Dictionary = deep_merge(defaults, raw)
	result["schema_version"] = CURRENT_SCHEMA_VERSION
	return result

static func default_data(preset_id: String = "custom") -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"id": preset_id,
		"display_name": preset_id.replace("_", " ").capitalize(),
		"description": "Custom Icon Studio render preset.",
		"tags": ["custom"],
		"resolution": {"width": 256, "height": 256},
		"supersampling": 1,
		"projection": "orthographic",
		"camera": {
			"orientation_strategy": "preserve",
			"yaw": 0.0,
			"pitch": -8.0,
			"roll": 0.0,
			"fov": 34.0,
			"distance": 3.0,
			"orthographic_size": 2.4,
			"occupancy": 0.82,
			"padding": 0.08,
			"target": [0.0, 0.0, 0.0],
			"offset": [0.0, 0.0, 0.0],
			"min_zoom": 0.1,
			"max_zoom": 100.0,
			"auto_frame": true
		},
		"lighting": {
			"rig": "neutral_studio",
			"ambient_energy": 0.45
		},
		"environment": {
			"background": "transparent",
			"color": [0.04, 0.05, 0.08, 1.0],
			"gradient_top": [0.10, 0.12, 0.20, 1.0],
			"gradient_bottom": [0.02, 0.025, 0.045, 1.0],
			"texture": ""
		},
		"shadows": {"mode": "contact", "opacity": 0.20, "blur": 3.0, "offset": [0.0, 5.0]},
		"post_process": {
			"exposure": 0.0,
			"brightness": 1.0,
			"contrast": 1.0,
			"saturation": 1.0,
			"gamma": 1.0,
			"sharpen": 0.0,
			"bloom": 0.0,
			"alpha_threshold": 0.01,
			"outline": {"enabled": false, "width": 2, "opacity": 0.85, "color": [0.03, 0.04, 0.08, 1.0]},
			"drop_shadow": {"enabled": false, "offset": [0.0, 4.0], "blur": 4, "opacity": 0.26, "color": [0.0, 0.0, 0.0, 1.0]}
		},
		"presentation": {
			"enabled": false,
			"rarity_color": [0.45, 0.65, 1.0, 1.0],
			"aura": {"enabled": false, "radius": 12, "opacity": 0.18},
			"border": {"enabled": false, "width": 3, "opacity": 0.7, "color": [0.45, 0.65, 1.0, 1.0]},
			"corner_badge": {"enabled": false, "size": 22, "color": [0.45, 0.65, 1.0, 1.0]}
		},
		"composition": {
			"center_mode": "aabb",
			"vertical_bias": 0.0,
			"horizontal_bias": 0.0,
			"scale": 1.0,
			"rotation_order": "yxz"
		},
		"output": {
			"format": "png",
			"transparent": true,
			"name_pattern": "{source_name}.png",
			"overwrite": false
		}
	}

static func deep_merge(base: Dictionary, patch: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key in patch.keys():
		var value: Variant = patch[key]
		if value is Dictionary and result.get(key) is Dictionary:
			result[key] = deep_merge(result[key], value)
		else:
			result[key] = value
	return result

func resolve(override: Dictionary) -> PresetDefinition:
	return PresetDefinition.new(deep_merge(data, override), source_path)

func get_id() -> String:
	return str(data.get("id", "custom"))

func get_display_name() -> String:
	return str(data.get("display_name", get_id()))

func to_dict() -> Dictionary:
	return data.duplicate(true)

func to_canonical_json() -> String:
	return JSON.stringify(_sort_value(data), "\t")

func validate() -> Array:
	var errors: Array = []
	var required: Array[String] = ["schema_version", "id", "resolution", "projection", "camera", "lighting", "environment", "post_process", "output"]
	for key in required:
		if not data.has(key):
			errors.append(_error("PRESET_FIELD_MISSING", "Missing required field '%s'." % key, key))

	var preset_id: String = get_id()
	if preset_id.is_empty() or not preset_id.is_valid_filename():
		errors.append(_error("PRESET_ID_INVALID", "Preset id must be a non-empty filename-safe string.", "id"))

	var schema_version: int = int(data.get("schema_version", -1))
	if schema_version != CURRENT_SCHEMA_VERSION:
		errors.append(_error("PRESET_SCHEMA_UNSUPPORTED", "Expected schema version %d, got %d." % [CURRENT_SCHEMA_VERSION, schema_version], "schema_version"))

	var resolution: Dictionary = data.get("resolution", {})
	var width: int = int(resolution.get("width", 0))
	var height: int = int(resolution.get("height", 0))
	if width < 16 or width > 8192:
		errors.append(_error("PRESET_RESOLUTION_INVALID", "Resolution width must be between 16 and 8192.", "resolution.width"))
	if height < 16 or height > 8192:
		errors.append(_error("PRESET_RESOLUTION_INVALID", "Resolution height must be between 16 and 8192.", "resolution.height"))

	var projection: String = str(data.get("projection", ""))
	if not ["orthographic", "perspective"].has(projection):
		errors.append(_error("PRESET_PROJECTION_INVALID", "Projection must be orthographic or perspective.", "projection"))

	var camera: Dictionary = data.get("camera", {})
	_check_number(errors, camera, "occupancy", 0.05, 0.99, "camera.occupancy")
	_check_number(errors, camera, "padding", 0.0, 0.45, "camera.padding")
	_check_number(errors, camera, "fov", 5.0, 170.0, "camera.fov")
	_check_number(errors, camera, "min_zoom", 0.001, 100000.0, "camera.min_zoom")
	_check_number(errors, camera, "max_zoom", 0.001, 100000.0, "camera.max_zoom")
	if float(camera.get("min_zoom", 0.0)) > float(camera.get("max_zoom", 0.0)):
		errors.append(_error("PRESET_ZOOM_RANGE_INVALID", "min_zoom cannot exceed max_zoom.", "camera"))

	var supersampling: int = int(data.get("supersampling", 1))
	if supersampling < 1 or supersampling > 8:
		errors.append(_error("PRESET_SUPERSAMPLING_INVALID", "Supersampling must be between 1 and 8.", "supersampling"))

	var background: String = str(data.get("environment", {}).get("background", "transparent"))
	if not ["transparent", "solid", "gradient"].has(background):
		errors.append(_error("PRESET_BACKGROUND_INVALID", "Background must be transparent, solid, or gradient.", "environment.background"))

	return errors

func _check_number(errors: Array, container: Dictionary, key: String, minimum: float, maximum: float, path: String) -> void:
	if not container.has(key):
		return
	var value: float = float(container[key])
	if not is_finite(value) or value < minimum or value > maximum:
		errors.append(_error("PRESET_VALUE_OUT_OF_RANGE", "%s must be between %s and %s." % [path, minimum, maximum], path))

func _error(code: String, message: String, path: String) -> Dictionary:
	return {"code": code, "message": message, "path": path}

static func _sort_value(value: Variant) -> Variant:
	if value is Dictionary:
		var output: Dictionary = {}
		var keys: Array[String] = []
		for key in value.keys():
			keys.append(str(key))
		keys.sort()
		for key in keys:
			output[key] = _sort_value(value[key])
		return output
	if value is Array:
		var array_output: Array = []
		for item in value:
			array_output.append(_sort_value(item))
		return array_output
	return value
