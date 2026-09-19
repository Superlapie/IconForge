extends RefCounted
class_name IconStudioTestRunner

const PreviewCameraScript = preload("res://core/services/preview_camera.gd")
const ApiTestRunnerScript = preload("res://tests/api_test_runner.gd")

var failures: Array = []
var passed: Array = []

func run() -> Dictionary:
	await _test_preset_contract()
	_test_override_contract()
	_test_export_override_isolation()
	_test_lighting_contract()
	_test_framing_contract()
	_test_preview_camera_contract()
	_test_image_quality_contract()
	_test_file_collection_contract()
	_test_inspection_contract()
	await _test_fixture_render()
	await _test_batch_unique_outputs()
	await _test_api_contract()
	return {"success": failures.is_empty(), "passed": passed, "failures": failures, "summary": {"passed": passed.size(), "failed": failures.size()}}

func _test_api_contract() -> void:
	var api_runner: RefCounted = ApiTestRunnerScript.new()
	var api_result: Dictionary = await api_runner.run()
	for label in api_result.get("passed", []):
		passed.append("api: %s" % label)
	for label in api_result.get("failures", []):
		failures.append("api: %s" % label)

func _test_preset_contract() -> void:
	var service: PresetService = PresetService.new()
	service.load_all()
	var entries: Array = service.list_presets()
	_assert(entries.size() >= 10, "preset listing includes production presets")
	for entry in entries:
		var preset: PresetDefinition = service.get_preset(str(entry.get("id", "")))
		_assert(preset != null and preset.validate().is_empty(), "preset validates: %s" % entry.get("id", ""))
	var migrated: PresetDefinition = PresetDefinition.new({"id": "legacy", "yaw": 22, "resolution": {"width": 64, "height": 64}})
	_assert(int(migrated.data.get("schema_version", 0)) == 1, "legacy preset migrates to schema 1")
	_assert(is_equal_approx(float(migrated.data.get("camera", {}).get("yaw", 0)), 22.0), "legacy flat yaw migrates into camera")
	_assert(PresetService.schema().has("fields"), "schema describes fields")

func _test_override_contract() -> void:
	var service: OverrideService = OverrideService.new()
	_assert(service.validate({"yaw": 18, "occupancy": 0.84}).is_empty(), "valid override passes")
	_assert(service.validate({"camera": {"min_zoom": 0.02, "max_zoom": 100.0}}).is_empty(), "nested camera zoom override passes")
	_assert(not service.validate({"occupancy": 1.2}).is_empty(), "invalid occupancy is rejected")
	_assert(not service.validate({"camera": {"min_zoom": 4.0, "max_zoom": 1.0}}).is_empty(), "invalid nested camera zoom range is rejected")
	_assert(service.validate({"lighting": {"key": {"angle": [-30.0, 45.0, 0.0]}}}).is_empty(), "lighting angle override passes")
	_assert(service.validate({"lighting": {"rig": "neutral_studio", "ambient_energy": 0.5, "key": {"angle": [-30.0, 45.0, 0.0], "intensity": 1.2, "color": [1.0, 0.93, 0.84, 1.0], "shadow": true}}}).is_empty(), "valid lighting configuration passes")
	_assert(not service.validate({"lighting": {"kee": {"angle": [-30.0, 45.0, 0.0]}}}).is_empty(), "misspelled lighting field is rejected")
	_assert(not service.validate({"lighting": {"key": {"angle": [-30.0, 45.0, 0.0], "energy": 1.2}}}).is_empty(), "unknown nested lighting field is rejected")
	_assert(not service.validate({"composition": {"bogus": 1}}).is_empty(), "unknown nested object field is rejected")
	_assert(not service.validate({"lighting": {"key": {"angle": [0.0, "bad", 0.0]}}}).is_empty(), "invalid lighting angle is rejected")
	_assert(not service.validate({"lighting": "studio"}).is_empty(), "malformed lighting type is rejected")
	_assert(not service.validate({"camera": {"fov": "banana"}}).is_empty(), "camera fov string is rejected")
	_assert(not service.validate({"camera": {"orientation_strategy": "super_epic_zoom_mode"}}).is_empty(), "unknown orientation strategy is rejected")
	_assert(not service.validate({"environment": {"background": 9217}}).is_empty(), "non-enum environment background is rejected")
	_assert(not service.validate({"width": 99999}).is_empty(), "out-of-range width is rejected")
	_assert(OverrideService.lighting_schema().has("light_keys"), "canonical lighting schema is defined")

