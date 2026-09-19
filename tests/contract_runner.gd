extends RefCounted
class_name IconForgeContractRunner

const _JobIdentity = preload("res://core/api/job_identity.gd")
const _Schema = preload("res://core/api/api_schema.gd")
const _AdvisoryIndex = preload("res://core/util/advisory_index.gd")
const ApiServiceScript = preload("res://core/api/api_service.gd")

var failures: Array = []
var passed: Array = []

func run() -> Dictionary:
	_test_version_metadata()
	_test_schema_capabilities()
	await _test_request_validation()
	_test_path_normalization()
	_test_gltf_dependency_discovery()
	_test_encoded_gltf_dependencies()
	_test_manifest_serialization()
	_test_cache_record_isolation()
	_test_cache_legacy_migration()
	_test_advisory_index_isolation()
	_test_review_path_contract()
	return {
		"success": failures.is_empty(),
		"passed": passed,
		"failures": failures,
		"summary": {"passed": passed.size(), "failed": failures.size()},
	}

func _test_version_metadata() -> void:
	_assert(IconForgeVersion.VERSION == "0.2.0", "tool version is 0.2.0")
	_assert(_Schema.CURRENT_SCHEMA_VERSION == 1, "machine api schema version remains 1")

func _test_schema_capabilities() -> void:
	var caps: Dictionary = _Schema.capabilities()
	_assert(caps.has("operations"), "capabilities lists operations")
	_assert(caps.has("purposes"), "capabilities lists purposes")

func _test_request_validation() -> void:
	var api: RefCounted = ApiServiceScript.new()
	var bad: Dictionary = await api.execute({"schema_version": 1, "operation": "render_asset", "asset": "fixtures/sword.gltf", "purpose": "inventory_icon", "yaw": 12})
	_assert(not bool(bad.get("success", true)), "safe mode rejects expert field")
	_assert(str(bad.get("code", "")) == "EXPERT_FIELD_IN_SAFE_MODE", "expert field code")

func _test_path_normalization() -> void:
	_assert(IconForgeFileUtil.normalize_path("a\\b/c") == "a/b/c", "path normalization converts backslashes")

func _test_gltf_dependency_discovery() -> void:
	var source: String = ProjectSettings.globalize_path("res://tests/e2e/assets/dependency/external.gltf")
	var deps: Array = _JobIdentity.dependency_hashes(source)
	var text: String = "\n".join(PackedStringArray(deps))
	_assert(text.find("external.bin") >= 0, "dependency discovery finds external bin")

func _test_encoded_gltf_dependencies() -> void:
	var source: String = ProjectSettings.globalize_path("res://tests/e2e/assets/dependency/encoded/encoded.gltf")
	var deps: Array = _JobIdentity.dependency_hashes(source)
	var text: String = "\n".join(PackedStringArray(deps))
	_assert(text.find("texture one.png") >= 0, "encoded uri resolves to decoded texture path")
	_assert(text.find("folder name/external.bin") >= 0, "encoded uri resolves to decoded bin path")

func _test_manifest_serialization() -> void:
	var manifest_service: RefCounted = ManifestService.new(ProjectSettings.globalize_path("res://out/contract_manifest_%d" % Time.get_ticks_usec()))
	var result: Dictionary = manifest_service.write_manifest("contract_job", {"operation": "render_asset", "status": "validated"})
	_assert(bool(result.get("success", false)), "manifest write succeeds")
	_assert(FileAccess.file_exists(str(result.get("path", ""))), "manifest file exists")

func _test_cache_record_isolation() -> void:
	var cache_a: CacheService = CacheService.new()
	var cache_b: CacheService = CacheService.new()
	var preset: PresetDefinition = PresetDefinition.new(PresetDefinition.default_data("contract_cache"))
	var key_a: String = "cache_key_a"
	var key_b: String = "cache_key_b"
	var output_a: String = ProjectSettings.globalize_path("res://out/cache_a_%d.png" % Time.get_ticks_usec())
	var output_b: String = ProjectSettings.globalize_path("res://out/cache_b_%d.png" % Time.get_ticks_usec())
	IconForgeFileUtil.write_text_atomic(output_a, "a")
	IconForgeFileUtil.write_text_atomic(output_b, "b")
	cache_a.store(key_a, "fixtures/sword.gltf", output_a, "weapon", {})
	cache_b.store(key_b, "fixtures/potion.gltf", output_b, "consumable", {})
	_assert(bool(cache_a.lookup(key_a, output_a).get("hit", false)), "cache record a readable")
	_assert(bool(cache_b.lookup(key_b, output_b).get("hit", false)), "cache record b readable")
	_assert(FileAccess.file_exists(ProjectSettings.globalize_path(cache_a._record_path(key_a))), "cache record a file exists")
	_assert(FileAccess.file_exists(ProjectSettings.globalize_path(cache_b._record_path(key_b))), "cache record b file exists")
	_assert(cache_a._record_path(key_a) != cache_b._record_path(key_b), "cache records use distinct per-key files")

