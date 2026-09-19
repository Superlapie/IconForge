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

func write_manifest(job_id: String, data: Dictionary) -> String:
	var manifest: Dictionary = {
		"schema_version": _Schema.CURRENT_SCHEMA_VERSION,
		"tool_version": _Version.VERSION,
		"job_id": job_id,
		"generated_at": Time.get_datetime_string_from_system(true),
	}
	for key in data.keys():
		manifest[key] = data[key]
	var path: String = manifest_path_for_job(job_id)
	IconStudioFileUtil.write_json_atomic(path, manifest)
	return path

func read_manifest(path: String) -> Dictionary:
	return IconStudioFileUtil.read_json(path)

func find_manifest_by_job_id(job_id: String) -> Dictionary:
	var path: String = manifest_path_for_job(job_id)
	if FileAccess.file_exists(path):
		return read_manifest(path)
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
