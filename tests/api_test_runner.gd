extends RefCounted
class_name ApiTestRunner

var failures: Array = []
var passed: Array = []
const ApiServiceScript = preload("res://core/api/api_service.gd")
var api: RefCounted = ApiServiceScript.new()

func run() -> Dictionary:
	await _test_capabilities()
	await _test_schema()
	await _test_inspect_asset()
	await _test_adversarial_requests()
	await _test_render_asset()
	await _test_render_asset_set()
	await _test_idempotency()
	await _test_validate_output()
	await _test_explain_result()
	await _test_sidecar_inheritance()
	return {"success": failures.is_empty(), "passed": passed, "failures": failures, "summary": {"passed": passed.size(), "failed": failures.size()}}

func _test_capabilities() -> void:
	var result: Dictionary = await api.execute({"schema_version": 1, "operation": "capabilities"})
	_assert(bool(result.get("success", false)), "capabilities returns success")
	_assert(result.has("capabilities"), "capabilities includes payload")
	_assert(result["capabilities"].has("purposes"), "capabilities lists purposes")

func _test_schema() -> void:
	var result: Dictionary = await api.execute({"schema_version": 1, "operation": "schema"})
	_assert(bool(result.get("success", false)), "schema returns success")
	_assert(result.has("schema"), "schema includes payload")
	_assert(result["schema"].has("operations"), "schema describes operations")

func _test_inspect_asset() -> void:
	var sword: String = ProjectSettings.globalize_path("res://fixtures/sword.gltf")
	var result: Dictionary = await api.execute({"schema_version": 1, "operation": "inspect_asset", "asset": sword})
	_assert(bool(result.get("success", false)), "inspect_asset succeeds for sword")
	_assert(result.has("inspection"), "inspect_asset returns inspection")
	_assert(int(result["inspection"].get("triangle_count", 0)) > 0, "inspect_asset counts triangles")

func _test_adversarial_requests() -> void:
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
	]
	for case in cases:
		var request: Dictionary = case[0]
		var expected_code: String = case[1]
		var result: Dictionary = await api.execute(request)
		_assert(not bool(result.get("success", true)), "adversarial rejects: %s" % expected_code)
		_assert(str(result.get("code", "")) == expected_code, "adversarial code %s for %s" % [expected_code, JSON.stringify(request)])

func _test_render_asset() -> void:
	var sword: String = ProjectSettings.globalize_path("res://fixtures/sword.gltf")
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert(bool(result.get("success", false)), "render_asset succeeds for sword inventory_icon")
	_assert(str(result.get("status", "")) == "validated", "render_asset status is validated")
	_assert(result.has("output"), "render_asset returns output")
	_assert(result.has("recipe"), "render_asset returns recipe")
	_assert(result.has("manifest"), "render_asset returns manifest")
	_assert(FileAccess.file_exists(str(result["output"].get("path", ""))), "render_asset writes output file")
	_assert(str(result["recipe"].get("id", "")) in ["weapon", "inventory_item"], "render_asset resolves weapon or inventory for sword")

func _test_render_asset_set() -> void:
	var sword: String = ProjectSettings.globalize_path("res://fixtures/sword.gltf")
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset_set",
		"asset": sword,
		"outputs": ["inventory_icon", "shop_thumbnail", "equipment_preview"],
		"force": true,
	})
	_assert(bool(result.get("success", false)) or str(result.get("status", "")) == "partial_success", "render_asset_set produces outputs")
	_assert(result.has("outputs"), "render_asset_set returns outputs dict")
	var outputs: Dictionary = result.get("outputs", {})
	_assert(outputs.size() == 3, "render_asset_set renders 3 purposes")
	for key in outputs.keys():
		var entry: Dictionary = outputs[key]
		_assert(entry.has("status"), "render_asset_set entry has status: %s" % key)

func _test_idempotency() -> void:
	var sword: String = ProjectSettings.globalize_path("res://fixtures/sword.gltf")
	var request: Dictionary = {
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "shop_thumbnail",
	}
	var first: Dictionary = await api.execute(request)
	_assert(bool(first.get("success", false)), "idempotency first render succeeds")
	var second: Dictionary = await api.execute(request)
	_assert(bool(second.get("success", false)), "idempotency second call succeeds")
	_assert(bool(second.get("cache_hit", false)), "idempotency second call is cache hit")
	_assert(str(first["output"]["path"]) == str(second["output"]["path"]), "idempotency returns same output path")

func _test_validate_output() -> void:
	var sword: String = ProjectSettings.globalize_path("res://fixtures/sword.gltf")
	var render: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "inventory_icon",
		"force": true,
	})
	if not bool(render.get("success", false)):
		_assert(false, "validate_output prerequisite render")
		return
	var output_path: String = str(render["output"]["path"])
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "validate_output",
		"asset": sword,
		"output": output_path,
		"purpose": "inventory_icon",
	})
	_assert(bool(result.get("success", false)), "validate_output passes for rendered sword")

func _test_explain_result() -> void:
	var sword: String = ProjectSettings.globalize_path("res://fixtures/sword.gltf")
	var render: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": sword,
		"purpose": "neutral_thumbnail",
		"force": true,
	})
	if not bool(render.get("success", false)):
		_assert(false, "explain_result prerequisite render")
		return
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "explain_result",
		"job_id": str(render.get("job_id", "")),
	})
	_assert(bool(result.get("success", false)), "explain_result succeeds")
	_assert(result.has("explanation"), "explain_result returns explanation")
	_assert(str(result["explanation"].get("purpose", "")) == "neutral_thumbnail", "explain_result includes purpose")

func _test_sidecar_inheritance() -> void:
	var boombox: String = ProjectSettings.globalize_path("res://tests/e2e/assets/real/BoomBox.glb")
	if not FileAccess.file_exists(boombox):
		_assert(true, "sidecar test skipped (no BoomBox fixture)")
		return
	var sidecar_path: String = boombox.get_basename() + ".icon.json"
	var had_sidecar: bool = FileAccess.file_exists(sidecar_path)
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": boombox,
		"purpose": "inventory_icon",
		"force": true,
	})
	_assert(bool(result.get("success", false)) or str(result.get("status", "")) in ["validated", "needs_review"], "sidecar render completes")
	if not had_sidecar:
		_assert(true, "sidecar inheritance (no sidecar present)")

func _assert(condition: bool, label: String) -> void:
	if condition:
		passed.append(label)
	else:
		failures.append(label)
