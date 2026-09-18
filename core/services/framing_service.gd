extends RefCounted
class_name FramingService

const ORIENTATION_STRATEGIES: Array[String] = [
	"preserve", "longest_axis_diagonal", "upright", "weapon_diagonal",
	"shield_frontal", "potion_three_quarter", "helmet_three_quarter",
	"creature_portrait", "character_full_body"
]

func resolve_camera(preset: PresetDefinition, inspection: Dictionary, override: Dictionary = {}) -> Dictionary:
	var camera: Dictionary = preset.data.get("camera", {}).duplicate(true)
	var composition: Dictionary = preset.data.get("composition", {}).duplicate(true)
	var resolved_override: Dictionary = override.duplicate(true)
	var flat_camera_keys: Array[String] = ["yaw", "pitch", "roll", "fov", "distance", "orthographic_size", "occupancy", "padding"]
	for key in flat_camera_keys:
		if resolved_override.has(key):
			camera[key] = resolved_override[key]
	if resolved_override.has("camera"):
		camera = PresetDefinition.deep_merge(camera, resolved_override["camera"])
	for key in ["scale", "vertical_bias", "horizontal_bias"]:
		if resolved_override.has(key):
			composition[key] = resolved_override[key]

	var dimensions: Vector3 = _array_to_vector(inspection.get("dimensions", [1.0, 1.0, 1.0]))
	var center: Vector3 = _array_to_vector(inspection.get("center", [0.0, 0.0, 0.0]))
	var strategy: String = str(camera.get("orientation_strategy", "preserve"))
	var orientation: Vector3 = Vector3(float(camera.get("pitch", 0.0)), float(camera.get("yaw", 0.0)), float(camera.get("roll", 0.0)))
	orientation += strategy_rotation(strategy, dimensions)
	var scale: float = clampf(float(composition.get("scale", 1.0)), 0.05, 20.0)
	var occupancy: float = clampf(float(camera.get("occupancy", 0.82)), 0.05, 0.99)
	var padding: float = clampf(float(camera.get("padding", 0.08)), 0.0, 0.45)
	var effective_occupancy: float = clampf(occupancy * (1.0 - padding), 0.05, 0.99)
	var radius: float = maxf(dimensions.length() * 0.5, 0.001)
	var max_dimension: float = maxf(maxf(dimensions.x, dimensions.y), dimensions.z)
	var ortho_size: float = float(camera.get("orthographic_size", 2.4))
	var fov: float = clampf(float(camera.get("fov", 34.0)), 5.0, 170.0)
	var distance: float = maxf(float(camera.get("distance", 3.0)), radius * 2.0)
	if bool(camera.get("auto_frame", true)):
		# The bounding sphere is conservative under arbitrary yaw/pitch/roll,
		# which is preferable to clipping a production asset.
		ortho_size = maxf(radius * 2.0 / effective_occupancy, max_dimension * 0.75 / effective_occupancy)
		ortho_size /= scale
		var half_fov: float = deg_to_rad(fov * 0.5)
		distance = maxf(radius / maxf(tan(half_fov), 0.001) / effective_occupancy, radius * 2.0)
		distance /= scale
	var target: Vector3 = _array_to_vector(camera.get("target", [0.0, 0.0, 0.0]))
	if str(composition.get("center_mode", "aabb")) == "aabb":
		target = center
	target.y += float(composition.get("vertical_bias", 0.0)) * dimensions.y
	target.x += float(composition.get("horizontal_bias", 0.0)) * dimensions.x
	var target_offset: Vector3 = _array_to_vector(camera.get("offset", [0.0, 0.0, 0.0]))
	target += target_offset
	return {
		"projection": str(preset.data.get("projection", "orthographic")),
		"orientation": orientation,
		"target": target,
		"radius": radius,
		"dimensions": dimensions,
		"orthographic_size": clampf(ortho_size, float(camera.get("min_zoom", 0.1)), float(camera.get("max_zoom", 100.0))),
		"fov": fov,
		"distance": distance,
		"occupancy": occupancy,
		"padding": padding,
		"scale": scale,
		"strategy": strategy
	}

func strategy_rotation(strategy: String, dimensions: Vector3) -> Vector3:
	match strategy:
		"longest_axis_diagonal":
			return Vector3(-8.0, 22.0, -28.0)
		"upright":
			return Vector3(0.0, 0.0, 0.0)
		"weapon_diagonal":
			return Vector3(-10.0, 22.0, -34.0 if dimensions.x >= dimensions.z else 34.0)
		"shield_frontal":
			return Vector3(-4.0, 0.0, 0.0)
		"potion_three_quarter":
			return Vector3(-8.0, 28.0, 0.0)
		"helmet_three_quarter":
			return Vector3(-8.0, 32.0, 0.0)
		"creature_portrait":
			return Vector3(-4.0, 18.0, 0.0)
		"character_full_body":
			return Vector3(-3.0, 12.0, 0.0)
	return Vector3.ZERO

func correction_size(current_size: float, target_occupancy: float, actual_occupancy: float, clipped: bool, minimum: float, maximum: float) -> float:
	if clipped or actual_occupancy > 0.96:
		return clampf(current_size * 1.20, minimum, maximum)
	if actual_occupancy < 0.02:
		return clampf(current_size * 0.65, minimum, maximum)
	if actual_occupancy < target_occupancy * 0.96:
		return clampf(current_size * actual_occupancy / maxf(target_occupancy, 0.01), minimum, maximum)
	if actual_occupancy > target_occupancy * 1.08:
		return clampf(current_size * actual_occupancy / maxf(target_occupancy, 0.01), minimum, maximum)
	return current_size

func _array_to_vector(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
