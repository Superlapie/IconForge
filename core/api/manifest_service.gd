extends RefCounted
class_name ManifestService

const _Schema = preload("res://core/api/api_schema.gd")
const _Version = preload("res://core/api/icon_forge_version.gd")
const _AdvisoryIndex = preload("res://core/util/advisory_index.gd")

## First-class production manifests for audit and reproducibility.

var workspace_root: String = ""
var test_fail_aggregate_write: bool = false
var test_fail_restore_output: bool = false
var test_fail_remove_output: bool = false

func _init(root: String = "") -> void:
	if root.is_empty():
		workspace_root = ProjectSettings.globalize_path("res://")
	else:
		workspace_root = IconForgeFileUtil.normalize_path(root)

func manifests_dir() -> String:
	return workspace_root.path_join("generated/manifests")

func output_index_path() -> String:
	return workspace_root.path_join("generated/output_index.json")

func ownership_path(output_path: String) -> String:
	return "%s.owner.json" % output_path

func manifest_path_for_job(job_id: String) -> String:
	return manifests_dir().path_join("%s.json" % job_id)

func reset_test_seams() -> void:
	test_fail_aggregate_write = false
	test_fail_restore_output = false
	test_fail_remove_output = false

func write_manifest(job_id: String, data: Dictionary) -> Dictionary:
	if test_fail_aggregate_write and str(data.get("operation", "")) == "render_asset_set":
		return {"success": false, "path": manifest_path_for_job(job_id), "error": {"code": "WRITE_FAILED", "message": "Could not write production manifest."}}
	var manifest: Dictionary = {
		"schema_version": _Schema.CURRENT_SCHEMA_VERSION,
		"tool_version": _Version.VERSION,
		"job_id": job_id,
		"generated_at": Time.get_datetime_string_from_system(true),
	}
	for key in data.keys():
		manifest[key] = data[key]
	var path: String = manifest_path_for_job(job_id)
	var write_error: Error = IconForgeFileUtil.write_json_atomic(path, manifest)
	if write_error != OK:
		return {"success": false, "path": path, "error": {"code": "WRITE_FAILED", "message": "Could not write production manifest.", "godot_error": write_error}}
	var read_back: Dictionary = read_manifest(path)
	if read_back.is_empty():
		return {"success": false, "path": path, "error": {"code": "WRITE_FAILED", "message": "Production manifest could not be read back after write."}}
	return {"success": true, "path": path, "manifest": read_back}

