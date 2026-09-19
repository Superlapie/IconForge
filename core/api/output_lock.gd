extends RefCounted
class_name OutputLock

const _ErrorCodes = preload("res://core/api/error_codes.gd")

const DEFAULT_TIMEOUT_MS: int = 60000
const STALE_MS: int = 120000
const POLL_MS: int = 50

var lock_dir: String = ""
var acquired: bool = false

func acquire(output_path: String, timeout_ms: int = DEFAULT_TIMEOUT_MS) -> Dictionary:
	lock_dir = "%s.lock" % output_path
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline:
		var created: Error = DirAccess.make_dir_absolute(lock_dir)
		if created == OK:
			_write_lease()
			acquired = true
			return {"success": true, "path": lock_dir}
		_reap_stale()
		OS.delay_msec(POLL_MS)
	return {
		"success": false,
		"error": {
			"code": "OUTPUT_LOCKED",
			"message": "Timed out waiting for exclusive access to output '%s'." % output_path,
			"path": output_path,
			"recommended_action": _ErrorCodes.recommended_action("OUTPUT_LOCKED"),
		},
	}

func release() -> void:
	if not acquired or lock_dir.is_empty():
		return
	var lease_path: String = lock_dir.path_join("lease.json")
	if FileAccess.file_exists(lease_path):
		DirAccess.remove_absolute(lease_path)
	if DirAccess.dir_exists_absolute(lock_dir):
		DirAccess.remove_absolute(lock_dir)
	acquired = false

func _write_lease() -> void:
	var lease_path: String = lock_dir.path_join("lease.json")
	var file: FileAccess = FileAccess.open(lease_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"pid": OS.get_process_id(),
		"acquired_at": Time.get_ticks_msec(),
	}))
	file.close()

func _reap_stale() -> void:
	if lock_dir.is_empty() or not DirAccess.dir_exists_absolute(lock_dir):
		return
	var lease_path: String = lock_dir.path_join("lease.json")
	var lease: Dictionary = {}
	if FileAccess.file_exists(lease_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(lease_path))
		if parsed is Dictionary:
			lease = parsed
	var acquired_at: int = int(lease.get("acquired_at", 0))
	if acquired_at == 0 or Time.get_ticks_msec() - acquired_at > STALE_MS:
		if FileAccess.file_exists(lease_path):
			DirAccess.remove_absolute(lease_path)
		DirAccess.remove_absolute(lock_dir)
