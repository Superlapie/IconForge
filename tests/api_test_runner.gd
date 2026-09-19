extends RefCounted
class_name ApiTestRunner

var failures: Array = []
var passed: Array = []
var scenarios_run: int = 0
const ApiServiceScript = preload("res://core/api/api_service.gd")
var api: RefCounted = ApiServiceScript.new()
var overrides: OverrideService = OverrideService.new()
var repo_root: String = ProjectSettings.globalize_path("res://")

func run() -> Dictionary:
	await _scenario_capabilities()
	await _scenario_schema()
	await _scenario_inspect_asset()
	await _scenario_adversarial_requests()
	await _scenario_schema_float_rejected()
	await _scenario_render_asset_hints()
	await _scenario_render_asset_set_hints()
	await _scenario_expert_numeric_fields()
	await _scenario_asset_id_validation()
	await _scenario_render_inventory()
	await _scenario_all_portrait_purposes()
	await _scenario_equipment_preview_resolution()
	await _scenario_render_asset_set_aggregate()
	await _scenario_idempotency_cache_hit()
	await _scenario_cache_hit_includes_manifest()
	await _scenario_hint_mutation_invalidates_cache()
	await _scenario_missing_manifest_invalidates_cache()
	await _scenario_corrupt_output_invalidates_cache()
	await _scenario_sidecar_precedence()
	await _scenario_same_basename_collision()
	await _scenario_external_workspace()
	await _scenario_path_traversal()
	await _scenario_validate_output()
	await _scenario_explain_result()
	await _scenario_safe_replace_preserves_on_failure()
	await _scenario_workspace_relative_source()
	await _scenario_force_collision_protection()
	await _scenario_invalid_sidecar_fails_closed()
	await _scenario_sidecar_typo_rejected()
	await _scenario_sidecar_lighting_strictness()
	await _scenario_source_mutation_invalidates_cache()
	await _scenario_manifest_commit_failure_blocks_validated()
	await _scenario_replace_failure_preserves_destination()
	await _scenario_portable_default_asset_id()
	await _scenario_validate_portrait_outputs()
	await _scenario_static_image_portrait()
	await _scenario_render_asset_set_inspects_once()
	await _scenario_safe_manifest_path_confinement()
	await _scenario_aggregate_failed()
	await _scenario_aggregate_partial_and_review()
	await _scenario_review_queue_workspace()
	await _scenario_output_lock_contention()
	await _scenario_aggregate_manifest_write_failure()
	await _scenario_workspace_exclusive_relative_path()
	await _scenario_sidecar_value_validation()
	await _scenario_unknown_ownership_fail_closed()
	await _scenario_manifest_lookup_prefers_matching_sha()
	await _scenario_validate_output_provenance()
	await _scenario_opaque_validation_requires_metadata()
	IconForgeFileUtil.reset_test_seams()
	api.manifest_service.reset_test_seams()
	AssetInspector.reset_inspect_count()
	return {
		"success": failures.is_empty(),
		"passed": passed,
		"failures": failures,
		"summary": {
			"scenarios": scenarios_run,
			"assertions_passed": passed.size(),
			"assertions_failed": failures.size(),
		},
	}

func _scenario_capabilities() -> void:
	scenarios_run += 1
	var result: Dictionary = await api.execute({"schema_version": 1, "operation": "capabilities"})
	_assert(bool(result.get("success", false)), "capabilities returns success")
	_assert(result.has("capabilities"), "capabilities includes payload")
	_assert(result["capabilities"].has("purposes"), "capabilities lists purposes")

func _scenario_schema() -> void:
	scenarios_run += 1
	var result: Dictionary = await api.execute({"schema_version": 1, "operation": "schema"})
	_assert(bool(result.get("success", false)), "schema returns success")
	_assert(result.has("schema"), "schema includes payload")
	_assert(result["schema"].has("operations"), "schema describes operations")

func _scenario_inspect_asset() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var result: Dictionary = await api.execute({"schema_version": 1, "operation": "inspect_asset", "asset": sword})
	_assert(bool(result.get("success", false)), "inspect_asset succeeds for sword")
	_assert(result.has("inspection"), "inspect_asset returns inspection")
	_assert(int(result["inspection"].get("triangle_count", 0)) > 0, "inspect_asset counts triangles")

