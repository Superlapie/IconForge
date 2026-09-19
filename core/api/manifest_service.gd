extends RefCounted
class_name ManifestService

const _Schema = preload("res://core/api/api_schema.gd")
const _Version = preload("res://core/api/icon_studio_version.gd")

## First-class production manifests for audit and reproducibility.

var workspace_root: String = ""

func _init(root: String = "") -> void:
	if root.is_empty():
		workspace_root = ProjectSettings.globalize_path("res://")
	else:
		workspace_root = IconStudioFileUtil.normalize_path(root)

func manifests_dir() -> String:
	return workspace_root.path_join("generated/manifests")

func manifest_path_for_job(job_id: String) -> String:
	return manifests_dir().path_join("%s.json" % job_id)

func write_manifest(job_id: String, data: Dictionary) -> Dictionary:
	var manifest: Dictionary = {
		"schema_version": _Schema.CURRENT_SCHEMA_VERSION,
		"tool_version": _Version.VERSION,
		"job_id": job_id,
		"generated_at": Time.get_datetime_string_from_system(true),
	}
	for key in data.keys():
		manifest[key] = data[key]
	var path: String = manifest_path_for_job(job_id)
	var write_error: Error = IconStudioFileUtil.write_json_atomic(path, manifest)
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

	var output_error: Error = IconStudioFileUtil.safe_replace_file(output_temp_path, output_path)
	if output_error != OK:
		_cleanup_temp(output_temp_path)
		return {"success": false, "error": {"code": "WRITE_FAILED", "message": "Could not commit validated output."}}

	var output_sha256: String = IconStudioFileUtil.file_hash(output_path)
	var manifest_payload: Dictionary = data.duplicate(true)
	manifest_payload["output"] = manifest_payload.get("output", {})
	manifest_payload["output"]["path"] = output_path
	manifest_payload["output"]["sha256"] = output_sha256

	var manifest_result: Dictionary = write_manifest(job_id, manifest_payload)
	if not bool(manifest_result.get("success", false)):
		if had_output and not output_backup_path.is_empty() and FileAccess.file_exists(output_backup_path):
			DirAccess.copy_absolute(output_backup_path, output_path)
		elif FileAccess.file_exists(output_path):
			DirAccess.remove_absolute(output_path)
		_cleanup_backup(output_backup_path)
		return manifest_result

	var stored: Dictionary = manifest_result.get("manifest", {})
	var stored_output: Dictionary = stored.get("output", {})
	if str(stored_output.get("sha256", "")) != output_sha256:
		if had_output and not output_backup_path.is_empty() and FileAccess.file_exists(output_backup_path):
			DirAccess.copy_absolute(output_backup_path, output_path)
		elif FileAccess.file_exists(output_path):
			DirAccess.remove_absolute(output_path)
		_cleanup_backup(output_backup_path)
		return {"success": false, "error": {"code": "MANIFEST_MISMATCH", "message": "Committed manifest does not match output hash."}}

	_cleanup_backup(output_backup_path)
	return {"success": true, "path": str(manifest_result.get("path", "")), "manifest": stored, "output_sha256": output_sha256}

func read_manifest(path: String) -> Dictionary:
	return IconStudioFileUtil.read_json(path)

func find_manifest_by_job_id(job_id: String) -> Dictionary:
	var path: String = manifest_path_for_job(job_id)
	if FileAccess.file_exists(path):
		return read_manifest(path)
	return {}

func find_manifest_by_output_path(output_path: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(manifests_dir()):
		return {}
	for entry in DirAccess.get_files_at(manifests_dir()):
		var candidate: Dictionary = read_manifest(manifests_dir().path_join(entry))
		if str(candidate.get("output", {}).get("path", "")) == output_path:
			return candidate
	return {}

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

func _cleanup_temp(temp_path: String) -> void:
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(IconStudioFileUtil.normalize_path(temp_path))

func _cleanup_backup(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
