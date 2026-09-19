extends RefCounted
class_name BatchService

const _Version = preload("res://core/api/icon_forge_version.gd")

var render_service: RenderService = RenderService.new()

func render_batch(input_path: String, preset: PresetDefinition, output_dir: String, options: Dictionary = {}) -> Dictionary:
	var sources: Array[String] = IconForgeFileUtil.collect_sources(input_path, bool(options.get("recursive", true)))
	return await render_sources(sources, preset, output_dir, options, input_path)

func render_sources(sources: Array, preset: PresetDefinition, output_dir: String, options: Dictionary = {}, input_path: String = "") -> Dictionary:
	if sources.is_empty():
		return {"success": false, "error": {"code": "BATCH_NO_SOURCES", "message": "No supported source assets were found.", "input": input_path}, "renders": []}
	var force: bool = bool(options.get("force", false))
	var manifest_enabled: bool = bool(options.get("manifest", true))
	var manifest_path: String = str(options.get("manifest_path", output_dir.path_join("manifest.json")))
	var pattern: String = str(preset.data.get("output", {}).get("name_pattern", "{source_name}.png"))
	var used_outputs: Dictionary = {}
	var renders: Array = []
	var success_count: int = 0
	var failure_count: int = 0
	var warning_count: int = 0
	var manifest_written: bool = false
	var manifest_status: String = "disabled" if not manifest_enabled else "pending"
	var manifest_error: Dictionary = {}
	for source_path in sources:
		var filename: String = _expand_pattern(pattern, str(source_path), preset.get_id())
		if filename.get_extension().is_empty():
			filename += ".png"
		var output_path: String = output_dir.path_join(filename)
		if used_outputs.has(output_path):
			output_path = IconForgeFileUtil.ensure_unique_output(output_path, used_outputs)
		used_outputs[output_path] = true
		var result: Dictionary = await render_service.render(str(source_path), preset, options.get("override", {}), output_path, force)
		if bool(result.get("success", false)):
			success_count += 1
		else:
			failure_count += 1
		var warnings: Array = result.get("warnings", [])
		warning_count += warnings.size()
		renders.append({
			"source": source_path,
			"output": output_path,
			"status": "success" if bool(result.get("success", false)) else "failed",
			"cache_hit": bool(result.get("cache_hit", false)),
			"warnings": warnings,
			"errors": result.get("errors", []) if result.has("errors") else ([result.get("error")] if result.has("error") else []),
			"metrics": result.get("metrics", {})
		})
	if manifest_enabled:
		var manifest: Dictionary = {
			"tool_version": _Version.VERSION,
			"preset": preset.get_id(),
			"input": input_path,
			"output": output_dir,
			"generated_at": Time.get_datetime_string_from_system(true),
			"summary": {"total": sources.size(), "success": success_count, "failed": failure_count, "warnings": warning_count},
			"renders": renders
		}
		var write_error: Error = IconForgeFileUtil.write_json_atomic(manifest_path, manifest)
		if write_error == OK:
			manifest_written = true
			manifest_status = "written"
		else:
			manifest_status = "failed"
			manifest_error = {
				"code": "WRITE_FAILED",
				"message": "Could not write batch manifest.",
				"path": manifest_path,
				"godot_error": write_error,
			}
	var result: Dictionary = {
		"success": failure_count == 0 and manifest_status != "failed",
		"partial_success": success_count > 0 and (failure_count > 0 or manifest_status == "failed"),
		"input": input_path,
		"output": output_dir,
		"preset": preset.get_id(),
		"summary": {"total": sources.size(), "success": success_count, "failed": failure_count, "warnings": warning_count},
		"manifest": manifest_path if manifest_written else "",
		"manifest_status": manifest_status,
		"renders": renders,
	}
	if manifest_status == "failed":
		result["error"] = manifest_error
	return result

func _expand_pattern(pattern: String, source_path: String, preset_id: String) -> String:
	var source_name: String = IconForgeFileUtil.source_name(source_path)
	var output: String = pattern
	output = output.replace("{source_name}", source_name)
	output = output.replace("{preset}", preset_id)
	output = output.replace("{id}", source_name)
	output = output.replace("{extension}", "png")
	return output

