extends RefCounted
class_name ReviewQueue

const _AdvisoryIndex = preload("res://core/util/advisory_index.gd")

## Immutable per-job review records under generated/reviews/.
## review_queue.json and generated/index/reviews/ are advisory indexes only.

var workspace_root: String = ""
static var test_fail_record_write: bool = false

static func reset_test_seams() -> void:
	test_fail_record_write = false

func _init(root: String = "") -> void:
	if root.is_empty():
		workspace_root = ProjectSettings.globalize_path("res://")
	else:
		workspace_root = IconForgeFileUtil.normalize_path(root)

func record(entry: Dictionary) -> Dictionary:
	var job_id: String = str(entry.get("job_id", ""))
	if job_id.is_empty():
		job_id = "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var payload: Dictionary = entry.duplicate(true)
	payload["job_id"] = job_id
	payload["recorded_at"] = Time.get_datetime_string_from_system(true)
	var path: String = record_path(job_id)
	if test_fail_record_write:
		return {
			"success": false,
			"path": path,
			"error": {
				"code": "WRITE_FAILED",
				"message": "Could not persist review record.",
				"path": path,
			},
		}
	var write_error: Error = IconForgeFileUtil.write_json_atomic(path, payload)
	if write_error != OK:
		return {
			"success": false,
			"path": path,
			"error": {
				"code": "WRITE_FAILED",
				"message": "Could not persist review record.",
				"path": path,
				"godot_error": write_error,
			},
		}
	_update_index(job_id, payload)
	return {"success": true, "path": path, "job_id": job_id, "record": payload}

func list_entries() -> Array:
	var entries: Array = []
	var dir_path: String = reviews_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		return entries
	for file_name in DirAccess.get_files_at(dir_path):
		if not str(file_name).ends_with(".json"):
			continue
		var record: Dictionary = IconForgeFileUtil.read_json(dir_path.path_join(file_name))
		if not record.is_empty():
			entries.append(record)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("recorded_at", "")) < str(b.get("recorded_at", ""))
	)
	return entries

func reviews_dir() -> String:
	return workspace_root.path_join("generated/reviews")

func record_path(job_id: String) -> String:
	return reviews_dir().path_join("%s.json" % job_id)

func queue_path() -> String:
	return workspace_root.path_join("generated/review_queue.json")

func _update_index(job_id: String, payload: Dictionary) -> void:
	var summary: Dictionary = {
		"job_id": job_id,
		"path": record_path(job_id),
		"code": str(payload.get("code", "")),
		"purpose": str(payload.get("purpose", "")),
		"recorded_at": str(payload.get("recorded_at", "")),
	}
	_AdvisoryIndex.write_record(workspace_root, "reviews", job_id, summary)
	var index: Dictionary = IconForgeFileUtil.read_json(queue_path())
	var entries: Array = []
	if index.has("entries") and index["entries"] is Array:
		entries = index["entries"]
	var replaced: bool = false
	for item_index in range(entries.size()):
		var existing: Dictionary = entries[item_index]
		if str(existing.get("job_id", "")) == job_id:
			entries[item_index] = summary
			replaced = true
			break
	if not replaced:
		entries.append(summary)
	IconForgeFileUtil.write_json_atomic(queue_path(), {"schema_version": 1, "entries": entries})
