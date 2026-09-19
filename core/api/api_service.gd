extends RefCounted
class_name ApiService

const _Request = preload("res://core/api/api_request.gd")
const _Response = preload("res://core/api/api_response.gd")
const _Schema = preload("res://core/api/api_schema.gd")
const _Purposes = preload("res://core/api/purpose_registry.gd")
const _RecipeResolver = preload("res://core/api/recipe_resolver.gd")
const _Workspace = preload("res://core/api/workspace_policy.gd")
const _ProductionQuality = preload("res://core/api/production_quality.gd")
const _JobService = preload("res://core/api/job_service.gd")
const _ManifestService = preload("res://core/api/manifest_service.gd")
const _ReviewQueue = preload("res://core/api/review_queue.gd")
const _ErrorCodes = preload("res://core/api/error_codes.gd")
const _JobIdentity = preload("res://core/api/job_identity.gd")
const _Mapper = preload("res://core/api/error_mapper.gd")
const _Version = preload("res://core/api/icon_studio_version.gd")

## Canonical machine API dispatcher. All safe-mode operations enter here.

enum RenderState {
	RECEIVED,
	VALIDATED_REQUEST,
	INSPECTED,
	RECIPE_RESOLVED,
	RENDERED,
	MEASURED,
	CORRECTED,
	VALIDATED_OUTPUT,
	COMMITTED,
	COMPLETED,
	NEEDS_REVIEW,
	FAILED,
}

var request_validator: RefCounted = _Request.new()
var purposes: RefCounted = _Purposes.new()
var recipe_resolver: RefCounted = _RecipeResolver.new()
var workspace: RefCounted
var inspector: AssetInspector = AssetInspector.new()
var render_service: RenderService = RenderService.new()
var production_quality: RefCounted = _ProductionQuality.new()
var job_service: RefCounted = _JobService.new()
var manifest_service: RefCounted
var review_queue: RefCounted
var overrides: OverrideService = OverrideService.new()

func _init(workspace_root: String = "") -> void:
	workspace = _Workspace.new(workspace_root)
	manifest_service = _ManifestService.new(workspace.workspace_root)
	review_queue = _ReviewQueue.new(workspace.workspace_root)

func execute(request: Dictionary, safe_mode: bool = true) -> Dictionary:
	var operation: String = str(request.get("operation", ""))
	var validation: Dictionary = request_validator.validate(request, safe_mode)
	if not bool(validation.get("success", false)):
		return _Response.from_validation_error(operation, validation.get("error", {}))
	var validated_request: Dictionary = validation["request"]
	operation = str(validated_request["operation"])

	match operation:
		"capabilities":
			return _Response.success(operation, {"capabilities": _Schema.capabilities()})
		"schema":
			return _Response.success(operation, {"schema": _Schema.describe()})
		"inspect_asset":
			return _inspect_asset(validated_request)
		"render_asset":
			return await _render_asset(validated_request, safe_mode)
		"render_asset_set":
			return await _render_asset_set(validated_request, safe_mode)
		"validate_output":
			return _validate_output_operation(validated_request)
		"explain_result":
			return _explain_result(validated_request, safe_mode)
		"render_expert":
			return await _render_expert(validated_request)
		_:
			return _Response.failure(operation, "UNKNOWN_OPERATION", "Unknown operation '%s'." % operation)

func _inspect_asset(request: Dictionary) -> Dictionary:
	var asset_result: Dictionary = workspace.resolve_asset_path(str(request["asset"]), str(request.get("asset_id", "")))
	if not bool(asset_result.get("success", false)):
		return _Response.failure("inspect_asset", str(asset_result["error"]["code"]), str(asset_result["error"]["message"]), asset_result["error"])
	var inspection: Dictionary = inspector.inspect(asset_result["path"])
	if not bool(inspection.get("success", false)):
		var err: Dictionary = inspection.get("error", {})
		return _Response.failure("inspect_asset", _mapped_code(err), str(err.get("message", "Inspection failed.")))
	inspection["asset_id"] = str(asset_result.get("asset_id", ""))
	inspection["source_hash"] = IconStudioFileUtil.file_hash(asset_result["path"])
	inspection["source_identity"] = str(asset_result.get("source_identity", ""))
	inspection["renderable"] = true
	inspection["morphology"] = recipe_resolver.classify_morphology(inspection)
	return _Response.success("inspect_asset", {"inspection": inspection})

