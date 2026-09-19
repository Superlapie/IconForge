extends RefCounted
class_name WorkspacePolicy

const _ErrorCodes = preload("res://core/api/error_codes.gd")

## Filesystem safety for safe-mode machine requests.

var workspace_root: String = ""
var generated_root: String = "generated"

func _init(root: String = "") -> void:
	if root.is_empty():
		workspace_root = ProjectSettings.globalize_path("res://")
	else:
		workspace_root = _normalize_absolute(root)
	generated_root = workspace_root.path_join("generated")

func resolve_asset_path(asset: String) -> Dictionary:
	if asset.is_empty():
		return _error("INVALID_REQUEST", "Asset path is required.")
	if _contains_traversal(asset):
		return _error("PATH_NOT_ALLOWED", "Path traversal is not permitted.", asset)
	var absolute: String = _resolve_to_absolute(asset)
	if not FileAccess.file_exists(absolute):
		if asset.begins_with("res://"):
			absolute = ProjectSettings.globalize_path(asset)
		elif not asset.is_absolute_path():
			absolute = ProjectSettings.globalize_path("res://" + asset.trim_prefix("./"))
	if not FileAccess.file_exists(absolute):
		return _error("SOURCE_NOT_FOUND", "Source asset does not exist.", asset)
	return {"success": true, "path": absolute, "asset_id": IconStudioFileUtil.source_name(absolute)}

func resolve_output_path(purpose_id: String, asset_id: String, purpose_registry: RefCounted) -> Dictionary:
	var purpose_def: Dictionary = purpose_registry.get_purpose(purpose_id)
	if purpose_def.is_empty():
		return _error("PURPOSE_UNSUPPORTED", "Purpose '%s' is not supported." % purpose_id, purpose_id)
	var category: String = str(purpose_def.get("destination_category", "icons/inventory"))
	var naming: String = str(purpose_def.get("naming_strategy", "{asset_id}.png"))
	var filename: String = naming.replace("{asset_id}", asset_id)
	if filename.get_extension().is_empty():
		filename += ".png"
	var output_dir: String = generated_root.path_join(category)
	var output_path: String = output_dir.path_join(filename)
	if not _is_under_generated_root(output_path):
		return _error("PATH_NOT_ALLOWED", "Resolved output escapes the generated root.", output_path)
	return {"success": true, "path": output_path, "directory": output_dir}

func _is_under_generated_root(path: String) -> bool:
	var absolute: String = _normalize_absolute(path)
	var root: String = _normalize_absolute(generated_root)
	return absolute == root or absolute.begins_with(root + "/")

func _contains_traversal(path: String) -> bool:
	var normalized: String = IconStudioFileUtil.normalize_path(path)
	for part in normalized.split("/"):
		if part == "..":
			return true
	return false

func _resolve_to_absolute(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return _normalize_absolute(path)
	return _normalize_absolute(ProjectSettings.globalize_path("res://" + path.trim_prefix("./")))

func _normalize_absolute(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return IconStudioFileUtil.normalize_path(ProjectSettings.globalize_path(path))
	return IconStudioFileUtil.normalize_path(path)

func _error(code: String, message: String, path: String = "") -> Dictionary:
	return {
		"success": false,
		"error": {
			"code": code,
			"message": message,
			"path": path,
			"recommended_action": _ErrorCodes.recommended_action(code),
		},
	}
