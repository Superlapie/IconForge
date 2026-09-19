extends RefCounted
class_name ManifestService

const _Schema = preload("res://core/api/api_schema.gd")

## First-class production manifests for audit and reproducibility.

const TOOL_VERSION: String = "0.1.0"
const MANIFESTS_DIR: String = "generated/manifests"

func write_manifest(job_id: String, data: Dictionary) -> String:
	var manifest: Dictionary = {
		"schema_version": _Schema.CURRENT_SCHEMA_VERSION,
		"tool_version": TOOL_VERSION,
		"job_id": job_id,
		"generated_at": Time.get_datetime_string_from_system(true),
	}
	for key in data.keys():
		manifest[key] = data[key]
	var path: String = ProjectSettings.globalize_path("res://").path_join(MANIFESTS_DIR).path_join("%s.json" % job_id)
	IconStudioFileUtil.write_json_atomic(path, manifest)
	return path

func read_manifest(path: String) -> Dictionary:
	return IconStudioFileUtil.read_json(path)

func find_manifest_by_job_id(job_id: String) -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join(MANIFESTS_DIR).path_join("%s.json" % job_id)
	if FileAccess.file_exists(path):
		return read_manifest(path)
	return {}