func _render_asset(request: Dictionary, safe_mode: bool) -> Dictionary:
	return await _render_asset_pipeline(request, safe_mode, {})

func _render_asset_pipeline(request: Dictionary, safe_mode: bool, shared_context: Dictionary) -> Dictionary:
	var trace: Array = []
	var state: int = RenderState.RECEIVED
	trace.append(_state_entry(state))

	var asset_result: Dictionary = workspace.resolve_asset_path(str(request["asset"]), str(request.get("asset_id", "")))
	if not bool(asset_result.get("success", false)):
		return _terminal_failure("render_asset", asset_result["error"], trace)
	state = RenderState.VALIDATED_REQUEST
	trace.append(_state_entry(state))

	var source_path: String = asset_result["path"]
	var asset_id: String = str(asset_result.get("asset_id", ""))
	var source_identity: String = str(asset_result.get("source_identity", ""))
	var purpose_id: String = str(request["purpose"])
	var hints: Dictionary = request.get("hints", {}) if request.has("hints") else {}
	var force: bool = bool(request.get("force", false))
	var purpose_def: Dictionary = purposes.get_purpose(purpose_id)

	var inspection: Dictionary = shared_context.get("inspection", {})
	if inspection.is_empty():
		inspection = inspector.inspect(source_path)
	state = RenderState.INSPECTED
	var source_hash: String = str(shared_context.get("source_hash", IconStudioFileUtil.file_hash(source_path)))
	var dependency_hashes: Array = shared_context.get("dependency_hashes", _JobIdentity.dependency_hashes(source_path))
	trace.append(_state_entry(state, {"source_hash": source_hash}))
	if not bool(inspection.get("success", false)):
		return _terminal_failure("render_asset", _mapped_error(inspection.get("error", {})), trace)

	var recipe: Dictionary = recipe_resolver.resolve(purpose_id, inspection, hints)
	state = RenderState.RECIPE_RESOLVED
	trace.append(_state_entry(state, {"preset_id": recipe.get("preset_id", ""), "reasons": recipe.get("resolution_reasons", [])}))
	if not bool(recipe.get("success", false)):
		return _terminal_review("render_asset", recipe.get("error", {}), trace, source_path, purpose_id, asset_id)

	var preset: PresetDefinition = recipe["preset"]
	var preset_id: String = str(recipe["preset_id"])
	var preset_revision: int = int(recipe["preset_revision"])

	var sidecar: Dictionary = overrides.load_for_source(source_path)
	if not bool(sidecar.get("success", false)):
		if bool(sidecar.get("found", false)):
			return _terminal_failure("render_asset", _mapped_error(sidecar.get("error", {})), trace)
	var sidecar_override: Dictionary = sidecar.get("override", {}) if bool(sidecar.get("found", false)) else {}
	var effective_override: Dictionary = PresetDefinition.deep_merge(recipe.get("override_patch", {}), sidecar_override)
	var effective_config_hash: String = _JobIdentity.effective_config_hash(preset, effective_override)

	var job_id: String = job_service.build_job_id({
		"operation": "render_asset",
		"source_path": source_path,
		"source_hash": source_hash,
		"dependency_hashes": dependency_hashes,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"preset_id": preset_id,
		"preset_revision": preset_revision,
		"effective_config_hash": effective_config_hash,
		"hints": hints,
		"workspace_root": workspace.workspace_root,
	})

	var output_result: Dictionary = workspace.resolve_output_path(purpose_id, asset_id, purposes)
	if not bool(output_result.get("success", false)):
		return _terminal_failure("render_asset", output_result["error"], trace, job_id)
	var output_path: String = output_result["path"]
	IconStudioFileUtil.ensure_directory(output_path)

	var collision: Dictionary = _check_output_collision(output_path, source_path)
	if not collision.is_empty():
		return collision

	var cache_hit: Dictionary = _try_cache_hit(output_path, purpose_def, preset, job_id, source_hash, source_identity, asset_id, purpose_id, preset_id, preset_revision, effective_config_hash, hints, force)
	if not cache_hit.is_empty():
		return cache_hit

	var temp_path: String = "%s.pending.%s.png" % [output_path.get_basename(), job_id]
	var correction_actions: Array = []
	var max_passes: int = int(purpose_def.get("max_correction_passes", 3))
	var render_result: Dictionary = await render_service.render(
		source_path, preset, effective_override, temp_path, true,
		{"skip_sidecar_load": true, "max_correction_passes": max_passes, "precomputed_inspection": inspection}
	)
	state = RenderState.RENDERED
	trace.append(_state_entry(state, {"render_passes": render_result.get("render_passes", 1)}))

	if not bool(render_result.get("success", false)):
		_cleanup_temp(temp_path)
		var render_err: Dictionary = _mapped_error(render_result.get("error", {"code": "RENDER_FAILED", "message": "Render failed."}))
		return _handle_render_failure("render_asset", render_err, trace, job_id, source_path, purpose_id, asset_id, preset_id, render_result)

	state = RenderState.MEASURED
	var frame_metrics: Dictionary = render_result.get("metrics", {})
	var quality: Dictionary = production_quality.validate_output(temp_path, purpose_def, preset, frame_metrics)
	trace.append(_state_entry(state, {"occupancy": quality.get("occupancy", 0.0), "clipped": quality.get("clipped", false)}))

	if int(render_result.get("render_passes", 1)) > 1:
		state = RenderState.CORRECTED
		correction_actions.append({"passes": render_result.get("render_passes", 1), "type": "auto_framing"})
		trace.append(_state_entry(state, {"actions": correction_actions}))

	if not bool(quality.get("success", false)):
		_cleanup_temp(temp_path)
		return _handle_quality_failure("render_asset", quality, trace, job_id, source_path, source_hash, source_identity, dependency_hashes, purpose_id, asset_id, preset_id, preset_revision, inspection, recipe, hints, effective_override, effective_config_hash, render_result, correction_actions)

	state = RenderState.VALIDATED_OUTPUT
	trace.append(_state_entry(state))

	var manifest_payload: Dictionary = _build_manifest_payload(
		"render_asset", job_id, source_path, source_hash, source_identity, dependency_hashes,
		asset_id, purpose_id, preset_id, preset_revision, effective_override, effective_config_hash,
		hints, inspection, recipe, quality, render_result, correction_actions, output_path, "", trace, false
	)
	var commit_result: Dictionary = manifest_service.commit_validated_render(temp_path, output_path, job_id, manifest_payload)
	if not bool(commit_result.get("success", false)):
		_cleanup_temp(temp_path)
		var commit_err: Dictionary = commit_result.get("error", {"code": "WRITE_FAILED", "message": "Could not commit validated production bundle."})
		return _Response.failure("render_asset", str(commit_err.get("code", "WRITE_FAILED")), str(commit_err.get("message", "Could not commit validated production bundle.")), {"job_id": job_id, "trace": trace})

	state = RenderState.COMMITTED
	trace.append(_state_entry(state))
	var output_sha256: String = str(commit_result.get("output_sha256", ""))
	var manifest_path: String = str(commit_result.get("path", ""))
	job_service.store_job_record(job_id, {"job_id": job_id, "operation": "render_asset", "status": "validated", "manifest": manifest_path, "trace": trace})

	state = RenderState.COMPLETED
	return _success_render(job_id, asset_id, purpose_id, output_path, output_sha256, preset, preset_id, preset_revision, quality, render_result, correction_actions, manifest_path, trace, false)