func commit_validated_render(output_temp_path: String, output_path: String, job_id: String, data: Dictionary) -> Dictionary:
	var output_backup_path: String = ""
	var had_output: bool = FileAccess.file_exists(output_path)
	if had_output:
		output_backup_path = "%s.rollback.%s" % [output_path, str(Time.get_ticks_usec())]
		var backup_error: Error = DirAccess.copy_absolute(output_path, output_backup_path)
		if backup_error != OK:
			return {"success": false, "error": {"code": "WRITE_FAILED", "message": "Could not back up existing output before commit."}}

	var output_error: Error = IconForgeFileUtil.safe_replace_file(output_temp_path, output_path)
	if output_error != OK:
		_cleanup_temp(output_temp_path)
		return {"success": false, "error": {"code": "WRITE_FAILED", "message": "Could not commit validated output."}}

	var output_sha256: String = IconForgeFileUtil.file_hash(output_path)
	var manifest_payload: Dictionary = data.duplicate(true)
	manifest_payload["output"] = manifest_payload.get("output", {})
	manifest_payload["output"]["path"] = output_path
	manifest_payload["output"]["sha256"] = output_sha256

	var manifest_result: Dictionary = write_manifest(job_id, manifest_payload)
	if not bool(manifest_result.get("success", false)):
		var rollback_result: Dictionary = _restore_output(output_path, had_output, output_backup_path)
		if not bool(rollback_result.get("success", true)):
			return _attach_recovery_backup(rollback_result, output_backup_path)
		_cleanup_backup(output_backup_path)
		return manifest_result

	var stored: Dictionary = manifest_result.get("manifest", {})
	var stored_output: Dictionary = stored.get("output", {})
	if str(stored_output.get("sha256", "")) != output_sha256:
		var rollback_result: Dictionary = _restore_output(output_path, had_output, output_backup_path)
		var mismatched_manifest_path: String = manifest_path_for_job(job_id)
		if FileAccess.file_exists(mismatched_manifest_path):
			DirAccess.remove_absolute(mismatched_manifest_path)
		if not bool(rollback_result.get("success", true)):
			return _attach_recovery_backup(rollback_result, output_backup_path)
		_cleanup_backup(output_backup_path)
		return {"success": false, "error": {"code": "MANIFEST_MISMATCH", "message": "Committed manifest does not match output hash."}}

	var ownership: Dictionary = {
		"job_id": job_id,
		"output": output_path,
		"sha256": output_sha256,
		"source": str(stored.get("source", data.get("source", ""))),
		"source_identity": str(stored.get("source_identity", data.get("source_identity", ""))),
		"source_hash": str(stored.get("source_hash", data.get("source_hash", ""))),
		"purpose": str(stored.get("purpose", data.get("purpose", ""))),
		"asset_id": str(stored.get("asset_id", data.get("asset_id", ""))),
		"updated_at": Time.get_datetime_string_from_system(true),
	}
	var owner_error: Error = IconForgeFileUtil.write_json_atomic(ownership_path(output_path), ownership)
	if owner_error != OK:
		var rollback_result: Dictionary = _restore_output(output_path, had_output, output_backup_path)
		if FileAccess.file_exists(manifest_path_for_job(job_id)):
			DirAccess.remove_absolute(manifest_path_for_job(job_id))
		if not bool(rollback_result.get("success", true)):
			return _attach_recovery_backup(rollback_result, output_backup_path)
		_cleanup_backup(output_backup_path)
		return {"success": false, "error": {"code": "WRITE_FAILED", "message": "Could not write output ownership record."}}

	_update_output_index(output_path, ownership)
	_cleanup_backup(output_backup_path)
	return {"success": true, "path": str(manifest_result.get("path", "")), "manifest": stored, "output_sha256": output_sha256, "ownership": ownership}

func read_ownership(output_path: String) -> Dictionary:
	var path: String = ownership_path(output_path)
	if not FileAccess.file_exists(path):
		return {}
	var ownership: Dictionary = IconForgeFileUtil.read_json(path)
	if ownership.is_empty() or str(ownership.get("source", "")).is_empty():
		return {"corrupt": true, "path": path}
	return ownership

func read_manifest(path: String) -> Dictionary:
	return IconForgeFileUtil.read_json(path)

func find_manifest_by_job_id(job_id: String) -> Dictionary:
	var path: String = manifest_path_for_job(job_id)
	if FileAccess.file_exists(path):
		return read_manifest(path)
	return {}

func find_manifest_by_output_path(output_path: String) -> Dictionary:
	var current_hash: String = IconForgeFileUtil.file_hash(output_path) if FileAccess.file_exists(output_path) else ""
	var ownership: Dictionary = read_ownership(output_path)
	if not ownership.is_empty() and not bool(ownership.get("corrupt", false)):
		var owned_manifest: Dictionary = find_manifest_by_job_id(str(ownership.get("job_id", "")))
		if not owned_manifest.is_empty():
			var owned_sha: String = str(owned_manifest.get("output", {}).get("sha256", ownership.get("sha256", "")))
			if current_hash.is_empty() or owned_sha == current_hash:
				return owned_manifest
	if not DirAccess.dir_exists_absolute(manifests_dir()):
		return {}
	var best: Dictionary = {}
	var best_generated_at: String = ""
	for entry in DirAccess.get_files_at(manifests_dir()):
		var candidate: Dictionary = read_manifest(manifests_dir().path_join(entry))
		if str(candidate.get("output", {}).get("path", "")) != output_path:
			continue
		var candidate_sha: String = str(candidate.get("output", {}).get("sha256", ""))
		if not current_hash.is_empty() and candidate_sha != current_hash:
			continue
		var generated_at: String = str(candidate.get("generated_at", ""))
		if best.is_empty() or generated_at >= best_generated_at:
			best = candidate
			best_generated_at = generated_at
	return best

