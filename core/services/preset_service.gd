extends RefCounted
class_name PresetService

const BUILTIN_DIR: String = "res://presets"
const USER_DIR: String = "user://iconstudio/presets"

var _presets: Dictionary = {}
var _paths: Dictionary = {}

func load_all() -> Array:
	_presets.clear()
	_paths.clear()
	_load_directory(BUILTIN_DIR)
	_load_directory(USER_DIR)
	return list_presets()

func _load_directory(directory_path: String) -> void:
	var dir: DirAccess = DirAccess.open(directory_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while not filename.is_empty():
		if not dir.current_is_dir() and filename.get_extension().to_lower() == "json":
			var path: String = directory_path.path_join(filename)
			var raw: Dictionary = IconStudioFileUtil.read_json(path)
			if not raw.is_empty():
				var preset: PresetDefinition = PresetDefinition.new(raw, path)
				if preset.validate().is_empty():
					_presets[preset.get_id()] = preset
					_paths[preset.get_id()] = path
		filename = dir.get_next()
	dir.list_dir_end()

func list_presets() -> Array:
	var result: Array = []
	var ids: Array[String] = []
	for key in _presets.keys():
		ids.append(str(key))
	ids.sort()
	for preset_id in ids:
		var preset: PresetDefinition = _presets[preset_id]
		result.append({
			"id": preset.get_id(),
			"display_name": preset.get_display_name(),
			"description": str(preset.data.get("description", "")),
			"tags": preset.data.get("tags", []),
			"source": "builtin" if str(_paths[preset_id]).begins_with("res://") else "user",
			"resolution": preset.data.get("resolution", {}),
			"projection": preset.data.get("projection", "orthographic")
		})
	return result

func get_preset(preset_id: String) -> PresetDefinition:
	if _presets.is_empty():
		load_all()
	return _presets.get(preset_id, null)

func require_preset(preset_id: String) -> Dictionary:
	var preset: PresetDefinition = get_preset(preset_id)
	if preset == null:
		return {"success": false, "error": {"code": "PRESET_NOT_FOUND", "message": "Preset '%s' was not found." % preset_id, "preset": preset_id}}
	return {"success": true, "preset": preset}

func save_preset(preset: PresetDefinition, destination: String = "") -> Dictionary:
	var path: String = destination
	if path.is_empty():
		path = USER_DIR.path_join("%s.json" % preset.get_id())
	var validation: Array = preset.validate()
	if not validation.is_empty():
		return {"success": false, "error": {"code": "PRESET_VALIDATION_FAILED", "message": "Preset validation failed.", "details": validation}}
	var error: Error = IconStudioFileUtil.write_text_atomic(path, preset.to_canonical_json())
	if error != OK:
		return {"success": false, "error": {"code": "PRESET_WRITE_FAILED", "message": "Could not write preset.", "path": path, "godot_error": error}}
	_presets[preset.get_id()] = preset
	_paths[preset.get_id()] = path
	return {"success": true, "path": path, "preset": preset.get_id()}

func explain(preset_id: String) -> Dictionary:
	var found: Dictionary = require_preset(preset_id)
	if not found.success:
		return found
	var preset: PresetDefinition = found.preset
	return {
		"success": true,
		"id": preset.get_id(),
		"display_name": preset.get_display_name(),
		"description": preset.data.get("description", ""),
		"tags": preset.data.get("tags", []),
		"projection": preset.data.get("projection", "orthographic"),
		"resolution": preset.data.get("resolution", {}),
		"camera": preset.data.get("camera", {}),
		"lighting": {"rig": preset.data.get("lighting", {}).get("rig", "")},
		"background": preset.data.get("environment", {}).get("background", "transparent"),
		"supported_overrides": [
			"yaw", "pitch", "roll", "occupancy", "padding", "scale",
			"vertical_offset", "horizontal_offset", "camera.min_zoom",
			"camera.max_zoom", "background", "width", "height"
		]
	}

static func schema() -> Dictionary:
	return {
		"schema_version": 1,
		"description": "Icon Studio canonical render preset schema.",
		"fields": {
			"schema_version": {"type": "integer", "required": true, "enum": [1], "description": "Schema version."},
			"id": {"type": "string", "required": true, "pattern": "^[a-z0-9][a-z0-9_-]*$", "description": "Stable filename-safe preset id."},
			"display_name": {"type": "string", "required": false, "description": "Human-readable label."},
			"description": {"type": "string", "required": false, "description": "Intended use and composition notes."},
			"tags": {"type": "array<string>", "required": false, "description": "Searchable intent tags."},
			"resolution": {
				"type": "object", "required": true, "fields": {
					"width": {"type": "integer", "min": 16, "max": 8192, "description": "Output width in pixels."},
					"height": {"type": "integer", "min": 16, "max": 8192, "description": "Output height in pixels."}
				}
			},
			"supersampling": {"type": "integer", "min": 1, "max": 8, "default": 1, "description": "Render multiplier before downsampling."},
			"projection": {"type": "enum", "values": ["orthographic", "perspective"], "description": "Camera projection."},
			"camera": {
				"type": "object", "fields": {
					"orientation_strategy": {"type": "enum", "values": ["preserve", "longest_axis_diagonal", "upright", "weapon_diagonal", "shield_frontal", "potion_three_quarter", "helmet_three_quarter", "creature_portrait", "character_full_body"], "description": "Predictable geometric orientation heuristic."},
					"yaw": {"type": "number", "description": "Manual yaw in degrees."},
					"pitch": {"type": "number", "description": "Manual pitch in degrees."},
					"roll": {"type": "number", "description": "Manual roll in degrees."},
					"fov": {"type": "number", "min": 5, "max": 170, "description": "Perspective field of view."},
					"distance": {"type": "number", "min": 0.001, "description": "Perspective camera distance."},
					"orthographic_size": {"type": "number", "min": 0.001, "description": "Orthographic vertical size before auto framing."},
					"occupancy": {"type": "number", "min": 0.05, "max": 0.99, "description": "Target silhouette occupancy of the shorter image axis."},
					"padding": {"type": "number", "min": 0, "max": 0.45, "description": "Additional normalized frame padding."},
					"target": {"type": "array<number>", "length": 3, "description": "Camera look-at target."},
					"offset": {"type": "array<number>", "length": 3, "description": "Camera target offset."},
					"min_zoom": {"type": "number", "min": 0.001, "max": 100000, "description": "Smallest auto-frame camera size/distance."},
					"max_zoom": {"type": "number", "min": 0.001, "max": 100000, "description": "Largest auto-frame camera size/distance."},
					"auto_frame": {"type": "boolean", "description": "Enable bounds-based framing."}
				}
			},
			"lighting": {"type": "object", "description": "Deterministic key/fill/rim studio rig."},
			"environment": {"type": "object", "description": "Transparent, solid, or gradient background."},
			"shadows": {"type": "object", "description": "Scene/contact shadow presentation."},
			"post_process": {"type": "object", "description": "Focused deterministic image processing."},
			"presentation": {"type": "object", "description": "Optional rarity/aura/border/badge layer kept separate from the object render."},
			"composition": {"type": "object", "description": "Center and scale adjustments."},
			"output": {"type": "object", "description": "File format, transparency, and naming rules."}
		}
	}
