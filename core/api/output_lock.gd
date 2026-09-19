extends RefCounted
class_name OutputLock

const _ErrorCodes = preload("res://core/api/error_codes.gd")

const DEFAULT_TIMEOUT_MS: int = 60000
const STALE_MS: int = 120000
const LEASE_WRITE_GRACE_MS: int = 5000
const POLL_MS: int = 50

var lock_dir: String = ""
var lease_token: String = ""
var acquired: bool = false

static var test_process_alive_override: Dictionary = {}
static var test_process_start_ticks_override: Dictionary = {}
static var test_dir_age_ms_override: int = -1

static func reset_test_seams() -> void:
	test_process_alive_override.clear()
	test_process_start_ticks_override.clear()
	test_dir_age_ms_override = -1

static func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func acquire(output_path: String, timeout_ms: int = DEFAULT_TIMEOUT_MS) -> Dictionary:
	lock_dir = "%s.lock" % output_path
	lease_token = ""
	acquired = false
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline:
		var created: Error = DirAccess.make_dir_absolute(lock_dir)
		if created == OK:
			lease_token = _generate_token()
			if not _write_lease():
				_remove_lock_dir_if_token_matches(lease_token)
				lease_token = ""
				OS.delay_msec(POLL_MS)
				continue
			acquired = true
			return {"success": true, "path": lock_dir, "token": lease_token}
		if _try_reap_stale():
			continue
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

func heartbeat() -> bool:
	if not acquired or lease_token.is_empty() or lock_dir.is_empty():
		return false
	var lease_path: String = lock_dir.path_join("lease.json")
	var lease: Dictionary = _read_lease_file()
	if str(lease.get("token", "")) != lease_token:
		return false
	lease["heartbeat_at_ms"] = _now_ms()
	return _write_lease_payload(lease_path, lease)

func release() -> void:
	if not acquired or lock_dir.is_empty() or lease_token.is_empty():
		acquired = false
		lease_token = ""
		return
	_remove_lock_dir_if_token_matches(lease_token)
	acquired = false
	lease_token = ""

func lock_directory_exists() -> bool:
	return not lock_dir.is_empty() and DirAccess.dir_exists_absolute(lock_dir)

func _generate_token() -> String:
	return "%d.%d.%d" % [OS.get_process_id(), Time.get_ticks_usec(), randi()]

func _write_lease() -> bool:
	var now_ms: int = _now_ms()
	var identity: Dictionary = _process_identity(OS.get_process_id())
	return _write_lease_payload(lock_dir.path_join("lease.json"), {
		"token": lease_token,
		"pid": OS.get_process_id(),
		"pid_start_ticks": int(identity.get("start_ticks", -1)),
		"acquired_at_ms": now_ms,
		"heartbeat_at_ms": now_ms,
	})

func _write_lease_payload(lease_path: String, payload: Dictionary) -> bool:
	var temp_path: String = "%s.tmp.%s" % [lease_path, str(Time.get_ticks_usec())]
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	var replace_error: Error = DirAccess.rename_absolute(temp_path, lease_path)
	if replace_error != OK:
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		return false
	return true

func _read_lease_file() -> Dictionary:
	var lease_path: String = lock_dir.path_join("lease.json")
	if not FileAccess.file_exists(lease_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(lease_path))
	return parsed if parsed is Dictionary else {}

func _try_reap_stale() -> bool:
	if lock_dir.is_empty() or not DirAccess.dir_exists_absolute(lock_dir):
		return false
	var lease_path: String = lock_dir.path_join("lease.json")
	if not FileAccess.file_exists(lease_path):
		var age_ms: int = _dir_age_ms(lock_dir)
		if age_ms < LEASE_WRITE_GRACE_MS:
			return false
		return _remove_lock_dir_unconditional()
	var lease: Dictionary = _read_lease_file()
	if lease.is_empty():
		return false
	if not _is_lease_stale(lease):
		return false
	return _remove_lock_dir_unconditional()

func _lease_activity_ms(lease: Dictionary) -> int:
	var heartbeat_ms: int = int(lease.get("heartbeat_at_ms", 0))
	var acquired_ms: int = int(lease.get("acquired_at_ms", 0))
	return maxi(heartbeat_ms, acquired_ms)