func _render_asset_set(request: Dictionary, safe_mode: bool) -> Dictionary:
	var asset_result: Dictionary = workspace.resolve_asset_path(str(request["asset"]), str(request.get("asset_id", "")))
	if not bool(asset_result.get("success", false)):
		return _Response.failure("render_asset_set", str(asset_result["error"]["code"]), str(asset_result["error"]["message"]))

	var source_path: String = asset_result["path"]
	var asset_id: String = str(asset_result.get("asset_id", ""))
	var hints: Dictionary = request.get("hints", {}) if request.has("hints") else {}
	var outputs: Array = request["outputs"]

	var inspection: Dictionary = inspector.inspect(source_path)
	if not bool(inspection.get("success", false)):
		return _Response.failure("render_asset_set", _mapped_code(inspection.get("error", {})), str(inspection.get("error", {}).get("message", "Inspection failed.")))

	var shared_context: Dictionary = {
		"inspection": inspection,
		"source_hash": IconStudioFileUtil.file_hash(source_path),
		"dependency_hashes": _JobIdentity.dependency_hashes(source_path),
	}

	var child_results: Dictionary = {}
	var child_job_ids: Array[String] = []
	var validated_count: int = 0
	var review_count: int = 0
	var fail_count: int = 0

	for purpose_id in outputs:
		var single_request: Dictionary = {
			"schema_version": 1,
			"operation": "render_asset",
			"asset": request["asset"],
			"purpose": str(purpose_id),
			"asset_id": asset_id,
			"force": request.get("force", false),
		}
		if request.has("hints"):
			single_request["hints"] = hints
		var result: Dictionary = await _render_asset_pipeline(single_request, safe_mode, shared_context)
		child_results[str(purpose_id)] = result
		if result.has("job_id"):
			child_job_ids.append(str(result["job_id"]))
		var status: String = str(result.get("status", "failed"))
		if bool(result.get("success", false)) and status == "validated":
			validated_count += 1
		elif status == "needs_review":
			review_count += 1
		else:
			fail_count += 1

	var aggregate_job_id: String = job_service.build_aggregate_job_id(child_job_ids, {
		"source_path": source_path,
		"source_hash": shared_context["source_hash"],
		"asset_id": asset_id,
		"outputs": outputs,
		"hints": hints,
		"workspace_root": workspace.workspace_root,
	})

	var aggregate_status: String = "failed"
	var aggregate_success: bool = false
	if validated_count == outputs.size():
		aggregate_status = "validated"
		aggregate_success = true
	elif validated_count > 0:
		aggregate_status = "partial_success"
	elif review_count == outputs.size():
		aggregate_status = "needs_review"
	elif fail_count > 0:
		aggregate_status = "failed"

	var aggregate_manifest_result: Dictionary = manifest_service.write_manifest(aggregate_job_id, {
		"operation": "render_asset_set",
		"source": source_path,
		"source_hash": shared_context["source_hash"],
		"asset_id": asset_id,
		"outputs": outputs,
		"hints": hints,
		"child_job_ids": child_job_ids,
		"children": child_results,
		"status": aggregate_status,
		"summary": {"total": outputs.size(), "validated": validated_count, "needs_review": review_count, "failed": fail_count},
	})
	var aggregate_manifest_path: String = ""
	if bool(aggregate_manifest_result.get("success", false)):
		aggregate_manifest_path = str(aggregate_manifest_result.get("path", ""))
		job_service.store_job_record(aggregate_job_id, {"job_id": aggregate_job_id, "operation": "render_asset_set", "status": aggregate_status, "manifest": aggregate_manifest_path})

	return {
		"schema_version": _Schema.CURRENT_SCHEMA_VERSION,
		"success": aggregate_success,
		"status": aggregate_status,
		"operation": "render_asset_set",
		"job_id": aggregate_job_id,
		"asset_id": asset_id,
		"manifest": aggregate_manifest_path,
		"summary": {"total": outputs.size(), "validated": validated_count, "needs_review": review_count, "failed": fail_count},
		"outputs": child_results,
	}

