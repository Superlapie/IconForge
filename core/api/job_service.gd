extends RefCounted
class_name JobService

const _JobIdentity = preload("res://core/api/job_identity.gd")

## Deterministic job identity from immutable render inputs.

const JOBS_DIR: String = "user://iconstudio/jobs"

func build_job_id(parts: Dictionary) -> String:
	return _JobIdentity.build_job_id(parts)

func build_aggregate_job_id(child_job_ids: Array[String], parts: Dictionary) -> String:
	return _JobIdentity.build_aggregate_job_id(child_job_ids, parts)

func store_job_record(job_id: String, record: Dictionary) -> void:
	var path: String = JOBS_DIR.path_join("%s.json" % job_id)
	IconStudioFileUtil.write_json_atomic(path, record)

func load_job_record(job_id: String) -> Dictionary:
	var path: String = JOBS_DIR.path_join("%s.json" % job_id)
	return IconStudioFileUtil.read_json(path)
