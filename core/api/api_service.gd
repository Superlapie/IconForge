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
var workspace: RefCounted = _Workspace.new()
var inspector: AssetInspector = AssetInspector.new()
var render_service: RenderService = RenderService.new()
var production_quality: RefCounted = _ProductionQuality.new()
var job_service: RefCounted = _JobService.new()
var manifest_service: RefCounted = _ManifestService.new()
var review_queue: RefCounted = _ReviewQueue.new()
var overrides: OverrideService = OverrideService.new()

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
			return _explain_result(validated_request)
		"render_expert":
			return await _render_expert(validated_request)
		_:
			return _Response.failure(operation, "UNKNOWN_OPERATION", "Unknown operation '%s'." % operation)

func _inspect_asset(request: Dictionary) -> Dictionary:
	var asset_result: Dictionary = workspace.resolve_asset_path(str(request["asset"]))
	if not bool(asset_result.get("success", false)):
		return _Response.failure("inspect_asset", str(asset_result["error"]["code"]), str(asset_result["error"]["message"]), asset_result["error"])
	var inspection: Dictionary = inspector.inspect(asset_result["path"])
	if not bool(inspection.get("success", false)):
		var err: Dictionary = inspection.get("error", {})
		return _Response.failure("inspect_asset", str(err.get("code", "SOURCE_IMPORT_FAILED")), str(err.get("message", "Inspection failed.")))
	inspection["asset_id"] = str(request.get("asset_id", asset_result.get("asset_id", "")))
	inspection["source_hash"] = IconStudioFileUtil.file_hash(asset_result["path"])
	inspection["renderable"] = true
	inspection["morphology"] = recipe_resolver.classify_morphology(inspection)
	return _Response.success("inspect_asset", {"inspection": inspection})

