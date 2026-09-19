extends RefCounted
class_name JobService

## Deterministic job identity from immutable render inputs.

const TOOL_VERSION: String = "0.1.0"
const JOBS_DIR: String = "user://iconstudio/jobs"

func build_job_id(operation: String, source_path: String, purpose: String, preset_id: String, preset_revision: int, hints: Dictionary = {}, expert_override: Dictionary = {}) -> String:
	var source_hash: String = IconStudioFileUtil.file_hash(source_path)
	var payload: Dictionary = {
		"operation": operation,
		"source_hash": source_hash,
		"purpose": purpose,
		"preset_id": preset_id,
		"preset_revision": preset_revision,
		"hints": hints,
		"expert_override": expert_override,
		"tool_version": TOOL_VERSION,
	}
	return JSON.stringify(PresetDefinition._sort_value(payload)).sha256_text()

func store_job_record(job_id: String, record: Dictionary) -> void:
	var path: String = JOBS_DIR.path_join("%s.json" % job_id)
	IconStudioFileUtil.write_json_atomic(path, record)

func load_job_record(job_id: String) -> Dictionary:
	var path: String = JOBS_DIR.path_join("%s.json" % job_id)
	return IconStudioFileUtil.read_json(path)

func manifest_path_for_job(job_id: String) -> String:
	return JOBS_DIR.path_join("%s.manifest.json" % job_id)