func _test_cache_legacy_migration() -> void:
	IconForgeFileUtil.reset_test_seams()
	var legacy_path: String = ProjectSettings.globalize_path("user://iconforge/cache.json")
	var legacy_dir: String = legacy_path.get_base_dir()
	var migrated_path: String = "%s.migrated" % legacy_path
	DirAccess.make_dir_recursive_absolute(legacy_dir)
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_path)
	if FileAccess.file_exists(migrated_path):
		DirAccess.remove_absolute(migrated_path)
	var fail_record_path: String = ProjectSettings.globalize_path("user://iconforge/cache/records/%s.json" % CacheService._safe_record_key("legacy_fail_key"))
	if FileAccess.file_exists(fail_record_path):
		DirAccess.remove_absolute(fail_record_path)
	var success_record_path: String = ProjectSettings.globalize_path("user://iconforge/cache/records/%s.json" % CacheService._safe_record_key("legacy_migration_key"))
	if FileAccess.file_exists(success_record_path):
		DirAccess.remove_absolute(success_record_path)
	var output_path: String = ProjectSettings.globalize_path("res://out/cache_legacy_%d.png" % Time.get_ticks_usec())
	IconForgeFileUtil.write_text_atomic(output_path, "legacy")

	var fail_write_error: Error = IconForgeFileUtil.write_json_atomic(legacy_path, {
		"legacy_fail_key": {
			"key": "legacy_fail_key",
			"source": "fixtures/potion.gltf",
			"output": output_path,
			"preset": "consumable",
			"tool_version": IconForgeVersion.VERSION,
			"metrics": {},
		},
	})
	_assert(fail_write_error == OK, "legacy cache fixture written for failed migration test")
	IconForgeFileUtil.test_write_json_atomic_error = ERR_CANT_CREATE
	CacheService.new()
	IconForgeFileUtil.reset_test_seams()
	_assert(FileAccess.file_exists(legacy_path), "legacy cache index kept when migration writes fail")
	_assert(not FileAccess.file_exists(migrated_path), "legacy cache index not archived on partial migration")

	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_path)

	var legacy_key: String = "legacy_migration_key"
	IconForgeFileUtil.write_json_atomic(legacy_path, {
		legacy_key: {
			"key": legacy_key,
			"source": "fixtures/sword.gltf",
			"output": output_path,
			"preset": "weapon",
			"tool_version": IconForgeVersion.VERSION,
			"metrics": {},
		},
	})
	var cache: CacheService = CacheService.new()
	_assert(FileAccess.file_exists(ProjectSettings.globalize_path(cache._record_path(legacy_key))), "legacy cache entry migrated to per-key record")
	_assert(not FileAccess.file_exists(legacy_path), "legacy cache index archived after successful migration")
	_assert(FileAccess.file_exists(migrated_path), "legacy cache index renamed to migrated marker")

func _test_advisory_index_isolation() -> void:
	var ws: String = ProjectSettings.globalize_path("res://out/advisory_ws_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ws)
	var ReviewQueueScript = load("res://core/api/review_queue.gd")
	var queue_a: RefCounted = ReviewQueueScript.new(ws)
	var queue_b: RefCounted = ReviewQueueScript.new(ws)
	var first: Dictionary = queue_a.record({"job_id": "review_parallel_a", "code": "FRAMING_UNRESOLVED"})
	var second: Dictionary = queue_b.record({"job_id": "review_parallel_b", "code": "OUTPUT_CLIPPED"})
	_assert(bool(first.get("success", false)) and bool(second.get("success", false)), "parallel advisory records persist")
	_assert(FileAccess.file_exists(queue_a.record_path("review_parallel_a")), "authoritative review a exists")
	_assert(FileAccess.file_exists(queue_b.record_path("review_parallel_b")), "authoritative review b exists")
	_assert(FileAccess.file_exists(_AdvisoryIndex.record_path(ws, "reviews", "review_parallel_a")), "advisory review index a exists")
	_assert(FileAccess.file_exists(_AdvisoryIndex.record_path(ws, "reviews", "review_parallel_b")), "advisory review index b exists")

	var manifest_service: RefCounted = ManifestService.new(ws)
	var output_path: String = ws.path_join("out/advisory_output.png")
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	IconForgeFileUtil.write_text_atomic(output_path, "probe")
	manifest_service._update_output_index(output_path, {
		"job_id": "advisory_output_job",
		"sha256": "probe",
		"source": "fixtures/sword.gltf",
		"purpose": "inventory_icon",
		"asset_id": "advisory_output_asset",
		"updated_at": Time.get_datetime_string_from_system(true),
	})
	_assert(FileAccess.file_exists(_AdvisoryIndex.record_path(ws, "output", output_path)), "advisory output index record exists")

func _test_review_path_contract() -> void:
	ReviewQueue.reset_test_seams()
	ApiServiceScript.reset_test_seams()
	var ws: String = ProjectSettings.globalize_path("res://out/review_contract_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ws)
	var api: RefCounted = ApiServiceScript.new(ws)
	ReviewQueue.test_fail_record_write = true
	ApiServiceScript.test_recipe_resolution_error = {
		"code": "RECIPE_RESOLUTION_FAILED",
		"message": "Injected review persistence failure.",
	}
	var result: Dictionary = await api.execute({
		"schema_version": 1,
		"operation": "render_asset",
		"asset": ProjectSettings.globalize_path("res://fixtures/sword.gltf"),
		"purpose": "inventory_icon",
		"asset_id": "review_contract_%d" % Time.get_ticks_usec(),
		"force": true,
	})
	ReviewQueue.reset_test_seams()
	ApiServiceScript.reset_test_seams()
	_assert(not bool(result.get("review_persisted", true)), "review persistence failure reported")
	_assert(str(result.get("review_path", "x")).is_empty(), "review path omitted on persistence failure")
	_assert(str(result.get("manifest", "x")).is_empty(), "manifest omitted on persistence failure")

func _assert(condition: bool, label: String) -> void:
	if condition:
		passed.append(label)
	else:
		failures.append(label)
