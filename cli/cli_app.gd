extends RefCounted
class_name IconForgeCli

const EXIT_OK: int = 0
const EXIT_USAGE: int = 2
const EXIT_RENDER: int = 3
const EXIT_PARTIAL: int = 4

var presets: PresetService = PresetService.new()
var inspector: AssetInspector = AssetInspector.new()
var render_service: RenderService = RenderService.new()
var batch_service: BatchService = BatchService.new()
var quality: QualityService = QualityService.new()
var compare: CompareService = CompareService.new()
var override_service: OverrideService = OverrideService.new()
const ApiServiceScript = preload("res://core/api/api_service.gd")

func run(raw_args: Array[String]) -> int:
	var args: Array[String] = _clean_args(raw_args)
	if args.is_empty() or args[0] in ["--help", "-h"]:
		return _finish(_help_result(), false, EXIT_OK)
	var command: String = args[0]
	presets.load_all()
	match command:
		"inspect":
			return _inspect(args)
		"preview":
			return await _render(args, true)
		"render":
			return await _render(args, false)
		"render-batch":
			return await _render_batch(args)
		"presets":
			return _finish({"success": true, "presets": presets.list_presets()}, _json_mode(args), EXIT_OK)
		"create-preset":
			return _create_preset(args)
		"validate-preset":
			return _validate_preset(args)
		"explain":
			return _explain(args)
		"schema":
			return _finish({"success": true, "schema": PresetService.schema()}, _json_mode(args), EXIT_OK)
		"compare":
			return _compare(args)
		"validate-output", "quality":
			return _validate_output(args)
		"api":
			return await _api(args)
		_:
			return _finish(_error("CLI_UNKNOWN_COMMAND", "Unknown command '%s'." % command, {"command": command}), _json_mode(args), EXIT_USAGE)

func _inspect(args: Array[String]) -> int:
	var source: String = _first_positional(args, 1)
	if source.is_empty():
		return _finish(_error("CLI_USAGE", "inspect requires a source path.", {"usage": "iconforge inspect SOURCE [--json]"}), _json_mode(args), EXIT_USAGE)
	var result: Dictionary = inspector.inspect(_path(source))
	return _finish(result, _json_mode(args), EXIT_OK if bool(result.get("success", false)) else EXIT_USAGE)

func _render(args: Array[String], preview: bool) -> int:
	var source_argument: String = _first_positional(args, 1)
	if source_argument.is_empty():
		return _finish(_error("CLI_USAGE", "render requires a source file or directory.", {}), _json_mode(args), EXIT_USAGE)
	var source_path: String = _path(source_argument)
	var preset_id: String = _option(args, "--preset", "neutral_asset_thumbnail")
	var preset_result: Dictionary = presets.require_preset(preset_id)
	if not bool(preset_result.get("success", false)):
		return _finish(preset_result, _json_mode(args), EXIT_USAGE)
	var preset: PresetDefinition = preset_result["preset"]
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(source_path)):
		var batch_args: Array[String] = args.duplicate()
		batch_args[0] = "render-batch"
		return await _render_batch(batch_args, preview)
	var output_path: String = _option(args, "--output", "")
	if output_path.is_empty():
		if preview:
			output_path = "user://iconforge/previews/%s_%s.png" % [IconForgeFileUtil.source_name(source_path), preset_id]
		else:
			output_path = "out/%s_%s.png" % [IconForgeFileUtil.source_name(source_path), preset_id]
	output_path = _path(output_path)
	var override: Dictionary = _inline_override(args)
	var explicit_override: String = _option(args, "--override", "")
	if not explicit_override.is_empty():
		var loaded_override: Dictionary = override_service.load_for_source(source_path, _path(explicit_override))
		if not bool(loaded_override.get("success", false)):
			return _finish(loaded_override, _json_mode(args), EXIT_USAGE)
		override = PresetDefinition.deep_merge(loaded_override.get("override", {}), override)
	var result: Dictionary = await render_service.render(source_path, preset, override, output_path, preview or _has_flag(args, "--force"))
	var exit_code: int = EXIT_OK if bool(result.get("success", false)) else EXIT_RENDER
	return _finish(result, _json_mode(args), exit_code)

