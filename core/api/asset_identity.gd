extends RefCounted
class_name AssetIdentity

const _ErrorCodes = preload("res://core/api/error_codes.gd")

const MAX_ASSET_ID_LENGTH: int = 128
const ALLOWED_PATTERN: String = "^[a-z0-9][a-z0-9._-]*$"

## Deterministic, collision-resistant asset identity for safe-mode output paths.

static func resolve(asset: String, source_path: String, workspace_root: String, explicit_asset_id: String = "") -> Dictionary:
	if not explicit_asset_id.is_empty():
		var validation: Dictionary = validate_asset_id(explicit_asset_id)
		if not bool(validation.get("success", false)):
			return validation
		return {"success": true, "asset_id": explicit_asset_id, "source_identity": _source_identity(source_path, workspace_root)}

	var normalized_source: String = IconStudioFileUtil.normalize_path(source_path)
	var stem: String = _sanitize_stem(normalized_source.get_file().get_basename())
	var root: String = IconStudioFileUtil.normalize_path(workspace_root).rstrip("/")
	var identity_basis: String = _workspace_relative(source_path, workspace_root)
	if not normalized_source.begins_with(root + "/"):
		identity_basis = normalized_source
	var path_hash: String = identity_basis.sha256_text().substr(0, 8)
	return {
		"success": true,
		"asset_id": "%s__%s" % [stem, path_hash],
		"source_identity": _source_identity(source_path, workspace_root),
	}

static func validate_asset_id(asset_id: String) -> Dictionary:
	if asset_id.is_empty():
		return _error("INVALID_REQUEST", "asset_id must not be empty.", "asset_id")
	if asset_id.length() > MAX_ASSET_ID_LENGTH:
		return _error("INVALID_REQUEST", "asset_id exceeds maximum length %d." % MAX_ASSET_ID_LENGTH, "asset_id")
	if asset_id.contains("..") or asset_id.contains("/") or asset_id.contains("\\"):
		return _error("PATH_NOT_ALLOWED", "asset_id must not contain path separators or traversal.", "asset_id")
	if asset_id.is_absolute_path():
		return _error("PATH_NOT_ALLOWED", "asset_id must not be an absolute path.", "asset_id")
	var regex: RegEx = RegEx.new()
	regex.compile(ALLOWED_PATTERN)
	if regex.search(asset_id) == null:
		return _error("INVALID_REQUEST", "asset_id must be filename-safe lowercase alphanumeric with ._- only.", "asset_id")
	return {"success": true, "asset_id": asset_id}

static func _sanitize_stem(stem: String) -> String:
	var lowered: String = stem.to_lower()
	var out: String = ""
	for i in range(lowered.length()):
		var ch: String = lowered.substr(i, 1)
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "." or ch == "_" or ch == "-":
			out += ch
		elif ch == " ":
			out += "_"
	if out.is_empty():
		return "asset"
	if not out[0].is_valid_int() and not out[0].is_valid_identifier():
		return "a_%s" % out
	return out

static func _source_identity(source_path: String, workspace_root: String) -> String:
	var absolute: String = IconStudioFileUtil.normalize_path(source_path)
	var root: String = IconStudioFileUtil.normalize_path(workspace_root).rstrip("/")
	if absolute.begins_with(root + "/"):
		return _workspace_relative(source_path, workspace_root)
	return absolute

static func _workspace_relative(source_path: String, workspace_root: String) -> String:
	var absolute_source: String = IconStudioFileUtil.normalize_path(source_path)
	var absolute_root: String = IconStudioFileUtil.normalize_path(workspace_root).rstrip("/")
	if absolute_source.begins_with(absolute_root + "/"):
		return absolute_source.substr(absolute_root.length() + 1)
	return absolute_source.get_file()

static func _error(code: String, message: String, field: String) -> Dictionary:
	return {
		"success": false,
		"error": {
			"code": code,
			"message": message,
			"field": field,
			"recommended_action": _ErrorCodes.recommended_action(code),
		},
	}
