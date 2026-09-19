extends RefCounted
class_name WorkspaceLayout

const SETTINGS_PATH: String = "user://iconstudio/workspace.json"

static func defaults() -> Dictionary:
	return {
		"split_offset": 260,
		"sources_collapsed": false,
		"inspector_collapsed": false
	}

static func load_settings() -> Dictionary:
	var result: Dictionary = defaults()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return result
	var data: Dictionary = IconStudioFileUtil.read_json(SETTINGS_PATH)
	if data.is_empty():
		return result
	result.merge(data, true)
	return result

static func save_settings(settings: Dictionary) -> void:
	var payload: Dictionary = defaults()
	payload.merge(settings, true)
	IconStudioFileUtil.write_json_atomic(SETTINGS_PATH, payload)
