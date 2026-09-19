extends RefCounted
class_name ReviewQueue

## Structured human-review records for needs_review outcomes.

var workspace_root: String = ""

func _init(root: String = "") -> void:
	if root.is_empty():
		workspace_root = ProjectSettings.globalize_path("res://")
	else:
		workspace_root = IconStudioFileUtil.normalize_path(root)

func record(entry: Dictionary) -> void:
	var queue: Array = _load_queue()
	var record: Dictionary = entry.duplicate(true)
	record["recorded_at"] = Time.get_datetime_string_from_system(true)
	queue.append(record)
	_save_queue(queue)

func list_entries() -> Array:
	return _load_queue()

func queue_path() -> String:
	return workspace_root.path_join("generated/review_queue.json")

func _load_queue() -> Array:
	var data: Dictionary = IconStudioFileUtil.read_json(queue_path())
	if data.has("entries") and data["entries"] is Array:
		return data["entries"]
	return []

func _save_queue(entries: Array) -> void:
	IconStudioFileUtil.write_json_atomic(queue_path(), {"schema_version": 1, "entries": entries})
