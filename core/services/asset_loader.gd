extends RefCounted
class_name AssetLoader

## Loads imported Godot scenes first, then falls back to the runtime glTF
## importer. The fallback is important for files dropped from outside the
## project because the editor has not necessarily created a .import artifact
## for them yet.
func load_packed_scene(source_path: String) -> Dictionary:
	# ResourceLoader is the right path for project-imported assets, but it emits
	# noisy "no loader" diagnostics for an arbitrary absolute GLB dropped from
	# the file manager. Keep that path clean and use Godot's runtime importer.
	var project_root: String = ProjectSettings.globalize_path("res://")
	var is_project_asset: bool = source_path.begins_with("res://") or source_path.begins_with("user://") or source_path.begins_with(project_root)
	if is_project_asset:
		var imported_scene: PackedScene = ResourceLoader.load(source_path) as PackedScene
		if imported_scene != null:
			return {"success": true, "packed_scene": imported_scene, "mode": "imported"}
	if not ["glb", "gltf"].has(source_path.get_extension().to_lower()):
		return _failure("SOURCE_LOAD_FAILED", "Godot was unable to load the imported 3D resource.", source_path)

	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var load_error: Error = document.append_from_file(source_path, state)
	if load_error != OK:
		return _failure("SOURCE_RUNTIME_LOAD_FAILED", "Godot's runtime glTF importer could not read the source.", source_path, load_error)
	var generated_scene: Node = document.generate_scene(state)
	if generated_scene == null:
		return _failure("SOURCE_RUNTIME_SCENE_FAILED", "Godot's runtime glTF importer did not generate a scene.", source_path)
	var packed_scene: PackedScene = PackedScene.new()
	var pack_error: Error = packed_scene.pack(generated_scene)
	generated_scene.free()
	if pack_error != OK:
		return _failure("SOURCE_RUNTIME_PACK_FAILED", "Godot could not prepare the runtime-imported scene for rendering.", source_path, pack_error)
	return {"success": true, "packed_scene": packed_scene, "mode": "runtime"}

func _failure(code: String, message: String, source_path: String, godot_error: Error = OK) -> Dictionary:
	var error: Dictionary = {"code": code, "message": message, "source": source_path}
	if godot_error != OK:
		error["godot_error"] = godot_error
	return {"success": false, "source": source_path, "error": error}