func manifest_matches_identity(manifest: Dictionary, identity: Dictionary) -> bool:
	if manifest.is_empty():
		return false
	for key in ["source_hash", "asset_id", "purpose", "effective_config_hash", "source_identity"]:
		if identity.has(key) and str(manifest.get(key, "")) != str(identity[key]):
			return false
	var recipe: Dictionary = manifest.get("recipe", {})
	if identity.has("preset_id") and str(recipe.get("id", "")) != str(identity["preset_id"]):
		return false
	if identity.has("preset_revision") and int(recipe.get("revision", -1)) != int(identity["preset_revision"]):
		return false
	var output: Dictionary = manifest.get("output", {})
	if identity.has("output_sha256") and str(output.get("sha256", "")) != str(identity["output_sha256"]):
		return false
	return true

func _update_output_index(output_path: String, ownership: Dictionary) -> void:
	var summary: Dictionary = {
		"output": output_path,
		"job_id": ownership.get("job_id", ""),
		"sha256": ownership.get("sha256", ""),
		"source": ownership.get("source", ""),
		"purpose": ownership.get("purpose", ""),
		"asset_id": ownership.get("asset_id", ""),
		"updated_at": ownership.get("updated_at", ""),
	}
	_AdvisoryIndex.write_record(workspace_root, "output", output_path, summary)
	var index: Dictionary = IconForgeFileUtil.read_json(output_index_path())
	index[output_path] = summary
	IconForgeFileUtil.write_json_atomic(output_index_path(), index)

func _restore_output(output_path: String, had_output: bool, output_backup_path: String) -> Dictionary:
	if test_fail_restore_output:
		return _attach_recovery_backup({
			"success": false,
			"error": {
				"code": "ROLLBACK_FAILED",
				"message": "Could not restore previous output after commit failure.",
				"path": output_path,
			},
		}, output_backup_path)
	if had_output and not output_backup_path.is_empty() and FileAccess.file_exists(output_backup_path):
		var restore_error: Error = DirAccess.copy_absolute(output_backup_path, output_path)
		if restore_error != OK:
			if FileAccess.file_exists(output_path):
				DirAccess.remove_absolute(output_path)
			return _attach_recovery_backup({
				"success": false,
				"error": {
					"code": "ROLLBACK_FAILED",
					"message": "Could not restore previous output after commit failure.",
					"path": output_path,
					"godot_error": restore_error,
				},
			}, output_backup_path)
		return {"success": true}
	if FileAccess.file_exists(output_path):
		if test_fail_remove_output:
			return {
				"success": false,
				"error": {
					"code": "ROLLBACK_FAILED",
					"message": "Could not remove uncommitted output after commit failure.",
					"path": output_path,
				},
			}
		var remove_error: Error = DirAccess.remove_absolute(output_path)
		if remove_error != OK or FileAccess.file_exists(output_path):
			return {
				"success": false,
				"error": {
					"code": "ROLLBACK_FAILED",
					"message": "Could not remove uncommitted output after commit failure.",
					"path": output_path,
					"godot_error": remove_error,
				},
			}
	return {"success": true}

func _attach_recovery_backup(result: Dictionary, output_backup_path: String) -> Dictionary:
	if not output_backup_path.is_empty() and FileAccess.file_exists(output_backup_path):
		var enriched: Dictionary = result.duplicate(true)
		var error: Dictionary = enriched.get("error", {}).duplicate(true)
		error["recovery_backup_path"] = output_backup_path
		enriched["error"] = error
		return enriched
	return result

func _cleanup_temp(temp_path: String) -> void:
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(IconForgeFileUtil.normalize_path(temp_path))

func _cleanup_backup(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