func _test_export_override_isolation() -> void:
	var base: Dictionary = {"yaw": 12.0, "occupancy": 0.8}
	var settings: Dictionary = {"width": 512, "height": 512, "supersampling": 4, "transparent": false, "overwrite": false}
	var export_override: Dictionary = StudioUi.build_export_override(base, settings)
	_assert(not base.has("supersampling"), "export helper does not mutate asset override")
	_assert(int(export_override.get("supersampling", 0)) == 4, "export helper applies supersampling ephemerally")
	_assert(str(export_override.get("background", "")) == "gradient", "export helper applies opaque background")
	_assert(not OverrideService.new().validate(export_override).is_empty(), "export-only supersampling cannot be saved as sidecar")
	_assert(OverrideService.new().validate(base).is_empty(), "asset override remains sidecar-valid after export helper")

func _test_batch_unique_outputs() -> void:
	var service: PresetService = PresetService.new()
	service.load_all()
	var preset: PresetDefinition = service.get_preset("weapon")
	if preset == null:
		_assert(false, "weapon preset exists for batch unique outputs")
		return
	var stamp: int = Time.get_ticks_usec()
	var dir_a: String = ProjectSettings.globalize_path("res://out/batch_unique_a_%d" % stamp)
	var dir_b: String = ProjectSettings.globalize_path("res://out/batch_unique_b_%d" % stamp)
	var output_dir: String = ProjectSettings.globalize_path("res://out/batch_unique_out_%d" % stamp)
	DirAccess.make_dir_recursive_absolute(dir_a)
	DirAccess.make_dir_recursive_absolute(dir_b)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var source_a: String = dir_a.path_join("item.gltf")
	var source_b: String = dir_b.path_join("item.gltf")
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://fixtures/sword.gltf"), source_a)
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://fixtures/potion.gltf"), source_b)
	var result: Dictionary = await BatchService.new().render_sources(
		[source_a, source_b],
		preset,
		output_dir,
		{"force": true, "manifest": false, "override": {}},
	)
	_assert(bool(result.get("success", false)), "same-basename batch succeeds")
	var renders: Array = result.get("renders", [])
	_assert(renders.size() == 2, "same-basename batch has two outputs")
	if renders.size() == 2:
		_assert(str(renders[0].get("output", "")) != str(renders[1].get("output", "")), "same-basename batch uses unique output paths")
		_assert(FileAccess.file_exists(str(renders[0].get("output", ""))), "first same-basename output exists")
		_assert(FileAccess.file_exists(str(renders[1].get("output", ""))), "second same-basename output exists")

func _test_framing_contract() -> void:
	var service: FramingService = FramingService.new()
	var preset: PresetDefinition = PresetDefinition.new(PresetDefinition.default_data("test"))
	var params: Dictionary = service.resolve_camera(preset, {"dimensions": [0.2, 2.0, 0.2], "center": [0, 1, 0]}, {"occupancy": 0.84})
	_assert(float(params.get("orthographic_size", 0)) > 0.0, "auto framing returns positive camera size")
	var corrected: float = service.correction_size(2.0, 0.82, 0.42, false, 0.1, 100.0)
	_assert(corrected < 2.0, "low occupancy produces bounded zoom correction")

