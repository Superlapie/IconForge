extends RefCounted
class_name AdvisoryIndex

## Per-record advisory index files. Authoritative state lives elsewhere; these are rebuildable hints.

static func record_path(root: String, category: String, key: String) -> String:
	return IconForgeFileUtil.normalize_path(root.path_join("generated/index/%s/%s.json" % [category, _safe_key(key)]))

static func records_dir(root: String, category: String) -> String:
	return IconForgeFileUtil.normalize_path(root.path_join("generated/index/%s" % category))

static func write_record(root: String, category: String, key: String, payload: Dictionary) -> Error:
	return IconForgeFileUtil.write_json_atomic(record_path(root, category, key), payload)

static func read_record(root: String, category: String, key: String) -> Dictionary:
	return IconForgeFileUtil.read_json(record_path(root, category, key))

static func _safe_key(key: String) -> String:
	if key.is_empty():
		return "empty"
	return key.sha256_text()