func _validate_output_operation(request: Dictionary) -> Dictionary:
	var asset_result: Dictionary = workspace.resolve_asset_path(str(request["asset"]), str(request.get("asset_id", "")))
	if not bool(asset_result.get("success", false)):
		return _Response.failure("validate_output", str(asset_result["error"]["code"]), str(asset_result["error"]["message"]))

	var purpose_id: String = str(request["purpose"])
	var purpose_def: Dictionary = purposes.get_purpose(purpose_id)
	if purpose_def.is_empty():
		return _Response.failure("validate_output", "PURPOSE_UNSUPPORTED", "Purpose '%s' is not supported." % purpose_id)

	var inspection: Dictionary = inspector.inspect(asset_result["path"])
	if not bool(inspection.get("success", false)):
		return _Response.failure("validate_output", _mapped_code(inspection.get("error", {})), str(inspection.get("error", {}).get("message", "Inspection failed.")))

	var recipe: Dictionary = recipe_resolver.resolve(purpose_id, inspection)
	if not bool(recipe.get("success", false)):
		return _Response.failure("validate_output", str(recipe.get("error", {}).get("code", "RECIPE_RESOLUTION_FAILED")), str(recipe.get("error", {}).get("message", "Recipe resolution failed.")))

	var preset: PresetDefinition = recipe["preset"]
	var output_path: String = str(request["output"])
	if not FileAccess.file_exists(output_path):
		output_path = ProjectSettings.globalize_path(output_path) if output_path.begins_with("res://") else output_path

	var frame_metrics: Dictionary = {}
	var production_manifest: Dictionary = manifest_service.find_manifest_by_output_path(output_path)
	if not production_manifest.is_empty():
		var manifest_output_sha: String = str(production_manifest.get("output", {}).get("sha256", ""))
		if manifest_output_sha.is_empty() or manifest_output_sha == IconStudioFileUtil.file_hash(output_path):
			frame_metrics = production_manifest.get("quality", {}).get("metrics", {})
	var quality: Dictionary = production_quality.validate_output(output_path, purpose_def, preset, frame_metrics)
	if bool(quality.get("success", false)):
		return _Response.success("validate_output", {
			"status": "validated",
			"purpose": purpose_id,
			"recipe": {"id": recipe["preset_id"], "revision": recipe["preset_revision"]},
			"quality": quality,
		})

	var primary: Dictionary = quality.get("errors", [{}])[0]
	return _Response.failure("validate_output", str(primary.get("code", "QUALITY_FAILED")), str(primary.get("message", "Validation failed.")), {"quality": quality})