func _scenario_adversarial_requests() -> void:
	scenarios_run += 1
	var cases: Array = [
		[{"operation": "render_asset"}, "INVALID_REQUEST"],
		[{"schema_version": 99, "operation": "render_asset", "asset": "x", "purpose": "inventory_icon"}, "UNSUPPORTED_SCHEMA_VERSION"],
		[{"schema_version": 1, "operation": "typo_op", "asset": "x", "purpose": "inventory_icon"}, "UNKNOWN_OPERATION"],
		[{"schema_version": 1, "operation": "render_asset", "asset": "x", "purpose": "inventory_icon", "yaw": 10}, "EXPERT_FIELD_IN_SAFE_MODE"],
		[{"schema_version": 1, "operation": "render_asset", "asset": "x", "purpose": "not_a_purpose"}, "PURPOSE_UNSUPPORTED"],
		[{"schema_version": 1, "operation": "render_asset", "asset": "fixtures/sword.gltf", "purpose": "inventory_icon", "bogus": true}, "UNKNOWN_FIELD"],
		[{"schema_version": 1, "operation": "render_asset", "asset": "../etc/passwd", "purpose": "inventory_icon"}, "PATH_NOT_ALLOWED"],
		[{"schema_version": 1, "operation": "render_asset", "asset": "missing.glb", "purpose": "inventory_icon"}, "SOURCE_NOT_FOUND"],
		[{"schema_version": 1, "operation": "render_asset_set", "asset": "fixtures/sword.gltf", "outputs": []}, "INVALID_REQUEST"],
		[{"schema_version": 1, "operation": "render_asset_set", "asset": "fixtures/sword.gltf", "outputs": ["inventory_icon", "inventory_icon"]}, "DUPLICATE_OUTPUTS"],
		[{"schema_version": 1, "operation": "render_asset", "asset": "fixtures/sword.gltf", "purpose": "inventory_icon", "hints": {"bogus": true}}, "UNKNOWN_FIELD"],
	]
	for case in cases:
		var request: Dictionary = case[0]
		var expected_code: String = case[1]
		var result: Dictionary = await api.execute(request)
		_assert(not bool(result.get("success", true)), "adversarial rejects: %s" % expected_code)
		_assert(str(result.get("code", "")) == expected_code, "adversarial code %s" % expected_code)

func _scenario_schema_float_rejected() -> void:
	scenarios_run += 1
	var result: Dictionary = await api.execute({
		"schema_version": 1.9,
		"operation": "render_asset",
		"asset": "fixtures/sword.gltf",
		"purpose": "inventory_icon",
	})
	_assert(not bool(result.get("success", true)), "float schema_version rejected")
	_assert(str(result.get("code", "")) == "INVALID_FIELD_TYPE", "float schema_version code")

func _scenario_render_asset_hints() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"hints": {"asset_class": "weapon", "orientation_hint": "diagonal"},
		"force": true,
	})
	_assert(bool(result.get("success", false)), "render_asset with hints succeeds")
	_assert(str(result.get("recipe", {}).get("id", "")) == "weapon", "asset_class weapon hint selects weapon preset")

func _scenario_render_asset_set_hints() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset_set",
		"asset": sword,
		"outputs": ["inventory_icon", "shop_thumbnail"],
		"hints": {"framing_bias": "looser"},
		"force": true,
	})
	_assert(result.has("outputs"), "render_asset_set hints accepted")
	_assert(int(result.get("summary", {}).get("total", 0)) == 2, "render_asset_set hints renders two outputs")

func _scenario_expert_numeric_fields() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var out_path: String = repo_root.path_join("out/api_expert_test.png")
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_expert",
		"asset": sword,
		"preset": "weapon",
		"output": out_path,
		"yaw": 12.0,
		"pitch": -6.0,
		"roll": 4.0,
		"occupancy": 0.82,
		"padding": 0.08,
		"scale": 1.0,
		"fov": 45.0,
		"force": true,
	}, false)
	_assert(bool(result.get("success", false)), "render_expert accepts numeric fields")

func _scenario_asset_id_validation() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var bad: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"asset_id": "../evil",
	})
	_assert(not bool(bad.get("success", true)), "asset_id traversal rejected")
	_assert(str(bad.get("code", "")) == "PATH_NOT_ALLOWED", "asset_id traversal code")

func _scenario_render_inventory() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert(bool(result.get("success", false)), "render_asset inventory_icon succeeds")
	_assert(str(result.get("status", "")) == "validated", "render_asset validated")
	_assert(result.has("manifest"), "render_asset returns manifest")
	_assert(FileAccess.file_exists(str(result["output"].get("path", ""))), "render_asset writes output")

func _scenario_all_portrait_purposes() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	for purpose in ["npc_portrait", "creature_portrait", "boss_portrait"]:
		var result: Dictionary = await api.execute({
			"schema_version": 1,
			"operation": "render_asset",
			"asset": sword,
			"purpose": purpose,
			"force": true,
		})
		_assert(bool(result.get("success", false)), "portrait purpose %s validates" % purpose)
		_assert(int(result.get("output", {}).get("width", 0)) > 0, "portrait %s has width" % purpose)

func _scenario_equipment_preview_resolution() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "equipment_preview",
		"force": true,
	})
	_assert(bool(result.get("success", false)), "equipment_preview renders")
	_assert(int(result.get("output", {}).get("width", 0)) == 512, "equipment_preview is 512 wide")
	_assert(int(result.get("output", {}).get("height", 0)) == 512, "equipment_preview is 512 tall")
	_assert(str(result.get("recipe", {}).get("id", "")) == "equipment_preview", "equipment_preview uses equipment preset")