func _test_preview_camera_contract() -> void:
	var preset: PresetDefinition = PresetDefinition.new(PresetDefinition.default_data("preview_camera"))
	var orbit: Dictionary = PreviewCameraScript.apply_orbit_delta({}, preset, Vector2(10.0, -5.0))
	var default_pitch: float = float(preset.data.get("camera", {}).get("pitch", -8.0))
	_assert(is_equal_approx(float(orbit["yaw"]), 10.0 * PreviewCameraScript.YAW_SENSITIVITY), "orbit delta updates yaw")
	_assert(is_equal_approx(float(orbit["pitch"]), default_pitch + -5.0 * PreviewCameraScript.PITCH_SENSITIVITY), "orbit delta updates pitch")
	var clamped: Dictionary = PreviewCameraScript.apply_orbit_delta({"pitch": 89.0}, preset, Vector2(0.0, 20.0))
	_assert(float(clamped["pitch"]) <= 90.0, "orbit pitch is clamped to 90 degrees")
	var zoom: Dictionary = PreviewCameraScript.apply_zoom_delta({}, preset, 2.0)
	var expected_occupancy: float = clampf(float(preset.data.get("camera", {}).get("occupancy", 0.82)) + 2.0 * PreviewCameraScript.ZOOM_SENSITIVITY, 0.4, 0.95)
	_assert(is_equal_approx(float(zoom["occupancy"]), expected_occupancy), "zoom delta updates occupancy")
	_assert(is_equal_approx(PreviewCameraScript.effective_value({"yaw": 12.0}, preset, "yaw"), 12.0), "effective value prefers override")

func _test_lighting_contract() -> void:
	var service: LightingRigService = LightingRigService.new()
	var neutral: Dictionary = service.resolve({"rig": "neutral_studio"})
	var dramatic: Dictionary = service.resolve({"rig": "dramatic_boss"})
	_assert(float(neutral.get("key", {}).get("intensity", 0.0)) != float(dramatic.get("key", {}).get("intensity", 0.0)), "named lighting rigs resolve distinct key energy")

func _test_image_quality_contract() -> void:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(8, 24):
		for x in range(8, 24):
			image.set_pixel(x, y, Color(1, 1, 1, 1))
	var metrics: Dictionary = ImageProcessor.new().silhouette_metrics(image)
	_assert(bool(metrics.get("has_silhouette", false)), "silhouette detects visible pixels")
	_assert(is_equal_approx(float(metrics.get("occupancy", 0)), 0.5), "silhouette occupancy is measurable")
	var blank: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	blank.fill(Color(0, 0, 0, 0))
	var quality: Dictionary = QualityService.new().inspect_image(blank, Vector2i(16, 16), 0.8)
	_assert(not bool(quality.get("success", true)), "quality gate rejects fully transparent output")

func _test_file_collection_contract() -> void:
	var sources: Array[String] = IconStudioFileUtil.collect_sources(ProjectSettings.globalize_path("res://tests/e2e/assets/real"), false)
	var glb_count: int = 0
	var extracted_texture_count: int = 0
	for source in sources:
		if source.get_extension().to_lower() == "glb":
			glb_count += 1
		if source.get_file().begins_with("Avocado_") or source.get_file().begins_with("BoomBox_"):
			extracted_texture_count += 1
	_assert(glb_count == 2, "batch source collection includes real GLBs")
	_assert(extracted_texture_count == 0, "batch source collection ignores embedded GLB textures")

func _test_inspection_contract() -> void:
	var service: AssetInspector = AssetInspector.new()
	var missing: Dictionary = service.inspect("fixtures/does_not_exist.gltf")
	_assert(not bool(missing.get("success", true)), "missing source returns machine error")
	var fixture: Dictionary = service.inspect(ProjectSettings.globalize_path("res://fixtures/sword.gltf"))
	_assert(bool(fixture.get("success", false)), "fixture GLTF imports for inspection")
	_assert(int(fixture.get("triangle_count", 0)) > 0, "fixture inspection counts triangles")

func _test_fixture_render() -> void:
	var service: PresetService = PresetService.new()
	service.load_all()
	var preset: PresetDefinition = service.get_preset("weapon")
	if preset == null:
		_assert(false, "weapon preset exists for fixture render")
		return
	var output: String = ProjectSettings.globalize_path("res://out/test_sword.png")
	var result: Dictionary = await RenderService.new().render(ProjectSettings.globalize_path("res://fixtures/sword.gltf"), preset, {}, output, true)
	_assert(bool(result.get("success", false)), "fixture GLTF renders to PNG")
	_assert(FileAccess.file_exists(output), "fixture render writes output")
	if FileAccess.file_exists(output):
		var image: Image = Image.new()
		_assert(image.load(output) == OK, "fixture output decodes")
		_assert(image.get_size() == Vector2i(256, 256), "fixture output has requested resolution")

func _assert(condition: bool, label: String) -> void:
	if condition:
		passed.append(label)
	else:
		failures.append(label)