func _explain_result(request: Dictionary, safe_mode: bool = true) -> Dictionary:
	var manifest_data: Dictionary = {}
	if request.has("job_id"):
		manifest_data = manifest_service.find_manifest_by_job_id(str(request["job_id"]))
	if manifest_data.is_empty() and request.has("manifest"):
		var manifest_path: String = str(request["manifest"])
		if safe_mode and not workspace.is_manifest_path_allowed(manifest_path):
			return _Response.failure("explain_result", "PATH_NOT_ALLOWED", "Manifest path is outside the workspace manifest directory.")
		manifest_data = manifest_service.read_manifest(manifest_path)
	if manifest_data.is_empty():
		return _Response.failure("explain_result", "JOB_NOT_FOUND", "No manifest found for the requested job.")

	return _Response.success("explain_result", {
		"explanation": {
			"job_id": manifest_data.get("job_id", ""),
			"operation": manifest_data.get("operation", ""),
			"purpose": manifest_data.get("purpose", ""),
			"recipe": manifest_data.get("recipe", {}),
			"resolution_reasons": manifest_data.get("resolution_reasons", []),
			"inspection_summary": manifest_data.get("inspection_summary", {}),
			"effective_override": manifest_data.get("effective_override", {}),
			"effective_config_hash": manifest_data.get("effective_config_hash", ""),
			"hints": manifest_data.get("hints", {}),
			"correction": manifest_data.get("correction", {}),
			"quality": manifest_data.get("quality", {}),
			"status": manifest_data.get("status", ""),
			"cache_hit": manifest_data.get("cache_hit", false),
			"trace": manifest_data.get("trace", []),
		},
	})

