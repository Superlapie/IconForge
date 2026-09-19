extends RefCounted
class_name ReviewQueue

## Structured human-review records for needs_review outcomes.

const QUEUE_PATH: String = "generated/review_queue.json"

func record(entry: Dictionary) -> void:
	var queue: Array = _load_queue()
	var record: Dictionary = entry.duplicate(true)
	record["recorded_at"] = Time.get_datetime_string_from_system(true)
	queue.append(record)
	_save_queue(queue)

func list_entries() -> Array:
	return _load_queue()

func _load_queue() -> Array:
	var path: String = _absolute_queue_path()
	var data: Dictionary = IconStudioFileUtil.read_json(path)
	if data.has("entries") and data["entries"] is Array:
		return data["entries"]
	return []

func _save_queue(entries: Array) -> void:
	var path: String = _absolute_queue_path()
	IconStudioFileUtil.write_json_atomic(path, {"schema_version": 1, "entries": entries})

func _absolute_queue_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join(QUEUE_PATH)
