extends RefCounted
class_name CliRecipe

static func build_render_command(source_path: String, preset_id: String, override: Dictionary, output_path: String = "") -> String:
	var parts: PackedStringArray = PackedStringArray(["iconstudio render \"%s\"" % source_path, "--preset %s" % preset_id])
	for key in ["yaw", "pitch", "roll", "occupancy", "padding", "scale"]:
		if override.has(key):
			parts.append("--%s %s" % [key, _format_value(key, override[key])])
	if not output_path.is_empty():
		parts.append("--output \"%s\"" % output_path)
	return " \\\n  ".join(parts)

static func build_effective_preset_json(preset: PresetDefinition, override: Dictionary) -> String:
	if preset == null:
		return "{}"
	var merged: Dictionary = preset.data.duplicate(true)
	for key in override.keys():
		if key == "camera" or key == "composition":
			continue
		merged[key] = override[key]
	var camera: Dictionary = merged.get("camera", {}).duplicate(true)
	for key in ["yaw", "pitch", "roll", "occupancy", "padding", "fov", "distance", "orthographic_size"]:
		if override.has(key):
			camera[key] = override[key]
	merged["camera"] = camera
	var composition: Dictionary = merged.get("composition", {}).duplicate(true)
	if override.has("scale"):
		composition["scale"] = override["scale"]
	merged["composition"] = composition
	return JSON.stringify(merged, "\t")

static func _format_value(key: String, value: Variant) -> String:
	if key == "occupancy" or key == "padding":
		return "%.2f" % float(value)
	if key == "scale":
		return "%.2f" % float(value)
	return str(value)