func _scenario_render_asset_set_aggregate() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset_set",
		"asset": sword,
		"outputs": ["inventory_icon", "shop_thumbnail", "equipment_preview"],
		"force": true,
	})
	_assert(result.has("job_id"), "render_asset_set has aggregate job_id")
	_assert(result.has("manifest"), "render_asset_set has aggregate manifest")
	_assert(str(result.get("status", "")) in ["validated", "partial_success"], "render_asset_set aggregate status")
	_assert(int(result.get("summary", {}).get("total", 0)) == 3, "render_asset_set three children")

func _scenario_idempotency_cache_hit() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var request: Dictionary = {
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "neutral_thumbnail",
	}
	var first: Dictionary = await api.execute(request)
	_assert(bool(first.get("success", false)), "idempotency first render")
	var second: Dictionary = await api.execute(request)
	_assert(bool(second.get("success", false)), "idempotency second render")
	_assert(bool(second.get("cache_hit", false)), "idempotency cache_hit true")
	_assert(str(first["output"]["path"]) == str(second["output"]["path"]), "idempotency same path")

func _scenario_cache_hit_includes_manifest() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var request: Dictionary = {
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "shop_thumbnail",
	}
	await api.execute(request)
	var cached: Dictionary = await api.execute(request)
	_assert(bool(cached.get("cache_hit", false)), "cache hit scenario")
	_assert(not str(cached.get("manifest", "")).is_empty(), "cache hit includes manifest")

func _scenario_hint_mutation_invalidates_cache() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var base: Dictionary = {
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"hints": {"asset_class": "weapon"},
		"force": true,
	}
	var first: Dictionary = await api.execute(base)
	_assert(bool(first.get("success", false)), "hint mutation first render")
	base["hints"] = {"asset_class": "armor"}
	base["force"] = false
	var second: Dictionary = await api.execute(base)
	_assert(bool(second.get("success", false)), "hint mutation second render")
	_assert(not bool(second.get("cache_hit", true)), "hint mutation prevents cache hit")

func _scenario_missing_manifest_invalidates_cache() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var request: Dictionary = {
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"hints": {"asset_class": "generic"},
	}
	var first: Dictionary = await api.execute(request)
	_assert(bool(first.get("success", false)), "missing manifest first render")
	var manifest_path: String = str(first.get("manifest", ""))
	if FileAccess.file_exists(manifest_path):
		DirAccess.remove_absolute(manifest_path)
	var second: Dictionary = await api.execute(request)
	_assert(bool(second.get("success", false)), "missing manifest re-renders")
	_assert(not bool(second.get("cache_hit", true)), "missing manifest prevents cache hit")

func _scenario_corrupt_output_invalidates_cache() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var request: Dictionary = {
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"hints": {"asset_class": "resource"},
	}
	var first: Dictionary = await api.execute(request)
	_assert(bool(first.get("success", false)), "corrupt cache first render")
	var output_path: String = str(first["output"]["path"])
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string("not a png")
		file.close()
	var second: Dictionary = await api.execute(request)
	_assert(bool(second.get("success", false)), "corrupt output re-renders")
	_assert(not bool(second.get("cache_hit", true)), "corrupt output prevents cache hit")

func _scenario_sidecar_precedence() -> void:
	scenarios_run += 1
	var temp_dir: String = repo_root.path_join("out/sidecar_prec_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temp_dir)
	var sword: String = temp_dir.path_join("sword.gltf")
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), sword)
	var sidecar_path: String = overrides.sidecar_path(sword)
	IconForgeFileUtil.write_json_atomic(sidecar_path, {"yaw": 33, "occupancy": 0.77})
	var with_hint: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"hints": {"framing_bias": "tighter"},
		"force": true,
	})
	_assert(bool(with_hint.get("success", false)) or str(with_hint.get("status", "")) == "needs_review", "sidecar precedence render completes")

func _scenario_invalid_sidecar_fails_closed() -> void:
	scenarios_run += 1
	var temp_dir: String = repo_root.path_join("out/sidecar_bad_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temp_dir)
	var sword: String = temp_dir.path_join("sword.gltf")
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), sword)
	var sidecar_path: String = overrides.sidecar_path(sword)
	IconForgeFileUtil.write_text_atomic(sidecar_path, "{not json")
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert(not bool(result.get("success", true)), "invalid sidecar blocks render")
	_assert(str(result.get("code", "")) == "OVERRIDE_INVALID", "invalid sidecar code")

func _scenario_sidecar_typo_rejected() -> void:
	scenarios_run += 1
	var temp_dir: String = repo_root.path_join("out/sidecar_typo_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temp_dir)
	var sword: String = temp_dir.path_join("sword.gltf")
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), sword)
	var sidecar_path: String = overrides.sidecar_path(sword)
	IconForgeFileUtil.write_json_atomic(sidecar_path, {"ocupancy": 0.8})
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert(not bool(result.get("success", true)), "sidecar typo blocks render")
	_assert(str(result.get("code", "")) == "OVERRIDE_INVALID", "sidecar typo code")