func _render_batch(args: Array[String], from_render: bool = false) -> int:
	var source_argument: String = _first_positional(args, 1)
	if source_argument.is_empty():
		return _finish(_error("CLI_USAGE", "render-batch requires an input directory or file.", {}), _json_mode(args), EXIT_USAGE)
	var preset_id: String = _option(args, "--preset", "neutral_asset_thumbnail")
	var preset_result: Dictionary = presets.require_preset(preset_id)
	if not bool(preset_result.get("success", false)):
		return _finish(preset_result, _json_mode(args), EXIT_USAGE)
	var output_dir: String = _option(args, "--output", "out")
	if output_dir.is_empty() or output_dir.ends_with(".png"):
		output_dir = "out"
	var options: Dictionary = {
		"force": _has_flag(args, "--force"),
		"manifest": not _has_flag(args, "--no-manifest"),
		"manifest_path": _path(_option(args, "--manifest", "")),
		"recursive": not _has_flag(args, "--no-recursive"),
		"override": _inline_override(args)
	}
	if str(options["manifest_path"]).is_empty():
		options.erase("manifest_path")
	var result: Dictionary = await batch_service.render_batch(_path(source_argument), preset_result["preset"], _path(output_dir), options)
	var exit_code: int = EXIT_OK if bool(result.get("success", false)) else (EXIT_PARTIAL if bool(result.get("partial_success", false)) else EXIT_RENDER)
	return _finish(result, _json_mode(args), exit_code)

func _create_preset(args: Array[String]) -> int:
	var preset_id: String = _first_positional(args, 1)
	if preset_id.is_empty():
		preset_id = _option(args, "--id", "custom_preset")
	var source_id: String = _option(args, "--from", "")
	var data: Dictionary = PresetDefinition.default_data(preset_id)
	if not source_id.is_empty():
		var base: PresetDefinition = presets.get_preset(source_id)
		if base == null:
			return _finish(_error("PRESET_NOT_FOUND", "Base preset '%s' was not found." % source_id, {}), _json_mode(args), EXIT_USAGE)
		data = base.to_dict()
		data["id"] = preset_id
	var preset: PresetDefinition = PresetDefinition.new(data)
	var destination: String = _option(args, "--output", "")
	if not destination.is_empty():
		destination = _path(destination)
	var result: Dictionary = presets.save_preset(preset, destination)
	return _finish(result, _json_mode(args), EXIT_OK if bool(result.get("success", false)) else EXIT_USAGE)

func _validate_preset(args: Array[String]) -> int:
	var path: String = _first_positional(args, 1)
	if path.is_empty():
		return _finish(_error("CLI_USAGE", "validate-preset requires a JSON file.", {}), _json_mode(args), EXIT_USAGE)
	var absolute: String = _path(path)
	var raw: Dictionary = IconForgeFileUtil.read_json(absolute)
	if raw.is_empty():
		return _finish(_error("PRESET_READ_FAILED", "Could not read preset JSON.", {"path": absolute}), _json_mode(args), EXIT_USAGE)
	var preset: PresetDefinition = PresetDefinition.new(raw, absolute)
	var errors: Array = preset.validate()
	var result: Dictionary = {"success": errors.is_empty(), "path": absolute, "preset": preset.get_id(), "schema_version": preset.data.get("schema_version", null), "errors": errors}
	return _finish(result, _json_mode(args), EXIT_OK if errors.is_empty() else EXIT_USAGE)

func _explain(args: Array[String]) -> int:
	var preset_id: String = _first_positional(args, 1)
	if preset_id.is_empty():
		return _finish(_error("CLI_USAGE", "explain requires a preset id.", {}), _json_mode(args), EXIT_USAGE)
	var result: Dictionary = presets.explain(preset_id)
	return _finish(result, _json_mode(args), EXIT_OK if bool(result.get("success", false)) else EXIT_USAGE)

func _compare(args: Array[String]) -> int:
	var first: String = _first_positional(args, 1)
	var second: String = _first_positional(args, 2)
	if first.is_empty() or second.is_empty():
		return _finish(_error("CLI_USAGE", "compare requires two image paths.", {}), _json_mode(args), EXIT_USAGE)
	var result: Dictionary = compare.compare(_path(first), _path(second))
	return _finish(result, _json_mode(args), EXIT_OK if bool(result.get("success", false)) else EXIT_USAGE)