func _render_expert(request: Dictionary) -> Dictionary:
	var asset_result: Dictionary = workspace.resolve_asset_path(str(request["asset"]))
	if not bool(asset_result.get("success", false)):
		return _Response.failure("render_expert", str(asset_result["error"]["code"]), str(asset_result["error"]["message"]))

	var presets_svc: PresetService = PresetService.new()
	presets_svc.load_all()
	var preset_result: Dictionary = presets_svc.require_preset(str(request["preset"]))
	if not bool(preset_result.get("success", false)):
		return _Response.failure("render_expert", "PRESET_NOT_FOUND", "Preset not found.")

	var override: Dictionary = {}
	for key in ["yaw", "pitch", "roll", "occupancy", "padding", "scale", "fov"]:
		if request.has(key):
			override[key] = request[key]

	var output_path: String = str(request["output"])
	var force: bool = bool(request.get("force", false))
	var result: Dictionary = await render_service.render(asset_result["path"], preset_result["preset"], override, output_path, force)
	if bool(result.get("success", false)):
		return _Response.success("render_expert", result)
	var mapped: Dictionary = _mapped_error(result.get("error", {}))
	return _Response.failure("render_expert", str(mapped.get("code", "RENDER_FAILED")), str(mapped.get("message", "Render failed.")), result)

func _try_cache_hit(output_path: String, purpose_def: Dictionary, preset: PresetDefinition, job_id: String, source_hash: String, source_identity: String, asset_id: String, purpose_id: String, preset_id: String, preset_revision: int, effective_config_hash: String, hints: Dictionary, force: bool) -> Dictionary:
	if force or not FileAccess.file_exists(output_path):
		return {}
	var manifest: Dictionary = manifest_service.find_manifest_by_job_id(job_id)
	if manifest.is_empty():
		return {}
	var output_sha256: String = IconStudioFileUtil.file_hash(output_path)
	if not manifest_service.manifest_matches_identity(manifest, {
		"source_hash": source_hash,
		"source_identity": source_identity,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"preset_id": preset_id,
		"preset_revision": preset_revision,
		"effective_config_hash": effective_config_hash,
		"output_sha256": output_sha256,
	}):
		return {}
	var quality: Dictionary = production_quality.validate_output(output_path, purpose_def, preset, manifest.get("quality", {}).get("metrics", {}))
	if not bool(quality.get("success", false)):
		return {}
	var manifest_path: String = manifest_service.manifest_path_for_job(job_id)
	return _success_render(job_id, asset_id, purpose_id, output_path, output_sha256, preset, preset_id, preset_revision, quality, {"render_passes": manifest.get("correction", {}).get("passes", 0)}, manifest.get("correction", {}).get("actions", []), manifest_path, manifest.get("trace", []), true)

func _check_output_collision(output_path: String, source_path: String) -> Dictionary:
	if not FileAccess.file_exists(output_path):
		return {}
	var owned: Dictionary = manifest_service.find_manifest_by_output_path(output_path)
	if owned.is_empty():
		return {}
	var owned_source: String = _normalize_source_path(str(owned.get("source", "")))
	var current_source: String = _normalize_source_path(source_path)
	if owned_source != current_source:
		return _Response.failure("render_asset", "ASSET_ID_COLLISION", "Output path is already owned by a different source.", {"path": output_path, "existing_source": owned.get("source", "")})
	return {}

func _normalize_source_path(path: String) -> String:
	return IconStudioFileUtil.normalize_path(path)

func _success_render(job_id: String, asset_id: String, purpose_id: String, output_path: String, output_sha256: String, preset: PresetDefinition, preset_id: String, preset_revision: int, quality: Dictionary, render_result: Dictionary, correction_actions: Array, manifest_path: String, trace: Array, cache_hit: bool) -> Dictionary:
	return _Response.success("render_asset", {
		"status": "validated",
		"job_id": job_id,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"output": {
			"path": output_path,
			"sha256": output_sha256,
			"width": int(preset.data.get("resolution", {}).get("width", 256)),
			"height": int(preset.data.get("resolution", {}).get("height", 256)),
		},
		"recipe": {"id": preset_id, "revision": preset_revision},
		"quality": {"status": "pass", "occupancy": quality.get("occupancy", 0.0), "clipped": quality.get("clipped", false)},
		"correction": {"passes": int(render_result.get("render_passes", 0)), "actions": correction_actions},
		"manifest": manifest_path,
		"cache_hit": cache_hit,
		"trace": trace,
	})

