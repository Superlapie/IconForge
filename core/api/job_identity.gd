extends RefCounted
class_name JobIdentity

const _Version = preload("res://core/api/icon_forge_version.gd")

## Canonical deterministic job/cache identity shared across ApiService and manifests.

static func source_snapshot_matches(source_path: String, expected_source_hash: String, expected_dependency_hashes: Array) -> bool:
	if IconForgeFileUtil.file_hash(source_path) != expected_source_hash:
		return false
	var current_hashes: Array[String] = dependency_hashes(source_path)
	if current_hashes.size() != expected_dependency_hashes.size():
		return false
	for index in range(current_hashes.size()):
		if str(current_hashes[index]) != str(expected_dependency_hashes[index]):
			return false
	return true

static func dependency_hashes(source_path: String) -> Array[String]:
	var seen: Dictionary = {}
	var hashes: Array[String] = []
	for dependency_path in _dependency_paths(source_path):
		if seen.has(dependency_path):
			continue
		seen[dependency_path] = true
		if FileAccess.file_exists(dependency_path):
			hashes.append("%s=%s" % [dependency_path, IconForgeFileUtil.file_hash(dependency_path)])
	hashes.sort()
	return hashes

static func _dependency_paths(source_path: String) -> Array[String]:
	var paths: Array[String] = []
	for dependency in ResourceLoader.get_dependencies(source_path):
		var dependency_path: String = IconForgeFileUtil.normalize_path(str(dependency).get_slice("::", 0))
		if not dependency_path.is_empty():
			paths.append(dependency_path)
	for external_path in _gltf_external_dependency_paths(source_path):
		if not paths.has(external_path):
			paths.append(external_path)
	return paths

static func _gltf_external_dependency_paths(source_path: String) -> Array[String]:
	if not source_path.to_lower().ends_with(".gltf"):
		return []
	if not FileAccess.file_exists(source_path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if not parsed is Dictionary:
		return []
	var base_dir: String = source_path.get_base_dir()
	var paths: Array[String] = []
	for buffer in parsed.get("buffers", []):
		if buffer is Dictionary:
			_append_gltf_uri_dependency(paths, base_dir, str(buffer.get("uri", "")))
	for image in parsed.get("images", []):
		if image is Dictionary:
			_append_gltf_uri_dependency(paths, base_dir, str(image.get("uri", "")))
	return paths

static func _append_gltf_uri_dependency(paths: Array[String], base_dir: String, uri: String) -> void:
	if uri.is_empty() or uri.begins_with("data:"):
		return
	var resolved: String = uri
	if not uri.begins_with("/") and not uri.contains("://"):
		resolved = IconForgeFileUtil.normalize_path(base_dir.path_join(uri))
	else:
		resolved = IconForgeFileUtil.normalize_path(uri)
	if not resolved.is_empty() and not paths.has(resolved):
		paths.append(resolved)

static func effective_config_hash(preset: PresetDefinition, effective_override: Dictionary) -> String:
	var payload: Dictionary = {
		"preset": preset.to_canonical_json(),
		"override": PresetDefinition._sort_value(effective_override),
	}
	return JSON.stringify(PresetDefinition._sort_value(payload)).sha256_text()

static func build_job_id(parts: Dictionary) -> String:
	var payload: Dictionary = {
		"operation": str(parts.get("operation", "")),
		"source_path": str(parts.get("source_path", "")),
		"source_hash": str(parts.get("source_hash", "")),
		"dependency_hashes": parts.get("dependency_hashes", []),
		"asset_id": str(parts.get("asset_id", "")),
		"purpose": str(parts.get("purpose", "")),
		"preset_id": str(parts.get("preset_id", "")),
		"preset_revision": int(parts.get("preset_revision", 1)),
		"effective_config_hash": str(parts.get("effective_config_hash", "")),
		"hints": parts.get("hints", {}),
		"workspace_root": str(parts.get("workspace_root", "")),
		"tool_version": _Version.VERSION,
	}
	return JSON.stringify(PresetDefinition._sort_value(payload)).sha256_text()

static func build_aggregate_job_id(child_job_ids: Array[String], parts: Dictionary) -> String:
	var sorted_children: Array[String] = child_job_ids.duplicate()
	sorted_children.sort()
	var payload: Dictionary = {
		"operation": "render_asset_set",
		"child_job_ids": sorted_children,
		"source_path": str(parts.get("source_path", "")),
		"source_hash": str(parts.get("source_hash", "")),
		"asset_id": str(parts.get("asset_id", "")),
		"outputs": parts.get("outputs", []),
		"hints": parts.get("hints", {}),
		"workspace_root": str(parts.get("workspace_root", "")),
		"tool_version": _Version.VERSION,
	}
	return JSON.stringify(PresetDefinition._sort_value(payload)).sha256_text()
