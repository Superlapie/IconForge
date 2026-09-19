extends RefCounted
class_name IconStudioFileUtil

const APP_DIR: String = "user://iconstudio"

static func ensure_directory(path: String) -> Error:
	var absolute: String = path
	if path.begins_with("res://") or path.begins_with("user://"):
		absolute = ProjectSettings.globalize_path(path)
	var dir_path: String = absolute.get_base_dir() if not absolute.ends_with("/") else absolute.trim_suffix("/")
	if dir_path.is_empty():
		return OK
	var error: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	return OK if error == OK or error == ERR_ALREADY_EXISTS else error

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func safe_replace_file(temp_path: String, destination_path: String) -> Error:
	if not FileAccess.file_exists(temp_path):
		return ERR_FILE_NOT_FOUND
	var absolute_temp: String = ProjectSettings.globalize_path(temp_path) if temp_path.begins_with("res://") or temp_path.begins_with("user://") else temp_path
	var absolute_destination: String = ProjectSettings.globalize_path(destination_path) if destination_path.begins_with("res://") or destination_path.begins_with("user://") else destination_path
	var dir_error: Error = ensure_directory(absolute_destination)
	if dir_error != OK:
		return dir_error
	var backup_path: String = "%s.bak.%s" % [absolute_destination, str(Time.get_ticks_usec())]
	var had_destination: bool = FileAccess.file_exists(absolute_destination)
	if had_destination:
		var copy_error: Error = DirAccess.copy_absolute(absolute_destination, backup_path)
		if copy_error != OK:
			return copy_error
	var rename_error: Error = DirAccess.rename_absolute(absolute_temp, absolute_destination)
	if rename_error != OK:
		if had_destination and FileAccess.file_exists(backup_path):
			if FileAccess.file_exists(absolute_destination):
				DirAccess.remove_absolute(absolute_destination)
			DirAccess.rename_absolute(backup_path, absolute_destination)
		return rename_error
	if had_destination and FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	return OK

static func write_json_atomic(path: String, value: Variant) -> Error:
	var dir_error: Error = ensure_directory(path)
	if dir_error != OK:
		return dir_error
	var temp_path: String = "%s.tmp.%s" % [path, str(Time.get_ticks_usec())]
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	file.close()
	return safe_replace_file(temp_path, path)

static func write_text_atomic(path: String, content: String) -> Error:
	var dir_error: Error = ensure_directory(path)
	if dir_error != OK:
		return dir_error
	var temp_path: String = "%s.tmp.%s" % [path, str(Time.get_ticks_usec())]
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	file.close()
	return safe_replace_file(temp_path, path)

static func file_hash(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "missing"
	return FileAccess.get_sha256(path)

static func source_name(path: String) -> String:
	return path.get_file().get_basename()

static func normalize_path(path: String) -> String:
	return path.replace("\\", "/")

static func is_supported_source(path: String) -> bool:
	return ["glb", "gltf", "png", "jpg", "jpeg", "webp"].has(path.get_extension().to_lower())

static func collect_sources(path: String, recursive: bool = true) -> Array[String]:
	var output: Array[String] = []
	if FileAccess.file_exists(path):
		if is_supported_source(path):
			output.append(path)
		return output
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return output
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return output
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child: String = path.path_join(entry)
			if dir.current_is_dir():
				if recursive:
					output.append_array(collect_sources(child, true))
			elif is_supported_source(child) and not is_embedded_texture_output(child):
				output.append(child)
		entry = dir.get_next()
	dir.list_dir_end()
	output.sort()
	return output

static func is_embedded_texture_output(path: String) -> bool:
	# Godot extracts embedded GLB textures beside the source as names such as
	# Model_0.png. They are dependencies of the model, not independent batch
	# inputs. Keep explicit user images supported unless a sibling GLB/glTF with
	# the matching base name proves this is an importer-generated texture.
	var extension: String = path.get_extension().to_lower()
	if not ["png", "jpg", "jpeg", "webp"].has(extension):
		return false
	var stem: String = source_name(path)
	var separator: int = stem.rfind("_")
	if separator <= 0:
		return false
	var suffix: String = stem.substr(separator + 1)
	if not suffix.is_valid_int():
		return false
	var base: String = stem.substr(0, separator)
	var parent: String = path.get_base_dir()
	return FileAccess.file_exists(parent.path_join(base + ".glb")) or FileAccess.file_exists(parent.path_join(base + ".gltf"))

static func ensure_unique_output(path: String, used: Dictionary) -> String:
	var candidate: String = path
	var stem: String = path.get_basename()
	var extension: String = path.get_extension()
	var index: int = 2
	while used.has(candidate) or FileAccess.file_exists(candidate):
		candidate = "%s_%d.%s" % [stem, index, extension]
		index += 1
	used[candidate] = true
	return candidate