func _build_manifest_payload(operation: String, job_id: String, source_path: String, source_hash: String, source_identity: String, dependency_hashes: Array, asset_id: String, purpose_id: String, preset_id: String, preset_revision: int, effective_override: Dictionary, effective_config_hash: String, hints: Dictionary, inspection: Dictionary, recipe: Dictionary, quality: Dictionary, render_result: Dictionary, correction_actions: Array, output_path: String, output_sha256: String, trace: Array, cache_hit: bool) -> Dictionary:
	return {
		"operation": operation,
		"job_id": job_id,
		"source": source_path,
		"source_hash": source_hash,
		"source_identity": source_identity,
		"dependency_hashes": dependency_hashes,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"recipe": {"id": preset_id, "revision": preset_revision},
		"effective_override": effective_override,
		"effective_config_hash": effective_config_hash,
		"inspection_summary": _inspection_summary(inspection),
		"resolution_reasons": recipe.get("resolution_reasons", []),
		"hints": hints,
		"correction": {"passes": int(render_result.get("render_passes", 1)), "actions": correction_actions},
		"quality": quality,
		"output": {
			"path": output_path,
			"sha256": output_sha256,
			"width": int(recipe["preset"].data.get("resolution", {}).get("width", 256)),
			"height": int(recipe["preset"].data.get("resolution", {}).get("height", 256)),
		},
		"status": "validated",
		"cache_hit": cache_hit,
		"trace": trace,
		"tool_version": _Version.VERSION,
	}

func _handle_render_failure(operation: String, error: Dictionary, trace: Array, job_id: String, source_path: String, purpose_id: String, asset_id: String, preset_id: String, render_result: Dictionary) -> Dictionary:
	var code: String = str(error.get("code", "RENDER_FAILED"))
	review_queue.record({
		"job_id": job_id,
		"asset": source_path,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"preset_id": preset_id,
		"code": code,
		"metrics": render_result.get("metrics", {}),
		"recommended_action": _ErrorCodes.recommended_action(code),
		"trace": trace,
	})
	var _unused: Dictionary = manifest_service.write_manifest(job_id, {
		"operation": operation,
		"source": source_path,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"recipe": {"id": preset_id},
		"status": "failed",
		"code": code,
		"trace": trace,
	})
	return _Response.failure(operation, code, str(error.get("message", "Render failed.")), {
		"job_id": job_id,
		"attempts": trace,
		"asset_id": asset_id,
		"purpose": purpose_id,
	})

func _handle_quality_failure(operation: String, quality: Dictionary, trace: Array, job_id: String, source_path: String, source_hash: String, source_identity: String, dependency_hashes: Array, purpose_id: String, asset_id: String, preset_id: String, preset_revision: int, inspection: Dictionary, recipe: Dictionary, hints: Dictionary, effective_override: Dictionary, effective_config_hash: String, render_result: Dictionary, correction_actions: Array) -> Dictionary:
	var primary: Dictionary = quality.get("errors", [{}])[0]
	var code: String = str(primary.get("code", "QUALITY_FAILED"))
	if code in ["OUTPUT_CLIPPED", "OCCUPANCY_LOW", "OCCUPANCY_HIGH"]:
		code = "FRAMING_UNRESOLVED"

	review_queue.record({
		"job_id": job_id,
		"asset": source_path,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"preset_id": preset_id,
		"code": code,
		"metrics": quality.get("metrics", {}),
		"correction": {"passes": int(render_result.get("render_passes", 1)), "actions": correction_actions},
		"recommended_action": _ErrorCodes.recommended_action(code),
		"trace": trace,
	})

	var _unused_review_manifest: Dictionary = manifest_service.write_manifest(job_id, {
		"operation": operation,
		"source": source_path,
		"source_hash": source_hash,
		"source_identity": source_identity,
		"dependency_hashes": dependency_hashes,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"recipe": {"id": preset_id, "revision": preset_revision},
		"effective_override": effective_override,
		"effective_config_hash": effective_config_hash,
		"hints": hints,
		"inspection_summary": _inspection_summary(inspection),
		"status": "needs_review",
		"quality": quality,
		"correction": {"passes": int(render_result.get("render_passes", 1)), "actions": correction_actions},
		"trace": trace,
	})

	return {
		"schema_version": _Schema.CURRENT_SCHEMA_VERSION,
		"success": false,
		"status": "needs_review",
		"operation": operation,
		"code": code,
		"message": str(primary.get("message", "Quality validation failed.")),
		"recommended_action": _ErrorCodes.recommended_action(code),
		"job_id": job_id,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"manifest": manifest_service.manifest_path_for_job(job_id),
		"attempts": trace,
		"quality": quality,
	}