func _scenario_sidecar_lighting_strictness() -> void:
	scenarios_run += 1
	var temp_dir: String = repo_root.path_join("out/sidecar_light_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temp_dir)
	var sword: String = temp_dir.path_join("sword.gltf")
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), sword)
	var sidecar_path: String = overrides.sidecar_path(sword)
	var first: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert(bool(first.get("success", false)), "sidecar lighting baseline renders")
	var output_path: String = str(first.get("output", {}).get("path", ""))
	IconForgeFileUtil.write_json_atomic(sidecar_path, {
		"lighting": {
			"rig": "neutral_studio",
			"ambient_energy": 0.5,
			"key": {"angle": [-30.0, 45.0, 0.0], "intensity": 1.2, "color": [1.0, 0.93, 0.84, 1.0], "shadow": true},
		},
	})
	var valid_light: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert(bool(valid_light.get("success", false)) or str(valid_light.get("status", "")) == "needs_review", "valid lighting sidecar accepted")
	var preserved_hash: String = IconForgeFileUtil.file_hash(output_path)
	IconForgeFileUtil.write_json_atomic(sidecar_path, {"lighting": {"kee": {"angle": [-30.0, 45.0, 0.0]}}})
	var misspelled: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert_override_invalid(misspelled, "misspelled lighting field")
	_assert(IconForgeFileUtil.file_hash(output_path) == preserved_hash, "misspelled lighting preserves output")
	IconForgeFileUtil.write_json_atomic(sidecar_path, {"lighting": {"key": {"angle": [-30.0, 45.0, 0.0], "energy": 1.2}}})
	var unknown_nested: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert_override_invalid(unknown_nested, "unknown nested lighting field")
	IconForgeFileUtil.write_json_atomic(sidecar_path, {"composition": {"bogus": 1}})
	var unknown_object: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert_override_invalid(unknown_object, "unknown nested object field")
	IconForgeFileUtil.write_json_atomic(sidecar_path, {"lighting": {"key": {"angle": [0.0, "bad", 0.0]}}})
	var malformed: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert_override_invalid(malformed, "malformed lighting value")
	_assert(FileAccess.file_exists(output_path), "invalid lighting sidecar does not delete output")
	_assert(IconForgeFileUtil.file_hash(output_path) == preserved_hash, "invalid lighting sidecar leaves prior artifact")

func _assert_override_invalid(result: Dictionary, label: String) -> void:
	_assert(not bool(result.get("success", true)), "%s blocks render" % label)
	_assert(str(result.get("code", "")) == "OVERRIDE_INVALID", "%s returns OVERRIDE_INVALID" % label)
	_assert(str(result.get("recommended_action", "")) == "fix_human_sidecar", "%s includes recommended_action" % label)
	_assert(str(result.get("status", "")) == "failed", "%s status is failed" % label)

func _scenario_same_basename_collision() -> void:
	scenarios_run += 1
	var dir_a: String = repo_root.path_join("out/collision_a")
	var dir_b: String = repo_root.path_join("out/collision_b")
	DirAccess.make_dir_recursive_absolute(dir_a)
	DirAccess.make_dir_recursive_absolute(dir_b)
	var copy_a: String = dir_a.path_join("item.gltf")
	var copy_b: String = dir_b.path_join("item.gltf")
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), copy_a)
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), copy_b)
	var first: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": copy_a,
		"purpose": "inventory_icon",
		"force": true,
	})
	var second: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": copy_b,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert(bool(first.get("success", false)), "collision first asset renders")
	_assert(bool(second.get("success", false)), "collision second asset renders")
	_assert(str(first.get("asset_id", "")) != str(second.get("asset_id", "")), "collision distinct asset_ids")
	_assert(str(first["output"]["path"]) != str(second["output"]["path"]), "collision distinct output paths")

func _scenario_external_workspace() -> void:
	scenarios_run += 1
	var temp_root: String = repo_root.path_join("out/workspace_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temp_root)
	var external_api: RefCounted = ApiServiceScript.new(temp_root)
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var result: Dictionary = await external_api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert(bool(result.get("success", false)), "external workspace render")
	var output_path: String = str(result["output"]["path"])
	_assert(output_path.begins_with(temp_root), "external workspace confines output")
	_assert(not output_path.contains(".."), "external workspace no traversal")

func _scenario_path_traversal() -> void:
	scenarios_run += 1
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": "fixtures/../../etc/passwd",
		"purpose": "inventory_icon",
	})
	_assert(not bool(result.get("success", true)), "path traversal blocked")

func _scenario_validate_output() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var render: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	if not bool(render.get("success", false)):
		_assert(false, "validate_output prerequisite")
		return
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "validate_output",
		"asset": sword,
		"output": str(render["output"]["path"]),
		"purpose": "inventory_icon",
	})
	_assert(bool(result.get("success", false)), "validate_output passes")