func _render_asset(request: Dictionary, safe_mode: bool) -> Dictionary:
	var trace: Array = []
	var state: int = RenderState.RECEIVED
	trace.append(_state_entry(state))

	var asset_result: Dictionary = workspace.resolve_asset_path(str(request["asset"]))
	if not bool(asset_result.get("success", false)):
		return _terminal_failure("render_asset", asset_result["error"], trace)
	state = RenderState.VALIDATED_REQUEST
	trace.append(_state_entry(state))

	var source_path: String = asset_result["path"]
	var asset_id: String = str(request.get("asset_id", asset_result.get("asset_id", "")))
	var purpose_id: String = str(request["purpose"])
	var hints: Dictionary = request.get("hints", {}) if request.has("hints") else {}
	var force: bool = bool(request.get("force", false))
	var purpose_def: Dictionary = purposes.get_purpose(purpose_id)

	var inspection: Dictionary = inspector.inspect(source_path)
	state = RenderState.INSPECTED
	trace.append(_state_entry(state, {"source_hash": IconStudioFileUtil.file_hash(source_path)}))
	if not bool(inspection.get("success", false)):
		return _terminal_failure("render_asset", inspection.get("error", {}), trace)

	var recipe: Dictionary = recipe_resolver.resolve(purpose_id, inspection, hints)
	state = RenderState.RECIPE_RESOLVED
	trace.append(_state_entry(state, {"preset_id": recipe.get("preset_id", ""), "reasons": recipe.get("resolution_reasons", [])}))
	if not bool(recipe.get("success", false)):
		return _terminal_review("render_asset", recipe.get("error", {}), trace, source_path, purpose_id, asset_id)

	var preset: PresetDefinition = recipe["preset"]
	var preset_id: String = str(recipe["preset_id"])
	var preset_revision: int = int(recipe["preset_revision"])
	var job_id: String = job_service.build_job_id("render_asset", source_path, purpose_id, preset_id, preset_revision, hints)

	var output_result: Dictionary = workspace.resolve_output_path(purpose_id, asset_id, purposes)
	if not bool(output_result.get("success", false)):
		return _terminal_failure("render_asset", output_result["error"], trace, job_id)
	var output_path: String = output_result["path"]
	IconStudioFileUtil.ensure_directory(output_path)

	var existing_valid: Dictionary = _check_existing_valid(output_path, purpose_def, preset, source_path, purpose_id, job_id, force)
	if not existing_valid.is_empty():
		return existing_valid

	var sidecar: Dictionary = overrides.load_for_source(source_path)
	var merged_override: Dictionary = PresetDefinition.deep_merge(
		sidecar.get("override", {}),
		recipe.get("override_patch", {})
	)

	var temp_path: String = "%s.pending.%s.png" % [output_path.get_basename(), job_id]
	var correction_actions: Array = []
	var render_result: Dictionary = await render_service.render(source_path, preset, merged_override, temp_path, true)
	state = RenderState.RENDERED
	trace.append(_state_entry(state, {"render_passes": render_result.get("render_passes", 1)}))

	if not bool(render_result.get("success", false)):
		_cleanup_temp(temp_path)
		var render_err: Dictionary = render_result.get("error", {"code": "RENDER_FAILED", "message": "Render failed."})
		return _handle_render_failure("render_asset", render_err, trace, job_id, source_path, purpose_id, asset_id, preset_id, render_result)

	state = RenderState.MEASURED
	var quality: Dictionary = production_quality.validate_output(temp_path, purpose_def, preset, inspection)
	trace.append(_state_entry(state, {"occupancy": quality.get("occupancy", 0.0), "clipped": quality.get("clipped", false)}))

	if int(render_result.get("render_passes", 1)) > 1:
		state = RenderState.CORRECTED
		correction_actions.append({"passes": render_result.get("render_passes", 1), "type": "auto_framing"})
		trace.append(_state_entry(state, {"actions": correction_actions}))

	if not bool(quality.get("success", false)):
		_cleanup_temp(temp_path)
		return _handle_quality_failure("render_asset", quality, trace, job_id, source_path, purpose_id, asset_id, preset_id, preset_revision, inspection, recipe, hints, render_result, correction_actions, output_path)

	state = RenderState.VALIDATED_OUTPUT
	trace.append(_state_entry(state))

	var commit_error: Error = _commit_temp(temp_path, output_path)
	if commit_error != OK:
		_cleanup_temp(temp_path)
		return _Response.failure("render_asset", "WRITE_FAILED", "Could not commit validated output.", {"job_id": job_id, "trace": trace})

	state = RenderState.COMMITTED
	trace.append(_state_entry(state))

	var manifest_path: String = manifest_service.write_manifest(job_id, {
		"operation": "render_asset",
		"source": source_path,
		"source_hash": IconStudioFileUtil.file_hash(source_path),
		"asset_id": asset_id,
		"purpose": purpose_id,
		"recipe": {"id": preset_id, "revision": preset_revision},
		"inspection_summary": _inspection_summary(inspection),
		"resolution_reasons": recipe.get("resolution_reasons", []),
		"hints": hints,
		"correction": {"passes": int(render_result.get("render_passes", 1)), "actions": correction_actions},
		"quality": quality,
		"output": {"path": output_path, "sha256": IconStudioFileUtil.file_hash(output_path), "width": preset.data.get("resolution", {}).get("width", 256), "height": preset.data.get("resolution", {}).get("height", 256)},
		"status": "validated",
		"cache_hit": false,
		"trace": trace,
	})

	var job_record: Dictionary = {
		"job_id": job_id,
		"operation": "render_asset",
		"status": "validated",
		"manifest": manifest_path,
		"trace": trace,
	}
	job_service.store_job_record(job_id, job_record)

	state = RenderState.COMPLETED
	return _Response.success("render_asset", {
		"status": "validated",
		"job_id": job_id,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"output": {
			"path": output_path,
			"sha256": IconStudioFileUtil.file_hash(output_path),
			"width": int(preset.data.get("resolution", {}).get("width", 256)),
			"height": int(preset.data.get("resolution", {}).get("height", 256)),
		},
		"recipe": {"id": preset_id, "revision": preset_revision},
		"quality": {"status": "pass", "occupancy": quality.get("occupancy", 0.0), "clipped": quality.get("clipped", false)},
		"correction": {"passes": int(render_result.get("render_passes", 1)), "actions": correction_actions},
		"manifest": manifest_path,
		"cache_hit": false,
		"trace": trace,
	})

