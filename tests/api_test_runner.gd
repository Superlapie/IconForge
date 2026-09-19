extends RefCounted
class_name ApiTestRunner

var failures: Array = []
var passed: Array = []
var scenarios_run: int = 0
const ApiServiceScript = preload("res://core/api/api_service.gd")
var api: RefCounted = ApiServiceScript.new()
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
	var sword: String = repo_root.path_join("fixtures/sword.gltf")
	var sidecar_path: String = sword.get_basename() + ".icon.json"
	var had_sidecar: bool = FileAccess.file_exists(sidecar_path)
	var original: String = ""
	if had_sidecar:
		original = FileAccess.get_file_as_string(sidecar_path)
	IconStudioFileUtil.write_json_atomic(sidecar_path, {"yaw": 33, "occupancy": 0.77})
	var with_hint: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"hints": {"framing_bias": "tighter"},
		"force": true,
	})
	_assert(bool(with_hint.get("success", false)) or str(with_hint.get("status", "")) == "needs_review", "sidecar precedence render completes")
	if had_sidecar:
		IconStudioFileUtil.write_text_atomic(sidecar_path, original)
	elif FileAccess.file_exists(sidecar_path):
		DirAccess.remove_absolute(sidecar_path)

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
	IconStudioFileUtil.write_text_atomic(dest, original)
	var error: Error = IconStudioFileUtil.safe_replace_file(repo_root.path_join("out/missing-temp.txt"), dest)
	_assert(error != OK, "safe_replace missing temp fails")
	_assert(FileAccess.get_file_as_string(dest) == original, "safe_replace preserves destination on failure")

func _assert(condition: bool, label: String) -> void:
	if condition:
		passed.append(label)
	else:
		failures.append(label)