func _api(args: Array[String]) -> int:
	var request: Dictionary = {}
	if _has_flag(args, "--stdin"):
		var stdin_text: String = ""
		if FileAccess.file_exists("/dev/stdin"):
			var stdin_file: FileAccess = FileAccess.open("/dev/stdin", FileAccess.READ)
			if stdin_file != null:
				stdin_text = stdin_file.get_as_text()
				stdin_file.close()
		if stdin_text.is_empty():
			return _finish(_error("CLI_USAGE", "api --stdin requires JSON on stdin.", {}), true, EXIT_USAGE)
		var parsed: Variant = JSON.parse_string(stdin_text)
		if not parsed is Dictionary:
			return _finish(_error("INVALID_REQUEST", "stdin did not contain a JSON object.", {}), true, EXIT_USAGE)
		request = parsed
	else:
		var request_path: String = _option(args, "--request", "")
		if request_path.is_empty():
			return _finish(_error("CLI_USAGE", "api requires --request FILE or --stdin.", {"usage": "iconforge api --request request.json --json"}), _json_mode(args), EXIT_USAGE)
		request = IconForgeFileUtil.read_json(_path(request_path))
		if request.is_empty():
			return _finish(_error("INVALID_REQUEST", "Could not read request JSON.", {"path": request_path}), _json_mode(args), EXIT_USAGE)
	var safe_mode: bool = not _has_flag(args, "--expert")
	var workspace_root: String = OS.get_environment("ICONFORGE_WORKSPACE_ROOT")
	if workspace_root.is_empty():
		workspace_root = OS.get_environment("ICONSTUDIO_WORKSPACE_ROOT")
	var workspace_option: String = _option(args, "--workspace-root", "")
	if not workspace_option.is_empty():
		workspace_root = workspace_option
	var api_service: RefCounted = ApiServiceScript.new(workspace_root)
	var result: Dictionary = await api_service.execute(request, safe_mode)
	var exit_code: int = EXIT_OK
	if not bool(result.get("success", false)):
		match str(result.get("status", "failed")):
			"needs_review":
				exit_code = EXIT_PARTIAL
			"partial_success":
				exit_code = EXIT_PARTIAL
			_:
				exit_code = EXIT_USAGE if str(result.get("code", "")) in ["INVALID_REQUEST", "UNKNOWN_OPERATION", "UNKNOWN_FIELD", "INVALID_FIELD_TYPE", "UNSUPPORTED_SCHEMA_VERSION"] else EXIT_RENDER
	return _finish(result, _json_mode(args) or true, exit_code)

func _validate_output(args: Array[String]) -> int:
	var output: String = _first_positional(args, 1)
	if output.is_empty():
		return _finish(_error("CLI_USAGE", "validate-output requires an image path.", {}), _json_mode(args), EXIT_USAGE)
	var expected_size: Vector2i = Vector2i.ZERO
	var analyze_alpha: bool = true
	var preset_id: String = _option(args, "--preset", "")
	var occupancy_override: String = _option(args, "--occupancy", "")
	var target_occupancy: float = 0.82
	if not preset_id.is_empty():
		var preset: PresetDefinition = presets.get_preset(preset_id)
		if preset != null:
			expected_size = Vector2i(int(preset.data.get("resolution", {}).get("width", 256)), int(preset.data.get("resolution", {}).get("height", 256)))
			target_occupancy = float(preset.data.get("camera", {}).get("occupancy", target_occupancy))
			analyze_alpha = str(preset.data.get("environment", {}).get("background", "transparent")) == "transparent"
	if not occupancy_override.is_empty():
		target_occupancy = float(occupancy_override)
	var result: Dictionary = quality.inspect_image_file(_path(output), expected_size, target_occupancy, analyze_alpha)
	return _finish(result, _json_mode(args), EXIT_OK if bool(result.get("success", false)) else EXIT_RENDER)