func _render_asset_set(request: Dictionary, safe_mode: bool) -> Dictionary:
	var asset_result: Dictionary = workspace.resolve_asset_path(str(request["asset"]))
	if not bool(asset_result.get("success", false)):
		return _Response.failure("render_asset_set", str(asset_result["error"]["code"]), str(asset_result["error"]["message"]))

	var outputs: Array = request["outputs"]
	var results: Dictionary = {}
	var success_count: int = 0
	var review_count: int = 0
	var fail_count: int = 0

	for purpose_id in outputs:
		var single_request: Dictionary = {
			"schema_version": 1,
			"operation": "render_asset",
			"asset": request["asset"],
			"purpose": str(purpose_id),
			"asset_id": request.get("asset_id", asset_result.get("asset_id", "")),
			"force": request.get("force", false),
		}
		if request.has("hints"):
			single_request["hints"] = request["hints"]
		var result: Dictionary = await _render_asset(single_request, safe_mode)
		results[str(purpose_id)] = result
		if bool(result.get("success", false)):
			success_count += 1
		elif str(result.get("status", "")) == "needs_review":
			review_count += 1
		else:
			fail_count += 1

	var aggregate_status: String = "validated"
	var aggregate_success: bool = fail_count == 0 and review_count == 0
	if success_count > 0 and (fail_count > 0 or review_count > 0):
		aggregate_status = "partial_success"
		aggregate_success = false
	elif review_count > 0 and success_count == 0:
		aggregate_status = "needs_review"
	elif fail_count > 0 and success_count == 0:
		aggregate_status = "failed"

	return {
		"schema_version": _Schema.CURRENT_SCHEMA_VERSION,
		"success": aggregate_success,
		"status": aggregate_status,
		"operation": "render_asset_set",
		"asset_id": str(request.get("asset_id", asset_result.get("asset_id", ""))),
		"summary": {"total": outputs.size(), "validated": success_count, "needs_review": review_count, "failed": fail_count},
		"outputs": results,
	}

func _validate_output_operation(request: Dictionary) -> Dictionary:
	var asset_result: Dictionary = workspace.resolve_asset_path(str(request["asset"]))
	if not bool(asset_result.get("success", false)):
		return _Response.failure("validate_output", str(asset_result["error"]["code"]), str(asset_result["error"]["message"]))

	var purpose_id: String = str(request["purpose"])
	var purpose_def: Dictionary = purposes.get_purpose(purpose_id)
	if purpose_def.is_empty():
		return _Response.failure("validate_output", "PURPOSE_UNSUPPORTED", "Purpose '%s' is not supported." % purpose_id)

	var inspection: Dictionary = inspector.inspect(asset_result["path"])
	if not bool(inspection.get("success", false)):
		return _Response.failure("validate_output", str(inspection.get("error", {}).get("code", "SOURCE_IMPORT_FAILED")), str(inspection.get("error", {}).get("message", "Inspection failed.")))

	var recipe: Dictionary = recipe_resolver.resolve(purpose_id, inspection)
	if not bool(recipe.get("success", false)):
		return _Response.failure("validate_output", str(recipe.get("error", {}).get("code", "RECIPE_RESOLUTION_FAILED")), str(recipe.get("error", {}).get("message", "Recipe resolution failed.")))

	var preset: PresetDefinition = recipe["preset"]
	var output_path: String = str(request["output"])
	if not FileAccess.file_exists(output_path):
		output_path = ProjectSettings.globalize_path(output_path) if output_path.begins_with("res://") else output_path

	var quality: Dictionary = production_quality.validate_output(output_path, purpose_def, preset, inspection)
	if bool(quality.get("success", false)):
		return _Response.success("validate_output", {
			"status": "validated",
			"purpose": purpose_id,
			"recipe": {"id": recipe["preset_id"], "revision": recipe["preset_revision"]},
			"quality": quality,
		})

	var primary: Dictionary = quality.get("errors", [{}])[0]
	return _Response.failure("validate_output", str(primary.get("code", "QUALITY_FAILED")), str(primary.get("message", "Validation failed.")), {"quality": quality})