func _holder_is_authoritative(lease: Dictionary, identity: Dictionary) -> bool:
	if not identity.get("alive", false):
		return false
	if OS.get_name() != "Linux":
		return false
	var lease_start: int = int(lease.get("pid_start_ticks", -1))
	var live_start: int = int(identity.get("start_ticks", -1))
	if lease_start >= 0 and live_start >= 0:
		return lease_start == live_start
	return false

func _is_lease_stale(lease: Dictionary) -> bool:
	var pid: int = int(lease.get("pid", 0))
	var identity: Dictionary = _process_identity(pid)
	if _holder_is_authoritative(lease, identity):
		return false
	var lease_start: int = int(lease.get("pid_start_ticks", -1))
	var live_start: int = int(identity.get("start_ticks", -1))
	if identity.get("alive", false) and lease_start >= 0 and live_start >= 0 and lease_start != live_start:
		return true
	var activity_ms: int = _lease_activity_ms(lease)
	if activity_ms <= 0:
		return _dir_age_ms(lock_dir) >= STALE_MS
	return _now_ms() - activity_ms > STALE_MS

func _dir_age_ms(path: String) -> int:
	if test_dir_age_ms_override >= 0:
		return test_dir_age_ms_override
	var modified_sec: int = int(FileAccess.get_modified_time(path))
	if modified_sec <= 0:
		return 0
	return max(0, _now_ms() - modified_sec * 1000)

func _process_identity(pid: int) -> Dictionary:
	if pid <= 0:
		return {"alive": false, "start_ticks": -1}
	if test_process_alive_override.has(pid):
		return {
			"alive": bool(test_process_alive_override[pid]),
			"start_ticks": int(test_process_start_ticks_override.get(pid, _process_start_ticks(pid))),
		}
	if pid == OS.get_process_id():
		return {"alive": true, "start_ticks": _current_process_start_ticks()}
	var os_name: String = OS.get_name()
	if os_name in ["Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD"]:
		var output: Array = []
		var exit_code: int = OS.execute("kill", ["-0", str(pid)], output, true, false)
		return {"alive": exit_code == 0, "start_ticks": _process_start_ticks(pid)}
	if os_name == "Windows":
		var output: Array = []
		OS.execute("tasklist", ["/FI", "PID eq %d" % pid, "/NH"], output, true, true)
		var text: String = "\n".join(PackedStringArray(output))
		var alive: bool = text.find(str(pid)) >= 0 and text.find("No tasks") < 0
		return {"alive": alive, "start_ticks": -1}
	return {"alive": false, "start_ticks": -1}

static func _current_process_start_ticks() -> int:
	return _process_start_ticks(OS.get_process_id())

static func _process_start_ticks(pid: int) -> int:
	if pid <= 0 or OS.get_name() != "Linux":
		return -1
	var stat_path: String = "/proc/%d/stat" % pid
	if not FileAccess.file_exists(stat_path):
		return -1
	var file: FileAccess = FileAccess.open(stat_path, FileAccess.READ)
	if file == null:
		return -1
	var stat_line: String = file.get_line()
	file.close()
	if stat_line.is_empty():
		return -1
	var close_paren: int = stat_line.rfind(")")
	if close_paren < 0:
		return -1
	var fields: PackedStringArray = stat_line.substr(close_paren + 2).split(" ", false)
	if fields.size() < 20:
		return -1
	return int(fields[19])

func _remove_lock_dir_if_token_matches(expected_token: String) -> void:
	if lock_dir.is_empty() or expected_token.is_empty() or not DirAccess.dir_exists_absolute(lock_dir):
		return
	var lease: Dictionary = _read_lease_file()
	if not lease.is_empty() and str(lease.get("token", "")) != expected_token:
		return
	_remove_lock_dir_unconditional()

func _remove_lock_dir_unconditional() -> bool:
	if lock_dir.is_empty() or not DirAccess.dir_exists_absolute(lock_dir):
		return true
	_cleanup_lock_artifacts()
	return not DirAccess.dir_exists_absolute(lock_dir)

func _cleanup_lock_artifacts() -> void:
	if lock_dir.is_empty() or not DirAccess.dir_exists_absolute(lock_dir):
		return
	var dir: DirAccess = DirAccess.open(lock_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var artifact_path: String = lock_dir.path_join(entry)
			if FileAccess.file_exists(artifact_path) or DirAccess.dir_exists_absolute(artifact_path):
				DirAccess.remove_absolute(artifact_path)
		entry = dir.get_next()
	dir.list_dir_end()
	if DirAccess.dir_exists_absolute(lock_dir):
		DirAccess.remove_absolute(lock_dir)
