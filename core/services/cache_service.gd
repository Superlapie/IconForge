extends RefCounted
class_name CacheService

const _Version = preload("res://core/api/icon_forge_version.gd")
const _JobIdentity = preload("res://core/api/job_identity.gd")
const LEGACY_INDEX_PATH: String = "user://iconforge/cache.json"
const RECORDS_DIR: String = "user://iconforge/cache/records"

var _legacy_migrated: bool = false

func _init() -> void:
	_migrate_legacy_index_if_needed()

func build_key(source_path: String, preset: PresetDefinition, override: Dictionary) -> String:
	var source_hash: String = IconForgeFileUtil.file_hash(source_path)
	var dependency_hashes: Array[String] = _JobIdentity.dependency_hashes(source_path)
	var payload: String = "%s\n%s\n%s\n%s\n%s" % [source_hash, "\n".join(dependency_hashes), preset.to_canonical_json(), JSON.stringify(override), _Version.VERSION]
	return payload.sha256_text()

func lookup(key: String, output_path: String, force: bool = false) -> Dictionary:
	if force or key.is_empty():
		return {"hit": false, "key": key}
	var entry: Dictionary = _read_record(key)
	if entry.is_empty() or not FileAccess.file_exists(output_path):
		return {"hit": false, "key": key}
	if str(entry.get("output", "")) != output_path:
		return {"hit": false, "key": key}
	if str(entry.get("tool_version", "")) != _Version.VERSION:
		return {"hit": false, "key": key}
	return {"hit": true, "key": key, "entry": entry}

func store(key: String, source_path: String, output_path: String, preset_id: String, metrics: Dictionary) -> void:
	if key.is_empty():
		return
	var entry: Dictionary = {
		"key": key,
		"source": source_path,
		"output": output_path,
		"preset": preset_id,
		"tool_version": _Version.VERSION,
		"metrics": metrics,
		"stored_at": Time.get_datetime_string_from_system(true),
	}
	IconForgeFileUtil.write_json_atomic(_record_path(key), entry)

func clear() -> void:
	var records_dir: String = ProjectSettings.globalize_path(RECORDS_DIR)
	if DirAccess.dir_exists_absolute(records_dir):
		for file_name in DirAccess.get_files_at(records_dir):
			if str(file_name).ends_with(".json"):
				DirAccess.remove_absolute(records_dir.path_join(file_name))
	if FileAccess.file_exists(ProjectSettings.globalize_path(LEGACY_INDEX_PATH)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_INDEX_PATH))

func _record_path(key: String) -> String:
	return "%s/%s.json" % [RECORDS_DIR, key]

func _read_record(key: String) -> Dictionary:
	return IconForgeFileUtil.read_json(_record_path(key))

func _migrate_legacy_index_if_needed() -> void:
	if _legacy_migrated:
		return
	_legacy_migrated = true
	var legacy_path: String = ProjectSettings.globalize_path(LEGACY_INDEX_PATH)
	if not FileAccess.file_exists(legacy_path):
		return
	var legacy: Dictionary = IconForgeFileUtil.read_json(LEGACY_INDEX_PATH)
	if legacy.is_empty():
		return
	for key in legacy.keys():
		var entry: Dictionary = legacy[key]
		if entry is Dictionary and not _read_record(str(key)).is_empty():
			continue
		if entry is Dictionary:
			var migrated: Dictionary = entry.duplicate(true)
			migrated["key"] = str(key)
			IconForgeFileUtil.write_json_atomic(_record_path(str(key)), migrated)
	var migrated_path: String = "%s.migrated" % legacy_path
	if not FileAccess.file_exists(migrated_path):
		DirAccess.rename_absolute(legacy_path, migrated_path)