func _scenario_explain_result() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var render: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "neutral_thumbnail",
		"force": true,
	})
	if not bool(render.get("success", false)):
		_assert(false, "explain_result prerequisite")
		return
	var explain: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "explain_result",
		"job_id": str(render.get("job_id", "")),
	})
	_assert(bool(explain.get("success", false)), "explain_result succeeds")
	_assert(str(explain["explanation"].get("purpose", "")) == "neutral_thumbnail", "explain_result purpose")

func _scenario_safe_replace_preserves_on_failure() -> void:
	scenarios_run += 1
	var dest: String = repo_root.path_join("out/safe_replace_dest.txt")
	var original: String = "original-content"
	IconForgeFileUtil.write_text_atomic(dest, original)
	var error: Error = IconForgeFileUtil.safe_replace_file(repo_root.path_join("out/missing-temp.txt"), dest)
	_assert(error != OK, "safe_replace missing temp fails")
	_assert(FileAccess.get_file_as_string(dest) == original, "safe_replace preserves destination on failure")

func _scenario_workspace_relative_source() -> void:
	scenarios_run += 1
	var ws: String = repo_root.path_join("out/ws_relative_%d" % Time.get_ticks_usec())
	var asset_dir: String = ws.path_join("assets/items")
	DirAccess.make_dir_recursive_absolute(asset_dir)
	var asset_rel: String = "assets/items/test_sword.gltf"
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), asset_dir.path_join("test_sword.gltf"))
	var external_api: RefCounted = ApiServiceScript.new(ws)
	var result: Dictionary = await external_api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": asset_rel,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert(bool(result.get("success", false)), "workspace relative source renders")
	_assert(str(result["output"]["path"]).begins_with(ws.path_join("generated")), "workspace relative output confined")

func _scenario_force_collision_protection() -> void:
	scenarios_run += 1
	var dir_a: String = repo_root.path_join("out/force_collision_a")
	var dir_b: String = repo_root.path_join("out/force_collision_b")
	DirAccess.make_dir_recursive_absolute(dir_a)
	DirAccess.make_dir_recursive_absolute(dir_b)
	var copy_a: String = dir_a.path_join("alpha.gltf")
	var copy_b: String = dir_b.path_join("beta.gltf")
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), copy_a)
	DirAccess.copy_absolute(repo_root.path_join("fixtures/potion.gltf"), copy_b)
	var shared_id: String = "shared_output_id_%d" % Time.get_ticks_usec()
	var first: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": copy_a,
		"purpose": "inventory_icon",
		"asset_id": shared_id,
		"force": true,
	})
	_assert(bool(first.get("success", false)), "force collision first render")
	var second: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": copy_b,
		"purpose": "inventory_icon",
		"asset_id": shared_id,
		"force": true,
	})
	_assert(not bool(second.get("success", true)), "force collision blocked")
	_assert(str(second.get("code", "")) == "ASSET_ID_COLLISION", "force collision code")

func _scenario_source_mutation_invalidates_cache() -> void:
	scenarios_run += 1
	var temp_dir: String = repo_root.path_join("out/mutate_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temp_dir)
	var source_path: String = temp_dir.path_join("mutate.gltf")
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), source_path)
	var request: Dictionary = {
		"schema_version": 1,
		"operation": "render_asset",
		"asset": source_path,
		"purpose": "neutral_thumbnail",
	}
	var first: Dictionary = await api.execute(request)
	_assert(bool(first.get("success", false)), "source mutation first render")
	var second: Dictionary = await api.execute(request)
	_assert(bool(second.get("cache_hit", false)), "source mutation cache hit before mutate")
	var overwrite: Error = DirAccess.copy_absolute(repo_root.path_join("fixtures/potion.gltf"), source_path)
	_assert(overwrite == OK, "source mutation replaced file bytes")
	var third: Dictionary = await api.execute(request)
	_assert(bool(third.get("success", false)), "source mutation rerender succeeds")
	_assert(not bool(third.get("cache_hit", true)), "source mutation invalidates cache")
	if bool(third.get("success", false)):
		var first_manifest: Dictionary = IconForgeFileUtil.read_json(str(first.get("manifest", "")))
		var third_manifest: Dictionary = IconForgeFileUtil.read_json(str(third.get("manifest", "")))
		_assert(str(first_manifest.get("source_hash", "")) != str(third_manifest.get("source_hash", "")), "source mutation changes source hash")

func _scenario_manifest_commit_failure_blocks_validated() -> void:
	scenarios_run += 1
	IconForgeFileUtil.reset_test_seams()
	IconForgeFileUtil.test_write_json_atomic_error = ERR_CANT_CREATE
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"asset_id": "manifest_commit_failure_probe",
		"hints": {"asset_class": "generic"},
		"force": true,
	})
	IconForgeFileUtil.reset_test_seams()
	_assert(not bool(result.get("success", true)), "manifest failure not validated")
	_assert(str(result.get("code", "")) == "WRITE_FAILED", "manifest failure code")

