extends Node

const IconForgeCliScript = preload("res://cli/cli_app.gd")
const ForgeUiScript = preload("res://app/forge_ui.gd")
const TestRunnerScript = preload("res://tests/test_runner.gd")

func _ready() -> void:
	var args: Array[String] = []
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in user_args:
		args.append(str(arg))
	# Rendering services attach temporary SubViewports to the scene tree.  Wait
	# until the main scene has finished its own child setup before doing so.
	await get_tree().process_frame
	if args.has("--test"):
		var runner: RefCounted = TestRunnerScript.new()
		var test_result: Dictionary = await runner.run()
		print(JSON.stringify(test_result))
		get_tree().quit(0 if bool(test_result.get("success", false)) else 1)
		return
	if args.has("--gui-interaction-test"):
		var interaction_gui: Control = ForgeUiScript.new()
		add_child(interaction_gui)
		await get_tree().process_frame
		var interaction_source: String = _argument_value(args, "--source", "")
		var interaction_result: Dictionary = await interaction_gui.run_interaction_e2e(interaction_source)
		print(JSON.stringify(interaction_result))
		get_tree().quit(0 if bool(interaction_result.get("success", false)) else 1)
		return
	if args.has("--gui-test"):
		var gui: Control = ForgeUiScript.new()
		add_child(gui)
		await get_tree().process_frame
		var source_path: String = _argument_value(args, "--source", "")
		var screenshot_path: String = _argument_value(args, "--screenshot", "")
		var gui_result: Dictionary = await gui.run_drop_e2e(source_path, screenshot_path)
		print(JSON.stringify(gui_result))
		get_tree().quit(0 if bool(gui_result.get("success", false)) else 1)
		return
	if args.has("--gui-native-test"):
		var native_gui: Control = ForgeUiScript.new()
		add_child(native_gui)
		await get_tree().process_frame
		var native_source_path: String = _argument_value(args, "--source", "")
		var native_screenshot_path: String = _argument_value(args, "--screenshot", "")
		var native_timeout_ms: int = int(_argument_value(args, "--timeout-ms", "30000"))
		var native_result: Dictionary = await native_gui.run_native_drop_wait(native_source_path, native_screenshot_path, native_timeout_ms)
		print(JSON.stringify(native_result))
		get_tree().quit(0 if bool(native_result.get("success", false)) else 1)
		return
	if args.has("--cli"):
		var cli: RefCounted = IconForgeCliScript.new()
		var exit_code: int = await cli.run(args)
		get_tree().quit(exit_code)
		return
	var ui: Control = ForgeUiScript.new()
	add_child(ui)

func _argument_value(args: Array[String], name: String, default_value: String) -> String:
	var index: int = args.find(name)
	if index >= 0 and index + 1 < args.size():
		return args[index + 1]
	return default_value
