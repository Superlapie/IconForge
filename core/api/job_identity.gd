extends RefCounted
class_name JobIdentity

const _Version = preload("res://core/api/icon_studio_version.gd")

## Canonical deterministic job/cache identity shared across ApiService and manifests.

static func dependency_hashes(source_path: String) -> Array[String]:
	var hashes: Array[String] = []
	for dependency in ResourceLoader.get_dependencies(source_path):
		var dependency_path: String = str(dependency).get_slice("::", 0)
		if FileAccess.file_exists(dependency_path):
			hashes.append("%s=%s" % [dependency_path, IconStudioFileUtil.file_hash(dependency_path)])
	hashes.sort()
	return hashes

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