func _scenario_replace_failure_preserves_destination() -> void:
	scenarios_run += 1
	IconForgeFileUtil.reset_test_seams()
	var dest: String = repo_root.path_join("out/replace_failure_dest.txt")
	var temp: String = repo_root.path_join("out/replace_failure_temp.txt")
	var original: String = "keep-me"
	IconForgeFileUtil.write_text_atomic(dest, original)
	IconForgeFileUtil.write_text_atomic(temp, "replacement")
	IconForgeFileUtil.test_fail_replace_after_backup = true
	var error: Error = IconForgeFileUtil.safe_replace_file(temp, dest)
	IconForgeFileUtil.reset_test_seams()
	_assert(error != OK, "injected replace failure returns error")
	_assert(FileAccess.get_file_as_string(dest) == original, "injected replace failure preserves destination")

func _scenario_portable_default_asset_id() -> void:
	scenarios_run += 1
	var ws1: String = repo_root.path_join("out/portable_ws1_%d" % Time.get_ticks_usec())
	var ws2: String = repo_root.path_join("out/portable_ws2_%d" % Time.get_ticks_usec())
	for ws in [ws1, ws2]:
		DirAccess.make_dir_recursive_absolute(ws.path_join("assets/items"))
		DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), ws.path_join("assets/items/sword.gltf"))
	var api1: RefCounted = ApiServiceScript.new(ws1)
	var api2: RefCounted = ApiServiceScript.new(ws2)
	var rel: String = "assets/items/sword.gltf"
	var r1: Dictionary = await api1.execute({"schema_version": 1, "operation": "inspect_asset", "asset": rel})
	var r2: Dictionary = await api2.execute({"schema_version": 1, "operation": "inspect_asset", "asset": rel})
	_assert(bool(r1.get("success", false)) and bool(r2.get("success", false)), "portable inspect succeeds")
	_assert(str(r1["inspection"].get("asset_id", "")) == str(r2["inspection"].get("asset_id", "")), "portable default asset_id matches")

func _scenario_validate_portrait_outputs() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	for purpose in ["npc_portrait", "creature_portrait", "boss_portrait"]:
		var render: Dictionary = await api.execute({
			"schema_version": 1,
			"operation": "render_asset",
			"asset": sword,
			"purpose": purpose,
			"force": true,
		})
		if not bool(render.get("success", false)):
			_assert(false, "validate portrait prerequisite %s" % purpose)
			continue
		var validate: Dictionary = await api.execute({
			"schema_version": 1,
			"operation": "validate_output",
			"asset": sword,
			"output": str(render["output"]["path"]),
			"purpose": purpose,
		})
		_assert(bool(validate.get("success", false)), "validate_output portrait %s" % purpose)

func _scenario_static_image_portrait() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var icon: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	if not bool(icon.get("success", false)):
		_assert(false, "static portrait prerequisite icon")
		return
	var png_path: String = str(icon["output"]["path"])
	var portrait: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": png_path,
		"purpose": "npc_portrait",
		"force": true,
	})
	_assert(bool(portrait.get("success", false)) or str(portrait.get("status", "")) == "needs_review", "static image npc_portrait completes")

func _scenario_render_asset_set_inspects_once() -> void:
	scenarios_run += 1
	AssetInspector.reset_inspect_count()
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	await api.execute({
		"schema_version": 1,
		"operation": "render_asset_set",
		"asset": sword,
		"outputs": ["inventory_icon", "shop_thumbnail"],
		"force": true,
	})
	_assert(AssetInspector.inspect_count == 1, "render_asset_set inspects source once")

func _scenario_safe_manifest_path_confinement() -> void:
	scenarios_run += 1
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "explain_result",
		"manifest": "/etc/passwd",
	})
	_assert(not bool(result.get("success", true)), "arbitrary manifest path rejected")
	_assert(str(result.get("code", "")) == "PATH_NOT_ALLOWED", "manifest path confinement code")

func _scenario_aggregate_failed() -> void:
	scenarios_run += 1
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset_set",
		"asset": "missing-aggregate.glb",
		"outputs": ["inventory_icon", "shop_thumbnail"],
	})
	_assert(not bool(result.get("success", true)), "aggregate missing source fails")
	_assert(str(result.get("status", "")) == "failed", "aggregate missing source status failed")