func _inline_override(args: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for mapping in [["--yaw", "yaw"], ["--pitch", "pitch"], ["--roll", "roll"], ["--occupancy", "occupancy"], ["--padding", "padding"], ["--scale", "scale"], ["--vertical-offset", "vertical_bias"], ["--horizontal-offset", "horizontal_bias"]]:
		var value: String = _option(args, str(mapping[0]), "")
		if not value.is_empty():
			result[str(mapping[1])] = float(value)
	for mapping in [["--width", "width"], ["--height", "height"]]:
		var size_value: String = _option(args, str(mapping[0]), "")
		if not size_value.is_empty():
			result[str(mapping[1])] = int(size_value)
	var background: String = _option(args, "--background", "")
	if not background.is_empty():
		result["background"] = background
	return result

func _clean_args(raw_args: Array[String]) -> Array[String]:
	var output: Array[String] = []
	var passed_separator: bool = false
	for raw in raw_args:
		var arg: String = str(raw)
		if arg == "--":
			passed_separator = true
			continue
		if arg in ["--cli", "--headless", "--editor", "--path"]:
			continue
		if not passed_separator and (arg.begins_with("--path=") or arg.begins_with("--rendering-method=")):
			continue
		output.append(arg)
	return output

func _first_positional(args: Array[String], ordinal: int) -> String:
	var positionals: Array[String] = []
	var index: int = 1
	while index < args.size():
		var value: String = args[index]
		if value.begins_with("--"):
			if value in ["--force", "--json", "--no-manifest", "--no-recursive"]:
				index += 1
				continue
			if not value.contains("=") and index + 1 < args.size() and not args[index + 1].begins_with("--"):
				index += 2
				continue
			index += 1
			continue
		positionals.append(value)
		index += 1
	return positionals[ordinal - 1] if ordinal - 1 < positionals.size() else ""

func _option(args: Array[String], name: String, fallback: String) -> String:
	for index in args.size():
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
		if args[index].begins_with(name + "="):
			return args[index].get_slice("=", 1)
	return fallback

func _has_flag(args: Array[String], flag: String) -> bool:
	return args.has(flag)

func _json_mode(args: Array[String]) -> bool:
	return args.has("--json")

func _path(value: String) -> String:
	if value.begins_with("res://") or value.begins_with("user://") or value.is_absolute_path():
		return value
	return ProjectSettings.globalize_path("res://" + value.trim_prefix("./"))

func _finish(result: Dictionary, json_mode: bool, exit_code: int) -> int:
	if json_mode:
		print(JSON.stringify(result))
	else:
		if bool(result.get("success", false)):
			print(_human_result(result))
		else:
			print("ERROR %s" % str(result.get("error", {}).get("code", "ICONFORGE_ERROR")))
			print(str(result.get("error", {}).get("message", "The command failed.")))
	return exit_code

func _human_result(result: Dictionary) -> String:
	if result.has("output"):
		return "OK  %s" % str(result.get("output", ""))
	if result.has("presets"):
		var names: Array[String] = []
		for preset in result["presets"]:
			names.append("%s — %s" % [preset.get("id", ""), preset.get("description", "")])
		return "\n".join(names)
	return JSON.stringify(result, "\t")

func _error(code: String, message: String, details: Dictionary) -> Dictionary:
	var error: Dictionary = {"code": code, "message": message}
	for key in details.keys():
		error[key] = details[key]
	return {"success": false, "error": error}

func _help_result() -> Dictionary:
	return {
		"success": true,
		"usage": "iconforge COMMAND [ARGS] [OPTIONS]",
		"commands": {
			"inspect": "Inspect a GLB/glTF/image and return metrics.",
			"preview": "Render a preview to the user preview directory.",
			"render": "Render one source file or dispatch a directory to batch rendering.",
			"render-batch": "Render all supported sources in a directory and write a manifest.",
			"presets": "List available render presets.",
			"create-preset": "Create a user preset from defaults or another preset.",
			"validate-preset": "Validate a preset JSON file.",
			"explain": "Describe a preset and supported overrides.",
			"schema": "Print the self-describing preset schema.",
			"compare": "Compare two images with deterministic pixel metrics.",
			"validate-output": "Run resolution, alpha, clipping, and occupancy checks.",
			"api": "Execute a canonical machine API request (--request FILE). Optional --workspace-root or ICONFORGE_WORKSPACE_ROOT."
		},
		"global_options": ["--json", "--force", "--preset ID", "--output PATH", "--request FILE", "--stdin", "--expert"]
	}