func _explain_result(request: Dictionary) -> Dictionary:
	var manifest_data: Dictionary = {}
	if request.has("job_id"):
		manifest_data = manifest_service.find_manifest_by_job_id(str(request["job_id"]))
	if manifest_data.is_empty() and request.has("manifest"):
		manifest_data = manifest_service.read_manifest(str(request["manifest"]))
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

	var presets: PresetService = PresetService.new()
	presets.load_all()
	var preset_result: Dictionary = presets.require_preset(str(request["preset"]))
	if not bool(preset_result.get("success", false)):
		return _Response.failure("render_expert", "PRESET_NOT_FOUND", "Preset not found.")

	var override: Dictionary = {}
	for key in ["yaw", "pitch", "roll", "occupancy", "padding", "scale"]:
		if request.has(key):
			override[key] = request[key]

	var output_path: String = str(request["output"])
	var force: bool = bool(request.get("force", false))
	var result: Dictionary = await render_service.render(asset_result["path"], preset_result["preset"], override, output_path, force)
	if bool(result.get("success", false)):
		return _Response.success("render_expert", result)
	return _Response.failure("render_expert", str(result.get("error", {}).get("code", "RENDER_FAILED")), str(result.get("error", {}).get("message", "Render failed.")), result)

func _check_existing_valid(output_path: String, purpose_def: Dictionary, preset: PresetDefinition, source_path: String, purpose_id: String, job_id: String, force: bool) -> Dictionary:
	if force or not FileAccess.file_exists(output_path):
		return {}
	var quality: Dictionary = production_quality.validate_output(output_path, purpose_def, preset)
	if not bool(quality.get("success", false)):
		return {}
	return _Response.success("render_asset", {
		"status": "validated",
		"job_id": job_id,
		"asset_id": IconStudioFileUtil.source_name(source_path),
		"purpose": purpose_id,
		"output": {
			"path": output_path,
			"sha256": IconStudioFileUtil.file_hash(output_path),
			"width": int(preset.data.get("resolution", {}).get("width", 256)),
			"height": int(preset.data.get("resolution", {}).get("height", 256)),
		},
		"recipe": {"id": preset.get_id(), "revision": preset.get_revision()},
		"quality": {"status": "pass", "occupancy": quality.get("occupancy", 0.0), "clipped": quality.get("clipped", false)},
		"correction": {"passes": 0, "actions": []},
		"cache_hit": true,
	})

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
	return _Response.failure(operation, code, str(error.get("message", "Render failed.")), {
		"job_id": job_id,
		"attempts": trace,
		"asset_id": asset_id,
		"purpose": purpose_id,
	})

func _handle_quality_failure(operation: String, quality: Dictionary, trace: Array, job_id: String, source_path: String, purpose_id: String, asset_id: String, preset_id: String, preset_revision: int, inspection: Dictionary, recipe: Dictionary, hints: Dictionary, render_result: Dictionary, correction_actions: Array, output_path: String) -> Dictionary:
	var primary: Dictionary = quality.get("errors", [{}])[0]
	var code: String = str(primary.get("code", "QUALITY_FAILED"))
	if code in ["OUTPUT_CLIPPED", "OCCUPANCY_LOW", "OCCUPANCY_HIGH", "FRAMING_UNRESOLVED"]:
		code = "FRAMING_UNRESOLVED" if code == "OUTPUT_CLIPPED" else code

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

	manifest_service.write_manifest(job_id, {
		"operation": operation,
		"source": source_path,
		"asset_id": asset_id,
		"purpose": purpose_id,
		"recipe": {"id": preset_id, "revision": preset_revision},
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
		"attempts": trace,
		"quality": quality,
	}

func _terminal_failure(operation: String, error: Dictionary, trace: Array, job_id: String = "") -> Dictionary:
	var code: String = str(error.get("code", "INTERNAL_ERROR"))
	var details: Dictionary = {"attempts": trace}
	if not job_id.is_empty():
		details["job_id"] = job_id
	return _Response.failure(operation, code, str(error.get("message", "Operation failed.")), details)

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

func _commit_temp(temp_path: String, output_path: String) -> Error:
	if not FileAccess.file_exists(temp_path):
		return ERR_FILE_NOT_FOUND
	IconStudioFileUtil.ensure_directory(output_path)
	if FileAccess.file_exists(output_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(output_path))
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(output_path))

func _cleanup_temp(temp_path: String) -> void:
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