func _terminal_failure(operation: String, error: Dictionary, trace: Array, job_id: String = "") -> Dictionary:
	var mapped: Dictionary = _mapped_error(error if error.has("code") else error)
	var code: String = str(mapped.get("code", "INTERNAL_ERROR"))
	var details: Dictionary = {"attempts": trace}
	if not job_id.is_empty():
		details["job_id"] = job_id
	return _Response.failure(operation, code, str(mapped.get("message", error.get("message", "Operation failed."))), details)

func _terminal_review(operation: String, error: Dictionary, trace: Array, source_path: String, purpose_id: String, asset_id: String) -> Dictionary:
	var code: String = str(error.get("code", "RECIPE_RESOLUTION_FAILED"))
	review_queue.record({
		"asset": source_path,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"code": code,
		"recommended_action": _ErrorCodes.recommended_action(code),
		"trace": trace,
	})
	return {
		"schema_version": _Schema.CURRENT_SCHEMA_VERSION,
		"success": false,
		"status": "needs_review",
		"operation": operation,
		"code": code,
		"message": str(error.get("message", "Recipe resolution failed.")),
		"recommended_action": _ErrorCodes.recommended_action(code),
		"attempts": trace,
	}

func _mapped_code(error: Dictionary) -> String:
	return str(_Mapper.map_error(error).get("code", "INTERNAL_ERROR"))

func _mapped_error(error: Dictionary) -> Dictionary:
	return _Mapper.map_error(error)

func _state_entry(state: int, data: Dictionary = {}) -> Dictionary:
	var names: Dictionary = {
		RenderState.RECEIVED: "RECEIVED",
		RenderState.VALIDATED_REQUEST: "VALIDATED_REQUEST",
		RenderState.INSPECTED: "INSPECTED",
		RenderState.RECIPE_RESOLVED: "RECIPE_RESOLVED",
		RenderState.RENDERED: "RENDERED",
		RenderState.MEASURED: "MEASURED",
		RenderState.CORRECTED: "CORRECTED",
		RenderState.VALIDATED_OUTPUT: "VALIDATED_OUTPUT",
		RenderState.COMMITTED: "COMMITTED",
		RenderState.COMPLETED: "COMPLETED",
		RenderState.NEEDS_REVIEW: "NEEDS_REVIEW",
		RenderState.FAILED: "FAILED",
	}
	var entry: Dictionary = {"state": names.get(state, "UNKNOWN")}
	for key in data.keys():
		entry[key] = data[key]
	return entry

func _inspection_summary(inspection: Dictionary) -> Dictionary:
	return {
		"kind": inspection.get("kind", ""),
		"dimensions": inspection.get("dimensions", []),
		"mesh_count": inspection.get("mesh_count", 0),
		"triangle_count": inspection.get("triangle_count", 0),
		"morphology": recipe_resolver.classify_morphology(inspection),
	}

func _cleanup_temp(temp_path: String) -> void:
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
