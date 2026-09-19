extends RefCounted
class_name CacheService

const _Version = preload("res://core/api/icon_forge_version.gd")
const _JobIdentity = preload("res://core/api/job_identity.gd")
const INDEX_PATH: String = "user://iconforge/cache.json"

var _entries: Dictionary = {}

func _init() -> void:
	_entries = IconForgeFileUtil.read_json(INDEX_PATH)

func build_key(source_path: String, preset: PresetDefinition, override: Dictionary) -> String:
	var source_hash: String = IconForgeFileUtil.file_hash(source_path)
	var dependency_hashes: Array[String] = _JobIdentity.dependency_hashes(source_path)
	var payload: String = "%s\n%s\n%s\n%s\n%s" % [source_hash, "\n".join(dependency_hashes), preset.to_canonical_json(), JSON.stringify(override), _Version.VERSION]
	return payload.sha256_text()

func lookup(key: String, output_path: String, force: bool = false) -> Dictionary:
	if force or not _entries.has(key) or not FileAccess.file_exists(output_path):
		return {"hit": false, "key": key}
	var entry: Dictionary = _entries[key]
	if str(entry.get("output", "")) != output_path:
		return {"hit": false, "key": key}
	return {"hit": true, "key": key, "entry": entry}

func store(key: String, source_path: String, output_path: String, preset_id: String, metrics: Dictionary) -> void:
	_entries[key] = {
		"source": source_path,
		"output": output_path,
		"preset": preset_id,
		"tool_version": _Version.VERSION,
		"metrics": metrics,
		"stored_at": Time.get_datetime_string_from_system(true)
	}
	IconForgeFileUtil.write_json_atomic(INDEX_PATH, _entries)

func clear() -> void:
	_entries.clear()
	IconForgeFileUtil.write_json_atomic(INDEX_PATH, _entries)