func _scenario_aggregate_partial_and_review() -> void:
	scenarios_run += 1
	var dir_a: String = repo_root.path_join("out/agg_a")
	var dir_b: String = repo_root.path_join("out/agg_b")
	DirAccess.make_dir_recursive_absolute(dir_a)
	DirAccess.make_dir_recursive_absolute(dir_b)
	var copy_a: String = dir_a.path_join("owner.gltf")
	var copy_b: String = dir_b.path_join("challenger.gltf")
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), copy_a)
	DirAccess.copy_absolute(repo_root.path_join("fixtures/potion.gltf"), copy_b)
	var shared_id: String = "agg_partial_owner_%d" % Time.get_ticks_usec()
	var owner: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": copy_a,
		"purpose": "inventory_icon",
		"asset_id": shared_id,
		"force": true,
	})
	_assert(bool(owner.get("success", false)), "aggregate partial owner renders")
	var mixed: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset_set",
		"asset": copy_b,
		"asset_id": shared_id,
		"outputs": ["inventory_icon", "shop_thumbnail"],
		"force": true,
	})
	_assert(str(mixed.get("status", "")) == "partial_success", "aggregate mixed collision is partial_success")
	var png: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	png.fill(Color(0, 0, 0, 0))
	var empty_path: String = repo_root.path_join("out/empty_portrait_src.png")
	png.save_png(empty_path)
	var review: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset_set",
		"asset": empty_path,
		"outputs": ["inventory_icon", "shop_thumbnail"],
		"force": true,
	})
	_assert(str(review.get("status", "")) in ["needs_review", "failed", "partial_success"], "aggregate empty image is non-validated")
	if str(review.get("status", "")) == "needs_review":
		_assert(int(review.get("summary", {}).get("validated", 1)) == 0, "needs_review aggregate has zero validated")

func _scenario_review_queue_workspace() -> void:
	scenarios_run += 1
	var ws: String = repo_root.path_join("out/review_ws_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ws)
	var ReviewQueueScript = load("res://core/api/review_queue.gd")
	var queue: RefCounted = ReviewQueueScript.new(ws)
	queue.record({"code": "FRAMING_UNRESOLVED", "purpose": "inventory_icon"})
	var path: String = str(queue.queue_path())
	_assert(path.begins_with(ws.path_join("generated")), "review queue uses workspace generated root")
	_assert(FileAccess.file_exists(path), "review queue wrote workspace file")

func _scenario_output_lock_contention() -> void:
	scenarios_run += 1
	var OutputLockScript = load("res://core/api/output_lock.gd")
	var path: String = repo_root.path_join("out/lock_probe_%d.png" % Time.get_ticks_usec())
	var first_lock: RefCounted = OutputLockScript.new()
	var first: Dictionary = first_lock.acquire(path, 250)
	_assert(bool(first.get("success", false)), "first lock acquires")
	var second_lock: RefCounted = OutputLockScript.new()
	var second: Dictionary = second_lock.acquire(path, 250)
	_assert(not bool(second.get("success", true)), "second lock times out")
	_assert(str(second.get("error", {}).get("code", "")) == "OUTPUT_LOCKED", "second lock code")
	first_lock.release()
	var third: Dictionary = second_lock.acquire(path, 250)
	_assert(bool(third.get("success", false)), "lock available after release")
	second_lock.release()

func _scenario_aggregate_manifest_write_failure() -> void:
	scenarios_run += 1
	api.manifest_service.reset_test_seams()
	api.manifest_service.test_fail_aggregate_write = true
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset_set",
		"asset": sword,
		"outputs": ["inventory_icon", "shop_thumbnail"],
		"asset_id": "agg_write_fail_%d" % Time.get_ticks_usec(),
		"force": true,
	})
	api.manifest_service.reset_test_seams()
	_assert(not bool(result.get("success", true)), "aggregate write failure is not success")
	_assert(str(result.get("status", "")) == "failed", "aggregate write failure status")
	_assert(str(result.get("code", "")) == "WRITE_FAILED", "aggregate write failure code")
	_assert(str(result.get("manifest", "x")).is_empty(), "aggregate write failure has empty manifest")
	_assert(bool(result.get("outputs", {}).get("inventory_icon", {}).get("success", false)), "aggregate write failure preserves validated children")

func _scenario_workspace_exclusive_relative_path() -> void:
	scenarios_run += 1
	var ws: String = repo_root.path_join("out/ws_exclusive_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ws)
	var external_api: RefCounted = ApiServiceScript.new(ws)
	var missing: Dictionary = await external_api.execute({
		"schema_version": 1,
		"operation": "inspect_asset",
		"asset": "fixtures/sword.gltf",
	})
	_assert(not bool(missing.get("success", true)), "workspace relative path does not fall back to repo")
	_assert(str(missing.get("code", "")) == "SOURCE_NOT_FOUND", "workspace exclusive missing source code")
	var explicit: Dictionary = await external_api.execute({
		"schema_version": 1,
		"operation": "inspect_asset",
		"asset": "res://fixtures/sword.gltf",
	})
	_assert(bool(explicit.get("success", false)), "res:// source still resolves from external workspace")

func _scenario_sidecar_value_validation() -> void:
	scenarios_run += 1
	_assert(not overrides.validate({"camera": {"fov": "banana"}}).is_empty(), "camera fov string rejected")
	_assert(not overrides.validate({"camera": {"orientation_strategy": "super_epic_zoom_mode"}}).is_empty(), "unknown orientation strategy rejected")
	_assert(not overrides.validate({"environment": {"background": 9217}}).is_empty(), "numeric environment background rejected")
	_assert(not overrides.validate({"width": 99999}).is_empty(), "grotesque width rejected")
	_assert(not overrides.validate({"lighting": {"ambient_energy": 99}}).is_empty(), "lighting energy out of range rejected")
	var temp_dir: String = repo_root.path_join("out/sidecar_value_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temp_dir)
	var sword: String = temp_dir.path_join("value.gltf")
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), sword)
	IconForgeFileUtil.write_json_atomic(overrides.sidecar_path(sword), {"camera": {"fov": "banana"}})
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert(not bool(result.get("success", true)), "sidecar value error blocks render")
	_assert(str(result.get("code", "")) == "OVERRIDE_INVALID", "sidecar value error code")

func _scenario_unknown_ownership_fail_closed() -> void:
	scenarios_run += 1
	var dir_a: String = repo_root.path_join("out/owner_unknown_a_%d" % Time.get_ticks_usec())
	var dir_b: String = repo_root.path_join("out/owner_unknown_b_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir_a)
	DirAccess.make_dir_recursive_absolute(dir_b)
	var copy_a: String = dir_a.path_join("alpha.gltf")
	var copy_b: String = dir_b.path_join("beta.gltf")
	DirAccess.copy_absolute(repo_root.path_join("fixtures/sword.gltf"), copy_a)
	DirAccess.copy_absolute(repo_root.path_join("fixtures/potion.gltf"), copy_b)
	var shared_id: String = "unknown_owner_%d" % Time.get_ticks_usec()
	var first: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": copy_a,
		"purpose": "inventory_icon",
		"asset_id": shared_id,
		"force": true,
	})
	_assert(bool(first.get("success", false)), "unknown ownership first render")
	var output_path: String = str(first["output"]["path"])
	var owner_path: String = "%s.owner.json" % output_path
	if FileAccess.file_exists(owner_path):
		DirAccess.remove_absolute(owner_path)
	var second: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": copy_b,
		"purpose": "inventory_icon",
		"asset_id": shared_id,
		"force": true,
	})
	_assert(not bool(second.get("success", true)), "unknown ownership blocks different source")
	_assert(str(second.get("code", "")) == "OUTPUT_OWNERSHIP_UNKNOWN", "unknown ownership code")

func _scenario_manifest_lookup_prefers_matching_sha() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var render: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "neutral_thumbnail",
		"asset_id": "manifest_sha_%d" % Time.get_ticks_usec(),
		"force": true,
	})
	_assert(bool(render.get("success", false)), "manifest sha lookup first render")
	var output_path: String = str(render["output"]["path"])
	var current_hash: String = str(render["output"]["sha256"])
	var decoy_path: String = api.manifest_service.manifests_dir().path_join("0000-decoy.json")
	IconForgeFileUtil.write_json_atomic(decoy_path, {
		"job_id": "0000-decoy",
		"generated_at": "9999-01-01T00:00:00Z",
		"output": {"path": output_path, "sha256": "deadbeef"},
		"quality": {"metrics": {"has_silhouette": true, "occupancy": 0.01, "clipped": false}},
		"source": sword,
		"purpose": "neutral_thumbnail",
	})
	var found: Dictionary = api.manifest_service.find_manifest_by_output_path(output_path)
	_assert(str(found.get("output", {}).get("sha256", "")) == current_hash, "manifest lookup uses current output sha")

func _scenario_validate_output_provenance() -> void:
	scenarios_run += 1
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var potion: String = repo_root.path_join("fixtures/potion.gltf")
	var render: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"asset_id": "provenance_%d" % Time.get_ticks_usec(),
		"force": true,
	})
	_assert(bool(render.get("success", false)), "provenance render")
	var mismatched: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "validate_output",
		"asset": potion,
		"output": str(render["output"]["path"]),
		"purpose": "inventory_icon",
	})
	_assert(not bool(mismatched.get("success", true)), "validate_output rejects other asset")
	_assert(str(mismatched.get("code", "")) == "MANIFEST_MISMATCH", "validate_output provenance code")
	var matched: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "validate_output",
		"asset": sword,
		"output": str(render["output"]["path"]),
		"purpose": "inventory_icon",
	})
	_assert(bool(matched.get("success", false)), "validate_output accepts matching asset")
	_assert(bool(matched.get("provenance_verified", false)), "validate_output provenance verified")

func _scenario_opaque_validation_requires_metadata() -> void:
	scenarios_run += 1
	var image: Image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.1, 0.2, 1.0))
	var path: String = repo_root.path_join("out/opaque_no_manifest_%d.png" % Time.get_ticks_usec())
	image.save_png(path)
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "validate_output",
		"asset": repo_root.path_join("fixtures/sword.gltf"),
		"output": path,
		"purpose": "npc_portrait",
	})
	_assert(not bool(result.get("success", true)), "opaque image without manifest fails")
	_assert(str(result.get("code", "")) == "VALIDATION_METADATA_REQUIRED", "opaque image without manifest code")

func _assert(condition: bool, label: String) -> void:
	if condition:
		passed.append(label)
	else:
		failures.append(label)
